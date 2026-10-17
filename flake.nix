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

  };

  outputs =
    inputs@{ self, nixpkgs, home-manager, sops-nix, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      # Import host registry (auto-aggregates per-host specs from hosts/*.nix)
      hostsConfig = import ./hosts/hosts.nix { inherit lib; };

      # Default username (can be overridden per-host)
      defaultUsername = "ivali";

      # Repository-wide nixpkgs overlays (see lib/overlays/).
      repoOverlays = import ./lib/overlays;

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = repoOverlays;
      };

      # Hermetic source for the Go tools: only Go source + go.mod/go.sum.
      # Keeps the buildGoModule src hash stable across unrelated repo edits so
      # ivali / bw-tui are not rebuilt from scratch every switch.
      goSrc = import ./lib/go-src.nix { src = self; lib = lib; };

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
          vendorHash = "sha256-cGilGwaEoLUnkzxiMjbT6SdEE7nFKMp2gup7HlXnB5s=";
          subPackages = [ "cmd/bw-tui" ];
          preBuild = "export CGO_ENABLED=0";
        };

        ivali = pkgs.buildGoModule {
          name = "ivali";
          src = goSrc;
          vendorHash = "sha256-cGilGwaEoLUnkzxiMjbT6SdEE7nFKMp2gup7HlXnB5s=";
          subPackages = [ "cmd/ivali" ];
          preBuild = "export CGO_ENABLED=0";
        };

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
        automation-smoke = import ./tests/automation-smoke.nix { inherit pkgs sops-nix home-manager; };
        bitwarden-smoke = import ./tests/bitwarden-smoke.nix { inherit pkgs sops-nix home-manager; };

        # Regression guard for the anyio test-quarantine overlay
        # (lib/overlays/anyio-tests.nix). Fails evaluation, without building
        # anyio, if the overlay is no longer applied.
        anyio-test-quarantine =
          let
            expected = [
              "test_tls_connectable"
              "test_glob_recurse_symlinks"
              "test_rglob"
            ];
            disabled = pkgs.python312Packages.anyio.disabledTests or [ ];
            missing = builtins.filter (test: !(builtins.elem test disabled)) expected;
          in
          if missing == [ ] then
            pkgs.runCommand "anyio-test-quarantine" { } "touch $out"
          else
            throw "lib/overlays/anyio-tests.nix is not applied; missing disabledTests: ${builtins.concatStringsSep ", " missing}";

        # Regression guard for the collabora-desktop coda-qt link-fix overlay
        # (lib/overlays/collabora-desktop.nix + lib/overlays/patches/). Fails
        # evaluation, without building collabora-desktop, if the overlay is no
        # longer applied (e.g. the overlay is dropped before the pinned nixpkgs
        # contains upstream commit c2342c171205).
        collabora-desktop-link-fix =
          let
            fixPatch = ./lib/overlays/patches/collabora-desktop/0002-fix-coda-qt-link.patch;
            applied = builtins.any
              (p: builtins.toString p == builtins.toString fixPatch)
              (pkgs.collabora-desktop.patches or [ ]);
          in
          if applied then
            pkgs.runCommand "collabora-desktop-link-fix" { } "touch $out"
          else
            throw "lib/overlays/collabora-desktop.nix is not applied; missing 0002-fix-coda-qt-link.patch in pkgs.collabora-desktop.patches";
      };
    };
}
