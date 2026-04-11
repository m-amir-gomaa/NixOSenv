# mako.nix — declarative notification daemon via Home Manager
# ────────────────────────────────────────────────────────────────────────────
# HOW THIS FITS INTO THE SYSTEM:
#   home.nix imports this file.
#   Home Manager enables the mako systemd user service and writes
#   ~/.config/mako/config at activation time.
#   Mako is a Wayland-native notification daemon (replaces dunst on Wayland).
#   It receives libnotify (D-Bus org.freedesktop.Notifications) messages from
#   any app that calls notify-send or uses the libnotify API.
#
# URGENCY LEVELS:
#   low      → subtle; auto-dismisses after 3 s (e.g. volume-change feedback)
#   normal   → default; auto-dismisses after 5 s
#   critical → persistent; must be manually dismissed (e.g. low battery alerts)
#
# COLOR SCHEME: dark grey, no purple.
#   Normal border:   #555555   dark grey
#   Low border:      #89b4fa   blue (kept — visually distinct from normal)
#   Critical border: #f38ba8   red  (kept — signals urgency clearly)
# ────────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.mako = {
    enable = true;

    extraConfig = ''
      font=JetBrainsMono Nerd Font 11

      background-color=#121212ee
      text-color=#cdd6f4
      border-color=#555555

      progress-color=over #2a2a2a

      border-size=2
      border-radius=8
      width=360
      height=100
      margin=10
      padding=12

      max-visible=5
      default-timeout=5000

      [urgency=low]
      border-color=#89b4fa
      default-timeout=3000

      [urgency=critical]
      border-color=#f38ba8
      background-color=#121212f0
      default-timeout=0
    '';
  };
}
