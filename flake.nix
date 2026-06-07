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
      gitlabSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL6Yyxm9WHZEZ9COGXkkwlWsvgvN7RYX59SjdYGrucEt itsivali@outlook.com";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # ── formatter ─────────────────────────────────────────────────────────────
      formatter.${system} = pkgs.nixpkgs-fmt;

      # ── package envs ──────────────────────────────────────────────────────────
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

      # ── NixOS configuration ───────────────────────────────────────────────────
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self username hostName;
          gitlabUrl = "https://gitlab.com/willisivali/nixos-infrastructure";
        };
        modules = [
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          # configuration.nix is the root module. It imports every
          # subdirectory (boot, networking, security, developer, desktop,
          # observability, ci) including security/tailscale.nix which is
          # where ivali.tailscale options are defined.
          ./configuration.nix
          {
            nixpkgs.config.allowUnfree = true;
            nix = {
              settings = {
                experimental-features = [ "nix-command" "flakes" ];
                auto-optimise-store = true;
                trusted-users = [ "root" username ];
                substituters = [ "https://cache.nixos.org" ];
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
              extraSpecialArgs = { inherit inputs username hostName; };
              users.${username} = import ./home/ivali.nix;
              backupFileExtension = "hm-backup";
            };
            system.stateVersion = "26.05";
          }
        ];
      };

      # ── CI checks ─────────────────────────────────────────────────────────────
      # Evaluates the full NixOS config without building it.
      # Safe to run on a dirty tree; used by `nix flake check` and the
      # install script's validate step.
      checks.${system}.laptop-config = pkgs.runCommand "check-laptop-config" { } ''
        echo ${
          self.nixosConfigurations.${hostName}.config.system.build.toplevel.drvPath
        } > $out
      '';
    };
}
