##############################################################################
#
# Prompt
#
# Purpose
# -------
# Two-line Starship prompt for the NixOS infrastructure.
#
# Line 1: identity → OS → host → directory → git → fill → time
# Line 2: shell → nix → lang → resources → status → prompt char
#
# Design language
# ---------------
# • Nerd Font icons (FiraCode/JetBrainsMono)
# • Catppuccin Mocha palette — matches terminal theme
# • ─ fills dead space on line 1; │ groups resources on line 2
# • Color encodes meaning: green = healthy, red = error, dim = metadata
#
##############################################################################

{ pkgs, lib, ... }:

let
  # ── Catppuccin Mocha palette ─────────────────────────────────────────
  c = {
    rosewater = "#F5E0DC";
    flamingo = "#F2CDCD";
    pink = "#F5C2E7";
    mauve = "#CBA6F7";
    red = "#F38BA8";
    maroon = "#EBA0AC";
    peach = "#FAB387";
    yellow = "#F9E1AF";
    green = "#A6E3A1";
    teal = "#94E2D5";
    sky = "#89DCEB";
    sapphire = "#74C7EC";
    blue = "#89B4FA";
    lavender = "#B4BEFE";
    text = "#CDD6F4";
    subtext1 = "#BAC2DE";
    subtext0 = "#A6ADC8";
    overlay2 = "#9399B2";
    overlay1 = "#7F849C";
    overlay0 = "#6C7086";
    surface2 = "#585B70";
    surface1 = "#45475A";
    surface0 = "#313244";
    base = "#1E1E2E";
  };

  # Helper: wrap Starship variable refs so Nix doesn't interpret ${}.
  # "$var" works in Nix because only "${" triggers interpolation.
  v = name: "$" + name;
in

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = false;
      scan_timeout = 30;
      palette = "catppuccin";

      # ── Palette ─────────────────────────────────────────────────────
      palettes.catppuccin = {
        "rosewater" = c.rosewater;
        "flamingo" = c.flamingo;
        "pink" = c.pink;
        "mauve" = c.mauve;
        "red" = c.red;
        "maroon" = c.maroon;
        "peach" = c.peach;
        "yellow" = c.yellow;
        "green" = c.green;
        "teal" = c.teal;
        "sky" = c.sky;
        "sapphire" = c.sapphire;
        "blue" = c.blue;
        "lavender" = c.lavender;
        "text" = c.text;
        "subtext1" = c.subtext1;
        "subtext0" = c.subtext0;
        "overlay2" = c.overlay2;
        "overlay1" = c.overlay1;
        "overlay0" = c.overlay0;
        "surface2" = c.surface2;
        "surface1" = c.surface1;
        "surface0" = c.surface0;
        "base" = c.base;
      };

      # ── Layout ──────────────────────────────────────────────────────
      format = lib.concatStrings [
        "╭─"
        "$username"
        "$os"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_commit"
        "$git_status"
        "$git_metrics"
        "$fill"
        "$cmd_duration"
        "$battery"
        "$time"
        "$line_break"
        "╰─"
        "$shell"
        "$nix_shell"
        "$nodejs"
        "$python"
        "$golang"
        "$rust"
        "$memory_usage"
        "\${custom.disk}"
        "$status"
        "$character"
      ];

      right_format = "";

      # ═══════════════════════════════════════════════════════════════
      # Modules
      # ═══════════════════════════════════════════════════════════════

      # ── Identity ────────────────────────────────────────────────
      username = {
        show_always = true;
        style_user = "bold ${c.mauve}";
        style_root = "bold ${c.red}";
        format = "[󰆎 $user]($style) ";
      };

      os = {
        disabled = false;
        style = "bold ${c.blue}";
        format = "[󱄅 $os]($style) ";
      };

      hostname = {
        ssh_only = false;
        style = "bold ${c.green}";
        format = "[󰒋 $hostname]($style) ";
      };

      # ── Directory ───────────────────────────────────────────────
      directory = {
        style = "bold ${c.sky}";
        truncation_length = 3;
        truncate_to_repo = true;
        format = "[󰉋 $path]($style) ";
        home_symbol = "~";
        repo_root_format = "[󰉋 $repo_root]($style) ";
        read_only = " 󰌾";
      };

      # ── Git ─────────────────────────────────────────────────────
      git_branch = {
        style = "bold ${c.green}";
        format = "[ $symbol$branch]($style) ";
        symbol = "󰊢 ";
        only_attached = true;
        always_show_remote = false;
      };

      git_commit = {
        style = "bold ${c.blue}";
        format = "[\\($hash$tag\\)]($style) ";
        tag_symbol = " 󰓹 ";
        tag_disabled = false;
        only_detached = false;
      };

      git_state = {
        style = "bold ${c.yellow}";
        format = "[ 󰑐 $state( $progress_current/$progress_total)]($style) ";
      };

      git_status = {
        style = "bold ${c.subtext1}";
        format = "[\\($all_status$ahead_behind\\)]($style) ";
        conflicted = "󰋇 ";
        ahead = "󰄬$count";
        behind = "󰄮$count";
        diverged = "󰄬$ahead_count󰄮$behind_count";
        up_to_date = "󰄵 ";
        untracked = "󰈛 ";
        stashed = "󰏗 ";
        modified = "󰏫 ";
        staged = "󰆤 ";
        renamed = "󰁕 ";
        deleted = "󰆴 ";
      };

      git_metrics = {
        disabled = false;
        format = "[+$added]($added_style)/[-$deleted]($deleted_style) ";
        added_style = "bold ${c.green}";
        deleted_style = "bold ${c.red}";
        only_nonzero_diffs = true;
      };

      # ── Fill ────────────────────────────────────────────────────
      fill = {
        style = "dim ${c.surface0}";
        symbol = "─";
      };

      # ── Shell ───────────────────────────────────────────────────
      shell = {
        style = "bold ${c.overlay1}";
        disabled = false;
        format = "[ $indicator]($style) ";
        zsh_indicator = "zsh";
        fish_indicator = "fish";
        bash_indicator = "bash";
      };

      # ── Nix ─────────────────────────────────────────────────────
      nix_shell = {
        style = "bold ${c.yellow}";
        symbol = "󱄅 ";
        format = "[ $symbol]($style) ";
        impure_msg = "impure";
        pure_msg = "pure";
        heuristic = true;
      };

      # ── Languages (contextual) ──────────────────────────────────
      nodejs = {
        style = "bold ${c.green}";
        format = "[ $version ]($style)";
        detect_extensions = [ "js" "ts" "jsx" "tsx" "mjs" "cjs" ];
        detect_files = [ "package.json" ".node-version" "tsconfig.json" ];
      };

      python = {
        style = "bold ${c.yellow}";
        format = "[ $version ]($style)";
        pyenv_version_name = true;
        detect_extensions = [ "py" ];
        detect_files = [ "requirements.txt" "pyproject.toml" "Pipfile" "poetry.lock" ];
      };

      golang = {
        style = "bold ${c.sky}";
        format = "[ $version]($style)";
        detect_extensions = [ "go" ];
        detect_files = [ "go.mod" "go.sum" ];
      };

      rust = {
        style = "bold ${c.peach}";
        format = "[ $version]($style)";
        detect_extensions = [ "rs" ];
        detect_files = [ "Cargo.toml" ];
      };

      docker_context = {
        style = "bold ${c.sapphire}";
        only_with_files = false;
        format = "[ 󰡨 $context]($style) ";
      };

      # ── System resources ────────────────────────────────────────
      memory_usage = {
        disabled = false;
        threshold = -1;
        style = "bold ${c.overlay1}";
        format = "[󰍛 $ram_pct RAM]($style) ";
      };

      custom.disk = {
        command = "df -h / | awk 'NR==2{print $3\"/\"$2}'";
        shell = "bash";
        style = "bold ${c.overlay1}";
        format = "[󰋊 $output]($style) ";
      };

      battery = {
        disabled = false;
        format = "[$symbol$percentage]($style) ";
        charging_symbol = "󰂄 ";
        discharging_symbol = "󰁹 ";
        display = [
          { threshold = 20; style = "bold ${c.red}"; }
          { threshold = 50; style = "bold ${c.yellow}"; }
          { threshold = 80; style = "bold ${c.green}"; }
          { threshold = 100; style = "bold ${c.green}"; }
        ];
      };

      # ── Metadata ────────────────────────────────────────────────
      cmd_duration = {
        style = "bold ${c.overlay1}";
        format = "[󰄬 $duration]($style) ";
        min_time = 2000;
        show_milliseconds = false;
      };

      status = {
        style = "bold ${c.red}";
        format = "[ ✗ $status]($style) ";
        disabled = false;
        pipestatus = true;
        pipestatus_separator = "|";
        success_symbol = "";
      };

      time = {
        style = "bold ${c.overlay1}";
        format = "[󰅐 $time]($style) ";
        disabled = false;
        time_format = "%H:%M";
      };

      sudo = { disabled = true; };
      localip = { disabled = true; };
      shlvl = { disabled = true; };
      container = { disabled = true; };

      # ── Prompt character ────────────────────────────────────────
      character = {
        success_symbol = "[❯](bold ${c.green})";
        error_symbol = "[❯](bold ${c.red})";
        vicmd_symbol = "[❮](bold ${c.yellow})";
        format = " $symbol";
      };
    };
  };

  # ── Auto-refresh (keeps RAM/time/battery current) ──────────────────
  programs.zsh.initContent = ''
    TMOUT=10
    TRAPALRM() {
        zle reset-prompt 2>/dev/null
    }
  '';
}
