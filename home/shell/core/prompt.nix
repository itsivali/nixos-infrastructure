##############################################################################
#
# Prompt
#
# Purpose
# -------
# Auto-generated module description.
#
##############################################################################

{ pkgs, lib, ... }:

let
  # Starship's prompt accent palette. Kept as its own Garuda-style accent set
  # (it predates the Gruvbox terminal theme; no longer tied to the emulator).
  ivaliPurple = "bold #CBA6F7"; # mauve
  ivaliCyan = "bold #89DCEB"; # sky
  ivaliGreen = "bold #A6E3A1"; # green
  ivaliGray = "#6C7086"; # overlay0
  ivaliGold = "bold #F9E1AF"; # yellow
  ivaliRed = "bold #F38BA8"; # red
  ivaliBlue = "bold #89B4FA"; # blue
  ivaliPink = "bold #F5C2E7"; # pink
  ivaliOrange = "bold #FAB387"; # peach
  ivaliText = "#CDD6F4"; # text
in

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = false;
      scan_timeout = 30;

      format = lib.concatStrings [
        # ── Top line ────────────────────────────────────────────────
        "╭─"
        "$username"
        "$container"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_status"
        "$git_metrics"
        "$fill"
        "$sudo"
        "$battery"
        "$time"
        "$line_break"
        # ── Bottom line ─────────────────────────────────────────────
        "╰─"
        "$nix_shell"
        "$shell"
        "$nodejs│"
        "$python│"
        "$golang│"
        "$docker_context│"
        "$memory_usage│"
        "$custom.disk│"
        "$cmd_duration│"
        "$status│"
        "$os│"
        "$character"
      ];

      right_format = "";

      # ── Context ──────────────────────────────────────────────────

      username = {
        show_always = true;
        style_user = ivaliPurple;
        style_root = ivaliRed;
        format = "[  $user]($style) ";
      };

      hostname = {
        ssh_only = false;
        style = ivaliGreen;
        format = "[ 󰒋 $hostname]($style) ";
      };

      container = {
        style = "dimmed white";
        format = "[  $name]($style) ";
      };

      directory = {
        style = ivaliCyan;
        truncation_length = 3;
        truncate_to_repo = true;
        format = "[  $path]($style) ";
        home_symbol = "~";
        repo_root_format = "[  $repo_root]($style) ";
        read_only = " ";
      };

      # ── Git ──────────────────────────────────────────────────────

      git_branch = {
        style = ivaliGreen;
        format = "[ $symbol$branch(:$remote_branch)]($style) ";
        symbol = " ";
        only_attached = true;
        always_show_remote = false;
      };

      # Garuda-style commit display: last commit hash + current tag
      git_commit = {
        style = ivaliBlue;
        format = "[\($hash$tag\)]($style) ";
        tag_symbol = "  ";
        tag_disabled = false;
        only_detached = false;
      };

      git_state = {
        style = ivaliGold;
        format = "[  $state( $progress_current of $progress_total)]($style) ";
        cherry_pick = "cherry-pick";
        revert = "revert";
        merge = "merge";
        bisect = "bisect";
        am = "am";
        am_or_rebase = "am/rebase";
        rebase = "rebase";
      };

      git_status = {
        style = ivaliText;
        format = "[\\($all_status$ahead_behind\\)]($style) ";
        conflicted = " ";
        ahead = "\${count}";
        behind = "\${count}";
        diverged = "\${ahead_count}\${behind_count}";
        up_to_date = " ";
        untracked = " ";
        stashed = " ";
        modified = " ";
        staged = " ";
        renamed = " ";
        deleted = "x";
      };

      git_metrics = {
        disabled = false;
        format = "[+$added]($added_style)/[-$deleted]($deleted_style) ";
        added_style = ivaliGreen;
        deleted_style = ivaliRed;
        only_nonzero_diffs = true;
      };

      # ── Nix ──────────────────────────────────────────────────────

      nix_shell = {
        style = ivaliGold;
        symbol = " ";
        format = "[ $symbol]($style) ";
        impure_msg = "impure";
        pure_msg = "pure";
        heuristic = true;
      };

      shell = {
        style = ivaliGray;
        disabled = false;
        format = "[  $indicator]($style) ";
        zsh_indicator = "zsh";
        fish_indicator = "fish";
        bash_indicator = "bash";
      };

      # ── Languages (only shown when in relevant directory) ────────

      nodejs = {
        style = ivaliGreen;
        format = "[  $version]($style) ";
        detect_extensions = [ "js" "ts" "jsx" "tsx" "mjs" "cjs" ];
        detect_files = [ "package.json" ".node-version" "tsconfig.json" ];
      };

      python = {
        style = ivaliGold;
        format = "[  $version]($style) ";
        pyenv_version_name = true;
        detect_extensions = [ "py" ];
        detect_files = [ "requirements.txt" "pyproject.toml" "Pipfile" "poetry.lock" ];
      };

      golang = {
        style = ivaliCyan;
        format = "[ $version nix]($style) ";
        detect_extensions = [ "go" ];
        detect_files = [ "go.mod" "go.sum" ];
      };

      docker_context = {
        style = ivaliPink;
        only_with_files = false;
        format = "[  $context]($style) ";
      };

      # ── System resources ──────────────────────────────────────────

      memory_usage = {
        disabled = false;
        threshold = -1;
        style = ivaliGray;
        format = "[ 󰍛 $ram_pct RAM]($style) ";
      };

      # Starship has no built-in disk module; use a custom one.
      custom = {
        disk = {
          command = "df -h / | awk 'NR==2 {printf \"%s/%s\", $3, $2}'";
          shell = "bash";
          style = ivaliGray;
          format = "[ 󰋊 Disk $output]($style) ";
        };
      };

      rust = { disabled = true; };
      localip = { disabled = true; };

      # ── Metadata ────────────────────────────────────────────────

      cmd_duration = {
        style = ivaliGray;
        format = "[ ⏱ $duration]($style) ";
        min_time = 500;
        show_milliseconds = true;
      };

      status = {
        style = ivaliRed;
        format = "[✗ $status]($style) ";
        disabled = false;
        pipestatus = true;
        pipestatus_separator = "|";
        success_symbol = "";
      };

      time = {
        style = ivaliGray;
        format = "[  $time]($style) ";
        disabled = false;
        time_format = "%H:%M";
      };

      shlvl = {
        style = ivaliGold;
        format = "[  \${shlvl}]($style) ";
        disabled = false;
        repeat = true;
        symbol = " ";
        threshold = 2;
      };

      sudo = {
        style = ivaliText;
        format = "[ as $user]($style) ";
        disabled = false;
      };

      battery = {
        disabled = false;
        format = "[$symbol$percentage]($style) ";
        display = [
          { threshold = 20; style = ivaliRed; }
          { threshold = 50; style = ivaliGold; }
          { threshold = 100; style = ivaliGreen; }
        ];
      };

      # ── NixOS snowflake ──────────────────────────────────────────
      os = {
        disabled = false;
        style = ivaliPurple;
        format = "[ ]($style)";
      };

      # ── Prompt character ─────────────────────────────────────────

      character = {
        success_symbol = "[❯](bold #A6E3A1)";
        error_symbol = "[❯](bold #F38BA8)";
        vicmd_symbol = "[❮](bold #A6E3A1)";
        format = " $symbol";
      };
    };
  };

  programs.zsh.initContent = ''
    # Refresh prompt every 10s so RAM/battery/time stay current
    TMOUT=10
    TRAPALRM() {
        zle reset-prompt 2>/dev/null
    }
  '';
}
