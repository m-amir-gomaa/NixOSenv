# nvim.nix — Home Manager module for Neovim
# ────────────────────────────────────────────────────────────────────────────
# HOW THIS FITS INTO THE SYSTEM:
#   home.nix imports this file.
#
# WHY programs.neovim INSTEAD OF environment.systemPackages:
#   programs.neovim is a Home Manager module that wraps the neovim package.
#   It correctly handles the `vi`, `vim`, `nvim` aliases, sets
#   $EDITOR / $VISUAL in the session env, and generates a proper wrapper
#   script that puts all extraPackages on the PATH only while Neovim is
#   running — so 100+ LSP binaries don't pollute the global PATH.
#
# WHY extraPackages INSTEAD OF Mason:
#   Mason downloads pre-built binaries at runtime and stores them in
#   ~/.local/share/nvim/mason/.  On NixOS this breaks because:
#     1. Downloaded ELF binaries use glibc paths that don't exist on NixOS.
#     2. The Nix store is read-only; patching binaries is not possible at runtime.
#   By listing all LSP servers and formatters in extraPackages, Nix provides
#   them from the store.  The Neovim config (in dotfiles/nvim/) is written to
#   use these store paths directly instead of relying on Mason.
#
# NEOVIM CONFIG LOCATION:
#   xdg.configFile."nvim".source = mkOutOfStoreSymlink …
#   This creates ~/.config/nvim → ~/NixOSenv/dotfiles/nvim (a live symlink).
#   Changes to Lua config files inside dotfiles/nvim/ are picked up immediately
#   without a Nix rebuild — only changes to THIS file (adding/removing packages)
#   require a rebuild.
# ────────────────────────────────────────────────────────────────────────────
{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true; # sets $EDITOR=nvim and $VISUAL=nvim
    viAlias = true; # `vi` → nvim
    vimAlias = true; # `vim` → nvim

    # All packages listed here are added to the PATH only while Neovim runs.
    # They are not visible in normal shell sessions.
    extraPackages = with pkgs; [
      # ── Language Servers (LSPs) ──────────────────────────────────────────
      # Each LSP provides code completion, go-to-definition, hover docs,
      # and diagnostics for one or more languages.
      gopls # Go
      nodePackages.vscode-langservers-extracted # HTML, CSS, JSON, ESLint
      nodePackages.typescript-language-server # TypeScript / JavaScript
      yaml-language-server # YAML
      nil # Nix (with nixfmt integration)
      bash-language-server # Bash / Shell
      pyright # Python (type checking)
      clang-tools # C / C++ (clangd + clang-format)
      lua-language-server # Lua (used by Neovim config itself)
      marksman # Markdown (go-to-definition for links)
      rust-analyzer # Rust
      taplo # TOML
      markdown-oxide # Markdown LSP with Obsidian-style backlinks

      # ── Formatters ───────────────────────────────────────────────────────
      # conform.nvim (or null-ls) calls these directly; they are NOT plugins.
      stylua # Lua
      shfmt # Shell
      gofumpt # Go (stricter gofmt)
      nodePackages.prettier # JS/TS/HTML/CSS/JSON/YAML/Markdown
      nodePackages.eslint_d # JS/TS linting (daemon mode = fast)
      nixfmt # Nix (classic formatter)
      alejandra # Nix (modern formatter)
      black # Python (PEP8 compliant)
      isort # Python import ordering
      ruff # Python linting + fast formatting
      prettierd # Prettier daemon (much faster repeated calls)

      # ── Linters ──────────────────────────────────────────────────────────
      shellcheck # Bash/sh static analysis
      selene # Lua linting
      golangci-lint # Go multi-linter
      yamllint # YAML
      htmlhint # HTML
      markdownlint-cli2 # Markdown
      cppcheck # C/C++ static analysis

      # ── Debug adapters ────────────────────────────────────────────────────
      delve # Go debugger (used by nvim-dap)
      lldb # C/C++/Rust debugger
      python313Packages.debugpy # Python debugger

      # ── Other tools Neovim plugins shell out to ───────────────────────────
      icu # Unicode data library (required by some LSPs)
      tree-sitter # CLI needed to compile grammars like latex via :TSInstall
      gcc # C compiler for Treesitter parser compilation
      gnumake # Build tool for compiling parsers
      git # Required for fetching parser sources

      # ── Snacks.nvim optional tools ────────────────────────────────────────
      lazygit # Snacks.lazygit integration
      ghostscript # Snacks.image: render PDF files (gs)
      tectonic # Snacks.image: render LaTeX math expressions
      mermaid-cli # Snacks.image: render Mermaid diagrams (mmdc)
      plantuml # Snacks.image: render PlantUML diagrams (puml)
      graphviz # Required for many PlantUML diagram types
      jdk # Required by PlantUML
      trash-cli # Snacks.explorer: send deleted files to trash instead of permanent delete
    ];
  };

  # Point ~/.config/nvim at the live dotfiles directory.
  # mkOutOfStoreSymlink is used (not a plain source copy) so Lua edits are
  # picked up without a rebuild.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "/home/qwerty/NixOSenv/dotfiles/nvim";
}
