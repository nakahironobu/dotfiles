# ---- p10k instant prompt (fast startup) ----
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$HOME/.local/bin:$PATH"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# ---- Antidote ----
source "$XDG_DATA_HOME/antidote/antidote.zsh"

ZSH_PLUGINS_TXT="$HOME/.zsh_plugins.txt"
ZSH_BUNDLE_ZSH="$XDG_CACHE_HOME/zsh/antidote_bundle.zsh"
mkdir -p "${ZSH_BUNDLE_ZSH:h}"

if [[ ! -f "$ZSH_BUNDLE_ZSH" || "$ZSH_PLUGINS_TXT" -nt "$ZSH_BUNDLE_ZSH" ]]; then
  antidote bundle < "$ZSH_PLUGINS_TXT" >| "$ZSH_BUNDLE_ZSH"
fi
source "$ZSH_BUNDLE_ZSH"

# ---- Powerlevel10k config ----
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# ---- Completion ----
autoload -Uz compinit
compinit -C

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ---- autosuggestions: 候補を部分的に受け入れる（→単語単位など） ----
bindkey '^f' autosuggest-accept   # Ctrl+Fで提案を丸ごと採用（好みで変更可）

# ---- fzf-tab: プレビュー無し（高速のまま） ----
zstyle ':fzf-tab:*' fzf-preview ''

# ---- 補完のキャッシュ（体感を少し良くすることがある） ----
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"


# ---- eza のエイリアス設定 (managed block でカバーされるため最小限に) ----
alias projects='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Projects'

# --- eza aliases (managed) ---
alias z='eza --classify'
alias zz='eza --tree --level=2 --classify'
alias zzz='eza --tree --level=3 --classify'
alias zzzz='eza --tree --level=4 --classify'
alias za='eza -lah --classify'
alias zl='eza -lh --classify'
alias ls='eza --classify'
alias ll='eza -lh --classify'


# --- iCloud cd aliases (managed) ---
alias icloud='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs'
alias desktop='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop'
alias ayumi='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi'
alias manami='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Manami'
alias sapix='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Manami/Manami-Sapix'
alias seg='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi/SEG'
alias kono='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi/KonoJuku'

# --- direnv hook (managed) ---
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
