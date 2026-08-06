# ── Legacy Boilerplate (Disabled for NixOS Compatibility) ─────────────────────
# These settings are now managed by Home Manager in your home.nix.
# Commenting them out prevents "no such file or directory" errors while
# sourcing this file for your custom aliases and paths.
#
# [[ -f /etc/zshrc ]] && . /etc/zshrc
# prompt off
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
# export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME="powerlevel10k/powerlevel10k"
# plugins=(sudo git zsh-syntax-highlighting colored-man-pages fzf-zsh-plugin fzf-tab)
# fpath=($HOME/NixOSenv/dotfiles/zsh/completions $fpath)
# source $ZSH/oh-my-zsh.sh
# [[ ! -f ${ZDOTDIR:-$HOME}/.p10k.zsh ]] || source ${ZDOTDIR:-$HOME}/.p10k.zsh

# ── API Keys (uncommitted) ────────────────────────────────────────────────────
# ~/.zshrc_secrets contains DEEPSEEK_API_KEY, TAVILY_API_KEY, etc.
# Never committed — add to .gitignore and keep local only.
[[ -f ~/.zshrc_secrets ]] && source ~/.zshrc_secrets

# ── PATH additions ────────────────────────────────────────────────────────────
export PATH="$PATH:/opt/nvim/"

# ── EncFS (encrypted folder) ─────────────────────────────────────────────────
# igoons  = mount ~/.encrypted  → ~/.decrypted via EncFS
# ugoon   = unmount ~/.decrypted
alias ugoon="fusermount -u ~/.decrypted"
alias igoons="encfs ~/.encrypted ~/.decrypted"

# ── Legacy / system paths (kept for backward compat) ─────────────────────────
# VCPKG is a C++ package manager (used on the old Arch setup, kept in case)
export VCPKG_ROOT=/home/lysander/vcpkg
export PATH=$VCPKG_ROOT:$PATH
# scdl-env: a Python virtualenv for scdl (SoundCloud downloader)
export PATH=/home/qwerty/scdl-env/bin:$PATH
# Go toolchain binaries
export PATH=$PATH:/usr/local/go/bin:/home/qwerty/go/bin

# ── Aliases ───────────────────────────────────────────────────────────────────
# Open Neovim with the NvChad config (separate NVIM_APPNAME isolates it)
alias nvchad='NVIM_APPNAME=nvchad nvim'
alias n='nvim'

# Switch local git identity to the "Lysander" anon account (old project alias)
alias lysander-git='git config --local user.name "Lysandercodes" && git config --local user.email "lysander2006@proton.me"'
alias showgitcreds='git config --list'
# Force SSH to use the anon ED25519 key for push/fetch in the current shell
alias lysandergitsshcommand='export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_anon"'

# ── File/path shortcuts (old snippetbox project) ──────────────────────────────
alias ui='~/code/snippetbox/ui/html/pages'
# Bulk rename: .html ↔ .tmpl (Go template files)
alias html2tmpl='for f in *.html; do mv -- "$f" "${f%.html}.tmpl"; done'
alias tmpl2html='for f in *.tmpl; do mv -- "$f" "${f%.tmpl}.html"; done'

alias todo_update='notes.sh ~/text/todo-TODAY'
alias flatpak-builder='flatpak run org.flatpak.Builder'
alias vc='cd ~/.config/nvim/ && nvim'
alias vs='cd ~/NixOSenv/ && nvim'
alias charlie-kirk='cd ~/Charlie-Kirkification-nix-support/charlie-kirk-project && nix-shell --run "python main.py"'

# NixOS rebuild (passwordless via sudo rule in configuration.nix)
alias nr="cd ~/NixOSenv && sudo nixos-rebuild switch --flake ~/NixOSenv#nixos"

alias g='cd ~/Downloads/library/GermanMechatronics/ && nvim'
alias t='cd ~/text/ && nvim'

# Copy the push-over-HTTPS token to clipboard (xclip = X11 clipboard)
alias push_over_https_megacorp='xclip -sel c < push_over_http'

# Download liked tracks from a SoundCloud profile as tagged MP3s
alias scdl='yt-dlp -x --audio-format mp3 --audio-quality 0 \
       --embed-thumbnail --embed-metadata --add-metadata \
       "https://soundcloud.com/luke-lysander/likes"'

alias l='ls -lt --human-readable'

# ── Hugo blog management ──────────────────────────────────────────────────────
alias hb="~/blog/scripts/build_preview.sh"   # build + open local preview
alias hn="~/blog/scripts/create_post.sh"     # scaffold a new post
alias hp="~/blog/scripts/deploy.sh"          # push to production

# ── Clipboard shortcuts ───────────────────────────────────────────────────────
alias cc='cat ~/NixOSenv/configuration.nix | xclip -sel c'
alias cf='cat ~/NixOSenv/flake.nix | xclip -sel c'
alias cb='cat ~/buffer.md | xclip -sel c'

# Reload Hyprland config without restarting the session
alias hr='hyprctl reload'

# ─────────────────────────────────────────────────────────────────────────────
# ── DeepSeek via Claude Code (Anthropic-compatible shim) ─────────────────────
#
# Claude Code uses the Anthropic SDK internally. DeepSeek exposes an
# Anthropic-compatible endpoint at api.deepseek.com/anthropic, so we can
# point the Anthropic env vars there to route ALL Claude Code traffic through
# DeepSeek instead, with no code changes.
#
# Model mapping:
#   ANTHROPIC_MODEL                  → default model for most requests
#   ANTHROPIC_DEFAULT_OPUS_MODEL     → used when /model opus is requested
#   ANTHROPIC_DEFAULT_SONNET_MODEL   → used when /model sonnet is requested
#   ANTHROPIC_DEFAULT_HAIKU_MODEL    → used when /model haiku is requested
#   CLAUDE_CODE_SUBAGENT_MODEL       → model used by spawned sub-agents
#
# deepseek-v4-flash = fast + cheap (default for most tasks)
# deepseek-v4-pro   = slower + smarter (mapped to "opus" for heavy reasoning)
deepseek() {
  export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
  export ANTHROPIC_API_KEY="$DEEPSEEK_API_KEY"
  export ANTHROPIC_MODEL="deepseek-v4-flash"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-flash"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
  export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
  echo "DeepSeek active — Flash (default) / Pro (/model opus)"
}

# Auto-enable DeepSeek on every new shell so Claude Code always uses it
deepseek
