# hypridle.nix — Home Manager configuration for Hypridle daemon
{ config, pkgs, ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Command to run when locking
        lock_cmd = "${pkgs.hyprlock}/bin/hyprlock";
        # Command run before sleep (such as lid close / suspend)
        before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
        # Command run after sleep (to wake up DPMS)
        after_sleep_cmd = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl dispatch dpms on";
      };

      listener = [
        # 1. Lock screen after 15 minutes (900s) of inactivity
        {
          timeout = 900;
          on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";
        }
        # 2. Turn off display 30 seconds after locking (930s total)
        {
          timeout = 930;
          on-timeout = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl dispatch dpms off";
          on-resume = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
