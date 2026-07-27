##############################################################################
#
# Host Registry
#
# Purpose
# -------
# Central registry of all known hosts. Each host defines its identity
# and feature flags. The flake.nix imports this and generates
# nixosConfigurations for each host.
#
# Adding a new host:
#   1. Add an entry here
#   2. Run `ivali bootstrap host <name>` to generate hardware config
#   3. Commit and push
#
# Structure:
#   <name> = {
#     hostName      = "hostname";           # networking.hostName
#     userName      = "username";           # Home Manager user
#     repoPath      = "/home/user/repo";    # Path to this repo on the host
#     tags          = [ "tag:..." ];        # Tailscale ACL tags
#     tailnetDomain = "xxx.ts.net";         # Optional split DNS domain
#     gitlabRunnerTags = [ "nixos", "..." ]; # GitLab runner tags
#     sshAuthorizedKeys = [ "ssh-...", ... ]; # SSH public keys
#     sopsKeyPath     = "/home/user/.config/sops/age/keys.txt"; # SOPS age key path
#     features = {
#       secrets         = true;             # Enable SOPS secrets
#       gitlabRunner    = true;             # Enable self-hosted GitLab runner
#       bot             = true;             # Enable Telegram bot
#       tailscale       = true;             # Enable Tailscale
#       tailscaleExitNode = true;           # Advertise as exit node
#       ssh             = true;             # Enable SSH daemon
#     #     # };
#     config = { ... };                    # Additional NixOS config overrides
#   };
#
##############################################################################

{ lib, ... }:

{
  ############################################################################
  # DEFAULT HOST TEMPLATE
  # Used by `ivali bootstrap host` as the base for new hosts
  ############################################################################
  default = {
    hostName = "laptop";
    userName = "user";
    repoPath = "/home/user/nixos-infrastructure";
    tags = [ "tag:personal" ];
    tailnetDomain = null;
    gitlabRunnerTags = [ "nixos" "self-hosted" ];
    sshAuthorizedKeys = [ ];
    sopsKeyPath = "/home/user/.config/sops/age/keys.txt";
    features = {
      secrets = true;
      gitlabRunner = true;
      bot = true;
      tailscale = true;
      tailscaleExitNode = true;
      ssh = true;
    };
    config = { };
  };

  ############################################################################
  # TEST HOST: testvm
  # Used for testing ivali bootstrap host
  ############################################################################
  testvm = {
    hostName = "testvm";
    userName = "testuser";
    repoPath = "/home/testuser/nixos-infrastructure";
    tags = [ "tag:test" ];
    tailnetDomain = null;
    gitlabRunnerTags = [ "nixos" "testvm" ];
    sshAuthorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEY test@testvm" ];
    features = {
      secrets = false;
      gitlabRunner = false;
      bot = false;
      tailscale = false;
      tailscaleExitNode = false;
      ssh = true;
    };
    config = { };
  };


  prague = {
    hostName = "prague";
    userName = "ivali";
    repoPath = "/home/ivali/nixos-infrastructure";
    tags = [ "tag:personal" ];
    tailnetDomain = "codlet-trench.ts.net";
    gitlabRunnerTags = [ "nixos" "prague" "self-hosted" ];
    sshAuthorizedKeys = [ ];
    sopsKeyPath = "/home/ivali/.config/sops/age/keys.txt";
    features = {
      secrets = true;
      bitwarden = true;
      gitlabRunner = true;
      bot = true;
      tailscale = true;
      tailscaleExitNode = true;
      ssh = true;
    };
    config = {
      ivali.desktop.gnome.enable = true;
      # Disable observability stack until laptop upgrade
      ivali.observability.enable = lib.mkForce false;
      # GitLab is the source of truth; the reconciler applies validated
      # commits (GitHub Actions validates the mirror and reports back).
      fleet.gitopsReconciler.enable = true;
      # Periodic health observer + auto-rollback on genuine service regression.
      fleet.deploymentHealth.enable = true;
      fleet.deploymentHealth.enableRollback = true;
      # Outlook/Office365 SMTP OAuth2: register an Entra ID *public* client
      # app (Mobile & desktop), grant delegated `SMTP.Send` for
      # https://outlook.office365.com, then paste its Application (client) ID
      # here. One-time `sudo oauth2ms --email=itsivali@outlook.com
      # --client-id=<id> --tenant=consumers authorize` caches the token.
      fleet.notifications.oauthClientId = "PASTE_ENTRA_CLIENT_ID_HERE";

      # ── Proposed features enabled 2026-07-19 (#4, #5, #6) ──────────
      # #4 Lite observability: /proc collector + Telegram/email alerts.
      #    Writes /var/lib/observability/state.json (read by `ivali status`).
      fleet.observability.lite.enable = true;
      # #5 Bot dead-man's-switch: alert if the bot stops polling.
      fleet.bot.watchdog.enable = true;
      fleet.bot.watchdog.thresholdSec = 300;
      # #6 Canary gate: run a NixOS VM smoke test before activating a new
      #    generation. CPU/disk heavy on every deploy — re-enabled now that
      #    the GNOME/Hyprland setup is finalized.
      fleet.gitopsReconciler.canary = true;

      # ── Local development databases ─────────────────────────────────
      ivali.dev.databases.enable = true;

      # ── Google Cloud SDK + GKE ──────────────────────────────────────
      ivali.cloud.enable = true;
      # ivali.cloud.projectId = "your-gcp-project-id";

      # ── Wayland clipboard ───────────────────────────────────────────
      ivali.desktop.clipboard.enable = true;
    };
  };
}
