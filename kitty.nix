# kitty.nix — Home Manager module for the Kitty terminal emulator
# ────────────────────────────────────────────────────────────────────────────
# HOW THIS FITS INTO THE SYSTEM:
#   home.nix imports this file.
#   The kitty binary is managed system-wide (environment.systemPackages in
#   configuration.nix).  This module only manages the *configuration*: it
#   creates a symlink from ~/.config/kitty → ~/NixOSenv/dotfiles/kitty so that
#   edits to the dotfiles directory take effect immediately without rebuilding.
#
# mkOutOfStoreSymlink creates a symlink that points to a path OUTSIDE the Nix
# store (i.e. a live directory).  This means changes to dotfiles/kitty/kitty.conf
# are picked up by Kitty immediately (on restart) without any nix rebuild step.
# Regular `xdg.configFile."kitty".source = ./dotfiles/kitty` would copy the
# directory into the store and only update on the next rebuild.
# ────────────────────────────────────────────────────────────────────────────
{ config, pkgs, ... }: {
  xdg.configFile."kitty".source =
    config.lib.file.mkOutOfStoreSymlink "/home/qwerty/NixOSenv/dotfiles/kitty";
}
