{ config, pkgs, lib, ... }:
{
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-margin-top = 5;
      control-center-margin-bottom = 5;
      control-center-margin-right = 5;
      control-center-margin-left = 5;
      notification-icon-size = 64;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;
      fit-to-screen = true;
      control-center-width = 400;
      control-center-height = 600;
      notification-window-width = 400;
      keyboard-shortcuts = true;
      image-visibility = "always";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;
      widgets = [
        "title"
        "dnd"
        "notifications"
        "mpris"
      ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear All";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        mpris = {
          image-size = 96;
          image-radius = 12;
        };
      };
    };
    style = ''
      @define-color bg-selected rgba(40, 40, 40, 0.7);
      @define-color bg-dark rgba(10, 10, 10, 0.95);
      @define-color bg-light rgba(20, 20, 20, 0.85);
      @define-color border-color rgba(30, 30, 30, 0.8);
      @define-color text-color #cdd6f4;
      @define-color text-dim #6c7086;

      * {
        font-family: "JetBrainsMono Nerd Font";
        background-clip: border-box;
      }

      .control-center {
        background: @bg-dark;
        border: 2px solid @border-color;
        border-radius: 12px;
        color: @text-color;
        padding: 10px;
      }

      .notification {
        background: @bg-light;
        border: 1px solid @border-color;
        border-radius: 10px;
        color: @text-color;
        margin: 5px;
        padding: 10px;
      }

      .notification-content {
        margin-top: 5px;
      }

      .notification-default-action,
      .notification-action {
        padding: 4px;
        margin: 2px;
        background: @bg-selected;
        border-radius: 6px;
        color: @text-color;
      }

      .notification-default-action:hover,
      .notification-action:hover {
        background: rgba(60, 60, 60, 0.9);
      }

      .summary {
        font-size: 14px;
        font-weight: bold;
      }

      .body {
        font-size: 13px;
        color: @text-dim;
      }

      .widget-title {
        font-size: 18px;
        margin: 8px;
        font-weight: bold;
      }

      .widget-title > button {
        background: @bg-selected;
        border-radius: 6px;
        padding: 4px 10px;
      }

      .widget-dnd {
        margin: 8px;
        font-size: 14px;
      }

      .widget-mpris {
        background: @bg-light;
        padding: 10px;
        border-radius: 10px;
        margin: 8px;
      }

      .widget-mpris-player {
        padding: 5px;
      }

      .widget-mpris-title {
        font-size: 14px;
        font-weight: bold;
      }

      .widget-mpris-subtitle {
        font-size: 12px;
        color: @text-dim;
      }
    '';
  };
}
