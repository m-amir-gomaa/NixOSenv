# hyprland.nix — Home Manager module for Hyprland
# ────────────────────────────────────────────────────────────────────────────
# All options verified against the Hyprland wiki (2025):
#   https://wiki.hyprland.org/Configuring/Variables/
#   https://wiki.hyprland.org/Configuring/Window-Rules/
#   https://wiki.hyprland.org/Configuring/Gestures/
#
# HOW THIS FILE FITS INTO THE SYSTEM:
#   flake.nix
#     └─ home-manager.users.qwerty = ./home.nix
#          └─ imports ./hyprland.nix   (this file)
#
# Home Manager translates the `settings` attrset into a Hyprland config file
# written to ~/.config/hypr/hyprland.conf at activation time.  Never edit
# that generated file directly — always edit this source instead and run `nr`.
# ────────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;

    # ── systemd integration ──────────────────────────────────────────────────
    # Registers hyprland-session.target in the user's systemd instance.
    # Other user services (waybar, mako, etc.) declare
    # After=hyprland-session.target so they only start once the compositor is
    # fully up, and are stopped when the session ends.
    systemd.enable = true;

    settings = {

      # ─── Monitor ──────────────────────────────────────────────────────────
      # Format: "NAME, RESOLUTION@RATE, POSITION, SCALE"
      # An empty name ("") is a catch-all matching any monitor not explicitly
      # listed.  "preferred" selects the native resolution at the highest
      # supported refresh rate; "auto" positions monitors without overlap.
      # To pin a specific monitor run `hyprctl monitors` to find its connector
      # name, then add e.g. "DP-1, 1920x1080@144, 0x0, 1"
      monitor = [ ",preferred,auto,1" ];

      # ─── General ──────────────────────────────────────────────────────────
      general = {
        # gaps_in  = gap between tiled windows on the shared edge (logical px)
        # gaps_out = gap between the outermost window edge and the screen border
        gaps_in = 4;
        gaps_out = 8;

        # border_size is in logical pixels (multiplied by output scale for HiDPI)
        border_size = 2;

        # Active border: dark-grey gradient at 45°.
        # Format: "rgba(RRGGBBAA) [rgba(RRGGBBAA)] [ANGLE]deg"
        # Two colours create a CSS-style linear gradient along the border.
        "col.active_border" = "rgba(606060ff) rgba(484848ff) 45deg";

        # Inactive border: barely-visible dark tone; unfocused windows recede
        "col.inactive_border" = "rgba(2a2a2aff)";

        # dwindle splits the focused window each time a new window opens.
        layout = "dwindle";

        # Allow dragging the border itself (not just the title bar) to resize
        resize_on_border = true;
      };

      # ─── Decoration ───────────────────────────────────────────────────────
      # blur and shadow are SUBcategories of decoration (wiki confirmed)
      decoration = {
        # Rounded corners in logical pixels
        rounding = 10;

        # 1.0 = fully opaque; 0.0 = transparent
        active_opacity = 1.0;
        inactive_opacity = 0.92; # slight transparency on unfocused windows

        # ── Gaussian blur behind windows ─────────────────────────────────────
        # size   = blur kernel radius (higher = softer, more GPU cost)
        # passes = number of blur iterations (2 is a good balance)
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
        };

        # ── Drop shadows ─────────────────────────────────────────────────────
        # range = shadow spread in pixels
        # color = shadow RGBA (dark, semi-transparent looks most natural)
        shadow = {
          enabled = true;
          range = 8;
          color = "rgba(1a1a2eee)";
        };
      };

      # ─── Animations ───────────────────────────────────────────────────────
      # Hyprland uses cubic Bézier curves for easing.
      # bezier format:  "NAME, P1x, P1y, P2x, P2y"  (same as CSS cubic-bezier)
      #   easeOut: fast start → decelerates (snappy for open/move)
      #   easeIn:  slow start → accelerates (natural for dismiss/exit)
      #
      # animation format: "EVENT, ENABLE, SPEED, CURVE [, STYLE]"
      #   SPEED = frame-count at 60 fps (lower = faster animation)
      #   STYLE = optional modifier: slide, slidevert, popin, fade, etc.
      animations = {
        enabled = true;
        bezier = [
          "easeOut, 0.16, 1, 0.3, 1"
          "easeIn,  0.7,  0, 0.84, 0"
        ];
        animation = [
          "windows,    1, 4,  easeOut, slide"
          "windowsOut, 1, 4,  easeIn,  slide"
          "border,     1, 10, default"
          "fade,       1, 5,  default"
          "workspaces, 1, 4,  easeOut, slidevert"
        ];
      };

      # ─── Input ────────────────────────────────────────────────────────────
      input = {
        kb_layout = "us";
        kb_variant = "";
        numlock_by_default = true;

        # kb_options is intentionally blank.
        kb_options = "";

        # follow_mouse=1: keyboard focus follows the cursor (no click needed)
        follow_mouse = 1;

        # sensitivity: range −1.0 … 1.0; 0 = libinput default acceleration
        sensitivity = 0;

        touchpad = {
          # Inverts scroll direction to match touchscreen convention
          # (finger-down scrolls the content down, viewport moves up)
          natural_scroll = true;
          disable_while_typing = true;
        };
      };

      # ─── Layouts ──────────────────────────────────────────────────────────
      # dwindle is Hyprland's binary-space-partition layout (default).
      # pseudotile     = window stays in its tiled slot but has floating sizing
      # preserve_split = keep the split axis when a window is closed so the
      #                  remaining windows don't unexpectedly rearrange
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      # master layout config (not the default but available via $mod+M)
      # new_status="master": new windows become the master pane
      master = {
        new_status = "master";
      };

      # ─── Gestures ─────────────────────────────────────────────────────────
      # Syntax since Hyprland 0.51+: "FINGERS, DIRECTION, ACTION"
      # gestures.workspace_swipe was removed; use the `gesture` list instead.
      # 3-finger horizontal swipe = switch workspaces
      gesture = [
        "3, horizontal, workspace"
      ];

      # ─── Miscellaneous ────────────────────────────────────────────────────
      misc = {
        # 0 = no built-in default wallpaper; swww handles wallpaper
        force_default_wallpaper = 0;
        # Remove the Hyprland logo shown before the wallpaper loads
        disable_hyprland_logo = true;
      };

      # ─── NVIDIA / Wayland environment ─────────────────────────────────────
      # These env vars are injected into every child process launched by
      # Hyprland.  They duplicate the system-level variables in
      # configuration.nix; some apps (launched via .desktop exec lines) may
      # not inherit the login session environment but always inherit the
      # compositor environment.
      #
      # LIBVA_DRIVER_NAME=nvidia      VA-API uses the NVIDIA proprietary driver
      # XDG_SESSION_TYPE=wayland      apps check this to pick Wayland vs X11
      # GBM_BACKEND=nvidia-drm        Mesa uses the nvidia-drm GBM backend
      # __GLX_VENDOR_LIBRARY_NAME     forces GLVND to load the NVIDIA GL lib
      # WLR_NO_HARDWARE_CURSORS=1     software cursor (avoids NVIDIA cursor glitch)
      # QT_QPA_PLATFORM=wayland       Qt apps use Wayland natively
      # QT_AUTO_SCREEN_SCALE_FACTOR   Qt auto-detects HiDPI scale from the output
      # GDK_BACKEND=wayland,x11       GTK tries Wayland first, falls back to X11
      # SDL_VIDEODRIVER=wayland       SDL games use the Wayland backend
      # CLUTTER_BACKEND=wayland       GNOME Clutter uses Wayland
      # XDG_CURRENT_DESKTOP / XDG_SESSION_DESKTOP
      #                               portal, IME, and desktop-aware code uses
      #                               these to identify the compositor
      # GIO_EXTRA_MODULES             exposes gvfs GIO modules to all processes;
      #                               enables trash://, smb://, mtp:// in GTK
      # GTK_THEME=Adwaita:dark        forces GTK3/4 apps to the dark Adwaita theme
      # QT_STYLE_OVERRIDE=kvantum-dark forces Qt apps to the dark Kvantum style
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "WLR_NO_HARDWARE_CURSORS,1"
        "QT_QPA_PLATFORM,wayland"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "GDK_BACKEND,wayland,x11"
        "SDL_VIDEODRIVER,wayland"
        "CLUTTER_BACKEND,wayland"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "GIO_EXTRA_MODULES,${pkgs.gvfs}/lib/gio/modules"
        "GTK_THEME,Adwaita:dark"
        "QT_STYLE_OVERRIDE,kvantum-dark"
        "ADW_DEBUG_COLOR_SCHEME,prefer-dark"
      ];

      # ─── Autostart ────────────────────────────────────────────────────────
      # exec-once runs each command exactly once when Hyprland starts.
      "exec-once" = [
        # THIS MUST BE THE VERY FIRST exec-once ENTRY.
        #
        # Root cause of mako (and many other services) not working on Hyprland:
        #
        # When SDDM launches Hyprland it starts a D-Bus session bus, but the
        # Wayland-specific variables (WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP,
        # XDG_SESSION_TYPE) only exist inside the Hyprland process environment.
        # Systemd user services start from the systemd --user manager, which
        # was launched at login BEFORE Hyprland set those variables.  So when
        # mako.service (or waybar, or any graphical service) starts, it sees a
        # D-Bus session that is missing WAYLAND_DISPLAY and therefore cannot
        # connect to the Wayland compositor — it either crashes silently or
        # shows nothing.
        #
        # `dbus-update-activation-environment --systemd` does two things:
        #   1. Exports the listed variables into the D-Bus activation environment
        #      so D-Bus-activated services (e.g. portals) see them.
        #   2. Runs `systemctl --user import-environment` under the hood,
        #      propagating the variables into every future systemd user service.
        #
        # After this call, mako.service, waybar.service and all other user
        # services that start via hyprland-session.target will have
        # WAYLAND_DISPLAY set and will be able to connect to the compositor.
        "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY"

        "kitty @ set-window scrollback-pager none"

        # ── Wallpaper ───────────────────────────────────────────────────────
        # swww-daemon must start first; it creates a unix socket that
        # `swww img` connects to.  The wipe transition gives a left→right
        # reveal effect on first load.
        "swww-daemon"
        "swww img ~/.config/hypr/wallpaper.jpg --transition-type wipe"

        # ── Keyring ─────────────────────────────────────────────────────────
        # gnome-keyring provides the libsecret D-Bus service used by browsers,
        # git credential helpers, SSH agents, and many other apps.
        # --components=secrets,pkcs11: start only the secrets and PKCS#11
        # (smart-card) backends; skip the SSH component.
        "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets,pkcs11"

        # ── Polkit agent ─────────────────────────────────────────────────────
        # changing system settings, installing packages) are silently denied.
        # This agent shows a GTK dialog for these requests.
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

        # ── Clipboard manager ────────────────────────────────────────────────
        # wl-paste --watch calls `cliphist store` each time the clipboard
        # changes, persisting entries in ~/.cache/cliphist/db.
        # The history is recalled with Super+V via a Rofi dmenu picker.
        "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store"
        "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store"
        "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular"

        # ── GVfs daemons — required for full Nautilus functionality ──────────
        # gvfsd         main daemon; handles trash://, smb://, mtp://, sftp://
        # gvfsd-fuse    FUSE bridge: mounts virtual GVfs paths as real filesystem
        #               paths under ~/.gvfs so any POSIX app can access them
        # gvfsd-metadata per-file emblems, bookmarks, and recent-file tags
        "${pkgs.gvfs}/libexec/gvfsd"
        "${pkgs.gvfs}/libexec/gvfsd-fuse /home/qwerty/.gvfs -f"
        "${pkgs.gvfs}/libexec/gvfsd-metadata"
      ];

      # ─── Variables ────────────────────────────────────────────────────────
      # Hyprland config variables (not env vars).
      # Expanded with $name in bind lines below.
      "$mod" = "SUPER";
      "$term" = "kitty";
      "$browser" = "firefox";
      "$menu" = "rofi -show drun -show-icons";
      # Recursive file search: fd lists all files under $HOME, rofi filters
      # them, and xdg-open launches the result with the appropriate application.
      # `bash -l` gives a login shell so XDG/MIME env vars are fully populated;
      # `setsid` detaches the child so it outlives the shell that spawned it.
      "$files" =
        "bash -lc 'fd --type f --hidden --exclude .git . $HOME | rofi -dmenu -i -p \"Open file\" | xargs -r -d \"\\n\" setsid xdg-open'";

      # ─── Keybinds ─────────────────────────────────────────────────────────
      # Format: "MODS, KEY, DISPATCHER [, PARAMS]"
      # Dispatchers used:
      #   exec COMMAND         run a shell command
      #   killactive           close the focused window
      #   exit                 terminate the Hyprland session (logout)
      #   fullscreen, 0        true fullscreen (no gaps/borders)
      #   togglefloating       toggle between tiled and floating
      #   pseudo               pseudotile (window in its tiled slot, floating size)
      #   togglesplit          flip split direction (horizontal ↔ vertical)
      #   movefocus, DIR       move keyboard focus; DIR = l/r/u/d
      #   movewindow, DIR      swap focused window with its neighbour
      #   workspace, N         switch to workspace N
      #   movetoworkspace, N   move focused window to workspace N
      bind = [
        # ── Launch ──────────────────────────────────────────────────────────
        "$mod, Return,      exec, $term"
        "$mod, B,           exec, $browser"
        "$mod, Space,       exec, $menu"
        # ── File search (rofi filebrowser) ──────────────────────────────────
        # Super+O: browse & open files without a file manager.
        # Navigate with arrow keys / type to filter; Enter opens with xdg-open.
        "$mod, O,           exec, $files"

        # Screenshot workflow (area selection):
        #   1. slurp for interactive region selection
        #   2. grim captures to temporary file
        #   3. zenity file dialog for location/name
        #   4. Move to user's chosen location
        "$mod SHIFT, A,     exec, ${pkgs.writeShellScriptBin "screenshot-area" ''
          set -e

          # Capture area to temporary file
          TEMP_FILE="/tmp/screenshot-$(date +%s).png"

          if ! grim -g "$(${pkgs.slurp}/bin/slurp)" "$TEMP_FILE"; then
            exit 1  # User cancelled selection
          fi

          # Use zenity file dialog
          SAVE_PATH=$(${pkgs.zenity}/bin/zenity \
            --file-selection \
            --save \
            --confirm-overwrite \
            --filename="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png" \
            --title="Save Screenshot")

          # If user cancelled dialog, clean up temp file
          if [ $? -ne 0 ] || [ -z "$SAVE_PATH" ]; then
            rm -f "$TEMP_FILE"
            exit 1
          fi

          # Move to final location
          mv "$TEMP_FILE" "$SAVE_PATH"

          # Optional: notify user
          ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "$SAVE_PATH"
        ''}/bin/screenshot-area"

        # Full screen screenshot (optional companion):
        "$mod SHIFT, S,     exec, ${pkgs.writeShellScriptBin "screenshot-full" ''
          set -e

          TEMP_FILE="/tmp/screenshot-$(date +%s).png"
          grim "$TEMP_FILE"

          SAVE_PATH=$(${pkgs.zenity}/bin/zenity \
            --file-selection \
            --save \
            --confirm-overwrite \
            --filename="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png" \
            --title="Save Screenshot")

          if [ $? -ne 0 ] || [ -z "$SAVE_PATH" ]; then
            rm -f "$TEMP_FILE"
            exit 1
          fi

          mv "$TEMP_FILE" "$SAVE_PATH"
          ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "$SAVE_PATH"
        ''}/bin/screenshot-full"

        # ── Screen recording ─────────────────────────────────────────────────
        # LIBVA_DRIVER_NAME is overridden per-command to "iHD" (Intel Media
        # Driver) because:
        #  • This laptop uses NVIDIA Prime Offload; the display/compositor runs
        #    on the Intel iGPU.
        #  • Setting LIBVA_DRIVER_NAME=nvidia globally would force wl-screenrec
        #    to attempt a cross-GPU DMA-BUF copy (Intel → NVIDIA) which fails
        #    silently, producing an empty 0-byte recording file.
        #  • Capturing and encoding on the same GPU (Intel) avoids the issue.
        # 1. $mod+R          → ⏺️ Video Only (Silent)
        # 2. $mod+W          → ⏺️ Screen + Desktop Audio
        # 3. $mod+T          → ⏺️ Screen + Microphone
        # 4. Same key again  → ⏸️ / ▶️ Toggle Pause/Resume
        # 5. $mod+S anytime  → ⏹️ Stop and Save
        "$mod, R, exec, ~/NixOSenv/scripts/record.sh toggle video"
        "$mod, W, exec, ~/NixOSenv/scripts/record.sh toggle internal"
        "$mod, T, exec, ~/NixOSenv/scripts/record.sh toggle mic"
        "$mod, S, exec, ~/NixOSenv/scripts/record.sh stop"

        "$mod, E, exec, nautilus"

        # Lowercase umlauts and eszett (direct character input)
        "MOD_ALT, a,          exec, wtype 'ä'"
        "MOD_ALT, o,          exec, wtype 'ö'"
        "MOD_ALT, u,          exec, wtype 'ü'"
        "MOD_ALT, s,          exec, wtype 'ß'"

        # Uppercase umlauts (Shift + MOD_ALT)
        "MOD_ALT SHIFT, a,    exec, wtype 'Ä'"
        "MOD_ALT SHIFT, o,    exec, wtype 'Ö'"
        "MOD_ALT SHIFT, u,    exec, wtype 'Ü'"
        # "MOD_ALT SHIFT, u,    exec, wtype 'ẞ'"
        #Capital eszett isn't supported by wtype but you can use neovim's tilde to capitalize the small version or google the capital version

        # Double-quote via MOD_ALT + apostrophe
        "MOD_ALT, apostrophe, exec, wtype '\"'"

        # ── Window management ───────────────────────────────────────────────
        "$mod, Q,           killactive"
        "$mod SHIFT, Q,     exit"
        "$mod, F,           fullscreen, 0"
        "$mod SHIFT, F,     togglefloating"
        "$mod, P,           pseudo"
        "$mod, J,           togglesplit"

        # ── Focus movement ───────────────────────────────────────────────────
        "$mod, H,  movefocus, l"
        "$mod, L,  movefocus, r"
        "$mod, K,  movefocus, u"
        "$mod, J,  movefocus, d"
        "$mod, left,  movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up,    movefocus, u"
        "$mod, down,  movefocus, d"

        # ── Move windows ─────────────────────────────────────────────────────
        "$mod SHIFT, H,     movewindow, l"
        "$mod SHIFT, L,     movewindow, r"
        "$mod SHIFT, K,     movewindow, u"
        "$mod SHIFT, J,     movewindow, d"

        # ── Workspaces ───────────────────────────────────────────────────────
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # ── Clipboard history ────────────────────────────────────────────────
        # Flow: cliphist list → Rofi dmenu picker → cliphist decode → wl-copy
        # cliphist decode converts the selected binary entry back and puts it
        # on the clipboard; wl-copy makes it available for Ctrl+V pasting.
        "$mod, V, exec, ${pkgs.cliphist}/bin/cliphist list | rofi -dmenu | ${pkgs.cliphist}/bin/cliphist decode | wl-copy"

        # Super+scroll → switch workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up,   workspace, e-1"
        ", XF86Calculator, exec, gnome-calculator"
      ];

      # ── Mouse binds ──────────────────────────────────────────────────────────
      # bindm format: "MODS, mouse:BUTTON, DISPATCHER"
      # mouse:272 = left button, mouse:273 = right button
      bindm = [
        "$mod, mouse:272, movewindow" # Super+drag    → move floating window
        "$mod, mouse:273, resizewindow" # Super+r-drag  → resize window
      ];

      # ── Media keys (hold-to-repeat + locked) ─────────────────────────────────
      # bindel = bind + repeat + locked (fires while held, works on lock screen)
      # wpctl is WirePlumber's CLI; @DEFAULT_AUDIO_SINK@ is the active output
      bindel = [
        ", XF86AudioRaiseVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp,   exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # ── Media keys (single-shot + locked) ───────────────────────────────────
      # bindl = bind + locked (works on lock screen)
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];

      # ─── Window Rules ─────────────────────────────────────────────────────
      # Syntax since Hyprland 0.51+:
      #   windowrule = EFFECT [VALUE], match:PROP REGEX
      #
      # match:class  → matches app_id / WM_CLASS (POSIX ERE)
      # match:title  → matches the window title   (POSIX ERE)
      windowrule = [
        # Float utility dialogs (they have fixed/minimum sizes and look wrong tiled)
        "float 1, match:class nm-connection-editor"
        "float 1, match:class blueman-manager"
        "float 1, match:title ^(Open|Save)"

        # Picture-in-Picture: float it and pin it across all workspaces
        "float 1, match:title Picture-in-Picture"
        "pin 1,   match:title Picture-in-Picture"

        # Suppress maximize events from apps.
        # Without this, apps calling the maximize protocol (some games, some
        # Electron apps) trigger a mode-set on the NVIDIA driver, causing a
        # momentary tearing artefact.
        "suppress_event maximize, match:class .*"
      ];
    };
  };
  home.file.".config/hypr/wallpaper.jpg".source = ./dotfiles/hypr/wallpaper.jpg;
}
