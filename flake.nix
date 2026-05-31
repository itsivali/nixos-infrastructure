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
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      formatter.${system} = pkgs.nixpkgs-fmt;

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

      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self username hostName;
          gitlabUrl = "https://gitlab.com/willisivali/nixos-infrastructure";
        };
        modules = [
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager

          ./hosts/laptop.nix
          ./boot
          ./networking
          ./security
          ./developer
          ./desktop/gnome-lean.nix
          ./observability
          ./ci/gitlab-runner.nix

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
              };
              gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 14d";
              };
            };

            users.users.${username} = {
              isNormalUser = true;
              description = "Willis Ivali";
              extraGroups = [ "wheel" "networkmanager" "docker" "video" "audio" ];
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs username hostName; };
              users.${username} = import ./home/ivali.nix;
              backupFileExtension = "hm-backup";
            };

            system.stateVersion = "25.11";
          }
        ];
      };

      checks.${system}.laptop-toplevel =
        self.nixosConfigurations.${hostName}.config.system.build.toplevel;

      nixosTests.${system}.laptop-smoke =
        import ./tests/laptop-smoke.nix { inherit pkgs; };
    };
}
