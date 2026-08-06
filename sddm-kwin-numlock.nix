{ config, pkgs, lib, ... }:

{
  system.activationScripts.sddmNumlock = ''
    mkdir -p /var/lib/sddm/.config
    cat << 'INI' > /var/lib/sddm/.config/kcminputrc
[Keyboard]
NumLock=0
INI
    chown -R sddm:sddm /var/lib/sddm/.config
  '';
}
