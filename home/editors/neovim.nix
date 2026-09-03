##############################################################################
#
# Neovim
#
# Purpose
# -------
# Modern Neovim configuration via Home Manager. Provides a full IDE-like
# experience with LSP, completion, treesitter, fuzzy finding, file tree,
# git integration, and Gruvbox theme matching the GNOME desktop.
#
# Ownership
# ---------
# programs.neovim, home.packages
#
# Does NOT Own
# ------------
# - Zed editor config (zed.nix)
# - Terminal aliases (home/shell/aliases/)
#
##############################################################################

{ pkgs, lib, ... }:

let
  # Helper for plugin config inline
  luaConfig = builtins.readFile;

  # LSP servers available on PATH
  lspPackages = with pkgs; [
    gopls
    nil
    typescript-language-server
    pyright
    rust-analyzer
    nixpkgs-fmt
    stylua
    ripgrep
    fd
  ];
in
{
  programs.neovim = {
    enable = false;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    waylandSupport = true;

    plugins = with pkgs.vimPlugins; [
      # UI
      { plugin = lualine-nvim; config = "lua require('lualine').setup({ options = { theme = 'gruvbox' } })"; type = "lua"; }
      { plugin = bufferline-nvim; config = "lua require('bufferline').setup({ options = { diagnostics = 'nvim_lsp' } })"; type = "lua"; }
      { plugin = which-key-nvim; config = "lua require('which-key').setup()"; type = "lua"; }
      { plugin = indent-blankline-nvim; config = "lua require('ibl').setup()"; type = "lua"; }
      { plugin = nvim-web-devicons; }

      # File explorer
      { plugin = nvim-tree-lua; config = "lua require('nvim-tree').setup({ view = { width = 30 } })"; type = "lua"; }

      # Fuzzy finder
      { plugin = telescope-nvim; config = "lua require('telescope').setup()"; type = "lua"; }
      plenary-nvim

      # Colorscheme
      gruvbox-nvim

      # LSP
      nvim-lspconfig
      { plugin = mason-nvim; config = "lua require('mason').setup()"; type = "lua"; }
      {
        plugin = mason-lspconfig-nvim;
        config = ''
          lua require('mason-lspconfig').setup({
            ensure_installed = { 'gopls', 'nil_ls', 'ts_ls', 'pyright', 'rust_analyzer' },
          })
        '';
        type = "lua";
      }

      # Completion
      {
        plugin = nvim-cmp;
        config = ''
          lua <<EOF
          local cmp = require('cmp')
          cmp.setup({
            snippet = {
              expand = function(args)
                require('luasnip').lsp_expand(args.body)
              end,
            },
            mapping = cmp.mapping.preset.insert({
              ['<C-b>'] = cmp.mapping.scroll_docs(-4),
              ['<C-f>'] = cmp.mapping.scroll_docs(4),
              ['<C-Space>'] = cmp.mapping.complete(),
              ['<C-e>'] = cmp.mapping.abort(),
              ['<CR>'] = cmp.mapping.confirm({ select = true }),
              ['<Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then cmp.select_next_item()
                else fallback() end
              end, { "i", "s" }),
              ['<S-Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then cmp.select_prev_item()
                else fallback() end
              end, { "i", "s" }),
            }),
            sources = cmp.config.sources({
              { name = 'nvim_lsp' },
              { name = 'luasnip' },
              { name = 'buffer' },
              { name = 'path' },
            }),
          })
          EOF
        '';
        type = "lua";
      }
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      { plugin = pkgs.vimPlugins.cmp_luasnip; }

      # Treesitter
      {
        plugin = nvim-treesitter.withAllGrammars;
        config = ''
          lua require('nvim-treesitter.configs').setup({
            highlight = { enable = true },
            indent = { enable = true },
            ensure_installed = { 'go', 'typescript', 'javascript', 'nix', 'python', 'bash', 'yaml', 'json', 'toml', 'lua', 'rust', 'html', 'css', 'markdown' },
          })
        '';
        type = "lua";
      }

      # Git
      gitsigns-nvim
      { plugin = lazygit-nvim; config = "vim.g.lazygit_floating_window_winblend = 0"; type = "lua"; }

      # Editing
      { plugin = comment-nvim; config = "lua require('Comment').setup()"; type = "lua"; }
      { plugin = nvim-autopairs; config = "lua require('nvim-autopairs').setup()"; type = "lua"; }
      { plugin = popup-nvim; }
    ];

    extraPackages = lspPackages;

    initLua = /* lua */ ''
      -- ── General Settings ──────────────────────────────────────────────
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.smartindent = true
      vim.opt.termguicolors = true
      vim.opt.mouse = "a"
      vim.opt.clipboard = "unnamedplus"
      vim.opt.undofile = true
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.opt.scrolloff = 8
      vim.opt.signcolumn = "yes"
      vim.opt.updatetime = 250
      vim.opt.timeoutlen = 300
      vim.opt.completeopt = "menu,menuone,noselect"
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- ── Colorscheme ───────────────────────────────────────────────────
      vim.cmd.colorscheme("gruvbox")
      vim.opt.background = "dark"

      -- ── Keymaps ───────────────────────────────────────────────────────
      local map = vim.keymap.set
      local opts = { noremap = true, silent = true }

      -- File explorer
      map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "File explorer" })
      map("n", "<leader>o", "<cmd>NvimTreeFocus<CR>", { desc = "Focus file explorer" })

      -- Telescope
      map("n", "<leader>f", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
      map("n", "<leader>g", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
      map("n", "<leader>b", "<cmd>Telescope buffers<CR>", { desc = "Buffers" })
      map("n", "<leader>h", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
      map("n", "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "Search buffer" })

      -- Git
      map("n", "<leader>gg", "<cmd>LazyGit<CR>", { desc = "LazyGit" })
      map("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", { desc = "Stage hunk" })
      map("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", { desc = "Reset hunk" })
      map("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", { desc = "Preview hunk" })

      -- Buffer navigation
      map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
      map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
      map("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "Close buffer" })

      -- Window navigation
      map("n", "<C-h>", "<C-w>h", opts)
      map("n", "<C-j>", "<C-w>j", opts)
      map("n", "<C-k>", "<C-w>k", opts)
      map("n", "<C-l>", "<C-w>l", opts)

      -- LSP keymaps (attached via autocmd)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local bmap = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end
          bmap("n", "gd", vim.lsp.buf.definition, "Go to definition")
          bmap("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          bmap("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
          bmap("n", "gr", vim.lsp.buf.references, "References")
          bmap("n", "K", vim.lsp.buf.hover, "Hover documentation")
          bmap("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          bmap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          bmap("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
          bmap("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
          bmap("n", "<leader>d", vim.diagnostic.open_float, "Line diagnostics")
        end,
      })

      -- Diagnostic signs
      vim.diagnostic.config({
        virtual_text = { prefix = "●" },
        signs = true,
        underline = true,
        update_in_insert = false,
      })

      -- Highlight on yank
      vim.api.nvim_create_autocmd("TextYankPost", {
        group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
        callback = function()
          vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
        end,
      })
    '';
  };
}
