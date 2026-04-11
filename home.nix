# home.nix — Home Manager configuration for the qwerty user
# ────────────────────────────────────────────────────────────────────────────
# HOW THIS FITS INTO THE SYSTEM:
#   flake.nix
#     └─ home-manager.users.qwerty = ./home.nix   (this file)
#
# Home Manager applies all settings from this file (and its imports) to the
# qwerty user's home directory at activation time (triggered by `nixos-rebuild
# switch`).  Generated config files are symlinked from the Nix store into
# ~/.config/ so they are immutable — never edit them directly.
# ────────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}:
let
  secrets = import ./secrets.nix;
in
{
  imports = [
    ./nvim.nix # Neovim + LSPs via programs.neovim
    ./kitty.nix # Kitty terminal config symlink
    ./hyprland.nix # Hyprland compositor + keybinds
    ./waybar.nix # Status bar
    ./swaync.nix # Notification center (replaces mako)
  ];

  home.username = "qwerty";
  home.homeDirectory = "/home/qwerty";
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # ── Session environment variables ─────────────────────────────────────────
  home.sessionVariables = {
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    MOZ_ENABLE_WAYLAND = "1";
    GTK_THEME = "Adwaita:dark";

    # ── AI Provider API Keys ───────────────────────────────────────────────
    ANTHROPIC_API_KEY    = secrets.anthropic_api_key;
    GEMINI_API_KEY       = secrets.gemini_api_key;
    OPEN_ROUTER_API_KEY  = secrets.open_router_api_key;
    GROQ_API_KEY         = secrets.groq_api_key;
    CEREBRAS_API_KEY     = secrets.cerebras_api_key;
    MISTRAL_API_KEY      = secrets.mistral_api_key;
    COHERE_API_KEY       = secrets.cohere_api_key;
    GITHUB_API_KEY       = secrets.github_api_key;

    # ── OpenClaude default provider: Gemini 2.5 Flash ─────────────────────
    # Switch providers at runtime using the oc-* aliases below.
    # openclaude requires CLAUDE_CODE_USE_OPENAI=1 for all non-Anthropic backends.
    # NOTE: Mistral models pass API test but fail in openclaude (max_completion_tokens
    # incompatibility) — excluded until openclaude fixes it.
    CLAUDE_CODE_USE_OPENAI = "1";
    OPENAI_API_KEY         = secrets.gemini_api_key;
    OPENAI_BASE_URL        = "https://generativelanguage.googleapis.com/v1beta/openai";
    OPENAI_MODEL           = "gemini-2.5-flash";
  };

  # ── GTK theming ──────────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.theme = null;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "Adwaita";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # ── Rofi ───────────────────────────────────────────────────────────────────
  programs.rofi = {
    enable = true;
    extraConfig = {
      modi = "drun,filebrowser";
      combi-modi = "drun,filebrowser";
      show-icons = true;
      combi-hide-mode-prefix = true;
      drun-display-format = "{name}";
      disable-history = false;
      sidebar-mode = false;
    };
    theme = let
      inherit (config.lib.formats.rasi) mkLiteral;
    in {
      "*" = {
        font = "JetBrainsMono Nerd Font 12";
        bg0 = mkLiteral "#0a0a0aff";
        bg1 = mkLiteral "#1a1a1aff";
        fg0 = mkLiteral "#e0e0e0ff";
        accent = mkLiteral "#ffffffff";
        urgent = mkLiteral "#f38ba8ff";
      };

      "window" = {
        width = mkLiteral "600px";
        background-color = mkLiteral "@bg0";
        border = mkLiteral "1px";
        border-color = mkLiteral "#ffffff15";
        border-radius = mkLiteral "12px";
        padding = mkLiteral "20px";
      };

      "mainbox" = {
        background-color = mkLiteral "transparent";
        children = [ "inputbar" "listview" ];
      };

      "inputbar" = {
        background-color = mkLiteral "transparent";
        children = [ "prompt" "entry" ];
        padding = mkLiteral "0 0 15px 0";
      };

      "prompt" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@accent";
        padding = mkLiteral "0 10px 0 0";
      };

      "entry" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg0";
        placeholder = "Search...";
      };

      "listview" = {
        background-color = mkLiteral "transparent";
        columns = 1;
        lines = 10;
        spacing = mkLiteral "5px";
      };

      "element" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg0";
        padding = mkLiteral "8px 12px";
        border-radius = mkLiteral "6px";
      };

      "element selected" = {
        background-color = mkLiteral "@bg1";
        text-color = mkLiteral "@accent";
      };

      "element-text" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
      };

      "element-icon" = {
        background-color = mkLiteral "transparent";
        size = mkLiteral "24px";
        padding = mkLiteral "0 10px 0 0";
      };
    };
  };

  # ── Zsh & Oh-My-Zsh ────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
    };

    shellAliases = {
      n   = "nvim";
      nr  = "age -d -i ~/.age-key.txt ~/NixOSenv/secrets.nix.age > ~/NixOSenv/secrets.nix && cd ~/NixOSenv && git add . && sudo nixos-rebuild switch --flake path:/home/qwerty/NixOSenv#nixos";
      vs  = "cd ~/NixOSenv/ && nvim";
      l   = "ls -lt --human-readable";
      o   = "xdg-open";

      # ── OpenClaude ────────────────────────────────────────────────────────
      # Default launch uses Gemini 2.5 Flash (set in sessionVariables above).
      oc     = "openclaude";
      claude = "openclaude";

      # ── Provider switching — verified working $(date +%Y-%m-%d) ───────────
      # Gemini (Flash only — Pro daily quota exhausted at test time)
      oc-gemini-flash = ''OPENAI_API_KEY="$GEMINI_API_KEY" OPENAI_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai" OPENAI_MODEL="gemini-2.5-flash" openclaude'';
      oc-gemini-pro   = ''OPENAI_API_KEY="$GEMINI_API_KEY" OPENAI_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai" OPENAI_MODEL="gemini-2.5-pro" openclaude'';

      # Groq (fast inference, all 7 models verified)
      oc-groq       = ''OPENAI_API_KEY="$GROQ_API_KEY" OPENAI_BASE_URL="https://api.groq.com/openai/v1" OPENAI_MODEL="llama-3.3-70b-versatile" openclaude'';
      oc-groq-qwen  = ''OPENAI_API_KEY="$GROQ_API_KEY" OPENAI_BASE_URL="https://api.groq.com/openai/v1" OPENAI_MODEL="qwen/qwen3-32b" openclaude'';
      oc-groq-fast  = ''OPENAI_API_KEY="$GROQ_API_KEY" OPENAI_BASE_URL="https://api.groq.com/openai/v1" OPENAI_MODEL="llama-3.1-8b-instant" openclaude'';
      oc-groq-llama4 = ''OPENAI_API_KEY="$GROQ_API_KEY" OPENAI_BASE_URL="https://api.groq.com/openai/v1" OPENAI_MODEL="meta-llama/llama-4-scout-17b-16e-instruct" openclaude'';
      oc-groq-cmpd  = ''OPENAI_API_KEY="$GROQ_API_KEY" OPENAI_BASE_URL="https://api.groq.com/openai/v1" OPENAI_MODEL="groq/compound" openclaude'';
      oc-gpt-oss    = ''OPENAI_API_KEY="$GROQ_API_KEY" OPENAI_BASE_URL="https://api.groq.com/openai/v1" OPENAI_MODEL="openai/gpt-oss-120b" openclaude'';
      oc-gpt-oss-sm = ''OPENAI_API_KEY="$GROQ_API_KEY" OPENAI_BASE_URL="https://api.groq.com/openai/v1" OPENAI_MODEL="openai/gpt-oss-20b" openclaude'';

      # Cerebras (2 of 3 verified; gpt-oss-120b 404'd)
      oc-cerebras = ''OPENAI_API_KEY="$CEREBRAS_API_KEY" OPENAI_BASE_URL="https://api.cerebras.ai/v1" OPENAI_MODEL="qwen-3-235b-a22b-instruct-2507" openclaude'';
      oc-cerebras-llm = ''OPENAI_API_KEY="$CEREBRAS_API_KEY" OPENAI_BASE_URL="https://api.cerebras.ai/v1" OPENAI_MODEL="llama3.1-8b" openclaude'';

      # OpenRouter free (verified — note: free models can rate-limit under heavy use)
      oc-nemotron  = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="nvidia/llama-3.1-nemotron-70b-instruct" openclaude'';
      oc-nemo-nano = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="nvidia/nemotron-nano-9b-v2:free" openclaude'';
      oc-gemma-27b = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="google/gemma-3-27b-it:free" openclaude'';
      oc-gemma-12b = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="google/gemma-3-12b-it:free" openclaude'';
      oc-minimax   = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="minimax/minimax-m2.5:free" openclaude'';
      oc-glm       = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="z-ai/glm-4.5-air:free" openclaude'';
      oc-trinity   = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="arcee-ai/trinity-large-preview:free" openclaude'';
      oc-lfm       = ''OPENAI_API_KEY="$OPEN_ROUTER_API_KEY" OPENAI_BASE_URL="https://openrouter.ai/api/v1" OPENAI_MODEL="liquid/lfm-2.5-1.2b-instruct:free" openclaude'';
    };

    initContent = lib.mkBefore ''
      export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [ "sudo" "git" "colored-man-pages" "bgnotify" ];
      theme = "robbyrussell";
    };
  };

  # ── Dotfile Symlinks ─────────────────────────────────────────────────────
  home.file.".p10k.zsh".source = ./dotfiles/zsh/.p10k.zsh;

}
