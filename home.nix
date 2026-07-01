# home.nix — Home Manager configuration for the qwerty user
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./nvim.nix
    ./kitty.nix
    ./hyprland.nix
    ./waybar.nix
    ./swaync.nix
  ];

  home.username = "qwerty";
  home.homeDirectory = "/home/qwerty";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  programs.home-manager.enable = true;

  # Install home-manager CLI package explicitly
  home.packages = with pkgs; [
    home-manager
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "amircodes";
      user.email = "amircodes@github.com";
      alias.co = "checkout";
      alias.br = "branch";
      alias.ci = "commit";
      alias.st = "status";
      alias.lg = "log --oneline --graph --all";
      alias.unstage = "reset HEAD --";
      alias.last = "log -1 HEAD";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  home.sessionVariables = {
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    MOZ_ENABLE_WAYLAND = "1";
    GTK_THEME = "Adwaita:dark";
    TAVILY_API_KEY = "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";
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

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
      "application/x-gnome-saved-search" = [ "org.gnome.Nautilus.desktop" ];

      # ── Images → Loupe ──────────────────────────────────────────────────────
      "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
      "image/png" = [ "org.gnome.Loupe.desktop" ];
      "image/gif" = [ "org.gnome.Loupe.desktop" ];
      "image/webp" = [ "org.gnome.Loupe.desktop" ];
      "image/tiff" = [ "org.gnome.Loupe.desktop" ];
      "image/bmp" = [ "org.gnome.Loupe.desktop" ];
      "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];
      "image/avif" = [ "org.gnome.Loupe.desktop" ];
      "image/heic" = [ "org.gnome.Loupe.desktop" ];
      "image/heif" = [ "org.gnome.Loupe.desktop" ];
      "image/x-portable-pixmap" = [ "org.gnome.Loupe.desktop" ];
      "image/x-portable-bitmap" = [ "org.gnome.Loupe.desktop" ];
      "image/x-portable-graymap" = [ "org.gnome.Loupe.desktop" ];
      "image/vnd.microsoft.icon" = [ "org.gnome.Loupe.desktop" ];

      # ── Video → Celluloid ───────────────────────────────────────────────────
      "video/mp4" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-matroska" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/webm" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-msvideo" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/quicktime" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/ogg" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/mpeg" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-flv" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/3gpp" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-ms-wmv" = [ "io.github.celluloid_player.Celluloid.desktop" ];

      # ── Audio → MPV ─────────────────────────────────────────────────────────
      "audio/mpeg" = [ "mpv.desktop" ];
      "audio/ogg" = [ "mpv.desktop" ];
      "audio/flac" = [ "mpv.desktop" ];
      "audio/x-wav" = [ "mpv.desktop" ];
      "audio/aac" = [ "mpv.desktop" ];
      "audio/opus" = [ "mpv.desktop" ];
      "audio/mp4" = [ "mpv.desktop" ];
      "audio/x-m4a" = [ "mpv.desktop" ];
      "audio/webm" = [ "mpv.desktop" ];

      # ── Documents ───────────────────────────────────────────────────────────
      "application/pdf" = [ "sioyek.desktop" ];
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
    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
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
          children = [
            "inputbar"
            "listview"
          ];
        };
        "inputbar" = {
          background-color = mkLiteral "transparent";
          children = [
            "prompt"
            "entry"
          ];
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

  # ── Zsh ────────────────────────────────────────────────────────────────────
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
      n = "nvim";
      nr = "cd ~/NixOSenv && sudo nixos-rebuild switch --flake ~/NixOSenv#nixos";
      nrb = "cd ~/NixOSenv && sudo nixos-rebuild boot --flake ~/NixOSenv#nixos";
      # ── Workspace Navigation & Study ──────────────────────────────────────
      vs = "cd ~/NixOSenv/ && nvim";
      vl = "cd ~/Learning/ && nvim";
      study = "python3 ~/Learning/study.py";
      l = "ls -lt --human-readable";
      o = "xdg-open";
      gpl = "git pull";

      # ── claude-code ───────────────────────────────────────────────────────
      ai = "unset __HM_SESS_VARS_SOURCED && source /etc/profiles/per-user/qwerty/etc/profile.d/hm-session-vars.sh && claude";

      # ── LM Studio ────────────────────────────────────────────────────────
      lmstudio = "lm-studio --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto";

      # ── Sovereign OS ─────────────────────────────────────────────────────
      sov-day = "python3 ~/Learning/Sovereign_German/sovereign_orchestrate.py";
      sov-drill = "python3 ~/Learning/Sovereign_German/sovereign_drills.py";
      sov-audio = "python3 ~/Learning/Sovereign_German/sovereign_audio.py";
      sov-anki = "python3 ~/Learning/Sovereign_German/sovereign_anki_gen.py";
      sov-career = "python3 ~/Learning/scripts/career_orchestrate.py";
    };

    initContent = ''
      # Force Home Manager session variables early
      if [ -z "$__HM_SESS_VARS_SOURCED" ] && [ -f /etc/profiles/per-user/qwerty/etc/profile.d/hm-session-vars.sh ]; then
        echo "Sourcing HM session vars..." >&2   # for debugging
        source /etc/profiles/per-user/qwerty/etc/profile.d/hm-session-vars.sh
      fi

      export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

      if [ -z "$ANTHROPIC_AUTH_TOKEN" ] && [ -f "$HOME/NixOSenv/secrets.nix" ]; then
        export ANTHROPIC_AUTH_TOKEN="$(nix eval --raw --impure --expr '(import "/home/qwerty/NixOSenv/secrets.nix").deepseek_api_key' 2>/dev/null || true)"
      fi

      [[ -f ~/NixOSenv/dotfiles/zsh/.zshrc ]] && source ~/NixOSenv/dotfiles/zsh/.zshrc

      zstyle ':completion:*:git-checkout:*' sort false
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'tree -C $realpath | head -n 20'
      zstyle ':fzf-tab:*' switch-group ',' '.'
      # Source Home Manager session vars as early as possible
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "sudo"
        "git"
        "colored-man-pages"
        "bgnotify"
      ];
      theme = "robbyrussell";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        golang.go
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
  };

  home.file.".p10k.zsh".source = ./dotfiles/zsh/.p10k.zsh;

  home.file.".config/sioyek/prefs_user.config".text = ''
    startup_commands toggle_dark_mode
    background_color           #1a1a1a
    dark_mode_background_color #1a1a1a
    dark_mode_text_color       #e0e0e0
    status_bar_color           #0a0a0a
    status_bar_text_color      #e0e0e0
    ui_font                    JetBrainsMono Nerd Font
    font_size                  12
    page_separator_width       2
    page_separator_color       #2a2a2a
    unfocused_page_opacity     0.8
  '';

  home.file.".config/sioyek/keys_user.config".text = ''
    toggle_dark_mode           d
    smart_jump_under_cursor    s
    overview_definition        o
    portal                     p
    toggle_custom_color        c
  '';
}
