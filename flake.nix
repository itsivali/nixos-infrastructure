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
      username = "ivali";
      hostName = "prague";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

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

        # FIX: required for `nix build` / CI default behavior
        default =
          self.nixosConfigurations.${hostName}.config.system.build.toplevel;

        # Standalone home-manager activation for user config only
        hm-activate =
          self.nixosConfigurations.${hostName}.config.home-manager.users.${username}.home.activationPackage;
      };

      # ─────────────────────────────────────────────
      # NixOS configuration
      # ─────────────────────────────────────────────
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
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              extraSpecialArgs = {
                inherit inputs username hostName;
              };

              users.${username} = import ./home/ivali.nix;
              backupFileExtension = "hm-backup";
            };
          }
        ];
      };

      # ─────────────────────────────────────────────
      # CI validation check
      # ─────────────────────────────────────────────
      checks.${system}.laptop-config = pkgs.runCommand "check-laptop-config" { } ''
        echo ${
          self.nixosConfigurations.${hostName}.config.system.build.toplevel.drvPath
        } > $out
      '';
    };
}
