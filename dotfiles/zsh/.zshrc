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
export PATH="$PATH:/opt/nvim/"
alias ugoon="fusermount -u ~/.decrypted"
alias igoons="encfs ~/.encrypted ~/.decrypted"

# YT-DLP, VCPKG and Go paths
export VCPKG_ROOT=/home/lysander/vcpkg
export PATH=$VCPKG_ROOT:$PATH
export PATH=/home/qwerty/scdl-env/bin:$PATH
export PATH=$PATH:/usr/local/go/bin:/home/qwerty/go/bin

# Aliases
alias nvchad='NVIM_APPNAME=nvchad nvim'
alias n='nvim'
alias lysander-git='git config --local user.name "Lysandercodes" && git config --local user.email "lysander2006@proton.me"'
alias showgitcreds='git config --list'
alias lysandergitsshcommand='export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_anon"'
alias ui='~/code/snippetbox/ui/html/pages'
alias html2tmpl='for f in *.html; do mv -- "$f" "${f%.html}.tmpl"; done'
alias tmpl2html='for f in *.tmpl; do mv -- "$f" "${f%.tmpl}.html"; done'
alias todo_update='notes.sh ~/text/todo-TODAY'
alias flatpak-builder='flatpak run org.flatpak.Builder'
alias vc='cd ~/.config/nvim/ && nvim'
alias vs='cd ~/NixOSenv/ && nvim'
alias charlie-kirk='cd ~/Charlie-Kirkification-nix-support/charlie-kirk-project && nix-shell --run "python main.py"'
alias nr="cd ~/NixOSenv && sudo nixos-rebuild switch --flake ~/NixOSenv#nixos"
alias g='cd ~/Downloads/library/GermanMechatronics/ && nvim'
alias t='cd ~/text/ && nvim'
alias push_over_https_megacorp='xclip -sel c < push_over_http'
alias scdl='yt-dlp -x --audio-format mp3 --audio-quality 0 \
       --embed-thumbnail --embed-metadata --add-metadata \
       "https://soundcloud.com/luke-lysander/likes"'

alias l='ls -lt --human-readable'

# Hugo Blog Management Aliases
alias hb="~/blog/scripts/build_preview.sh"
alias hn="~/blog/scripts/create_post.sh"
alias hp="~/blog/scripts/deploy.sh"
alias cc='cat ~/NixOSenv/configuration.nix | xclip -sel c'
alias cf='cat ~/NixOSenv/flake.nix | xclip -sel c'
alias cb='cat ~/buffer.md | xclip -sel c'
alias hr='hyprctl reload'

# ================== ORIGINAL DEEPSEEK ==================
original-deepseek() {
  export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="sk-cff51b85d3b4456db1ddedd8c9365d9a"
  export ANTHROPIC_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
  export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
  export CLAUDE_CODE_EFFORT_LEVEL="max"
  echo "✅ Switched to Original DeepSeek (Paid / Faster)"
}

# ================== OPENROUTER FREE ROUTER ==================
openrouter-free() {
  export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
  export ANTHROPIC_AUTH_TOKEN="sk-or-v1-REDACTED"
  export ANTHROPIC_API_KEY=""                                    # ← Must be empty string

  # openrouter/free router — auto-selects from 24 free models
  # Filters for: tool calling, vision, structured outputs based on request
  export ANTHROPIC_MODEL="openrouter/free"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="openrouter/free"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="openrouter/free"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="openrouter/free"
  export CLAUDE_CODE_SUBAGENT_MODEL="openrouter/free"

  echo "✅ Switched to OpenRouter Free Router"
  echo "   Auto-selects from 24 free models — 1M ctx, 1000 req/day"
}
 
gpt-oss-free() {
  export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
  export ANTHROPIC_AUTH_TOKEN="YOUR_OPENROUTER_API_KEY"
  export ANTHROPIC_API_KEY=""

  export ANTHROPIC_MODEL="openai/gpt-oss-120b:free"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="openai/gpt-oss-120b:free"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="openai/gpt-oss-120b:free"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="openai/gpt-oss-120b:free"
  export CLAUDE_CODE_SUBAGENT_MODEL="openai/gpt-oss-120b:free"

  echo "✅ Switched to GPT-OSS-120B (Free)"
}

# Quick status checker
claude-status() {
  echo "Current Base URL: $ANTHROPIC_BASE_URL"
  echo "Current Model: $ANTHROPIC_MODEL"
}

