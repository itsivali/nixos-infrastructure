{ pkgs, lib, ... }:

let
  ivaliPurple = "bold #A78BFA";
  ivaliCyan = "bold #22D3EE";
  ivaliGreen = "bold #4ADE80";
  ivaliGray = "#9CA3AF";
  ivaliGold = "bold #FBBF24";
in

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = false;
      scan_timeout = 30;

      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_state"
        "$git_status"
        "$git_metrics"
        "$fill"
        "$time"
        "$line_break"
        "$nix_shell"
        "$nodejs"
        "$python"
        "$golang"
        "$cmd_duration"
        "$status"
        "$character"
      ];

      right_format = "";

      # ── Context ──────────────────────────────────────────────────

      username = {
        show_always = true;
        style_user = ivaliPurple;
        style_root = "bold red";
        format = "[ $user]($style) ";
      };

      hostname = {
        ssh_only = false;
        style = ivaliGreen;
        format = "[ $hostname]($style) ";
      };

      directory = {
        style = ivaliCyan;
        truncation_length = 3;
        truncate_to_repo = true;
        format = "[ $path]($style) ";
        home_symbol = " ";
        repo_root_format = "[ $repo_root]($style) ";
        read_only = " ";
      };

      # ── Git ──────────────────────────────────────────────────────

      git_branch = {
        style = ivaliPurple;
        format = "[ $branch]($style) ";
        only_attached = true;
      };

      git_state = {
        style = "bold yellow";
        format = "[\($state( $progress_current of $progress_total)\)]($style) ";
        cherry_pick = " cherry-pick";
        revert = " revert";
        merge = " merge";
        bisect = " bisect";
        am = " am";
        am_or_rebase = " am/rebase";
        rebase = " rebase";
      };

      git_status = {
        style = "bold yellow";
        format = "[\\( $all_status$ahead_behind \\)]($style) ";
        conflicted = "! ";
        ahead = "↑\${count}";
        behind = "↓\${count}";
        diverged = "⇡\${ahead_count}⇣\${behind_count}";
        untracked = "? ";
        stashed = "$ ";
        modified = "✎ ";
        staged = "+ ";
        renamed = "→ ";
        deleted = "✘ ";
      };

      git_metrics = {
        disabled = false;
        format = "[\(+$added -$deleted\)]($style) ";
        added_style = "bold green";
        deleted_style = "bold red";
        only_nonzero_diffs = true;
      };

      # ── Nix ──────────────────────────────────────────────────────

      nix_shell = {
        style = "bold yellow";
        symbol = "❄";
        format = "[$symbol]($style) ";
        impure_msg = "impure";
        pure_msg = "pure";
        heuristic = true;
      };

      # ── Languages (only shown when in relevant directory) ────────

      nodejs = {
        symbol = " ";
        style = "bold #22C55E";
        format = "[$symbol $version]($style) ";
        detect_extensions = [ "js" "ts" "jsx" "tsx" "mjs" "cjs" ];
        detect_files = [ "package.json" ".node-version" "tsconfig.json" ];
        not_if_venv = true;
      };

      python = {
        symbol = " ";
        style = "bold #FBBF24";
        format = "[$symbol $version]($style) ";
        pyenv_version_name = true;
        detect_extensions = [ "py" ];
        detect_files = [ "requirements.txt" "pyproject.toml" "Pipfile" "poetry.lock" ];
      };

      golang = {
        symbol = " ";
        style = "bold #60A5FA";
        format = "[$symbol $version]($style) ";
        detect_extensions = [ "go" ];
        detect_files = [ "go.mod" "go.sum" ];
      };

      docker = { disabled = true; };
      rust = { disabled = true; };
      localip = { disabled = true; };

      # ── Metadata ────────────────────────────────────────────────

      cmd_duration = {
        style = ivaliGray;
        format = "[⏱ $duration]($style) ";
        min_time = 500;
        show_milliseconds = true;
      };

      status = {
        style = "bold red";
        format = "[$status]($style) ";
        disabled = false;
        not_found_symbol = "✘";
        signal_symbol = "✘";
        pipestatus = true;
        pipestatus_separator = " ";
      };

      time = {
        style = ivaliGray;
        format = "[ $time]($style) ";
        disabled = false;
        time_format = "%H:%M:%S";
      };

      shlvl = {
        style = "bold yellow";
        format = "[$symbol\${shlvl}]($style) ";
        disabled = false;
        repeat = true;
        symbol = " ";
        threshold = 2;
      };

      # ── Prompt character ─────────────────────────────────────────

      character = {
        success_symbol = "[❯](bold #A78BFA)";
        error_symbol = "[❯](bold #F87171)";
        vicmd_symbol = "[❮](bold #4ADE80)";
        format = "$symbol ";
      };
    };
  };
}
