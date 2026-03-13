# flake.nix — NixOS system flake entrypoint
# ────────────────────────────────────────────────────────────────────────────
# WHAT IS A FLAKE?
#   A flake is a Nix file with a standardised structure: it declares `inputs`
#   (external dependencies pinned in flake.lock) and `outputs` (packages,
#   NixOS configurations, dev shells, etc.).
#   `flake.lock` pins every input to an exact git revision so builds are
#   reproducible across machines and time.
#
# HOW TO REBUILD:
#   sudo nixos-rebuild switch --flake ~/NixOSenv#nixos
#   (alias: nr — defined in dotfiles/zsh/.zshrc)
#
# HOW TO UPDATE INPUTS:
#   nix flake update                     # update all inputs
#   nix flake update nixpkgs             # update only nixpkgs
#
# HOW TO CHECK THE SYSTEM CLOSES:
#   nix flake check                      # evaluate all outputs for errors
# ────────────────────────────────────────────────────────────────────────────
{
  description = "NixOS config — Hyprland laptop (NVIDIA Prime + Intel iGPU)";
  inputs = {
    # ── nixpkgs — main package collection ────────────────────────────────────
    # nixos-unstable tracks the rolling-release branch; it is more current than
    # a stable release but occasionally has broken packages for a few hours.
    # All other inputs are instructed to `follows` this so they share a single
    # nixpkgs instance and don't pull in duplicate copies of the package set.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # ── fenix — nightly Rust toolchain ───────────────────────────────────────
    # fenix provides Rust components (rustc, cargo, clippy, rust-src, etc.)
    # from the official Rust nightly channel.  This gives access to unstable
    # features and the latest rust-analyzer-nightly.
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ── home-manager — user-level dotfile management ──────────────────────────
    # Home Manager is a Nix module system for managing user configuration.
    # It is wired in as a NixOS module (home-manager.nixosModules.home-manager)
    # so `nixos-rebuild switch` applies both system and user changes in one step.
    # `inputs.nixpkgs.follows` ensures it uses the same nixpkgs closure.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ── antigravity-nix — Cursor IDE (agentic AI coding tool) ────────────────
    # antigravity-nix packages the Cursor IDE for NixOS, solving the usual
    # GLIBC/FHS incompatibilities by wrapping the AppImage.
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ── neovim-nightly-overlay — Bleeding edge Neovim ─────────────────────────
    # Provides the latest Neovim nightly builds and optimized treesitter parsers.
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";



    # ── german-pronunciation-cli — Rust-based German pronunciation trainer ──────
    # Replaces the deprecated aussprachetrainer flake.
    # CLI tool (gp): IPA transcription, Edge TTS, Whisper STT scoring,
    # Vim modal REPL, fuzzy autocomplete over 170k words, SQLite spaced repetition.
    # german-pronunciation-cli.url = "github:m-amir-gomaa/The_German_Pronunciation_CLI_App";
  };
  outputs =
    {
      self,
      fenix,
      nixpkgs,
      antigravity-nix,
      # german-pronunciation-cli,  # uncomment when flake.nix is added to the repo
      home-manager,
      neovim-nightly-overlay,
      ...
    }:
    {
      # ── Standalone packages ───────────────────────────────────────────────────
      # These can be built with `nix build .#PACKAGE_NAME`
      packages.x86_64-linux = {
        # default: the stable Rust toolchain (rustc + cargo)
        default = fenix.packages.x86_64-linux.stable.toolchain; # CHANGED: minimal nightly → stable
        # autocommit: the AI autocommit tool (see modules/autocommit-pkg.nix)
        autocommit = nixpkgs.legacyPackages.x86_64-linux.callPackage ./modules/autocommit-pkg.nix { };
      };
      # ── NixOS system configuration ────────────────────────────────────────────
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # ── Core system config ──────────────────────────────────────────────
          ./hardware-configuration.nix # auto-generated hardware options
          ./configuration.nix # all system-level options
          # ── Antigravity (Cursor IDE) ─────────────────────────────────────────
          # Added as an inline module (not via overlay) so the package is in
          # environment.systemPackages without scoping issues.
          {
            nixpkgs.config.allowUnfree = true;
            environment.systemPackages = [
              antigravity-nix.packages.x86_64-linux.default
              # german-pronunciation-cli.packages.x86_64-linux.default  # uncomment when flake.nix is added to the repo
            ];
          }
          # ── Overlays: Fenix Rust + autocommit + pinned Hugo ───────────────────
          # An overlay is a function (final: prev: { … }) that extends or overrides
          # the nixpkgs package set.  `final` is the fully-resolved set (use for
          # callPackage); `prev` is the pre-overlay set (use to override).
          (
            { pkgs, ... }:
            {
              nixpkgs.overlays = [
                # fenix.overlays.default adds pkgs.fenix.{complete,minimal,stable,…} attrs
                fenix.overlays.default
                # neovim-nightly-overlay adds pkgs.neovim-nightly
                neovim-nightly-overlay.overlays.default
                (final: prev: {
                  less = prev.less.overrideAttrs (old: {
                    postInstall = ''
                      sed -i 's/--no-lesskey//g' $out/share/less/lesskey.src || true
                    '';
                  });
                  # autocommit: our custom Python package for AI-powered git commits
                  autocommit = final.callPackage ./modules/autocommit-pkg.nix { };
                  # Hugo: pinned to 0.156.0 because later versions changed the
                  # template syntax in ways that broke the existing blog templates.
                  # overrideAttrs replaces only src + version; everything else
                  # (build system, dependencies, meta) is inherited from nixpkgs.
                  hugo = prev.hugo.overrideAttrs (_: {
                    version = "0.156.0";
                    src = final.fetchFromGitHub {
                      owner = "gohugoio";
                      repo = "hugo";
                      rev = "v0.156.0";
                      hash = "sha256-7I6CONFpkYd3+2C5xssEmRQGJGDOc1RnlX6UDGy/JZU=";
                    };
                    vendorHash = "sha256-X1wndkxemlUis2oWc4ufdonZqgO6aQikij0rU3jZaRs=";
                    doCheck = false; # upstream tests are fragile across versions
                  });
                })
              ];
              environment.systemPackages = [
                # Stable Rust toolchain: rustc, cargo, clippy, rust-src,
                # rustfmt, rust-docs.
                # withComponents builds a single derivation that merges all selected
                # components; this avoids multiple PATH entries for rust tools.
                (pkgs.fenix.stable.withComponents [
                  # CHANGED: complete (nightly) → stable
                  "cargo"
                  "clippy"
                  "rust-src"
                  "rustc"
                  "rustfmt"
                  "rust-docs"
                ])
                # rust-analyzer: LSP for Rust; stable build to match the stable toolchain.
                pkgs.fenix.stable.rust-analyzer # CHANGED: rust-analyzer-nightly → stable
                pkgs.hugo
              ];
            }
          )
          # ── Automatic NixOS upgrades ──────────────────────────────────────────
          # system.autoUpgrade rebuilds the system from this flake on a weekly
          # schedule via a systemd timer.  It updates the nixpkgs and
          # antigravity-nix inputs before building and commits the updated
          # flake.lock via --commit-lock-file so the repo stays in sync.
          #
          # randomizedDelaySec spreads the upgrade across a 45-minute window after
          # the scheduled time to avoid thundering-herd issues if multiple machines
          # share the same schedule.
          {
            system.autoUpgrade = {
              enable = true;
              flake = self.outPath;
              flags = [
                "--update-input"
                "nixpkgs"
                "--update-input"
                "antigravity-nix"
                "--commit-lock-file"
                "-L" # verbose log (shows package changes)
              ];
              dates = "weekly";
              randomizedDelaySec = "45min";
              operation = "switch"; # apply immediately (not "boot")
            };
          }
          # ── Home Manager integration ──────────────────────────────────────────
          # home-manager.nixosModules.home-manager makes Home Manager a NixOS
          # module so it runs as part of `nixos-rebuild switch`.
          home-manager.nixosModules.home-manager
          {
            # useGlobalPkgs: use the system nixpkgs instance (avoids a second
            # evaluation of nixpkgs inside Home Manager)
            home-manager.useGlobalPkgs = true;
            # useUserPackages: install user packages via users.users.*.packages
            # (they appear in the user's profile, not in the system profile)
            home-manager.useUserPackages = true;
            # backupFileExtension: if Home Manager wants to write a file that
            # already exists as a non-managed file, back it up with this suffix
            # instead of aborting the activation.
            home-manager.backupFileExtension = "backup";
            # Wire each home.nix file to its respective user.
            home-manager.users.qwerty = import ./home.nix;
            home-manager.users.root = import ./home-root.nix;
          }
        ];
      };
    };
}
