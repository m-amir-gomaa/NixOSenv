# hyprlock.nix — Home Manager configuration for Hyprlock screen locker
{ config, pkgs, ... }:
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
      };

      background = [
        {
          # Automatically uses a blurred screenshot of the screen as the lockscreen background
          path = "screenshot";
          blur_passes = 3;
          blur_size = 7;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.7; # slightly dimmed
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          size = "280, 50";
          outline_thickness = 2;
          dots_size = 0.22; # Scale of input-field height
          dots_spacing = 0.2; # Scale of dots' absolute size
          dots_center = true;
          
          # Colors matching your dark aesthetic
          outer_color = "rgba(255, 255, 255, 0.1)";
          inner_color = "rgba(10, 10, 10, 0.6)";
          font_color = "rgba(240, 240, 240, 0.9)";
          
          fade_on_empty = false;
          placeholder_text = "<i>Enter password to unlock...</i>";
          hide_input = false;
          
          position = "0, -100";
          halign = "center";
          valign = "center";
          
          # Visual feedback on caps lock or validation errors
          fail_color = "rgba(200, 50, 50, 1.0)";
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          fail_transition = 300; # ms
        }
      ];

      label = [
        # Clock
        {
          text = "$TIME";
          color = "rgba(242, 243, 244, 0.9)";
          font_size = 90;
          font_family = "JetBrainsMono Nerd Font ExtraBold";
          position = "0, 150";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 3;
        }
        # Date
        {
          text = "cmd[update:43200000] date +\"%A, %d %B %Y\"";
          color = "rgba(200, 200, 200, 0.8)";
          font_size = 18;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 80";
          halign = "center";
          valign = "center";
        }
        # User greeting
        {
          text = "Hello, $USER";
          color = "rgba(200, 200, 200, 0.8)";
          font_size = 16;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -30";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
