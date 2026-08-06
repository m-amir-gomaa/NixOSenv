{
  writeShellScriptBin,
  symlinkJoin,
  ...
}:

let
  # instaScript lives outside the nix store (venv + models cached in ~).
  # The wrapper sets NixOS lib paths for pip wheels, then execs the venv.
  # Vault organization is Claude Code's job — only the extraction CLI is wrapped.
  project = "/home/qwerty/Projects/instaScript";
  env = ''
    source ${project}/bin/nixlibs.sh
    export_instainfo_ld_library_path
    export HF_HUB_DISABLE_XET=1
    export PYTHONPATH="${project}"
    # Local vault path (repo default is neutral ~/ig_intel).
    export IG_INTEL_VAULT="/home/qwerty/THE_VAULT/instainfo/ig_intel"
  '';
in
symlinkJoin {
  name = "instascript";
  paths = [
    (writeShellScriptBin "instascript" ''
      ${env}
      exec ${project}/.venv/bin/python -m instascript "$@"
    '')
  ];
  meta = {
    description = "instaScript — reel/audio → local transcript → optional DeepSeek summary + factual flags (Claude Code manages the vault)";
    mainProgram = "instascript";
  };
}
