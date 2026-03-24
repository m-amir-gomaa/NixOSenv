{ config, lib, pkgs, ... }:
let
  titanDir = "/home/qwerty/TitanGateway";
  learningDir = "/home/qwerty/Learning";
in
{
  # Titan Ecosystem — Generated Module
  home.sessionVariables = {
    MANPATH = "${titanDir}/docs/man:" + (config.home.sessionVariables.MANPATH or "$MANPATH");
  };
  programs.zsh.initExtra = lib.mkAfter ''
    # Titan Smart Autocompletion
    [[ -f "${titanDir}/scripts/titan-completion.sh" ]] && source "${titanDir}/scripts/titan-completion.sh"
  '';
}
