# waybar.nix — declarative Waybar configuration via Home Manager
# ────────────────────────────────────────────────────────────────────────────
# HOW THIS FITS INTO THE SYSTEM:
#   home.nix imports this file.
#   Home Manager enables the waybar systemd user service and writes the JSON
#   config + CSS stylesheet to ~/.config/waybar/{config,style.css}.
#   The service declares After=hyprland-session.target so Waybar only starts
#   once Hyprland is running; it stops when the session ends.
#
# COLOR SCHEME: dark grey (no purple).
#   Background:  rgba(18,18,18, …)   near-black bar
#   Accent:      #787878             medium grey for active/hover states
#   Urgent:      #f38ba8             red (battery critical, urgent workspaces)
#   Warning:     #f9e2af             yellow (battery warning, high temperature)
#   Text:        #cdd6f4             light grey (readable on dark backgrounds)
#   Dim text:    #6c7086             subdued grey for inactive workspaces
# ────────────────────────────────────────────────────────────────────────────
{ config, pkgs, lib, ... }:
{
  programs.waybar = {
    enable  = true;
    systemd = {
      enable = true;
      # Tie to Hyprland session so Waybar doesn't start on a bare TTY login
      target = "hyprland-session.target";
    };

    # ── Bar layout ──────────────────────────────────────────────────────────
    # Waybar supports multiple bars (the outer list); we use one.
    # module names must match the JSON keys in the modules-* lists.
    settings = [{
      layer    = "top";     # render above windows
      position = "top";
      height   = 34;
      spacing  = 4;         # pixels between modules

      modules-left   = [ "hyprland/workspaces" "hyprland/submap" ];
      modules-center = [ "clock" ];
      modules-right  = [
        "pulseaudio"
        "network"
        "cpu"
        "memory"
        "temperature"
        "battery"
        "tray"
      ];

      # ── Workspace indicator ─────────────────────────────────────────────
      # hyprland/workspaces polls the Hyprland IPC socket for workspace events.
      # format-icons maps workspace numbers to Nerd Font glyphs; `active` and
      # `urgent` use the same glyph as `default` but CSS classes style them
      # differently (see stylesheet below).
      "hyprland/workspaces" = {
        disable-scroll = true;   # don't change workspace on scroll over the bar
        all-outputs    = true;   # show workspaces from all monitors
        on-click       = "activate";
        format         = "{icon}";
        format-icons = {
          "1" = "";   "2" = "";   "3" = "";
          "4" = "";   "5" = "";
          default = "";
          active  = "";
          urgent  = "";
        };
      };

      # ── Clock ───────────────────────────────────────────────────────────
      # Click the clock to toggle between time and full date.
      # tooltip shows a mini calendar via pango markup.
      clock = {
        format     = " {:%H:%M}";
        format-alt = " {:%A, %B %d, %Y}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      # ── CPU ─────────────────────────────────────────────────────────────
      cpu = {
        format  = " {usage}%";
        tooltip = false;
      };

      # ── Memory ──────────────────────────────────────────────────────────
      memory = {
        format = " {}%";
      };

      # ── Temperature ─────────────────────────────────────────────────────
      # critical-threshold triggers the `.critical` CSS class; the format-icons
      # list maps temperature ranges (coolest to hottest) to Nerd Font icons.
      temperature = {
        critical-threshold = 80;
        format       = "{icon} {temperatureC}°C";
        format-icons = [ "" "" "" "" "" ];
      };

      # ── Battery ─────────────────────────────────────────────────────────
      battery = {
        states = { warning = 30; critical = 15; };
        format          = "{icon} {capacity}%";
        format-charging = " {capacity}%";
        format-plugged  = " {capacity}%";
        format-icons    = [ "" "" "" "" "" ];
      };

      # ── Network ─────────────────────────────────────────────────────────
      # on-click opens an iwctl TUI inside a Kitty window for Wi-Fi management.
      # iwctl is the iwd interactive shell (see configuration.nix for iwd setup).
      network = {
        format-wifi        = " {signalStrength}%";
        format-ethernet    = " {ipaddr}";
        format-disconnected = "󰌙 ";
        tooltip-format     = "{essid} ({signalStrength}%) via {gwaddr}";
        on-click           = "kitty -e iwctl";
      };

      # ── Audio ───────────────────────────────────────────────────────────
      # Reads PipeWire/PulseAudio volume via libpulse; on-click opens pavucontrol.
      pulseaudio = {
        format       = "{icon} {volume}%";
        format-muted = "󰖁 ";
        format-icons = { default = [ "" "" "" ]; };
        on-click     = "pavucontrol";
      };

      # ── System tray ─────────────────────────────────────────────────────
      # Renders SNI (StatusNotifierItem) tray icons from running apps.
      tray = {
        spacing = 8;
      };
    }];

    # ── Stylesheet ──────────────────────────────────────────────────────────
    # Standard GTK/CSS rendered by Waybar's built-in WebKit CSS engine.
    # NOTE: @import of external GTK theme files is NOT supported by Waybar's
    # CSS parser and will crash the bar.  All colours are inlined here.
    #
    # COLOR VARIABLES (not native CSS vars — just comments for reference):
    #   bar background:    rgba(18, 18, 18, 0.92)    near-black, slight transparency
    #   module background: rgba(36, 36, 36, 0.85)    dark grey pill
    #   accent:            #787878                   medium grey highlight
    #   dim text:          #6c7086                   inactive workspace labels
    #   primary text:      #cdd6f4                   all readable text
    style = ''
      /* ── Reset ──────────────────────────────────────────────────────── */
      * {
        border:        none;
        border-radius: 0;
        font-family:   "JetBrainsMono Nerd Font", monospace;
        font-size:     13px;
        min-height:    0;
      }

      /* ── Bar window ─────────────────────────────────────────────────── */
      window#waybar {
        background-color: rgba(18, 18, 18, 0.92);
        color:            #cdd6f4;
        transition:       background-color 0.5s;
        /* Subtle dark-grey bottom border instead of purple */
        border-bottom:    2px solid rgba(100, 100, 100, 0.4);
      }

      /* ── Workspace buttons ───────────────────────────────────────────── */
      #workspaces button {
        padding:       2px 8px;
        color:         #6c7086;    /* dim — inactive workspaces recede */
        background:    transparent;
        border-radius: 6px;
        margin:        3px 2px;
        transition:    all 0.2s ease;
      }

      /* Hover: slightly lighter grey pill */
      #workspaces button:hover {
        background: rgba(120, 120, 120, 0.15);
        color:      #aaaaaa;
      }

      /* Active workspace: visible grey pill + bright text */
      #workspaces button.active {
        background: rgba(120, 120, 120, 0.30);
        color:      #cccccc;
      }

      /* Urgent workspace (e.g. an app that needs attention) */
      #workspaces button.urgent {
        background: rgba(243, 139, 168, 0.3);
        color:      #f38ba8;
      }

      /* ── Generic module pill ─────────────────────────────────────────── */
      /* All right-side modules share this dark rounded pill style */
      #clock, #battery, #cpu, #memory, #temperature,
      #network, #pulseaudio, #tray {
        padding:       0 10px;
        margin:        3px 2px;
        border-radius: 8px;
        background:    rgba(36, 36, 36, 0.85);
        color:         #cdd6f4;
      }

      /* ── State overrides ─────────────────────────────────────────────── */
      #battery.warning              { color: #f9e2af; }   /* yellow */
      #battery.critical             { color: #f38ba8; background: rgba(243,139,168,0.2); }
      #temperature.critical         { color: #f38ba8; }
    '';
  };
}
