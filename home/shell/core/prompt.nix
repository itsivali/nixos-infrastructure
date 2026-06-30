{ pkgs, lib, ... }:

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
        "$localip"
        "$shlvl"
        "$nix_shell"
        "$directory"
        "$git_branch"
        "$git_status"
        "$git_metrics"
        "$custom.repo"
        "$line_break"
        "$character"
      ];

      right_format = "$cmd_duration$status";

      username = {
        show_always = true;
        style_user = "bold cyan";
        style_root = "bold red";
        format = "[ $user]($style)";
      };

      hostname = {
        ssh_only = false;
        style = "bold green";
        format = "@[$hostname]($style) ";
      };

      directory = {
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = true;
        format = "in [ $path]($style)";
        home_symbol = " ";
      };

      git_branch = {
        style = "bold purple";
        format = "on [$symbol$branch(:$remote_branch)]($style) ";
        symbol = " ";
      };

      git_status = {
        style = "bold yellow";
        format = "[\\[$all_status$ahead_behind\\]]($style) ";
        conflicted = " ";
        ahead = " \${count}";
        behind = " \${count}";
        diverged = " ⇡\${ahead_count}⇣\${behind_count}";
        untracked = " ";
        stashed = " ";
        modified = " ";
        staged = " ";
        renamed = " ";
        deleted = " ";
      };

      git_metrics = {
        disabled = false;
      };

      nix_shell = {
        style = "bold yellow";
        symbol = " ";
        format = "via [$symbol$state]($style) ";
        impure_msg = "impure";
        pure_msg = "pure";
        heuristic = true;
      };

      cmd_duration = {
        style = "bold yellow";
        format = "took [⏱ $duration]($style) ";
        show_milliseconds = true;
        min_time = 1;
      };

      status = {
        style = "bold red";
        format = "with [ $status]($style) ";
        disabled = false;
      };

      localip = {
        style = "bold yellow";
        format = "via [ $localipv4]($style) ";
        ssh_only = true;
      };

      shlvl = {
        style = "bold yellow";
        format = "[\${shlvl}]($style) ";
        disabled = false;
        repeat = true;
      };

      character = {
        success_symbol = "[](bold green)";
        error_symbol = "[](bold red)";
        vicmd_symbol = "[](bold green)";
        format = "$symbol ";
      };

      custom.repo = {
        command = lib.concatStrings [
          "if git rev-parse --show-toplevel 2>/dev/null | grep -q 'nixos-infrastructure$'; "
          "then echo '    infra'; "
          "fi"
        ];
        style = "bold green";
        format = "[■ $output]($style)";
        when = true;
        shell = "bash";
      };
    };
  };
}
