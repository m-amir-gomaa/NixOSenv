# disko.nix — declarative disk layout for a fresh install
# ────────────────────────────────────────────────────────────────────────────
# WARNING: This describes the OS disk ONLY (nvme0n1: /boot + /).
# The SATA data disk (sda: /THE_VAULT) is deliberately NOT included — it is
# never repartitioned. This file is standalone (not part of the system config);
# it is read by the `disko` CLI, run from the installer ISO on a brand-new
# machine. NEVER run disko against a machine you want to keep.
#
# Usage (fresh install, from the NixOS installer ISO, inside the cloned repo):
#   sudo nix run .#disko -- --mode disko ./disko.nix
#   sudo nixos-generate-config --root /mnt
#   sudo nixos-install --flake ./#nixos
#
# Layout matches this machine's current disk (see hardware-configuration.nix):
#   nvme0n1p1  1G  vfat  /boot   (EF00)
#   nvme0n1p2  rest ext4 /        (root)
# Swap is handled by zram (see configuration.nix), not a disk partition.
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
