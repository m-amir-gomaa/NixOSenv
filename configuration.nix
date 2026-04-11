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
#   • /THE_VAULT: 744 GB HDD partition (sda2) mounted at boot
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
    ./modules/auto-git-nixosenv.nix
    ./modules/mineru.nix
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # ── Networking (systemd-networkd + iwd) ──────────────────────────────────
  networking.hostName = "nixos";
  networking.networkmanager.enable = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;

  # Suppress DHCP-provided DNS so it doesn't override the global DoT servers.
  # These files keep DHCP for IP/gateway/NTP but discard DNS + domain hints.
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

  # DNS-over-TLS via systemd-resolved
  # Primary: AdGuard (no-log, no-filter)   Fallback: Quad9 (malware-blocking)
  # DNSOverTLS = "yes" hard-fails if TLS is unavailable — no plaintext fallback.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "94.140.14.14#dns.adguard-dns.com 2a10:50c0::ad1:ff#dns.adguard-dns.com";
      FallbackDNS = "9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net";
      DNSOverTLS = "yes";
      DNSSEC = "true";
      Domains = "~.";
    };
  };

  # ── Locale & Time ─────────────────────────────────────────────────────────
  time.timeZone = "Africa/Cairo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ALL = "en_US.UTF-8";
  };

  # ── Display & Compositor ─────────────────────────────────────────────────
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";
  services.xserver.videoDrivers = [ "nvidia" ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "qwerty";
  };

  # ── NVIDIA Prime offload (Intel iGPU drives display; MX350 on demand) ───
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # intel-media-driver provides LIBVA_DRIVER_NAME=iHD for wl-screenrec.
    # The compositor lives on Intel, so recording must also stay on Intel.
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # ── Audio (PipeWire) ──────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true; # session manager — required for screencast portal
  };

  services.printing.enable = true;

  # ── AI & Search (Ollama + SearXNG) ──────────────────────────────────────────
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu; # Force CPU-only on Intel i7-1165G7
  };

  services.searx = {
    enable = true;
    package = pkgs.searxng; # Use SearXNG engine
    settings = {
      server.port = 8888;
      server.bind_address = "127.0.0.1";
      server.secret_key = "change_me_if_public";
      server.limiter = false; # Disable rate limiting to prevent 403 Forbidden
      search.formats = [
        "html"
        "json"
      ]; # Enable JSON API
      engines = [
        {
          name = "stackoverflow";
          engine = "stackoverflow";
          shortcut = "so";
        }
        {
          name = "github";
          engine = "github";
          shortcut = "gh";
        }
        {
          name = "arxiv";
          engine = "arxiv";
          shortcut = "ar";
        }
        {
          name = "google";
          engine = "google";
        }
      ];
    };
  };

  # ── Sovereign Engineering (Tier 7) ──────────────────────────────────────────
  
  # Kernel-Level Monitoring Tools (eBPF-ready)
  # (No dedicated programs.ebpf option exists; tools are listed in systemPackages)
  programs.bash.enableLsColors = true;

  # ── Economic Autonomy (Lightning Network — custom systemd unit) ─────────────
  # services.lnd is not available as a NixOS module; wired manually.
  users.users.lnd = {
    isSystemUser = true;
    group = "lnd";
    home = "/var/lib/lnd";
    createHome = true;
  };
  users.groups.lnd = {};

  systemd.services.lnd = {
    description = "Lightning Network Daemon (Sovereign Swarm)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = ''${pkgs.lnd}/bin/lnd \
        --bitcoin.active \
        --bitcoin.mainnet \
        --bitcoin.node=neutrino \
        --neutrino.connect=mainnet-btcd.lnd.cloud \
        --alias=sovereign-swarm \
        --color=#6B4EFE \
        --lnddir=/var/lib/lnd'';
      User = "lnd";
      Group = "lnd";
      Restart = "on-failure";
      RestartSec = "10s";
      LimitNOFILE = 65536;
    };
  };

  # ── Swarm Observability (Disabled) ───────────────────────────────────────────

  # ── Users ─────────────────────────────────────────────────────────────────
  users.users.qwerty = {
    isNormalUser = true;
    description = "qwerty";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
    ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  programs.firefox.enable = true;
  programs.dconf.enable = true;
  qt.enable = true;
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # ── System packages ───────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Core tools
    qbittorrent
    marksman
    icu
    curl
    wget
    git
    gitkraken
    gcc
    gnumake
    unzip
    cmake
    fd
    ripgrep
    android-tools
    syncthing
    unixtools.xxd
    pandoc
    zoom-us
    dart-sass
    tree
    tldr
    parted
    tparted
    rsync

    # Terminal
    kitty

    # Wayland / Hyprland stack
    waybar
    mako
    swww
    rofi
    swaynotificationcenter
    grim
    slurp
    swappy
    zenity
    wl-screenrec
    obs-studio
    wl-clipboard
    cliphist
    wl-clip-persist
    brightnessctl
    pavucontrol
    xdg-utils
    playerctl
    libnotify
    polkit_gnome

    # Files & documents
    nautilus
    gvfs
    libmtp # Android MTP support
    libimobiledevice # iOS support
    ifuse # iOS mount support
    evince
    gnome-calculator
    mpv
    celluloid
    poppler-utils # pdfinfo, pdftotext
    qpdf
    mupdf # mutool
    pdftk

    # Dark mode theming
    adw-gtk3 # GTK3 port of Adwaita (dark variant)
    adwaita-icon-theme # symbolic icons for GTK apps
    adwaita-qt # Qt style matching Adwaita Dark
    libsForQt5.qtstyleplugin-kvantum # Qt5 Kvantum engine
    kdePackages.qtstyleplugin-kvantum # Qt6 Kvantum engine

    # Python
    (python313.withPackages (
      ps: with ps; [
        pip
        pyqt6
        matplotlib
        pyqtgraph
        plyer
        pyinstaller
        requests
        pyyaml
        openai
        python-dotenv
      ]
    ))
    sqlite

    # Qt6
    qt6.qtbase
    qt6.qtwayland

    # Graphics
    libGL
    mesa
    mesa-demos

    # Development
    go
    cargo
    nodejs_24
    bun
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
    wasistlos
    materialgram
    localsend
    yt-dlp
    ffmpeg
    wireshark
    dig
    encfs
    pdfarranger
    kdePackages.okular
    kdePackages.breeze-icons
    pkgs.bitwarden-cli
    gnupg
    zip
    age

    anki-bin
    tauon
    loupe
    obsidian

    # Misc
    pdfstudio2024
    gnome-keyring
    seahorse
    espeak
    speechd
    piper-tts
    ydotool
    wtype
    uv
    kaggle # Stable CLI (1.8.x) — the 2.0 pip version has upload-auth bugs
    libreoffice-fresh

    # God-mode auditing toolkit
    btop
    iotop
    bandwhich
    strace
    ltrace
    lsof
    sysstat
    ncdu
    bpftrace
    bcc

    # Tier 7 — Economic & Observability
    lnd
    prometheus
    prometheus-node-exporter
    grafana

    # Containers & AppImage
    appimage-run

    # Cachix
    devenv
    cachix
  ];
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.devmon.enable = true;
  # ── Learning OS — Script PATH ─────────────────────────────────────────────
  # Makes ~/Learning/bin scripts (foundry, book-progress, book-cleanup,
  # extraction-watchdog, split-chapters.py, pdf-pages.py) available
  # system-wide without needing absolute paths.
  environment.sessionVariables = {
    PATH = [ "$HOME/Learning/bin" ];
    MANPATH = [ "$HOME/Learning/man" ];
  };

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.noto
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];

  fonts.fontconfig = {
    enable = true;
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

  # ── XDG portals ───────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
    ];
    config.common = {
      default = [
        "hyprland"
      ];
    };
  };

  xdg.mime.defaultApplications = {
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    "application/x-gnome-saved-search" = [ "org.gnome.Nautilus.desktop" ];
    "video/mp4" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/x-matroska" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/webm" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/x-msvideo" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/quicktime" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/ogg" = [ "io.github.celluloid_player.Celluloid.desktop" ];
    "video/mpeg" = [ "io.github.celluloid_player.Celluloid.desktop" ];
  };

  # ── Environment variables ─────────────────────────────────────────────────
  environment.variables = {
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
    LESS = "-R";
  };

  # ── Power management ──────────────────────────────────────────────────────
  services.tlp.enable = true;
  services.tlp.settings = {
    START_CHARGE_THRESH_BAT0 = 70;
    STOP_CHARGE_THRESH_BAT0 = 80;
  };
  services.power-profiles-daemon.enable = false;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # ── Systemd integration ───────────────────────────────────────────────────
  services.timesyncd.enable = true;
  services.fstrim.enable = true;
  systemd.coredump.enable = true;
  systemd.services.systemd-machined.enable = true;

  # ── Filesystem mounts ─────────────────────────────────────────────────────

  # /mnt/hdd — secondary HDD partition, automounted on first access
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-uuid/301d7c5e-e13e-44ad-bfe4-3a76901c457d";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
    ];
  };

  # /THE_VAULT — primary HDD partition (sda2, 744 GB ext4)
  # Mounted eagerly at boot (no automount) so MinerU can access it without
  # a race condition against the automount daemon.
  # noatime skips access-time writes — worthwhile on spinning disk.
  fileSystems."/THE_VAULT" = {
    device = "/dev/disk/by-uuid/e5c56896-646c-449e-a06f-d1d8bfd218fe";
    fsType = "ext4";
    options = [
      "nofail"
      "defaults"
      "noatime"
    ];
  };

  # ── Misc ──────────────────────────────────────────────────────────────────
  system.stateVersion = "25.11";

  services.dbus.packages = [ pkgs.glib ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
  ];

  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 7d";
  nix.settings.auto-optimise-store = true;
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "weekly" ];
  nix.settings.min-free = 10737418240; # 10GB
  nix.settings.max-free = 21474836480; # 20GB

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "qwerty" ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=100M
  '';
  programs.browserpass.enable = true; # browser integration
  # ── Syncthing ─────────────────────────────────────────────────────────────
  services.syncthing = {
    enable = true;
    user = "qwerty";
    dataDir = "/home/qwerty"; # Default base for relative paths
    configDir = "/home/qwerty/.config/syncthing";
    openDefaultPorts = true;
  };
  systemd.services.disk-space-alert = {
    description = "Warn when root partition exceeds 85%";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "disk-space-alert" ''
        USAGE=$(${pkgs.coreutils}/bin/df / | ${pkgs.gawk}/bin/awk 'NR==2 {print $5}' | tr -d '%')
        if [ "$USAGE" -gt 85 ]; then
          ${pkgs.util-linux}/bin/wall "WARNING: Root partition at $USAGE%"
        fi
      '';
    };
    startAt = "daily";
  };

  # Automated Lean Profile Maintenance
  systemd.services.nix-profile-maintenance = {
    description = "Purge old nix profile generations (Lean Memory)";
    serviceConfig = {
      Type = "oneshot";
      User = "qwerty";
      ExecStart = "${pkgs.nix}/bin/nix profile wipe-history --older-than 7d";
    };
    startAt = "weekly";
  };
}
