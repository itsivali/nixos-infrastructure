{ pkgs, config, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";
in

{
  programs.zsh.initContent = ''
    ######################################################################
    # Auto-dashboard — launch ivali dashboard on cd into repo
    ######################################################################
    _ivali_auto_dashboard() {
      # Only trigger on interactive terminals
      [[ -z "$SSH_TTY" ]] || return
      [[ $TERM != "dumb" ]] || return

      local repo_dir="${repoDir}"

      # Check if we just entered the repo directory
      if [[ "$PWD" == "$repo_dir" || "$PWD" == "$repo_dir"/* ]]; then
        # Only show once per shell session
        if [[ -z "$IVALI_DASHBOARD_SHOWN" ]] && command -v ivali &>/dev/null; then
          export IVALI_DASHBOARD_SHOWN=1
          # Brief health summary on cd, not the full TUI (use `ivali dashboard` for that)
          ivali status 2>/dev/null || true
        fi
      fi
    }

    # Register chpwd hook (avoid Nix interpolation with ''$)
    typeset -ag chpwd_functions
    if [[ -z "''${chpwd_functions[(r)_ivali_auto_dashboard]}" ]]; then
      chpwd_functions+=(_ivali_auto_dashboard)
    fi

    # Run once on initial shell start
    _ivali_auto_dashboard
  '';
}
