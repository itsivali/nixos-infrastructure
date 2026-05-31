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
      system   = "x86_64-linux";
      username = "ivali";
      hostName = "prague";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # ── formatter ────────────────────────────────────────────────────────────
      formatter.${system} = pkgs.nixpkgs-fmt;

      # ── package envs (for inspection / nix build .#system) ───────────────────
      packages.${system} = {
        system = pkgs.buildEnv {
          name  = "ivali-system-packages";
          # import returns a list; buildEnv.paths expects a list — correct.
          paths = import ./packages/system { inherit pkgs; };
        };
        user = pkgs.buildEnv {
          name  = "ivali-user-packages";
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
          # Custom NixOS modules (defines ivali.tailscale and any other
          # ivali.* options used in configuration.nix).
          ./modules
          ./configuration.nix
          {
            nixpkgs.config.allowUnfree = true;
            nix = {
              settings = {
                experimental-features = [ "nix-command" "flakes" ];
                auto-optimise-store   = true;
                trusted-users         = [ "root" username ];
                substituters          = [ "https://cache.nixos.org" ];
                warn-dirty            = false;
              };
              gc = {
                automatic = true;
                dates     = "weekly";
                options   = "--delete-older-than 14d";
              };
            };
            users.users.${username} = {
              isNormalUser  = true;
              description   = "Willis Ivali";
              extraGroups   = [ "wheel" "networkmanager" "docker" "video" "audio" ];
            };
            home-manager = {
              useGlobalPkgs       = true;
              useUserPackages     = true;
              extraSpecialArgs    = { inherit inputs username hostName; };
              users.${username}   = import ./home/ivali.nix;
              backupFileExtension = "hm-backup";
            };
            system.stateVersion = "25.11";
          }
        ];
      };

      # ── CI checks ─────────────────────────────────────────────────────────────
      # checks.* is what `nix flake check` evaluates and (optionally) builds.
      # Pointing it at toplevel.drvPath gives us a lightweight eval-only check
      # that works even without QEMU or a clean tree.
      # The VM smoke test is gated behind an explicit `nix build .#checks...`
      # rather than running on every `nix flake check`.
      checks.${system} = {
        # Evaluates the full NixOS config; fails fast on type errors.
        # Does NOT build the system — it only derives the .drv path.
        laptop-config = pkgs.runCommand "check-laptop-config" { } ''
          echo ${
            self.nixosConfigurations.${hostName}.config.system.build.toplevel.drvPath
          } > $out
        '';
      };
    };
}