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
#        ~/.ssh/id_ed25519 and the "m-amir-gomaa" git identity.
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
#   AUTOCOMMIT_INTERVAL  (optional)  seconds between checks; default 300 (5 min)
#   GITHUB_TOKEN         (optional)  if set, push uses HTTPS with this token
#                                    instead of SSH. Add to secrets.env:
#                                      GITHUB_TOKEN=ghp_...
#
# SSH KEY SETUP (if not using GITHUB_TOKEN):
#   The service uses ~/.ssh/id_ed25519 via GIT_SSH_COMMAND.
#   Ensure the corresponding public key is added to the GitHub account and
#   that the remote is configured as an SSH URL:
#     git -C ~/NixOSenv remote set-url origin git@github.com:USER/NixOSenv.git
#
# FIXING PUSH (quick):
#   If SSH push is broken, easiest fix is to add GITHUB_TOKEN to secrets.env.
#   The script will push via HTTPS automatically — no SSH key needed.
# ────────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}:

let
  user = "qwerty";
  repoDir = "/home/${user}/NixOSenv";
  branch = "main";
in
{
  environment.systemPackages = with pkgs; [
    autocommit # defined in modules/autocommit-pkg.nix; built from source
    git
    openssh
  ];

  # ── Systemd user service ──────────────────────────────────────────────────
  # This is a systemd --user service (runs in the user's session, not as root).
  # "default.target" is the standard target for user services that should start
  # whenever the user logs in.
  systemd.user.services.auto-git-autocommit = {
    description = "AI-powered Autocommit for ~/NixOSenv";
    wantedBy = [ "default.target" ];

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
        # set -euo pipefail makes the script strict:
        #   -e  exit immediately if any command fails
        #   -u  treat unset variables as errors (catches typos)
        #   -o pipefail  if any command in a pipe fails, the whole pipe fails
        # Together these prevent silent failures that are hard to debug.
        set -euo pipefail

        GIT="${pkgs.git}/bin/git"
        SSH="${pkgs.openssh}/bin/ssh"

        # GIT_SSH_COMMAND tells git which SSH binary and key to use for push/fetch.
        # IdentitiesOnly=yes prevents SSH from offering other keys from the agent,
        # which could cause unexpected authentication if the agent has many keys.
        export GIT_SSH_COMMAND="$SSH -i /home/${user}/.ssh/id_ed25519 -o IdentitiesOnly=yes"

        cd "${repoDir}"
        $GIT config --local user.name  "amircodes"
        $GIT config --local user.email "mo.gomaa.formal@gmail.com"

        # mktemp -d creates a unique temporary directory (e.g. /tmp/tmp.xZ3k9).
        # We write the config here so the API key never touches a predictable path.
        # trap ensures this directory is deleted when the script exits for any reason
        # (normal exit, error, or SIGTERM from systemd stopping the service).
        CONFIG_DIR=$(mktemp -d)
        trap 'rm -rf "$CONFIG_DIR"' EXIT

        # '\'$\{VAR:-default} is Nix-escaped bash parameter expansion.
        # The extra '\'  # escapes the $ so Nix doesn't try to interpolate it.
        # At runtime this reads as: use $VAR if set, otherwise use the default.
        BASE_URL=''${AUTOCOMMIT_BASE_URL:-"https://api.openai.com/v1/"}
        MODEL=''${AUTOCOMMIT_MODEL:-"gpt-4o"}
        PUSH=''${AUTOCOMMIT_PUSH:-"true"}

        # INTERVAL: how many seconds to wait between change checks.
        # Default is 300 (5 minutes) — not 30 — to avoid commit spam.
        INTERVAL=''${AUTOCOMMIT_INTERVAL:-"300"}

        cat > "$CONFIG_DIR/config.yaml" <<-EOF
            repo_path: "${repoDir}"
            interval_seconds: $INTERVAL
            api_key: "$AUTOCOMMIT_API_KEY"
            base_url: "$BASE_URL"
            push: $PUSH
            model: "$MODEL"
            timeout: 30
        EOF

        # Main loop: check for meaningful changes, then commit and push.
        while true; do
          cd "${repoDir}"

          # Stage everything: modified, deleted, and new files.
          # -A means "all" — equivalent to git add . from the repo root.
          $GIT add -A

          # git diff --cached shows what is staged (ready to commit).
          # --quiet suppresses output and returns exit code 1 if there are changes.
          # If the staged diff IS empty (nothing to commit), skip and wait.
          if $GIT diff --cached --quiet; then
            sleep "$INTERVAL"
            continue
          fi

          # Count how many files changed in the staged diff.
          # diff --cached --name-only lists one filename per line.
          # wc -l counts the lines = number of changed files.
          CHANGED_FILES=$($GIT diff --cached --name-only | wc -l)

          # Count total lines added and removed across all staged changes.
          # diff --cached --shortstat prints a summary like:
          #   "3 files changed, 10 insertions(+), 2 deletions(-)"
          # grep -oP '\d+(?= insertion)' extracts just the insertion count.
          # The || echo 0 handles the case where there are no insertions at all
          # (e.g. pure deletions), preventing the script from crashing on empty grep.
          # NOTE: Since `set -e` is on, we have to handle the grep error explicitly in a subshell.
          INSERTIONS=$( ($GIT diff --cached --shortstat | grep -oP '\d+(?= insertion)') || echo 0)
          DELETIONS=$( ($GIT diff --cached --shortstat | grep -oP '\d+(?= deletion)') || echo 0)
          TOTAL_LINES=$(( INSERTIONS + DELETIONS ))

          # Meaningfulness filter:
          # Only commit if EITHER of these thresholds is met:
          #   - at least 2 files changed, OR
          #   - at least 5 lines changed across all files
          # This prevents single-character edits or auto-saves from
          # generating noisy commits.
          if [ "$CHANGED_FILES" -lt 2 ] && [ "$TOTAL_LINES" -lt 5 ]; then
            # Not meaningful enough — unstage everything and wait.
            # git reset HEAD unstages all staged changes without touching
            # the actual files on disk (a "soft" unstage).
            $GIT reset HEAD
            sleep "$INTERVAL"
            continue
          fi

          # Changes are meaningful — hand off to autocommit to generate
          # an AI commit message and commit. autocommit reads config.yaml
          # from the current directory, so we cd there first.
          cd "$CONFIG_DIR"
          ${pkgs.autocommit}/bin/autocommit

          # Push if enabled.
          if [ "$PUSH" = "true" ]; then
            cd "${repoDir}"

            # If GITHUB_TOKEN is set in secrets.env, push via HTTPS.
            # This is the easiest fix if SSH push is broken — just add
            # GITHUB_TOKEN=ghp_... to ~/.config/autocommit/secrets.env.
            # The token is injected into the URL at runtime and never
            # stored in git config or on disk.
            if [ -n "''${GITHUB_TOKEN:-}" ]; then
              HTTPS_REMOTE="https://m-amir-gomaa:$GITHUB_TOKEN@github.com/m-amir-gomaa/NixOSenv.git"
              $GIT push "$HTTPS_REMOTE" ${branch} || echo "HTTPS push failed — will retry next cycle"
            else
              # Fall back to SSH (uses GIT_SSH_COMMAND set above).
              $GIT push origin ${branch} || echo "SSH push failed — will retry next cycle"
            fi
          fi

          sleep "$INTERVAL"
        done
      '';

      # Restart the service 10 seconds after any failure (e.g. network blip,
      # API error, git conflict) so commit coverage is robust.
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
