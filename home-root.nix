{ config, pkgs, lib, ... }:
{
  imports = [
    ./nvim.nix
    ./kitty.nix
  ];

  home.username = "root";
  home.homeDirectory = "/root";

  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;

  home.sessionVariables = {
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1";
  };

  # ── Neovim Fix ───────────────────────────────────────────────────────────
  # Home Manager fails if /root/.config/nvim is a symlink (e.g. to qwerty's nvim)
  # because it wants to manage it as a directory to place init.lua.
  # This script clears the symlink if it exists before linkGeneration runs.
  home.activation.removeNvimConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    if [ -L "$HOME/.config/nvim" ]; then
      echo "Removing existing nvim config symlink to allow Home Manager to manage the directory..."
      $DRY_RUN_CMD rm -f "$HOME/.config/nvim"
    fi
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
