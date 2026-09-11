##############################################################################
#
# IVALI Control Plane Aliases
#
# Purpose
# -------
# Shortcuts for the IVALI NixOS infrastructure control plane CLI.
#
# Ownership
# ---------
# ivali control plane
#
# Responsibilities
# ----------------
# - System status, health, and diagnostics (ivs, ivd, ivh)
# - Repository operations (ivg, ivx, ivscan, iviv)
# - Deployment workflow (ivdep, ivreb, ivup, ivrec)
# - Security and observability (ivsec, ivobs, ivlogs)
# - Documentation (ivdoc)
# - Development workflow aliases (flow, newfeature, ...) live in
#   nix.nix — keeping a single canonical source for those.
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    # ── Core ──────────────────────────────────────────────────────────
    iv = "ivali";
    ivs = "ivali status";
    ivd = "ivali doctor";
    ivv = "ivali verify";

    # ── Repository ────────────────────────────────────────────────────
    ivg = "ivali graph";
    ivx = "ivali explain";
    ivscan = "ivali scan";
    iviv = "ivali inventory";
    ivsearch = "ivali search";

    # ── Deployment ────────────────────────────────────────────────────
    ivdep = "ivali deploy";
    ivreb = "ivali rebuild";
    ivup = "ivali update";
    ivrec = "ivali reconcile";
    ivb = "ivali bootstrap";

    # ── Observability ─────────────────────────────────────────────────
    ivobs = "ivali observability";
    ivlogs = "ivali logs";
    ivmet = "ivali metrics";
    ivhealth = "ivali health";
    ivmon = "ivali monitor";

    # ── Security ──────────────────────────────────────────────────────
    ivsec = "ivali security";
    ivsecscan = "ivali security-scan";
    ivfw = "ivali firewall";

    # ── Desktop / Remote / Cloud ──────────────────────────────────────
    remote = "ivali remote";
    rdp = "ivali remote status";
    rdp-creds = "ivali remote credentials";
    cloud = "ivali cloud";
    od = "ivali cloud onedrive status";
    odsetup = "ivali cloud onedrive setup";
    od-start = "onedrive --monitor";
    audio = "ivali desktop audio";

    # ── Other ─────────────────────────────────────────────────────────
    ivdoc = "ivali docs";
    ivdiff = "ivali diff";
    ivrem = "ivali remediation";
    ivrb = "ivali rollback";
    ivbk = "ivali backup";
    ivrs = "ivali restore";
    ivsuggest = "ivali suggest";
    ivai = "ivali ai";
    ivts = "ivali tailscale";
    ivsecrets = "ivali secrets";
    ivusers = "ivali users";
  };
}
