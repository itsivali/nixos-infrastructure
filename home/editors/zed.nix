##############################################################################
#
# Zed
#
# Purpose
# -------
# Declarative Zed editor configuration via Home Manager. Configured for
# a multi-language development workflow: Go, TypeScript, Python, Kotlin,
# Nix, and infrastructure as code.
#
# Ownership
# ---------
# programs.zed-editor (Home Manager)
#
# Does NOT Own
# ------------
# - Neovim config (neovim.nix)
# - Terminal aliases (home/shell/aliases/)
#
##############################################################################

{ pkgs, ... }:

{
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;

    extensions = [
      # Languages
      "nix"
      "toml"
      "dockerfile"
      "python"
      "go"
      "yaml"
      "typescript"
      "kotlin"
      "java"
      "sql"

      # Cloud / IaC
      "azure"
      "terraform"
      "gitlab"

      # Frontend
      "vite"
      "next"
      "node"
      "react"

      # DevOps
      "docker-compose"
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
        kotlin = true;
        java = true;
        sql = true;
        "docker-compose" = true;
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
          formatter = {
            external = {
              command = "ruff";
              arguments = [ "format" "-" ];
            };
          };
          format_on_save = "on";
        };

        Go = {
          formatter = {
            external = {
              command = "goimports";
            };
          };
          format_on_save = "on";
        };

        Kotlin = {
          formatter = {
            external = {
              command = "ktlint";
              arguments = [ "--format" "-" ];
            };
          };
          format_on_save = "on";
        };

        TypeScript = {
          formatter = {
            external = {
              command = "prettier";
              arguments = [ "--parser" "typescript" ];
            };
          };
          format_on_save = "on";
        };

        JavaScript = {
          formatter = {
            external = {
              command = "prettier";
              arguments = [ "--parser" "javascript" ];
            };
          };
          format_on_save = "on";
        };

        SQL = {
          formatter = {
            external = {
              command = "sqlfmt";
            };
          };
          format_on_save = "on";
        };
      };
    };
  };
}
