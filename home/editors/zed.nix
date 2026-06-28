{ pkgs, ... }:

{
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;

    extensions = [
      "nix"
      "toml"
      "dockerfile"
      "python"
      "go"
      "yaml"
      "typescript"
      "azure"
      "terraform"
      "gitlab"
      "vite"
      "next"
      "node"
      "react"
    ];

    userSettings = {
      theme = {
        mode = "system";
        light = "Gruvbox Light";
        dark = "Gruvbox Dark";
      };

      auto_install_extensions = {
        dockerfile = true;
        go = true;
        nix = true;
        python = true;
        toml = true;
        yaml = true;
        typescript = true;
        azure = true;
        terraform = true;
        gitlab = true;
        vite = true;
        next = true;
        node = true;
        react = true;
      };

      vim_mode = false;

      ui_font_size = 16;
      buffer_font_size = 14;

      autosave = "on_focus_change";

      format_on_save = "on";
      formatter = "auto";

      tab_size = 2;
      soft_wrap = "editor_width";
      show_whitespaces = "selection";

      inlay_hints.enabled = true;

      terminal = {
        shell.program = "zsh";

        env = {
          EDITOR = "zeditor --wait";
        };
      };

      git.inline_blame.enabled = true;

      languages = {
        Nix = {
          formatter.external.command = "nixfmt";
          format_on_save = "on";
        };

        Python = {
          format_on_save = "on";
        };
      };
    };
  };
}
