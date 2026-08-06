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
    ./sddm-kwin-numlock.nix
    ./cachix.nix
    ./modules/auto-git-nixosenv.nix
    ./modules/mineru.nix
    ./blocky.nix
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  # Keep only the 10 most recent NixOS generations in the boot menu.
  # Without a limit the menu grows forever and EFI partition fills up.
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  # Block the open-source Nouveau driver — it conflicts with the proprietary
  # NVIDIA driver and can cause boot failures or rendering corruption.
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1" # Required for Wayland: enables kernel DRM modesetting for NVIDIA
    "nvidia-drm.fbdev=1" # Exposes an fbdev node so early console and Plymouth work
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Needed for suspend/resume: preserves VRAM across sleep
    "pcie_aspm=off" # Disable PCIe Active State Power Management — prevents GPU stutter
    "nvme_core.default_ps_max_latency_us=0" # Disable NVMe power states — avoids latency spikes on reads
  ];
  # Enable ARM64 emulation via QEMU binfmt_misc.
  # Allows running aarch64 binaries transparently (e.g. `docker buildx` cross-builds,
  # testing ARM containers, running ARM Go/Rust binaries directly).
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Disable iwlwifi + iwlmvm power saving at the kernel driver level.
  # TLP's WIFI_PWR_ON_* only controls the nl80211 power-save flag; the MVM
  # driver has its own power_scheme that causes the card to sleep mid-TCP.
  # power_save=0 disables driver-level PS; power_scheme=1 = active/full-power.
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
    options iwlmvm power_scheme=1
  '';

  # ── Networking (systemd-networkd + iwd) ──────────────────────────────────
  networking.hostName = "nixos";
  networking.networkmanager.enable = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;
  networking.firewall.enable = false;

  # Non-FHS compat: some tools (e.g. utcp CLI executor) hardcode /bin/bash,
  # which NixOS does not provide. Symlink it to the real bash.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
  ];

  # Pin search.nixos.org to its IP to bypass DNS censorship (ISP blocks it in Egypt).
  # Without this, `nix search nixpkgs ...` hangs waiting for DNS resolution.
  networking.hosts = {
    "104.198.14.52" = [ "search.nixos.org" ];
  };

  # iwd — lightweight Wi-Fi connection daemon (replaces wpa_supplicant)
  networking.wireless.iwd = {
    enable = true;
    settings = {
      Network = {
        EnableIPv6 = true;
        RoutePriorityOffset = 300;
      };
      Settings.AutoConnect = true;
    };
  };

  # Tell systemd-networkd to use DHCP for IP/gateway but ignore router DNS
  # (we set our own DNS via systemd-resolved below)
  systemd.network.networks = {
    "10-wlan" = {
      matchConfig.Name = "wlan0";
      networkConfig.DHCP = "yes";
      dhcpV4Config = {
        UseDNS = false;
        UseDomains = false;
      };
    };
    "20-eth" = {
      matchConfig.Name = "enp3s0";
      networkConfig.DHCP = "yes";
      dhcpV4Config = {
        UseDNS = false;
        UseDomains = false;
      };
    };
  };

  # DNS via systemd-resolved — plain UDP, no DoT (ISP blocks port 853)
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "8.8.8.8 1.1.1.1";
      FallbackDNS = "9.9.9.9";
      DNSOverTLS = "no";
      DNSSEC = "false";
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
    wayland.compositor = "kwin";
    autoNumlock = true;
    theme = "where_is_my_sddm_theme";
    extraPackages = with pkgs; [
      kdePackages.qt5compat
      kdePackages.qtsvg
    ];
  };

  # ── Prevent nixos-rebuild switch from killing the running Hyprland session ──
  # Without this, switch-to-configuration restarts display-manager.service on
  # every rebuild (even if nothing display-related changed), which sends SIGTERM
  # to SDDM → your entire Wayland/Hyprland session dies and the screen goes black.
  # Changes to SDDM config take effect on the NEXT login without this flag.
  systemd.services.display-manager.restartIfChanged = false;

  services.displayManager.autoLogin = {
    enable = false;
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
    package = config.boot.kernelPackages.nvidiaPackages.legacy_535;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # ── Audio (PipeWire) ──────────────────────────────────────────────────────
  # PulseAudio and PipeWire conflict — disable PulseAudio so PipeWire's
  # compatibility shim (services.pipewire.pulse.enable) can own the socket.
  services.pulseaudio.enable = false;
  # rtkit (RealtimeKit) lets PipeWire request real-time thread scheduling
  # from the kernel without running as root. Required for glitch-free audio.
  security.rtkit.enable = true;
  # Allow qwerty to run all commands without password.
  # Needed for: nixos-rebuild, USB mount/fsck, systemctl, etc.
  security.sudo.extraRules = [
    {
      users = [ "qwerty" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
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
    enable = false;
    package = pkgs.ollama-cpu; # Force CPU-only on Intel i7-1165G7
    environmentVariables = {
      OLLAMA_NUM_CTX = "8192";
    };
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
  users.groups.lnd = { };

  systemd.services.lnd = {
    description = "Lightning Network Daemon (Sovereign Swarm)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.lnd}/bin/lnd \
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
      "docker"
      "kvm"
      "libvirtd"
    ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  programs.firefox.enable = true;
  # dconf is a key/value settings database used by GTK/GNOME apps.
  # Required by: gnome-keyring, nautilus, pavucontrol, and some Hyprland plugins.
  programs.dconf.enable = true;
  # qt.enable installs platform integration packages (qt5ct, Breeze style)
  # so Qt apps respect dark mode and don't look broken on a non-KDE desktop.
  qt.enable = true;
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    (
      (where-is-my-sddm-theme.override {
        variants = [ "qt6" ];
        themeConfig.General = {
          passwordTextColor = "white";
          cursorColor = "white";
        };
      }).overrideAttrs
      (old: {
        # Patch Main.qml to inject a live clock above the password field.
        # sed cannot reliably do multiline replacements inside a Nix string literal,
        # so we use Python's str.replace() which handles it correctly.
        installPhase = (old.installPhase or "") + ''
                  QML=$out/share/sddm/themes/where_is_my_sddm_theme/Main.qml
                  ${pkgs.python3}/bin/python3 - "$QML" <<'PYEOF'
          import sys

          path = sys.argv[1]
          with open(path, 'r') as f:
              content = f.read()

          content = content.replace("import QtQuick 2.15", "import QtQuick 2.15\nimport QtQml", 1)

          clock_qml = """        Text {
                      id: clockLabel
                      anchors.horizontalCenter: passwordInput.horizontalCenter
                      anchors.bottom: passwordInput.top
                      anchors.bottomMargin: 80
                      color: "white"
                      style: Text.Outline
                      styleColor: "black"
                      font.pointSize: 48
                      font.bold: true
                      z: 100

                      function updateTime() {
                          var d = new Date();
                          var h = d.getHours();
                          var m = d.getMinutes();
                          text = (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
                      }

                      Component.onCompleted: updateTime()

                      Timer {
                          interval: 1000
                          running: true
                          repeat: true
                          onTriggered: clockLabel.updateTime()
                      }
                  }
                  """

          needle = "        Component.onCompleted: {"
          content = content.replace(needle, clock_qml + needle, 1)

          with open(path, 'w') as f:
              f.write(content)
          PYEOF
        '';
      })
    )
    ntfs3g
    # Core tools
    chromium
    qbittorrent
    marksman
    icu
    curl
    wget
    git
    gh
    gitkraken
    gcc
    gnumake
    unzip
    cmake
    fd
    ripgrep
    android-tools
    scrcpy
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
    gdb
    torsocks
    texliveFull

    # Terminal
    kitty

    # Wayland / Hyprland stack
    waybar
    mako
    awww
    rofi
    swaynotificationcenter
    grim
    slurp
    swappy
    zenity
    wl-screenrec
    obs-studio

    # Recording — terminal + screen (automated demos)
    #  • vhs          → scripted terminal videos (.tape → mp4/gif/webm)
    #  • ttyd         → VHS runtime dep (terminal served over websocket)
    #  • chromium     → VHS headless renderer (go-rod); needs a system browser
    #  • asciinema    → lightweight terminal capture (.cast, interactive replay)
    #  • asciinema-agg→ asciicast → animated GIF
    vhs
    ttyd
    chromium
    asciinema
    asciinema-agg

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
    calibre

    # Dark mode theming
    adw-gtk3 # GTK3 port of Adwaita (dark variant)
    adwaita-icon-theme # symbolic icons for GTK apps
    adwaita-qt # Qt style matching Adwaita Dark
    libsForQt5.qtstyleplugin-kvantum # Qt5 Kvantum engine
    kdePackages.qtstyleplugin-kvantum # Qt6 Kvantum engine

    # Python
    ((python314.override {
      packageOverrides = self: super: {
        # rtoml: segfault in tests on Python 3.14 (transitive dep of manim-slides)
        rtoml = super.rtoml.overrideAttrs (_: {
          doInstallCheck = false;
        });
      };
    }).withPackages (
      ps: with ps; [
        pip
        pyqt6
        matplotlib
        # pyqtgraph 0.14.0: SVGExporter.py:427 crashes on single-token SVG path
        # commands (e.g. "M", "L") under Python 3.14. Tests run via installCheck
        # phase (pytestCheckHook). doInstallCheck = false suppresses that phase.
        (ps.pyqtgraph.overrideAttrs (_: {
          doInstallCheck = false;
        }))
        plyer
        pyinstaller
        requests
        pyyaml
        openai
        python-dotenv
        manim
        manim-slides
        py
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
    psmisc # fuser, killall, pstree

    # Apps & utilities
    discord
    google-chrome
    tor-browser
    karere
    materialgram
    localsend
    yt-dlp
    ffmpeg
    wireshark
    dig
    pdfarranger
    kdePackages.okular
    kdePackages.breeze-icons
    sioyek
    pkgs.bitwarden-cli
    gnupg
    zip
    age
    cryptsetup

    anki-bin
    tauon
    loupe
    papers
    obsidian
    lmstudio

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

    # Tailscale (disabled)
    # tailscale
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

  # ── Environment variables ─────────────────────────────────────────────────
  environment.variables = {
    # Force VA-API (video acceleration) to use the NVIDIA driver globally.
    # Individual commands that need Intel VA-API (e.g. wl-screenrec) override
    # this per-invocation with LIBVA_DRIVER_NAME=iHD.
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    # Tell Mesa's GLX dispatch to use the NVIDIA vendor library instead of
    # the default llvmpipe or radeon path. Required for NVIDIA + Wayland.
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # NVIDIA KMS cursors are broken in wlroots-based compositors (Hyprland).
    # This flag forces software cursor rendering, fixing invisible/glitchy cursors.
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint Electron-based apps (VS Code, Discord, etc.) to use native Wayland
    # via the --ozone-platform=wayland flag. Without this they run via XWayland
    # and look blurry on HiDPI or have input lag.
    NIXOS_OZONE_WL = "1";
    # Pass ANSI escape codes (colours) through `less` without stripping them.
    # Affects `git log`, `man`, and any pager output with colour.
    LESS = "-R";
  };

  # ── Power management ──────────────────────────────────────────────────────
  services.tlp.enable = true;
  services.tlp.settings = {
    START_CHARGE_THRESH_BAT0 = 70;
    STOP_CHARGE_THRESH_BAT0 = 80;
    # Disable Wi-Fi power saving to prevent iwlwifi sleep/disconnect bugs
    WIFI_PWR_ON_AC = "off";
    WIFI_PWR_ON_BAT = "off";
  };
  # power-profiles-daemon conflicts with TLP — both manage CPU governors and
  # power modes. Only one can win; TLP wins because it has battery thresholds.
  services.power-profiles-daemon.enable = false;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  # Register hyprlock as a PAM service so it can authenticate against
  # /etc/shadow (or GNOME keyring). Without this, hyprlock silently fails
  # to verify any password and you get locked out permanently.
  security.pam.services.hyprlock = { };

  # pam_mount auto-mounts an encrypted disk image when qwerty logs in.
  # .projects.img is a LUKS-encrypted loop device; it surfaces as ~/Projects.
  # discard passes TRIM commands through the loop device into the image file,
  # keeping the sparse file compact on the host SSD.
  security.pam.mount = {
    enable = true;
    extraVolumes = [
      "<volume user=\"qwerty\" fstype=\"crypt\" path=\"/home/qwerty/.projects.img\" mountpoint=\"/home/qwerty/Projects\" options=\"loop,discard\" />"
    ];
  };

  # ── Systemd integration ───────────────────────────────────────────────────
  services.timesyncd.enable = true;
  # Run fstrim weekly to discard unused SSD blocks. Maintains write performance
  # and longevity on NAND flash. Safe on all modern SSDs and loop devices.
  services.fstrim.enable = true;
  systemd.coredump.enable = true;
  systemd.coredump.settings.Coredump = {
    MaxUse = "5G";
    KeepFree = "20G";
  };
  # systemd-machined manages container/VM machine records.
  # Required by libvirtd for proper machine registration; without it,
  # virt-manager shows warnings and some guest features break.
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

  fileSystems."/var/lib/systemd/coredump" = {
    device = "/THE_VAULT/coredumps";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  # ── Misc ──────────────────────────────────────────────────────────────────
  services.tor = {
    enable = true;
    # SOCKS client disabled: the always-on 127.0.0.1:9050 proxy causes
    # Cloudflare (Upwork, etc.) to flag requests routed through Tor exit nodes.
    # Use `torsocks <cmd>` for on-demand Tor routing instead.
    client.enable = false;
  };

  system.stateVersion = "25.11";

  services.dbus.packages = [ pkgs.glib ];

  programs.appimage = {
    enable = true;
    # Register AppImage as a binfmt_misc handler so AppImages run directly
    # without needing `appimage-run` wrapper every time.
    binfmt = true;
  };
  # nix-ld creates a fake dynamic linker stub at /lib/ld-linux-x86-64.so.2
  # (and /lib64/). Without this, pre-built ELF binaries (pip wheels, vendor
  # tools, AppImages) fail with "No such file or directory" because NixOS
  # doesn't have glibc at the FHS path they expect.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib # libstdc++.so and libgcc_s.so — required by most C++ binaries
  ];

  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 7d";
  nix.settings.auto-optimise-store = true;
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "weekly" ];
  nix.settings.min-free = 10737418240; # 10GB
  nix.settings.max-free = 21474836480; # 20GB
  nix.settings.max-jobs = 2;
  nix.settings.cores = 4;

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "qwerty" ];
  virtualisation.libvirtd.enable = true;
  # virtualisation.docker.enable = true; # Removed per user request
  # SPICE USB redirection allows passing USB devices from host into VMs
  # managed by virt-manager. Requires the spice-vdagentd service and a
  # SPICE graphics channel in the guest XML config.
  virtualisation.spiceUSBRedirection.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=100M
  '';
  # browserpass is a browser extension host for the `pass` password manager.
  # It lets Firefox/Chrome extensions read passwords from ~/.password-store
  # via native messaging (no clipboard, no xdotool hacks).
  programs.browserpass.enable = true;
  # ── Syncthing ─────────────────────────────────────────────────────────────
  services.syncthing = {
    enable = true;
    user = "qwerty";
    dataDir = "/home/qwerty"; # Default base for relative paths
    configDir = "/home/qwerty/.config/syncthing";
    openDefaultPorts = true;
  };
  systemd.user.services.disk-space-alert = {
    description = "Warn when root partition exceeds 80%";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "disk-space-alert" ''
        USAGE=$(${pkgs.coreutils}/bin/df / | ${pkgs.gawk}/bin/awk 'NR==2 {print $5}' | tr -d '%')
        if [ "$USAGE" -gt 80 ]; then
          ${pkgs.libnotify}/bin/notify-send -u critical "Disk Space Alert" "Root partition is at $USAGE%"
          ${pkgs.util-linux}/bin/wall "WARNING: Root partition at $USAGE%"
        fi
      '';
    };
    startAt = "hourly";
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

  # rsync Music/Projects/Downloads → /THE_VAULT/backups (no --delete: backups retain
  # files removed from live dirs, so phone synced from backup never loses files)
  systemd.services.backup-to-vault = {
    description = "rsync Music/Projects/Downloads to /THE_VAULT/backups";
    serviceConfig = { Type = "oneshot"; User = "qwerty"; };
    path = [ pkgs.rsync pkgs.coreutils ];
    script = ''
      set -e
      D=/THE_VAULT/backups
      rsync -a --quiet /THE_VAULT/Music/     "$D/Music/"
      # Projects LUKS loop may be unmounted → dir empty → rsync no-op, dest untouched
      # lost+found is root-owned fs metadata → exclude (perms fail otherwise)
      rsync -a --quiet --exclude='lost+found' --exclude='.git/' --exclude='node_modules/' \
        --exclude='target/' /home/qwerty/Projects/ "$D/Projects/"
      rsync -a --quiet /THE_VAULT/Downloads/ "$D/Downloads/"
      date -Is >> "$D/last-run.log"
    '';
    startAt = "hourly";
  };

  # ── Swap ──────────────────────────────────────────────────────────────────
  # Add 8 GB swapfile to prevent OOM hard-lockups when running LLMs or heavy tasks
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192;
    }
  ];

  zramSwap.enable = true;
  zramSwap.memoryMax = 4294967296; # 4GB
  zramSwap.algorithm = "zstd";

  systemd.oomd.enableUserSlices = true;

  services.borgbackup.jobs."vault" = {
    paths = [
      "/home/qwerty/.projects.img"
      "/home/qwerty/.local/share/Anki2"
      "/home/qwerty/.mozilla"
      "/home/qwerty/.config/google-chrome"
      "/home/qwerty/Learning"
      "/home/qwerty/Documents"
      "/home/qwerty/.ssh"
      "/home/qwerty/.config/autocommit/secrets.env"
    ];
    repo = "/THE_VAULT/borg-backup";
    encryption.mode = "none";
    startAt = "weekly";
    doInit = true;
  };
}
