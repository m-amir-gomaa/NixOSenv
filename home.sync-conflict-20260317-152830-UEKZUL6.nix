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
    ./mako.nix # Notification daemon
  ];

  home.username = "qwerty";
  home.homeDirectory = "/home/qwerty";
  home.stateVersion = "25.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # ── Session environment variables ─────────────────────────────────────────
  # These are set in ~/.profile (sourced by PAM on login) and therefore
  # available to all processes in the session, including those launched by
  # .desktop files and D-Bus-activated services.
  home.sessionVariables = {
    # Silence .NET globalization warnings on NixOS (no ICU data in PATH)
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1";
    # Wayland session identity (some apps fall back to X11 if these are unset)
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    # Firefox native Wayland backend (otherwise it runs under XWayland)
    MOZ_ENABLE_WAYLAND = "1";
    # Force GTK dark theme for apps that read this env var at startup
    GTK_THEME = "Adwaita:dark";
  };

  # ── GTK theming — dark mode for all GTK2/3/4 apps ─────────────────────────
  # Home Manager writes ~/.config/gtk-{2,3,4.0}/settings.ini and
  # ~/.gtkrc-2.0.  GTK reads these files before drawing any window.
  #
  # adw-gtk3 is the GTK3 port of GNOME's libadwaita theme.  It gives GTK3
  # apps (Nautilus, pavucontrol, etc.) the same appearance as GTK4 apps.
  # The ":dark" suffix selects its dark variant.
  gtk = {
    enable = true;

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      # Adwaita icon theme — the standard GNOME icon set.
      # Used by Nautilus, GTK file dialogs, system tray, etc.
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };

    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
    };

    gtk3.extraConfig = {
      # Force dark colour scheme at the GTK3 level (belt-and-suspenders with
      # the dconf key below for apps that read one but not the other)
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # ── dconf — GNOME/libadwaita dark colour scheme ───────────────────────────
  # Many GTK4/libadwaita apps (GNOME Videos, GNOME Files, etc.) read the
  # org.gnome.desktop.interface color-scheme key from dconf rather than
  # honouring GTK_THEME.  Setting it to "prefer-dark" makes them choose their
  # dark variant automatically without hardcoding a theme name.
  #
  # dconf.settings is written to ~/.config/dconf/user (a GVariant binary).
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "Adwaita";
    };
  };

  # ── Qt theming — dark mode for Qt5/6 apps ────────────────────────────────
  # qt.enable makes Home Manager write QT_QPA_PLATFORMTHEME and QT_STYLE_OVERRIDE
  # into the session env so Qt apps pick up the right theme without per-app config.
  #
  # platformTheme = "gtk3": Qt uses the GTK3 integration plugin, inheriting the
  # active GTK theme (adw-gtk3-dark).  This is the most seamless option on a
  # GTK-dominant desktop because Qt apps look consistent with GTK apps.
  #
  # style.name = "adwaita-dark": the Qt style engine uses the Adwaita Dark
  # style as a fallback for apps that don't use the platform theme plugin.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # ── Mako systemd service fix ──────────────────────────────────────────────
  # Home Manager's services.mako module creates mako.service with:
  #   After=graphical-session.target
  #   PartOf=graphical-session.target
  #
  # The problem: on a bare SDDM → Hyprland setup (without a full GNOME/KDE
  # session), `graphical-session.target` is never activated by the display
  # manager.  Systemd waits for it forever and mako never starts — which is
  # why no notifications ever appeared after migrating from GNOME.
  #
  # `hyprland-session.target` IS activated (by wayland.windowManager.hyprland.
  # systemd.enable = true in hyprland.nix), so binding mako to it instead
  # ensures it starts as soon as the compositor is ready.
  #
  # mkForce overrides the default strings that Home Manager generates so we
  # don't end up with both targets in the unit file.
  # systemd.user.services.mako = {
  #   Unit = {
  #     After    = lib.mkForce [ "hyprland-session.target" ];
  #     PartOf   = lib.mkForce [ "hyprland-session.target" ];
  #     # Require D-Bus to be running (it always is after login, but explicit is safe)
  #     Requires = [ "dbus.socket" ];
  #   };
  #   # Also restart mako if it crashes (e.g. a malformed config re-test)
  #   Service.Restart = lib.mkDefault "on-failure";
  # };

  # ── Syncthing ─────────────────────────────────────────────────────────────
  # Syncthing is a peer-to-peer file synchronisation daemon.  Home Manager
  # enables it as a systemd user service; it starts automatically on login.
  # Config and database are kept in ~/.config/syncthing/ (not the default
  # ~/.local/share/syncthing/) so they live alongside other dotfiles.
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=/home/qwerty/.config/syncthing"
      "--data=/home/qwerty/.config/syncthing"
    ];
  };
}
