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
    inputs@{ self
    , nixpkgs
    , home-manager
    , sops-nix
    , ...
    }:
    let
      system = "x86_64-linux";
      username = "ivali";
      hostName = "prague";

      gitlabSshKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL6Yyxm9WHZEZ9COGXkkwlWsvgvN7RYX59SjdYGrucEt itsivali@outlook.com";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # ─────────────────────────────────────────────────────────────
      # Formatter
      # ─────────────────────────────────────────────────────────────
      formatter.${system} = pkgs.nixpkgs-fmt;

      # ─────────────────────────────────────────────────────────────
      # Packages
      # ─────────────────────────────────────────────────────────────
      packages.${system} = {
        system = pkgs.buildEnv {
          name = "ivali-system-packages";
          paths = import ./packages/system { inherit pkgs; };
        };

        user = pkgs.buildEnv {
          name = "ivali-user-packages";
          paths = import ./packages/user { inherit pkgs; };
        };
      };

      # ─────────────────────────────────────────────────────────────
      # CI DevShell (CRITICAL FIX)
      # replaces nix profile installs in CI
      # ─────────────────────────────────────────────────────────────
      devShells.${system}.ci = pkgs.mkShell {
        packages = with pkgs; [
          git
          cachix
          attic-client
          syft
          nix
          jq
        ];

        NIX_CONFIG = ''
          experimental-features = nix-command flakes
        '';
      };

      # ─────────────────────────────────────────────────────────────
      # NixOS configuration
      # ─────────────────────────────────────────────────────────────
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs self username hostName;
          gitlabUrl = "https://gitlab.com/willisivali/nixos-infrastructure";
        };

        modules = [
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager

          ./configuration.nix

          {
            nixpkgs.config.allowUnfree = true;

            nix = {
              settings = {
                experimental-features = [ "nix-command" "flakes" ];
                auto-optimise-store = true;

                trusted-users = [ "root" username ];

                substituters = [
                  "https://cache.nixos.org"
                ];

                trusted-substituters = [
                  "https://cache.nixos.org"
                ];

                builders-use-substitutes = true;

                warn-dirty = false;
              };

              gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 14d";
              };
            };

            users.users.${username} = {
              isNormalUser = true;
              description = "Wilis Ivali";
              extraGroups = [ "wheel" "networkmanager" "docker" "video" "audio" ];

              openssh.authorizedKeys.keys = [
                gitlabSshKey
              ];
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              extraSpecialArgs = {
                inherit inputs username hostName;
              };

              users.${username} = import ./home/ivali.nix;
              backupFileExtension = "hm-backup";
            };

            system.stateVersion = "26.05";
          }
        ];
      };

      # ─────────────────────────────────────────────────────────────
      # CI checks (FIXED)
      # now actually validates system build
      # ─────────────────────────────────────────────────────────────
      checks.${system} = {
        nixos = self.nixosConfigurations.${hostName}.config.system.build.toplevel;
      };
    };
}
