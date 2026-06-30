{ pkgs, lib, ... }:

let
  ivaliPurple = "bold #A78BFA";
  ivaliCyan  = "bold #22D3EE";
  ivaliGreen = "bold #4ADE80";
  ivaliGray  = "#9CA3AF";
in

{
  programs.zsh.plugins = [
    {
      name = "zsh-completions";
      src = pkgs.zsh-completions;
    }
  ];

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = true;
      scan_timeout = 10;

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
        "$custom.repo"
        "$fill"
        "$cmd_duration"
        "$status"
        "$line_break"
        "$character"
      ];

      right_format = "";

      # ── Context ──────────────────────────────────────────────────

      username = {
        show_always = true;
        style_user = ivaliPurple;
        style_root = "bold red";
        format = "[ $user]($style) ";
      };

      hostname = {
        ssh_only = false;
        style = ivaliGreen;
        format = "[ $hostname]($style) ";
      };

      directory = {
        style = ivaliCyan;
        truncation_length = 3;
        truncate_to_repo = true;
        format = "[ $path]($style) ";
        home_symbol = " ";
        repo_root_format = "[ $repo_root]($style) ";
      };

      # ── Git ──────────────────────────────────────────────────────

      git_branch = {
        style = ivaliPurple;
        format = "[ $branch]($style) ";
        symbol = "";
        only_attached = true;
      };

      git_state = {
        style = "bold yellow";
        format = "[\($state( $progress_current of $progress_total)\)]($style) ";
        cherry_pick = "�22 cherry-pick";
        revert = " revert";
        merge = " merge";
        bisect = " bisect";
        am = " am";
        am_or_revert = " am/revert";
        rebase = " rebase";
      };

      git_status = {
        style = "bold yellow";
        format = "[\\( $all_status$ahead_behind \\)]($style) ";
        conflicted = "";
        ahead = "\${count}";
        behind = "\${count}";
        diverged = "⇡\${ahead_count}⇣\${behind_count}";
        untracked = "";
        stashed = "";
        modified = "";
        staged = "";
        renamed = "";
        deleted = "";
      };

      git_metrics = {
        disabled = false;
        format = "[\(+$added ($deleted)\)]($style) ";
        added_style = "bold green";
        deleted_style = "bold red";
        only_nonzero = true;
      };

      # ── Nix ──────────────────────────────────────────────────────

      nix_shell = {
        style = "bold yellow";
        symbol = "";
        format = "[$symbol]($style) [$state]($style) ";
        impure_msg = "impure";
        pure_msg = "pure";
        heuristic = true;
      };

      # ── Utility modules (only shown when relevant) ───────────────

      nodejs = {
        symbol = "";
        style = "bold #22C55E";
        format = "via [$symbol(v$version) ]($style) ";
        detect_extensions = ["js" "ts" "jsx" "tsx" "mjs" "cjs"];
        detect_files = ["package.json" ".node-version" "tsconfig.json"];
        not_if_venv = true;
      };

      python = {
        symbol = "";
        style = "bold #FBBF24";
        format = "via [$symbol$version( \($virtualenv\))]($style) ";
        pyenv_version_name = true;
        detect_extensions = ["py"];
        detect_files = ["requirements.txt" "pyproject.toml" "Pipfile" "poetry.lock"];
      };

      docker = {
        symbol = "";
        style = "bold #60A5FA";
        format = "via [$symbol]($style) ";
        detect_extensions = [];
        detect_files = ["docker-compose.yml" "Dockerfile" ".dockerignore"];
      };

      golang = {
        symbol = "";
        style = "bold #60A5FA";
        format = "via [$symbol(v$version) ]($style) ";
        detect_extensions = ["go"];
        detect_files = ["go.mod" "go.sum"];
      };

      rust = {
        symbol = "";
        style = "bold #F87171";
        format = "via [$symbol(v$version) ]($style) ";
        detect_extensions = ["rs"];
        detect_files = ["Cargo.toml"];
      };

      # ── Metadata ────────────────────────────────────────────────

      cmd_duration = {
        style = ivaliGray;
        format = "[⏱ $duration]($style) ";
        show_milliseconds = true;
        min_time = 500;
      };

      status = {
        style = "bold red";
        format = "[ $status]($style) ";
        disabled = false;
        not_found = " not found";
        signal_symbol = " ";
        pipestatus = true;
        pipestatus_separator = "  ";
      };

      time = {
        style = ivaliGray;
        format = "[ $time]($style) ";
        disabled = false;
        time_format = "%T";
      };

      localip = {
        style = "bold yellow";
        format = "[ $localipv4]($style) ";
        ssh_only = true;
      };

      shlvl = {
        style = "bold yellow";
        format = "[$symbol\${shlvl}]($style) ";
        disabled = false;
        repeat = true;
        symbol = " ";
        threshold = 2;
      };

      # ── Prompt character ─────────────────────────────────────────

      character = {
        success_symbol = "[](bold #A78BFA)";
        error_symbol = "[](bold #F87171)";
        vicmd_symbol = "[](bold #4ADE80)";
        format = "$symbol ";
      };

      # ── Custom: IVALI repo context ──────────────────────────────

      custom.repo = {
        command = lib.concatStrings [
          "root=$(git rev-parse --show-toplevel 2>/dev/null) && "
          "basename=$(basename \"$root\" 2>/dev/null) && "
          "if [ \"$basename\" = \"nixos-infrastructure\" ]; then "
          "  echo \"  infra\"; "
          "elif git rev-parse --git-dir >/dev/null 2>&1; then "
          "  echo \"\"; "
          "fi"
        ];
        style = ivaliGreen;
        format = "[$output]($style) ";
        when = true;
        shell = "bash";
      };
    };
  };
}
