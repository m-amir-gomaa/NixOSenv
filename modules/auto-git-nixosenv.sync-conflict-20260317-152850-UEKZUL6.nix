# modules/auto-git-nixosenv.nix — AI-powered autocommit for ~/NixOSenv
# ────────────────────────────────────────────────────────────────────────────
# HOW THIS FITS INTO THE SYSTEM:
#   configuration.nix imports this module.
#
# WHAT IT DOES:
#   Installs and runs the `autocommit` tool (see autocommit-pkg.nix) as a
#   persistent systemd user service.  Every 30 seconds (configurable via
#   AUTOCOMMIT_INTERVAL) it:
#     1. Checks ~/NixOSenv for uncommitted changes.
#     2. If changes exist, calls the OpenAI API to generate a commit message.
#     3. Commits and pushes to the remote (GitHub) using the SSH key at
#        ~/.ssh/id_ed25519_anon and the "Lysandercodes" git identity.
#
# SECRETS HANDLING:
#   The OpenAI API key is NOT stored in the Nix store (which is world-readable).
#   Instead it is read from ~/.config/autocommit/secrets.env at service start.
#   Create that file with:
#     mkdir -p ~/.config/autocommit
#     echo 'AUTOCOMMIT_API_KEY=sk-...' > ~/.config/autocommit/secrets.env
#     chmod 600 ~/.config/autocommit/secrets.env
#
# CUSTOMISATION (all via secrets.env or environment variables):
#   AUTOCOMMIT_API_KEY   (required)  OpenAI API key
#   AUTOCOMMIT_BASE_URL  (optional)  override API base URL (e.g. for a proxy)
#   AUTOCOMMIT_MODEL     (optional)  model name; default "gpt-4o"
#   AUTOCOMMIT_PUSH      (optional)  "true"/"false"; default true
#   AUTOCOMMIT_INTERVAL  (optional)  seconds between commit checks; default 30
#
# SSH KEY SETUP:
#   The service uses ~/.ssh/id_ed25519_anon via GIT_SSH_COMMAND.
#   Ensure the corresponding public key is added to the GitHub account and
#   that the remote is configured as an SSH URL:
#     git -C ~/NixOSenv remote set-url origin git@github.com:USER/NixOSenv.git
# ────────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}:

let
  user    = "qwerty";
  repoDir = "/home/${user}/NixOSenv";
  branch  = "main";
in
{
  environment.systemPackages = with pkgs; [
    autocommit   # defined in modules/autocommit-pkg.nix; built from source
    git
    openssh
  ];

  # ── Systemd user service ──────────────────────────────────────────────────
  # This is a systemd --user service (runs in the user's session, not as root).
  # "default.target" is the standard target for user services that should start
  # whenever the user logs in.
  systemd.user.services.auto-git-autocommit = {
    description = "AI-powered Autocommit for ~/NixOSenv";
    wantedBy    = [ "default.target" ];

    serviceConfig = {
      # EnvironmentFile: load secrets from this file into the service env.
      # The leading "%-" means "optional; don't fail if the file is missing"
      # (so the system still boots on first setup before the key is configured).
      EnvironmentFile = "-%h/.config/autocommit/secrets.env";

      WorkingDirectory = repoDir;

      # ExecStart: a Nix-generated shell script.
      # Using writeShellScript ensures:
      #   a) The script is stored immutably in the Nix store.
      #   b) All tool paths are absolute (no PATH dependency at runtime).
      #   c) set -euo pipefail makes any unhandled error abort the service so
      #      systemd can restart it cleanly rather than silently continuing.
      ExecStart = pkgs.writeShellScript "autocommit-wrapper" ''
        #!/usr/bin/env bash
        set -euo pipefail

        GIT="${pkgs.git}/bin/git"
        SSH="${pkgs.openssh}/bin/ssh"

        # GIT_SSH_COMMAND tells git which SSH binary and key to use for push/fetch.
        # IdentitiesOnly=yes prevents SSH from offering other keys from the agent,
        # which could cause unexpected authentication if the agent has many keys.
        export GIT_SSH_COMMAND="$SSH -i /home/${user}/.ssh/id_ed25519_anon -o IdentitiesOnly=yes"

        # Set the git committer identity for this repo only (--local).
        # This identity shows up in `git log` and on GitHub.
        cd "${repoDir}"
        $GIT config --local user.name  "Lysandercodes"
        $GIT config --local user.email "lysander2006@proton.me"

        # Build a temporary config.yaml for autocommit.
        # mktemp -d creates a tmpfs directory that is cleaned up on EXIT by trap.
        # We write config.yaml here instead of ~/.config/autocommit/config.yaml
        # so the API key (read from the env var) is never written to disk.
        CONFIG_DIR=$(mktemp -d)
        trap 'rm -rf "$CONFIG_DIR"' EXIT

        # Read overrides from env or fall back to sensible defaults.
        BASE_URL=''${AUTOCOMMIT_BASE_URL:-"https://api.openai.com/v1/"}
        MODEL=''${AUTOCOMMIT_MODEL:-"gpt-4o"}
        PUSH=''${AUTOCOMMIT_PUSH:-"true"}
        INTERVAL=''${AUTOCOMMIT_INTERVAL:-"30"}

        cat > "$CONFIG_DIR/config.yaml" <<EOF
repo_path: "${repoDir}"
interval_seconds: $INTERVAL
api_key: "$AUTOCOMMIT_API_KEY"
base_url: "$BASE_URL"
push: $PUSH
model: "$MODEL"
timeout: 30
EOF

        # Run autocommit from its own config directory.
        # exec replaces the shell process with autocommit so systemd tracks the
        # right PID for restart logic.
        cd "$CONFIG_DIR"
        exec ${pkgs.autocommit}/bin/autocommit
      '';

      # Restart the service 10 seconds after any failure (e.g. network blip,
      # API error, git conflict) so commit coverage is robust.
      Restart    = "always";
      RestartSec = "10s";
    };
  };
}
