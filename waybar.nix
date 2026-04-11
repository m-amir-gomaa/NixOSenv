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
      targets = [ "hyprland-session.target" ];
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
        "custom/notification"
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
          "1" = "󰄯";
          "2" = "󰄯";
          "3" = "󰄯";
          "4" = "󰄯";
          "5" = "󰄯";
          default = "󰄯";
          active  = "󰮯";
          urgent  = "󰀨";
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

      # ── SwayNC Notification Toggle ──────────────────────────────────────
      "custom/notification" = {
        tooltip = false;
        format = " {icon}";
        format-icons = {
          notification = "󱅫";
          none = "󰂚";
          dnd-notification = "󱅫";
          dnd-none = "󰂛";
          inhibited-notification = "󱅫";
          inhibited-none = "󰂚";
          dnd-inhibited-notification = "󱅫";
          dnd-inhibited-none = "󰂛";
        };
        return-type = "json";
        exec-if = "which swaync-client";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
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
      /* ── Obsidian Design System ─────────────────────────────────── */
      @define-color bg-bar     rgba(10, 10, 10, 0.92);
      @define-color bg-module  rgba(26, 26, 26, 0.55);
      @define-color bg-hover   rgba(45, 45, 45, 0.8);
      @define-color border-gl  rgba(255, 255, 255, 0.08);
      @define-color text-main  #e0e0e0;
      @define-color text-dim   #666666;
      @define-color accent     #ffffff;

      * {
        border:        none;
        border-radius: 0;
        font-family:   "JetBrainsMono Nerd Font", monospace;
        font-size:     13px;
        min-height:    0;
      }

      /* ── Bar window ─────────────────────────────────────────────────── */
      window#waybar {
        background-color: @bg-bar;
        color:            @text-main;
        transition:       all 0.5s ease;
        border-bottom:    1px solid @border-gl;
      }

      /* ── Workspace dots ──────────────────────────────────────────────── */
      #workspaces button {
        padding:       0 8px;
        color:         @text-dim;
        background:    transparent;
        margin:        4px 2px;
        font-size:     16px; /* slightly larger for the dots */
        transition:    all 0.3s cubic-bezier(.55,-0.04,.3,1.44);
      }

      #workspaces button:hover {
        color:      @text-main;
        background: rgba(255, 255, 255, 0.05);
        border-radius: 6px;
      }

      #workspaces button.active {
        color:      @accent;
        background: transparent;
      }

      #workspaces button.urgent {
        color:      #f38ba8;
      }

      /* ── Generic module pill (Unified Obsidian) ─────────────────────── */
      #clock, #battery, #cpu, #memory, #temperature,
      #network, #pulseaudio, #tray, #custom-notification {
        padding:       0 12px;
        margin:        5px 3px;
        border-radius: 6px;
        background:    @bg-module;
        color:         @text-main;
        border:        1px solid @border-gl;
        transition:    all 0.3s ease;
      }

      #clock:hover, #battery:hover, #cpu:hover, #memory:hover, 
      #temperature:hover, #network:hover, #pulseaudio:hover, 
      #custom-notification:hover {
        background: @bg-hover;
        border:     1px solid rgba(255, 255, 255, 0.15);
      }

      /* ── State overrides ─────────────────────────────────────────────── */
      #battery.critical             { color: #f38ba8; border-color: rgba(243, 139, 168, 0.3); }
      #battery.warning              { color: #f9e2af; }
      #temperature.critical         { color: #f38ba8; }
    '';
  };
}
