# modules/mineru.nix — MinerU PDF-to-Markdown converter (FHS sandbox + venv)
# ────────────────────────────────────────────────────────────────────────────
# WHAT IS MINERU?
#   MinerU (github.com/opendatalab/MinerU) is an open-source tool that
#   converts PDFs into structured Markdown or JSON.  It uses a pipeline of
#   ML models (layout detection, OCR, table recognition) to handle complex
#   documents including scanned pages, multi-column layouts, and tables.
#
# WHY NOT JUST `pip install mineru`?
#   MinerU has ~80 transitive PyPI dependencies including PyTorch, Transformers,
#   and OpenCV.  These wheels bundle compiled C++ extensions that expect a
#   standard FHS Linux filesystem (e.g. /lib/x86_64-linux-gnu/libstdc++.so.6).
#   NixOS does not provide this layout — shared libraries live in /nix/store
#   instead.  The wheels therefore fail at import time with "cannot open shared
#   object file" errors unless we fake the FHS environment they expect.
#
# HOW THIS MODULE WORKS — THREE-LAYER DESIGN:
#
#   Layer 1 — buildFHSEnv (the sandbox)
#     pkgs.buildFHSEnv creates a lightweight Linux namespace that presents a
#     standard FHS directory tree (/usr, /lib, /bin, etc.) populated with
#     symlinks into the Nix store.  Any binary run inside sees a normal Linux
#     filesystem, so dlopen() calls from pip wheels resolve correctly.
#     We define TWO separate FHS envs (fhsEnv and fhsSetupEnv) that share the
#     same targetPkgs and profile but differ in their runScript (see Layer 3).
#
#   Layer 2 — pip virtualenv at /var/lib/mineru/venv
#     Inside the FHS sandbox we create a standard Python virtualenv.  This is
#     where MinerU and all its PyPI dependencies are actually installed.
#     Storing it in /var/lib/mineru (outside the Nix store) means:
#       • pip can write to it without root after initial setup
#       • ML model weights cached by MinerU at ~/.cache/mineru persist normally
#       • Upgrading is just bumping mineruVersion and re-running mineru-setup
#     The installed version is recorded in /var/lib/mineru/.installed-version
#     so mineru-setup is idempotent and skips reinstall if already current.
#
#   Layer 3 — two FHS envs with explicit runScripts
#     Both FHS envs use pkgs.writeShellScript for their runScript.  This is
#     critical: the script's shebang is a Nix store bash path, which bwrap can
#     find because it bind-mounts /nix/store into the container.  The sandbox's
#     own /bin/bash then executes the script.
#
#     fhsEnv        — runScript execs "$@", so `mineru-fhs cmd args` runs
#                     `cmd args` inside the FHS.  The mineruBin wrapper passes
#                     `venv/bin/python venv/bin/mineru "$@"` explicitly,
#                     bypassing shebang lookup entirely.
#     fhsSetupEnv   — runScript contains the pip install logic; used by
#                     `mineru-setup` to create/upgrade the venv.
#
# BUG FIX NOTES (what was wrong before):
#
#   BUG 1 — The hang:
#     fhsEnv had NO runScript, so buildFHSEnv defaulted to runScript = "bash".
#     The wrapper called:  mineru-fhs -- /var/lib/mineru/venv/bin/mineru
#     bwrap then ran:      bash -- /var/lib/mineru/venv/bin/mineru
#     In bash, `bash -- script` sets the script as a positional parameter but
#     bash STILL starts as an interactive login shell — it hangs waiting for
#     stdin.  The fix is an explicit runScript = writeShellScript that does
#     `exec "$@"`, and the wrapper no longer uses `--`.
#
#   BUG 2 — "cannot execute binary file":
#     Manually entering the FHS with `mineru-fhs -- bash -c "..."` passed
#     `bash -c ...` as args to the default bash runScript, making bwrap run:
#     `bash bash -c ...`.  bash tried to execute "bash" as a shell script
#     (an ELF binary) → ENOEXEC → "cannot execute binary file".
#     The fix is the same: explicit runScript that does `exec "$@"` so
#     `mineru-fhs cmd args` correctly exec's `cmd args` inside FHS.
#
#   BUG 3 — The broken venv (python3 missing from venv/bin):
#     The venv was partially initialised (python → python3 symlink existed
#     but python3 itself did not).  Because .installed-version was already
#     written to match mineruVersion, mineru-setup exited early with "already
#     installed" and never recreated the venv.  The fix is to force a clean
#     venv on every setup run by removing the venv directory first, and to add
#     a systemd activation script so `sudo nixos-rebuild switch` re-runs setup
#     automatically whenever mineruVersion changes.
#
# WHAT `mineru-setup` DOES STEP BY STEP:
#   1. Checks /var/lib/mineru/.installed-version against mineruVersion.
#      If already installed, exits early.
#   2. Removes any existing (possibly broken) venv directory.
#   3. Enters fhsSetupEnv (via exec) which launches bwrap.
#   4. Inside the FHS namespace (sandbox's own bash runs the runScript):
#      a. python3 -m venv /var/lib/mineru/venv --upgrade-deps
#         python3 here is /usr/bin/python3 inside FHS, which is a symlink into
#         the Nix store.  The resulting venv has:
#           venv/bin/python  → python3          (relative symlink)
#           venv/bin/python3 → /usr/bin/python3 (absolute, valid inside FHS)
#         Outside FHS the python3 symlink is dangling, but mineru always runs
#         inside FHS so it resolves correctly.
#      b. pip install --upgrade pip
#      c. pip install "mineru==<version>" with CPU-only PyTorch wheels
#      d. echo <version> > .installed-version
#
# WHAT `mineru` DOES:
#   Enters fhsEnv and explicitly invokes:
#     /var/lib/mineru/venv/bin/python  /var/lib/mineru/venv/bin/mineru  "$@"
#   We pass venv/bin/python (not the script's shebang) so the kernel never
#   needs to resolve the shebang interpreter — Python is exec'd directly.
#   Inside FHS, venv/bin/python → python3 → /usr/bin/python3 resolves fine,
#   and Python reads venv/pyvenv.cfg to find the venv's site-packages.
#
# WHY GPU ACCELERATION IS NOT USED:
#   MinerU's GPU-accelerated backends require a minimum of 6–10 GB VRAM.
#   This system's NVIDIA GeForce MX350 has only 2 GB VRAM — below the
#   minimum for every GPU backend.  The pipeline backend on pure CPU
#   (enforced via the PyTorch CPU-only wheel index below) is the correct
#   and stable choice for this machine.
#
# FIRST RUN — MODEL DOWNLOADS:
#   The first time you run `mineru` on a PDF it will download several GB of
#   model weights from HuggingFace into ~/.cache/mineru.  This is normal and
#   only happens once per model version.  Subsequent runs use the cache.
#
# UPGRADING MINERU:
#   Bump mineruVersion, run `sudo nixos-rebuild switch` (or `nr`).
#   The systemd activation script detects the version mismatch and re-runs
#   mineru-setup automatically.  You can also run `sudo mineru-setup` manually.
#
# USAGE
# ─────────────────────────────────────────────────────────────────────────────
#
# ── Setup ────────────────────────────────────────────────────────────────────
#
#   sudo mineru-setup
#     Install or upgrade MinerU into /var/lib/mineru/venv.
#     Runs automatically on `nixos-rebuild switch` when mineruVersion changes.
#     On first run, MinerU will also download several GB of model weights from
#     HuggingFace into ~/.cache/mineru — this is normal and happens only once.
#
# ── Basic usage ──────────────────────────────────────────────────────────────
#
#   mineru -p document.pdf -o ./output -b pipeline
#     Parse a single PDF.  The pipeline backend runs in pure CPU mode and is
#     the correct choice for this machine (MX350 has only 2 GB VRAM, below
#     the 6 GB minimum required by any GPU-accelerated backend).
#
#   mineru -p ./books/ -o ./output -b pipeline
#     Parse an entire directory of PDFs in one pass.
#
# ── Parsing method (-m) ──────────────────────────────────────────────────────
#
#   -m auto   Default.  MinerU decides per-page whether to use text extraction
#             or OCR based on content type.  Best for mixed documents.
#   -m txt    Force text extraction only.  Fastest.  Use when the PDF is
#             purely digital-born with no scanned pages.
#   -m ocr    Force OCR on every page.  Use for fully scanned documents or
#             when auto produces garbled output on a specific file.
#
#   Example:
#     mineru -p scanned_book.pdf -o ./output -b pipeline -m ocr
#
# ── Language hint (-l) ───────────────────────────────────────────────────────
#
#   Improves OCR accuracy when the document is not in English.
#   Only effective with the pipeline backend.
#
#   Supported values: ch, en, arabic, cyrillic, devanagari, latin, korean,
#                     japanese, chinese_cht, el, ka, ta, te, th, east_slavic
#
#   Example (Arabic document):
#     mineru -p arabic_book.pdf -o ./output -b pipeline -l arabic
#
# ── Page range (-s / -e) ─────────────────────────────────────────────────────
#
#   Parse only a subset of pages (0-based index).
#   Useful for testing output quality on a large document before committing
#   to a full run, or for splitting a book into chunks manually.
#
#   Example (pages 10–49, i.e. 40 pages):
#     mineru -p book.pdf -o ./output -b pipeline -s 10 -e 49
#
# ── Feature toggles ──────────────────────────────────────────────────────────
#
#   -f false   Disable formula parsing.  Speeds up processing on documents
#              with no mathematical content where formula detection would
#              fire on decorative symbols or section numbers.
#   -t false   Disable table parsing.  Use when tables are images or the
#              document has no tabular data worth extracting.
#
#   Example (fast mode, plain prose document):
#     mineru -p report.pdf -o ./output -b pipeline -f false -t false
#
# ── Output files ─────────────────────────────────────────────────────────────
#
#   MinerU writes output to a subdirectory named after the input file:
#     ./output/<filename>/
#       <filename>.md          ← the Markdown transcript (primary output)
#       <filename>.json        ← structured JSON with layout metadata
#       images/                ← extracted figures, diagrams, tables as PNGs
#       <filename>_origin.pdf  ← copy of the input PDF
#
# ── NotebookLM preparation ───────────────────────────────────────────────────
#
#   NotebookLM (notebooklm.google.com) accepts PDF, plain text, and Markdown
#   as uploaded sources (up to 200 MB / 500,000 words per source, 50 sources
#   per notebook).  Markdown is the preferred format: it gives NotebookLM
#   clean, structured text with headings preserved and strips out the binary
#   overhead of PDF that can cause NotebookLM to skip or misread sections.
#
#   The .md file MinerU produces at ./output/<filename>/<filename>.md is
#   ready to upload directly to NotebookLM with no further conversion needed.
#
#   Workflow:
#     1. Run MinerU on your PDF:
#          mineru -p my_book.pdf -o ./output -b pipeline
#
#     2. Verify the Markdown looks sane (skim for garbled sections):
#          nvim ./output/my_book/my_book.md
#
#     3. Optional — check word count to ensure you are within the 500k limit:
#          wc -w ./output/my_book/my_book.md
#
#     4. If the word count exceeds 500,000 words, split the PDF first using
#        the page range flags and upload each chunk as a separate source:
#          mineru -p my_book.pdf -o ./output/part1 -b pipeline -s 0   -e 299
#          mineru -p my_book.pdf -o ./output/part2 -b pipeline -s 300 -e 599
#          # Upload ./output/part1/my_book/my_book.md and
#          #        ./output/part2/my_book/my_book.md as two separate sources.
#
#     5. Upload the .md file to NotebookLM:
#          notebooklm.google.com → New notebook → Upload → select the .md file
#
#   Notes:
#     • Do NOT upload the images/ folder or the .json file to NotebookLM —
#       NotebookLM does not index image content and the JSON is noisy for it.
#     • If a chapter was scanned (images of text), re-run that page range
#       with -m ocr to get proper text before uploading.
#     • For a book already split into chapter PDFs (e.g. by a splitter tool),
#       run MinerU on each chapter PDF separately and upload each .md as its
#       own NotebookLM source — this gives you per-chapter citation granularity
#       inside NotebookLM (up to 50 sources per notebook).
# ────────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # ── version pin ────────────────────────────────────────────────────────────
  mineruVersion = "2.7.6"; # bump this to upgrade; venv is rebuilt automatically

  # ── system libraries the pip wheels dlopen at runtime ─────────────────────
  # Shared across both FHS envs so the closure is identical.
  sharedTargetPkgs =
    p: with p; [
      # Python runtime
      python312
      python312Packages.pip
      python312Packages.virtualenv

      # Native libs required by torch / opencv / pdf rendering wheels
      stdenv.cc.cc.lib # libstdc++
      zlib
      libGL
      libGLU
      glib
      nss
      nspr
      dbus
      atk
      cups
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
      libxcursor
      libxi
      pango
      cairo
      expat
      fontconfig
      freetype
      harfbuzz
      libjpeg
      libpng
      libtiff
      poppler
      poppler-utils
      ghostscript
    ];

  # ── shared environment profile ─────────────────────────────────────────────
  # profile is sourced inside the FHS namespace before the runScript runs.
  # We prepend the venv's bin dir to PATH so that `python3` and `mineru`
  # inside the sandbox resolve to the venv copies, not the system ones.
  sharedProfile = ''
    export MINERU_VENV=/var/lib/mineru/venv
    export HF_HOME=/THE_VAULT/mineru/models
    export MINERU_CACHE_DIR=/THE_VAULT/mineru/models
    export PATH="$MINERU_VENV/bin:$PATH"
    export LD_LIBRARY_PATH="${
      pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.libGL
      ]
    }:$LD_LIBRARY_PATH"
  '';

  # ── FHS env for normal usage ───────────────────────────────────────────────
  # FIX: use an explicit runScript = writeShellScript that does `exec "$@"`.
  #
  # Without this, buildFHSEnv defaults to runScript = "bash", which means
  # `mineru-fhs cmd args` becomes `bwrap [...] bash cmd args`.  bash then
  # treats `cmd` as a script to run with bash as the interpreter, breaking
  # Python scripts.  Worse, `mineru-fhs -- cmd` (with the -- convention)
  # becomes `bwrap [...] bash -- cmd`, and `bash -- cmd` sets cmd as a
  # positional parameter but still starts bash interactively → hangs.
  #
  # With runScript = writeShellScript "r" 'exec "$@"', the bwrap call becomes:
  #   bwrap [...] /nix/store/.../r  cmd  args
  # The script's shebang (/nix/store/.../bash) is found via the /nix/store
  # bind-mount that buildFHSEnv sets up automatically, so it executes
  # correctly inside the container.  It then does `exec cmd args` directly.
  fhsEnv = pkgs.buildFHSEnv {
    name = "mineru-fhs";
    targetPkgs = sharedTargetPkgs;
    profile = sharedProfile;
    runScript = pkgs.writeShellScript "mineru-fhs-run" ''
      exec "$@"
    '';
  };

  # ── Separate FHS env for setup ─────────────────────────────────────────────
  # runScript is executed by the sandbox's own bash after entering the FHS
  # namespace.  writeShellScript gives us a proper Nix store script whose
  # shebang bwrap can find via the /nix/store bind-mount.
  fhsSetupEnv = pkgs.buildFHSEnv {
    name = "mineru-fhs-setup";
    targetPkgs = sharedTargetPkgs;
    profile = sharedProfile;
    runScript = pkgs.writeShellScript "mineru-setup-inner" ''
      set -euo pipefail
      VENV=/var/lib/mineru/venv
      mkdir -p /var/lib/mineru

      echo "Creating fresh venv at $VENV …"
      # Always start from a clean venv so python/python3 symlinks are created
      # correctly by THIS Python (the FHS's /usr/bin/python3).  An existing
      # venv from a previous failed or out-of-FHS attempt would have broken
      # interpreter symlinks that python3 -m venv --upgrade-deps won't fix.
      rm -rf "$VENV"
      python3 -m venv "$VENV" --upgrade-deps

      echo "Upgrading pip …"
      "$VENV/bin/pip" install --upgrade pip

      echo "Installing MinerU ${mineruVersion} (CPU-only PyTorch wheels) …"
      # The [pipeline] extra pulls in torch, torchvision, and the layout/OCR
      # model dependencies.  Without it, mineru installs but torch is missing
      # and crashes at startup with: NameError: name 'torch' is not defined
      "$VENV/bin/pip" install "mineru[pipeline]==${mineruVersion}" \
        --extra-index-url https://download.pytorch.org/whl/cpu

      echo "${mineruVersion}" > /var/lib/mineru/.installed-version
      echo "Done. Run: mineru -p file.pdf -o ./out -b pipeline"
    '';
  };

  # ── mineru entry-point wrapper ─────────────────────────────────────────────
  # FIX: pass venv/bin/python explicitly as the interpreter rather than
  # relying on the shebang in venv/bin/mineru.
  #
  # Why: the venv's mineru script has shebang #!/var/lib/mineru/venv/bin/python.
  # The kernel resolves that to venv/bin/python → python3 (relative symlink).
  # Inside FHS, venv/bin/python3 → /usr/bin/python3 (absolute) resolves fine.
  # But if we let the kernel read the shebang, it must first exec venv/bin/mineru
  # and read the shebang BEFORE entering the FHS — so /usr/bin/python3 doesn't
  # exist yet.  By passing python explicitly as the first argument to the FHS
  # exec, Python is invoked INSIDE the FHS where all paths resolve correctly.
  # Python then reads venv/pyvenv.cfg and finds the venv's site-packages.
  mineruBin = pkgs.writeShellScriptBin "mineru" ''
    exec ${fhsEnv}/bin/mineru-fhs \
      /var/lib/mineru/venv/bin/python \
      /var/lib/mineru/venv/bin/mineru "$@"
  '';

  # ── one-shot setup script (installs / upgrades the venv) ──────────────────
  # The outer script handles the version-check guard, then exec's into
  # fhsSetupEnv whose internal script runs inside the FHS namespace.
  mineruSetup = pkgs.writeShellScriptBin "mineru-setup" ''
    set -euo pipefail
    VERSION_FILE=/var/lib/mineru/.installed-version

    # Skip if already on the right version
    if [[ -f "$VERSION_FILE" ]] && [[ "$(cat "$VERSION_FILE")" == "${mineruVersion}" ]]; then
      echo "MinerU ${mineruVersion} is already installed."
      exit 0
    fi

    echo "Installing MinerU ${mineruVersion} into /var/lib/mineru/venv …"
    exec ${fhsSetupEnv}/bin/mineru-fhs-setup
  '';

in
{
  # ── expose both binaries system-wide ──────────────────────────────────────
  environment.systemPackages = [
    mineruBin
    mineruSetup
  ];

  # ── persistent venv directory ─────────────────────────────────────────────
  # systemd-tmpfiles creates /var/lib/mineru on boot if it doesn't exist.
  # The venv itself is created by mineru-setup, not by Nix, so it survives
  # nixos-rebuild and is not wiped between generations.
  systemd.tmpfiles.rules = [
    "d /var/lib/mineru 0755 root root -"
    "d /THE_VAULT/mineru/models 0755 qwerty users -"
  ];

  # ── automatic setup on activation ─────────────────────────────────────────
  # Runs `mineru-setup` as part of `nixos-rebuild switch` whenever
  # mineruVersion changes.  This replaces the previous workflow of manually
  # running `sudo mineru-setup` after each version bump.
  #
  # The script is idempotent: if .installed-version already matches, it exits
  # immediately without network access or disk writes.
  #
  # Note: this runs as root.  The venv is owned by root but world-readable,
  # so non-root users can run `mineru` (which only reads the venv, not writes).
  system.activationScripts.mineru-setup = {
    # Run after systemd-tmpfiles has created /var/lib/mineru
    deps = [ "users" "groups" ];
    text = ''
      VERSION_FILE=/var/lib/mineru/.installed-version
      if [[ ! -f "$VERSION_FILE" ]] || [[ "$(cat "$VERSION_FILE")" != "${mineruVersion}" ]]; then
        echo "mineru-setup: installing MinerU ${mineruVersion} …"
        ${mineruSetup}/bin/mineru-setup || true
      fi
    '';
  };
}
