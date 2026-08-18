##############################################################################
#
# Utility Aliases
#
# Purpose
# -------
# General shell utility aliases for daily use.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for general utilities
#
# Responsibilities
# ----------------
# - Screen and history (cls, h)
# - Safe defaults (mkdir, rm, df, free)
# - System inspection (ports, ip, psg, du, top)
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    cls = "clear";
    h = "history";
    mkdir = "mkdir -p";
    rm = "rm -I";
    df = "df -h";
    free = "free -h";
    ip = "ip -c addr";
    du = "du -h --max-depth=1";
    top = "btop";
    grep = "grep --color=auto";
    diff = "diff --color=auto";
    path = "echo $PATH | tr ':' '\\n' | nl";
  };
}
