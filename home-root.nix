{ config, pkgs, ... }:
{
  imports = [
    ./nvim.nix
    ./kitty.nix
  ];

  home.username = "root";
  home.homeDirectory = "/root";

  home.stateVersion = "25.11";

  home.sessionVariables = {
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
