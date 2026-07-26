##############################################################################
#
# Flake
#
# Purpose
# -------
# Autonomous NixOS and Home Manager infrastructure for ivali.
# Supports multiple hosts with dynamic configuration.
#
##############################################################################

{
  description = "Autonomous NixOS and Home Manager infrastructure for ivali";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, home-manager, sops-nix, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      # Import host registry
      hostsConfig = import ./hosts/hosts.nix { inherit lib; };

      # Default username (can be overridden per-host)
      defaultUsername = "ivali";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Hermetic source for the Go tools: only Go source + go.mod/go.sum.
      # Keeps the buildGoModule src hash stable across unrelated repo edits so
      # ivali / bw-tui / ivali-bot are not rebuilt from scratch every switch.
      goSrc = import ./lib/go-src.nix { src = self; lib = lib; };

      # Google Jules CLI — pre-built Go binary patched for NixOS
      julesVersion = "0.1.42";
      julesBinary = pkgs.stdenv.mkDerivation {
        pname = "jules-cli";
        version = julesVersion;
        src = pkgs.fetchurl {
          url = "https://storage.googleapis.com/jules-cli/v${julesVersion}/jules_external_v${julesVersion}_linux_amd64.tar.gz";
          hash = "sha256-c869LI+Jubsk703MuM15Q8y2npmzfeJnwvV5Mjen0QM=";
        };
        sourceRoot = ".";
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          mkdir -p $out/libexec/jules
          cp jules $out/libexec/jules/jules
          chmod +x $out/libexec/jules/jules
          runHook postInstall
        '';
      };
      julesWrapped = pkgs.writeShellScriptBin "jules" ''
        export JULES_CONFIG_DIR="''${JULES_CONFIG_DIR:-$HOME/.jules}"
        if [ -z "''${JULES_API_KEY:-}" ] && [ -f /run/secrets/jules-api-key ]; then
          export JULES_API_KEY="$(cat /run/secrets/jules-api-key)"
        fi
        exec ${julesBinary}/libexec/jules/jules "$@"
      '';

      # Generate nixosConfigurations for each host
      nixosConfigurations = lib.mapAttrs
        (name: hostSpec:
          lib.nixosSystem {
            inherit system;

            specialArgs = {
              inherit self inputs;
              flake = self;
              hostSpec = hostSpec;
              defaultUsername = hostSpec.userName or defaultUsername;
              username = hostSpec.userName or defaultUsername;
              gitlabUrl = "https://gitlab.com/willisivali/nixos-infrastructure";
            };

            modules = [
              sops-nix.nixosModules.sops
              home-manager.nixosModules.home-manager

              ./configuration.nix

              # Host-specific hardware configuration (per-host or fallback)
              (
                let
                  hostHw = ./hosts + "/${name}/hardware-configuration.nix";
                  fallbackHw = ./hosts/hardware-configuration.nix;
                in
                if builtins.pathExists hostHw then hostHw else fallbackHw
              )

              # Host-specific configuration from template
              ./lib/host-templates/laptop.nix

              # Feed the Go-built tools into the local binary cache module.
              # (Done here rather than via specialArgs so the caching module
              # stays usable under nixosTest, which does not forward them.)
              {
                goBinaryCache.packages = [
                  self.packages.${system}.ivali
                  self.packages.${system}.bw-tui
                  self.packages.${system}.ivali-bot
                ];
              }

              # Home Manager user configuration
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;

                  extraSpecialArgs = {
                    inherit inputs hostSpec defaultUsername;
                    hostName = hostSpec.hostName;
                    username = hostSpec.userName or defaultUsername;
                  };

                  users.${hostSpec.userName or defaultUsername} = import ./home/ivali.nix;
                  backupFileExtension = "hm-backup";
                };
              }
            ];
          }
        )
        hostsConfig;
    in
    {
      # ─────────────────────────────────────────────
      # Formatter
      # ─────────────────────────────────────────────
      formatter.${system} = pkgs.nixpkgs-fmt;

      # ─────────────────────────────────────────────
      # Package sets
      # ─────────────────────────────────────────────
      packages.${system} = {
        system = pkgs.buildEnv {
          name = "ivali-system-packages";
          paths =
            (import ./packages/cli { inherit pkgs; })
            ++ (import ./packages/desktop { inherit pkgs; })
            ++ [ self.packages.${system}.bw-tui ];
        };

        user = pkgs.buildEnv {
          name = "ivali-user-packages";
          paths = (import ./packages/user { inherit pkgs; })
            ++ [ self.packages.${system}.bw-tui self.packages.${system}.ivali ];
        };

        bw-tui = pkgs.buildGoModule {
          name = "bw-tui";
          src = goSrc;
          vendorHash = "sha256-26Sj0Wx3u1tfgxjJey3fpa/wGqh+7/MCVEGJZgWzbzU=";
          subPackages = [ "cmd/bw-tui" ];
          preBuild = "export CGO_ENABLED=0";
        };

        ivali-bot = pkgs.buildGoModule {
          name = "ivali-bot";
          src = goSrc;
          vendorHash = "sha256-26Sj0Wx3u1tfgxjJey3fpa/wGqh+7/MCVEGJZgWzbzU=";
          subPackages = [ "cmd/ivali-bot" ];
          # Static pure-Go binary: avoids linking libresolv.so.2, whose
          # PROT_EXEC mmap is denied by the ivali-bot AppArmor profile
          # (caused the bot to exit 127 on every start).
          preBuild = "export CGO_ENABLED=0";
        };

        ivali = pkgs.buildGoModule {
          name = "ivali";
          src = goSrc;
          vendorHash = "sha256-26Sj0Wx3u1tfgxjJey3fpa/wGqh+7/MCVEGJZgWzbzU=";
          subPackages = [ "cmd/ivali" ];
          preBuild = "export CGO_ENABLED=0";
        };

        jules = julesWrapped;

        # FIX: required for `nix build` / CI default behavior
        default =
          self.nixosConfigurations.prague.config.system.build.toplevel;

        # Standalone home-manager activation for user config only
        hm-activate =
          self.nixosConfigurations.prague.config.home-manager.users.${defaultUsername}.home.activationPackage;
      };

      # ─────────────────────────────────────────────
      # NixOS configurations (generated above)
      # ─────────────────────────────────────────────
      inherit nixosConfigurations;

      # ─────────────────────────────────────────────
      # Checks (NixOS smoke tests for nix flake check)
      # ─────────────────────────────────────────────
      checks.${system} = {
        laptop-smoke = import ./tests/laptop-smoke.nix { inherit pkgs sops-nix home-manager; };
        security-smoke = import ./tests/security-smoke.nix { inherit pkgs sops-nix home-manager; };
        observability-smoke = import ./tests/observability-smoke.nix { inherit pkgs sops-nix home-manager; };
        services-smoke = import ./tests/services-smoke.nix { inherit pkgs sops-nix home-manager; };
        home-manager-smoke = import ./tests/home-manager-smoke.nix { inherit pkgs sops-nix home-manager; };
        bot-integration = import ./tests/bot-integration.nix { inherit pkgs sops-nix home-manager; };
        automation-smoke = import ./tests/automation-smoke.nix { inherit pkgs sops-nix home-manager; };
        bitwarden-smoke = import ./tests/bitwarden-smoke.nix { inherit pkgs sops-nix home-manager; };
        bot-desktop-smoke = import ./tests/bot-desktop-smoke.nix { inherit pkgs sops-nix home-manager; };
        jules-smoke = import ./tests/jules-smoke.nix { inherit pkgs sops-nix home-manager; };
      };
    };
}
