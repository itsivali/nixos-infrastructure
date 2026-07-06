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

      # Import host registry
      hostsConfig = import ./hosts/hosts.nix { inherit lib; };

      # Default username (can be overridden per-host)
      defaultUsername = "ivali";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Generate nixosConfigurations for each host
      nixosConfigurations = lib.mapAttrs (name: hostSpec:
        lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit inputs self;
            hostSpec = hostSpec;
            defaultUsername = hostSpec.userName or defaultUsername;
            username = hostSpec.userName or defaultUsername;
            gitlabUrl = "https://gitlab.com/willisivali/nixos-infrastructure";
          };

          modules = [
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager

            ./configuration.nix

            # Host-specific hardware configuration
            ./hosts/hardware-configuration.nix

            # Host-specific configuration from template
            ./lib/host-templates/laptop.nix

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
      ) hostsConfig;
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
            ++ (import ./packages/desktop { inherit pkgs; });
        };

        user = pkgs.buildEnv {
          name = "ivali-user-packages";
          paths = import ./packages/user { inherit pkgs; };
        };

        bw = pkgs.buildGoModule {
          name = "bw";
          src = pkgs.lib.cleanSourceWith {
            filter = name: type:
              !(type == "directory" && builtins.baseNameOf name == "vendor")
            ;
            src = self;
          };
          vendorHash = "sha256-26Sj0Wx3u1tfgxjJey3fpa/wGqh+7/MCVEGJZgWzbzU=";
          subPackages = [ "cmd/bw" ];
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
    };
}