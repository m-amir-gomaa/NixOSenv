# configuration.nix — NixOS system-level configuration
# ────────────────────────────────────────────────────────────────────────────
# HOW THIS FITS INTO THE SYSTEM:
#   flake.nix
#     └─ nixosConfigurations.nixos
#          ├─ hardware-configuration.nix   (auto-generated, don't edit)
#          ├─ configuration.nix            (this file — all system-level options)
#          └─ home-manager.users.*         (user-level dotfiles in home.nix)
#
# This file configures:
#   • Boot, networking (systemd-networkd + iwd), DNS (resolved + DoH)
#   • Display stack: NVIDIA Prime offload + Hyprland Wayland compositor
#   • Audio: PipeWire + WirePlumber (replaces PulseAudio)
#   • Fonts: Noto (full Unicode) + Nerd Fonts (terminal icons)
#   • Flatpak sandbox: font/icon squares fix + global dark-mode env vars
#   • GTK3/Qt dark theme packages (adw-gtk3, adwaita-qt, kvantum)
#   • Power management: TLP (battery charge thresholds 70–80%)
#   • Systemd integration: timesyncd, fstrim, coredump
#   • Automatic weekly NixOS upgrades via system.autoUpgrade (in flake.nix)
#
# After editing, apply with:  sudo nixos-rebuild switch --flake ~/NixOSenv#nixos
# Shortcut alias:             nr   (defined in dotfiles/zsh/.zshrc)
# ────────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./cachix.nix
    ./modules/auto-git-nixosenv.nix # automatic git commits and pushes to github using SSH keys
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking (systemd-networkd + iwd)
  networking.hostName = "nixos";
  networking.networkmanager.enable = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;

  # Suppress DHCP-provided DNS on all interfaces.
  # Without explicit .network files, systemd-networkd accepts DNS servers
  # pushed by DHCP and installs them as per-link resolvers. Per-link DNS
  # takes priority over the global encrypted servers in services.resolved,
  # so all queries silently go to the ISP plaintext DNS, defeating DNSOverTLS.
  #
  # These files keep DHCP for IP/gateway/NTP but drop DNS and domain hints.
  # resolved then falls through to the global AdGuard/Quad9 DoT servers.
  systemd.network.networks = {
    "10-wlan" = {
      matchConfig.Name = "wlan0";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      dhcpV4Config = {
        UseDNS = false;
        UseDomains = false;
      };
      dhcpV6Config = {
        UseDNS = false;
        UseDomains = false;
      };
      ipv6AcceptRAConfig = {
        UseDNS = false;
        UseDomains = false;
      };
    };
    "20-eth" = {
      matchConfig.Name = "enp3s0";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      dhcpV4Config = {
        UseDNS = false;
        UseDomains = false;
      };
      dhcpV6Config = {
        UseDNS = false;
        UseDomains = false;
      };
      ipv6AcceptRAConfig = {
        UseDNS = false;
        UseDomains = false;
      };
    };
  };

  # Wi-Fi backend for systemd-networkd
  networking.wireless.iwd = {
    enable = true;
    settings = {
      Network = {
        EnableIPv6 = true;
        RoutePriorityOffset = 300;
      };
      Settings = {
        AutoConnect = true;
      };
    };
  };

  # DNS Setup (systemd-resolved with DNS-over-TLS)
  #
  # SECURITY NOTES:
  #   • DNSOverTLS = "yes"  — enforces TLS for every query; a connection that
  #     cannot be upgraded to TLS is hard-failed (no silent plaintext fallback).
  #     ("opportunistic" would silently fall back to plaintext — never use it.)
  #   • FallbackDNS uses the same hostname#SNI format so it is also encrypted.
  #     An empty FallbackDNS = "" would leave you with no DNS if both primary
  #     servers are unreachable; the encrypted Quad9 entry is a safer default.
  #   • DNSSEC = "true" validates signed responses end-to-end.
  #   • Domains = "~." makes resolved the authoritative resolver for all
  #     domains (the "." catch-all), preventing leaks to link-local resolvers.
  #
  # Primary:  AdGuard DNS (no-logs, no-filter variant) over TLS port 853
  # Fallback: Quad9 (malware-blocking, no-log) over TLS port 853
  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        DNS = "94.140.14.14#dns.adguard-dns.com 2a10:50c0::ad1:ff#dns.adguard-dns.com";
        FallbackDNS = "9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net";
        DNSOverTLS = "yes";
        DNSSEC = "true";
        Domains = "~.";
      };
    };
  };

  # Locale & Time
  time.timeZone = "Africa/Cairo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ALL = "en_US.UTF-8";
  };

  # ── Display & Compositor ───────────────────────────────────────────────
  # Hyprland (Wayland compositor) replaces GNOME.
  # X11 is still enabled for xwayland legacy-app support only.
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # allow legacy X11 apps inside Hyprland
  };

  # SDDM as display manager (Wayland / Qt native, lightweight)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Auto-login (shared option for all display managers)
  services.displayManager.autoLogin = {
    enable = true;
    user = "qwerty";
  };

  # Audio (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # WirePlumber is the session manager for PipeWire.
    # Required for the PipeWire screencast portal used by xdg-desktop-portal-hyprland.
    # Without it the portal cannot negotiate screen-capture streams and recording fails.
    wireplumber.enable = true;
  };

  # Printing
  services.printing.enable = true;

  # Users
  users.users.qwerty = {
    isNormalUser = true;
    description = "qwerty";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video" # access /dev/dri/* for VAAPI (required for wl-screenrec)
      "render" # access /dev/dri/renderD* nodes (required for GPU encoding)
    ];
    shell = pkgs.zsh;
  };

  # ── Auto Login is now handled by SDDM (see above) ──────────────────────

  # Shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Browsers
  programs.firefox.enable = true;

  # NVIDIA & Graphics
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Intel VAAPI driver — used by wl-screenrec for encoding.
    # With Prime offload the display runs on the Intel iGPU, so capture
    # and encoding must stay on the same GPU (intel-media-driver / iHD).
    # Setting LIBVA_DRIVER_NAME=nvidia system-wide while the compositor
    # lives on Intel causes a cross-GPU DMA-BUF copy that silently fails
    # and produces a 0-byte recording. The keybinds override LIBVA_DRIVER_NAME
    # to "iHD" so wl-screenrec uses this driver instead.
    extraPackages = with pkgs; [
      intel-media-driver # provides LIBVA_DRIVER_NAME=iHD (Gen 8+)
    ];
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    powerManagement.enable = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Experimental features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Qt global wrapping
  qt.enable = true;

  # Allow unfree packages (NVIDIA driver requires it)
  nixpkgs.config.allowUnfree = true;

  # Packages
  environment.systemPackages = with pkgs; [
    qbittorrent # Core tools
    neovim
    marksman
    icu
    curl
    wget
    git
    gitkraken
    gcc
    unzip
    cmake
    fd
    ripgrep
    androidenv.androidPkgs.platform-tools
    syncthing
    unixtools.xxd
    pandoc
    zoom-us
    dart-sass
    tree
    tldr

    # ── Terminals ────────────────────────────────────────────────
    kitty

    # ── Wayland / Hyprland stack ─────────────────────────────────
    waybar # status bar (systemd user service)
    mako # notification daemon
    swww # wallpaper daemon
    rofi # app launcher / dmenu (rofi-wayland merged into rofi)
    grim # screenshot tool
    slurp # region selection for screenshots
    swappy # screenshot annotation / quick edit
    zenity # native file dialog (works with xdg-desktop-portal)
    wl-screenrec # GPU-accelerated Wayland screen recorder
    obs-studio # full-featured screen recorder / streamer
    wl-clipboard # wl-copy / wl-paste
    cliphist # clipboard history
    brightnessctl # screen brightness control

    pavucontrol # PulseAudio/PipeWire volume UI
    pulseaudio # provides pactl for audio device management in scripts

    xdg-utils # xdg-open etc.
    playerctl # media key control
    libnotify # notify-send
    polkit_gnome # authentication agent (replaces GNOME's)

    nautilus
    gvfs # important for trash, network shares, removable drives, etc.
    xdg-desktop-portal-gnome # helps with portals/dialogs on non-GNOME (optional but fixes many issues)
    evince
    totem
    gnome-calculator

    # Video players
    mpv # lightweight, GPU-accelerated, Wayland-native video player
    celluloid # GTK4 GUI frontend for mpv (integrates with Nautilus file manager)

    # ── Dark mode theming ──────────────────────────────────────────────────
    # adw-gtk3: GTK3 port of the libadwaita (GNOME 42+) theme.
    #   Gives GTK3 apps (Nautilus, pavucontrol, file dialogs) the same dark
    #   appearance as GTK4 apps.  home.nix selects "adw-gtk3-dark".
    adw-gtk3
    # adwaita-icon-theme: the standard GNOME icon set.
    #   Required by Nautilus, GTK file pickers, and any GTK app that renders
    #   symbolic icons.  Without it, icon slots render as blank squares.
    adwaita-icon-theme
    # adwaita-qt: Qt style that mirrors Adwaita Dark.
    #   Makes Qt5/6 apps (qbittorrent, okular, VirtualManager, etc.) look
    #   consistent with GTK apps on the same dark desktop.
    adwaita-qt
    # libsForQt5.qtstyleplugin-kvantum: SVG-based Qt theme engine.
    #   Required so QT_STYLE_OVERRIDE=kvantum-dark env var (set in hyprland.nix)
    #   can resolve the "kvantum-dark" style name for Qt5 apps.
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum # Qt6 variant

    # Python + PyQt6
    python3
    python313
    python313Packages.pip
    python313Packages.pyqt6
    python313Packages.matplotlib
    python313Packages.pyqtgraph
    python313Packages.plyer
    python313Packages.pyinstaller
    python313Packages.requests
    sqlite

    # Qt6
    qt6.qtbase
    qt6.qtwayland

    # Graphics & verification
    libGL
    mesa
    mesa-demos # provides glxinfo

    # Development tools
    go
    cargo
    gnumake42
    nodejs_24
    nodePackages.prettier
    prettierd
    lua
    luajit
    lua-language-server
    stylua
    nil
    shfmt
    gofumpt
    inotify-tools
    imagemagick

    # Apps & utilities
    discord
    google-chrome
    tor-browser
    zapzap
    materialgram
    localsend
    yt-dlp
    ffmpeg
    wireshark
    dig
    encfs
    pdfarranger
    kdePackages.okular
    # breeze-icons: the KDE Breeze icon theme.
    # Okular (and other KDE/Qt apps) look up icons by name from the active
    # icon theme at runtime.  On a non-KDE desktop the Breeze theme is not
    # installed by default, so every toolbar button, sidebar entry, and
    # document control that uses a symbolic icon renders as a blank square.
    # Adding breeze-icons to systemPackages puts it in
    # /run/current-system/sw/share/icons/ which is in XDG_DATA_DIRS, so Qt
    # icon engines find it automatically.
    kdePackages.breeze-icons

    # ── Flatpak store GUI ──────────────────────────────────────────────────
    # gnome-software is the standard graphical store for Flatpak (and
    # PackageKit) apps.  It installs a .desktop file, so it appears in
    # `rofi -show drun` like any other app — the user can launch it, browse
    # Flathub, and install/update/remove flatpak apps without a GNOME session.
    #
    # Why it's needed after replacing GNOME with Hyprland:
    #   GNOME Shell includes gnome-software as a built-in panel.  Once you
    #   replace the shell, the store is gone.  Installing gnome-software as a
    #   standalone package restores it; it runs perfectly fine without GNOME.
    #
    # The flatpak plugin is compiled in by default on NixOS unstable.
    # After first install, open the app and add the Flathub remote if not
    # already present:
    #   flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    gnome-software
    pdfstudio2024
    gnome-keyring
    seahorse
    espeak
    speechd
    piper-tts
    ydotool
    wtype
    uv
    libreoffice
    autokey

    # ── God-Mode Auditing Toolkit ────────────────────────────────
    btop # CPU/Mem/Net dashboard
    iotop # SSD/Disk IO by process
    bandwhich # Network bandwidth by process
    strace # Syscall tracer
    ltrace # Dynamic library tracer
    lsof # List open files / sockets
    sysstat # iostat, mpstat, pidstat
    ncdu # TUI disk space analyzer

    # (Nerd Fonts have been moved to fonts.packages below)

    # Containers
    flatpak
    appimage-run

    # Cursor-cli
    cursor-cli

    # cachix
    devenv
    cachix

    rsync
    # calibre, anki, kirta are installed using flathub
    #recording
    wf-recorder

    claude-code
    claude-monitor
    claude-code-acp
    claude-code-router
  ];

  # ── Fonts ────────────────────────────────────────────────────────────────
  # fonts.packages is the correct NixOS API for fonts. Packages listed here
  # are indexed by fontconfig (the /etc/fonts cache) so every app — terminals,
  # GUI apps, video players, document viewers — can find them. Fonts placed only
  # in environment.systemPackages are NOT added to the fontconfig search path,
  # which is why tofu squares appear in apps that rely on fontconfig fallback.
  fonts.packages = with pkgs; [
    # ── Full Noto family — covers virtually every Unicode script ──────────
    # noto-fonts       : Latin, Greek, Cyrillic, Arabic, Hebrew, Devanagari,
    #                    Thai, Armenian, Georgian + many more (900+ languages)
    noto-fonts
    # noto-fonts-cjk-sans : Chinese (Simplified + Traditional), Japanese, Korean
    #                        The single most common source of tofu on the web.
    noto-fonts-cjk-sans
    # noto-fonts-color-emoji : full colour emoji set (Noto Color Emoji)
    noto-fonts-color-emoji
    # noto-fonts-extra : additional less-common scripts (Adlam, Balinese, etc.)
    noto-fonts

    # ── Nerd Fonts (moved here from systemPackages) ───────────────────────
    # These are the patched variants used by terminal apps and Waybar icons.
    # nerd-fonts.noto is the Noto Mono variant with code glyphs — it does NOT
    # include the full Noto Sans/Serif coverage above, so both are needed.
    nerd-fonts.noto
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];

  fonts.fontconfig = {
    enable = true;
    # Set Noto fonts as the default fallback for each generic family.
    # When an app requests a font that isn't installed, fontconfig falls back
    # to these instead of rendering empty squares.
    defaultFonts = {
      sansSerif = [
        "Noto Sans"
        "Noto Color Emoji"
      ];
      serif = [
        "Noto Serif"
        "Noto Color Emoji"
      ];
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  services.flatpak.enable = true;

  # ── Flatpak sandbox font & icon fix ──────────────────────────────────────
  # Problem: Flatpak apps run inside a bubblewrap sandbox and cannot see the
  # Nix font/icon store paths by default.  This causes blank squares (□□□)
  # wherever an app renders glyphs, icons, or UI controls that depend on
  # files only present outside the sandbox.
  #
  # ALL flatpak apps (global override):
  #   --filesystem=/run/current-system/sw/share/fonts:ro
  #                                     explicit NixOS font store path
  #   --filesystem=/nix/var/nix/profiles/system/sw/share/fonts:ro
  #                                     stable symlink to the same fonts
  #   --env=FONTCONFIG_FILE=/etc/fonts/fonts.conf
  #                                     fontconfig inside sandbox uses the
  #                                     system-generated conf (includes all
  #                                     Nix store font directories)
  #   --env=GTK_THEME=Adwaita:dark      dark mode for every sandbox
  #   --env=XCURSOR_THEME=Adwaita       consistent cursor theme
  #
  #   NOTE: "host-fonts" is NOT a valid --filesystem argument (it is a portal
  #   permission token only).  Using it causes the entire command to fail,
  #   silently skipping all overrides even with `|| true`.  Always use the
  #   explicit absolute paths above.
  #
  # Per-app overrides (see below):
  #   Totem     icon paths for play/pause/seek controls
  #   Evince    icon paths + GSettings schema paths for toolbar icons
  #   Papers    icon paths
  #   Okular    icon paths + Breeze theme env var
  #
  # This script runs at every `nixos-rebuild switch` via
  # system.activationScripts (as root).  `flatpak override --system`
  # writes persistent overrides to /var/lib/flatpak/overrides/.
  system.activationScripts.flatpak-theming = {
    # Run after the flatpak service is configured
    deps = [ "etc" ];
    text = ''
      FLATPAK="${pkgs.flatpak}/bin/flatpak"

      # ── Global overrides (apply to every installed flatpak) ───────────────
      # IMPORTANT: "host-fonts" is a Flatpak *portal* permission, NOT a valid
      # argument for `flatpak override --filesystem`.  Valid locations are:
      #   host, host-os, host-etc, home, xdg-*, ~/dir, /dir (absolute paths)
      # Using host-fonts causes the entire override command to fail, so none
      # of the font paths, env vars, or dark-mode settings below get applied
      # to any sandbox — even though `|| true` suppresses the exit code.
      # Fix: use the explicit absolute NixOS paths instead.
      #
      # NOTE on icons: the global override omits icon paths intentionally.
      # Exposing all of /run/current-system/sw/share/icons to every sandbox
      # is a larger surface than needed; per-app icon overrides are below.
      $FLATPAK override --system \
        --filesystem=/run/current-system/sw/share/fonts:ro \
        --filesystem=/nix/var/nix/profiles/system/sw/share/fonts:ro \
        --env=FONTCONFIG_FILE=/etc/fonts/fonts.conf \
        --env=GTK_THEME=Adwaita:dark \
        --env=GTK_APPLICATION_PREFER_DARK_THEME=1 \
        --env=XCURSOR_THEME=Adwaita \
        --env=XCURSOR_SIZE=24 \
        || true

      # ── Shared icon-path helper ───────────────────────────────────────────
      # Several GNOME flatpak apps need read-only access to the Nix icon store.
      # This function applies the same set of overrides to any app ID passed
      # as arguments, keeping the script DRY.
      apply_icon_fix() {
        for APP in "$@"; do
          $FLATPAK override --system "$APP" \
            --filesystem=/run/current-system/sw/share/icons:ro \
            --filesystem=/nix/var/nix/profiles/system/sw/share/icons:ro \
            --env=ADWAITA_ICON_THEME=Adwaita \
            || true
        done
      }

      # ── GNOME Videos (Totem) ──────────────────────────────────────────────
      # Totem needs access to the icon theme path to resolve symbolic icons
      # used in its transport controls (play/pause/seek).  Without this the
      # buttons render as blank squares even when fonts are available.
      apply_icon_fix org.gnome.Totem

      # Refresh the icon cache inside the Totem flatpak so it picks up the
      # newly accessible icons on next launch.
      $FLATPAK run --command=gtk4-update-icon-cache org.gnome.Totem \
        /run/current-system/sw/share/icons/Adwaita 2>/dev/null || true

      # ── Document viewers ──────────────────────────────────────────────────
      # org.gnome.Papers  — new libadwaita rewrite of Evince (GNOME 47+)
      # org.kde.okular    — KDE document viewer; needs Adwaita + Breeze icons
      apply_icon_fix org.gnome.Papers org.kde.okular

      # ── org.gnome.Evince — extra fix beyond apply_icon_fix ────────────────
      # Evince has two separate sources of blank squares on a non-GNOME desktop:
      #
      # 1. Missing Adwaita icons — apply_icon_fix already handles this by
      #    exposing /run/current-system/sw/share/icons:ro to the sandbox.
      #
      # 2. Missing GSettings schemas — Evince reads UI configuration (toolbar
      #    layout, icon names, action labels) from GSettings at startup.
      #    On a GNOME session these schemas are compiled into
      #    /run/current-system/sw/share/gsettings-schemas/ and exposed
      #    automatically.  Inside the sandbox on a bare Hyprland session,
      #    GSettings cannot find host schemas and silently falls back to
      #    hardcoded defaults that reference icon names not present in the
      #    sandbox's own small icon set — those render as blank squares.
      #
      #    Fix: expose both the icons path (apply_icon_fix) AND the two
      #    GSettings schema directories:
      #      gsettings-schemas/  — compiled GVariant schema databases
      #      glib-2.0/schemas/   — raw XML schemas (GLib reads both locations)
      apply_icon_fix org.gnome.Evince
      $FLATPAK override --system org.gnome.Evince \
        --filesystem=/run/current-system/sw/share/gsettings-schemas:ro \
        --filesystem=/run/current-system/sw/share/glib-2.0/schemas:ro \
        || true

      # Additional Breeze icon path for KDE document viewer flatpak
      $FLATPAK override --system org.kde.okular \
        --env=BREEZE_ICON_THEME=breeze \
        || true
    '';
  };

  # ── XDG portals — required for Wayland screen share, file pickers ──────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland # Hyprland-native portal
      xdg-desktop-portal-gtk # GTK file picker fallback
    ];
    config.common.default = "hyprland";
  };

  xdg.mime.defaultApplications = {
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    "application/x-gnome-saved-search" = [ "org.gnome.Nautilus.desktop" ];
    # Video formats → celluloid (mpv GUI)
    "video/mp4" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/x-matroska" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/webm" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/x-msvideo" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/quicktime" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/ogg" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/mpeg" = [ "io.github.celluloid_player.Celluloid.desktop" ];
  };

  # ── Flatpak app discovery (Rofi) ─────────────────────────────────────────
  # Flatpak installs .desktop files to /var/lib/flatpak/exports/share/applications/
  # and ~/.local/share/flatpak/exports/share/applications/. Rofi scans XDG_DATA_DIRS
  # to find .desktop files. In an SDDM → Hyprland session /etc/profile.d/flatpak.sh
  # (which normally adds these paths) is never sourced, so flatpak apps are invisible.
  # sessionVariables appends to the existing XDG_DATA_DIRS rather than overwriting it.
  environment.sessionVariables = {
    XDG_DATA_DIRS = [
      "/var/lib/flatpak/exports/share" # system-wide flatpak installs
      "$HOME/.local/share/flatpak/exports/share" # per-user flatpak installs
    ];
  };

  # ── NVIDIA env vars at the system level ─────────────────────────────────
  environment.variables = {
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1"; # Electron apps use Wayland
    LESS = "-R";
  };
  # Power management
  services.tlp.enable = true;
  services.tlp.settings = {
    START_CHARGE_THRESH_BAT0 = 70;
    STOP_CHARGE_THRESH_BAT0 = 80;
  };
  services.power-profiles-daemon.enable = false;
  # gnome-keyring still provides the libsecret backend used by many apps.
  # Keep it enabled but without the GNOME session integration.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  # ── Pure Systemd Integration ──────────────────────────────────────────
  # Replace standalone daemons with pure systemd primitives
  services.timesyncd.enable = true; # NTP via systemd-timesyncd.service
  services.fstrim.enable = true; # SSD trim via fstrim.timer
  systemd.coredump.enable = true; # Crash dump management natively
  systemd.services.systemd-machined.enable = true; # VM/Container tracing
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; # Procs systemd-binfmt.service

  # System version & extras
  # ── HDD mount ─────────────────────────────────────────────────────────────
  # Find your HDD's UUID by running:  lsblk -f
  # Common fsType values:
  #   "ext4"   – Linux formatted drive
  #   "ntfs3"  – Windows/NTFS drive (kernel driver, faster than ntfs-3g)
  #   "exfat"  – cross-platform removable drives
  #
  # IMPORTANT: keep "nofail" so the system still boots if the HDD is
  # disconnected or powered off. "x-systemd.automount" mounts it on first
  # access rather than blocking at boot.
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-uuid/301d7c5e-e13e-44ad-bfe4-3a76901c457d"; # ← replace with your UUID
    fsType = "ext4"; # ← change to ntfs3 if Windows-formatted
    options = [
      "nofail" # don't halt boot if drive is absent
      "x-systemd.automount" # mount on first access, not at boot
      "x-systemd.idle-timeout=60" # unmount after 60 s of inactivity
    ];
  };

  system.stateVersion = "25.11";

  services.dbus.packages = [ pkgs.glib ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  programs.nix-ld.enable = true;

  # Automatic cleanup
  nix.gc.automatic = true;
  nix.gc.dates = "daily";
  nix.gc.options = "--delete-older-than 10d";
  nix.settings.auto-optimise-store = true;

  # QEMU/KVM
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = [ "qwerty" ];

  virtualisation.libvirtd.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;
}
