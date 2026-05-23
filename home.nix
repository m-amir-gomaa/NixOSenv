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

  # --- AI Provider API Keys (Moved to runtime env) ---
  home.sessionVariables = {
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    MOZ_ENABLE_WAYLAND = "1";
    GTK_THEME = "Adwaita:dark";

    CLAUDE_CODE_USE_OPENAI = "1";
    OPENAI_API_KEY         = "ollama";
    OPENAI_BASE_URL        = "http://localhost:11434/v1";
    OPENAI_MODEL           = "qwen2.5-coder:7b";
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

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
    };

    shellAliases = {
      n   = "nvim";
      nr  = "age -d -i ~/.age-key.txt ~/NixOSenv/secrets.nix.age > ~/NixOSenv/secrets.nix && cd ~/NixOSenv && git add . && sudo nixos-rebuild switch --flake path:/home/qwerty/NixOSenv#nixos";
      nrb = "age -d -i ~/.age-key.txt ~/NixOSenv/secrets.nix.age > ~/NixOSenv/secrets.nix && cd ~/NixOSenv && git add . && sudo nixos-rebuild boot --flake path:/home/qwerty/NixOSenv#nixos";
      vs  = "cd ~/NixOSenv/ && nvim";
      l   = "ls -lt --human-readable";
      o   = "xdg-open";

      # ── OpenClaude (Local Providers Only) ──────────────────────────────────
      # Default launch uses local Ollama with Qwen2.5-Coder (set in sessionVariables above).
      oc          = ''CLAUDE_CODE_USE_OPENAI=1 OPENAI_API_KEY="ollama" OPENAI_BASE_URL="http://localhost:11434/v1" OPENAI_MODEL="qwen2.5-coder:7b" openclaude'';
      claude      = ''CLAUDE_CODE_USE_OPENAI=1 OPENAI_API_KEY="ollama" OPENAI_BASE_URL="http://localhost:11434/v1" OPENAI_MODEL="qwen2.5-coder:7b" openclaude'';
      oc-ollama   = ''CLAUDE_CODE_USE_OPENAI=1 OPENAI_API_KEY="ollama" OPENAI_BASE_URL="http://localhost:11434/v1" OPENAI_MODEL="qwen2.5-coder:7b" openclaude'';
      oc-lmstudio = ''CLAUDE_CODE_USE_OPENAI=1 OPENAI_API_KEY="lm-studio" OPENAI_BASE_URL="http://localhost:1234/v1" OPENAI_MODEL="loaded-model" openclaude'';

      # LM Studio Wayland Launcher (enforces GPU window decorations & native scaling)
      lmstudio    = "lm-studio --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto";

      # ── Sovereign OS Unified CLI ──────────────────────────────────────────
      sov-day    = "python3 ~/Learning/Sovereign_German/sovereign_orchestrate.py";
      sov-drill  = "python3 ~/Learning/Sovereign_German/sovereign_drills.py";
      sov-audio  = "python3 ~/Learning/Sovereign_German/sovereign_audio.py";
      sov-anki   = "python3 ~/Learning/Sovereign_German/sovereign_anki_gen.py";
      sov-career = "python3 ~/Learning/scripts/career_orchestrate.py";
    };

    initContent = ''
      export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

      # ── Home-wide Zsh Dotfiles ──────────────────────────────────────────────
      # Sources your custom aliases and paths from the NixOSenv repository.
      [[ -f ~/NixOSenv/dotfiles/zsh/.zshrc ]] && source ~/NixOSenv/dotfiles/zsh/.zshrc

      # ── fzf-tab Configuration ───────────────────────────────────────────────
      # Disable sort when completing `git checkout`
      zstyle ':completion:*:git-checkout:*' sort false
      # Set descriptions format to enable group support
      zstyle ':completion:*:descriptions' format '[%d]'
      # Set list-colors to enable filename colorizing
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      # Force zsh not to show completion menu, which allows fzf-tab to capture the request
      zstyle ':completion:*' menu no
      # Preview directory's content with eza when completing cd
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'tree -C $realpath | head -n 20'
      # Switch group using `,` and `.`
      zstyle ':fzf-tab:*' switch-group ',' '.'
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [ "sudo" "git" "colored-man-pages" "bgnotify" ];
      theme = "robbyrussell";
    };
  };

  # ── fzf — fuzzy finder + Ctrl+R history search ───────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;  # sources key-bindings.zsh → Ctrl+R, Ctrl+T, Alt+C
  };

  # ── VS Code — Reproducible IDE ──────────────────────────────────────────
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      golang.go
      ms-python.python
      ms-azuretools.vscode-docker
      eamodio.gitlens
      christian-kohler.path-intellisense
    ];
    userSettings = {
      "editor.fontSize" = 14;
      "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'monospace'";
      "editor.fontLigatures" = true;
      "workbench.colorTheme" = "Default Dark Modern";
      "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";
      "window.titleBarStyle" = "custom";
    };
  };

  # ── Dotfile Symlinks ─────────────────────────────────────────────────────
  home.file.".p10k.zsh".source = ./dotfiles/zsh/.p10k.zsh;

  # ── Sioyek (Premium PDF Reader) ─────────────────────────────────────────
  home.file.".config/sioyek/prefs_user.config".text = ''
    # Premium Dark Mode & Visuals
    startup_commands toggle_dark_mode
    background_color           #1a1a1a
    dark_mode_background_color #1a1a1a
    dark_mode_text_color       #e0e0e0
    status_bar_color           #0a0a0a
    status_bar_text_color      #e0e0e0
    ui_font                    JetBrainsMono Nerd Font
    font_size                  12

    # Performance & Smoothness
    page_separator_width       2
    page_separator_color       #2a2a2a
    unfocused_page_opacity     0.8
  '';

  home.file.".config/sioyek/keys_user.config".text = ''
    # Premium Shortcuts
    toggle_dark_mode           d
    smart_jump_under_cursor    s
    overview_definition        o
    portal                     p
    toggle_custom_color        c
  '';

}
