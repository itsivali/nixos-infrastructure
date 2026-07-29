##############################################################################
#
# Prague — Primary Host (AMD Laptop)
#
# Purpose
# -------
# Host spec for prague: full SRE/development workstation with GNOME,
# GitOps, observability, Telegram bot, and local dev databases.
#
##############################################################################

{ lib, ... }:

{
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
    ivali.desktop.hyprland.enable = true;
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
}
