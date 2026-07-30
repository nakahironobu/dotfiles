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

# ---- コマンドラインを vim 操作にする（vi モード） ----
# Esc でノーマルモード → h j k l・w b・0 ^ $・dd cw x 等が使える。i / a で挿入に戻る。
# tmux の prefix が C-a のため行頭移動の C-a は tmux に取られるが、vi モードなら
# 「Esc → 0（行頭）/ $（行末）」で代用できるので C-a 不要。p10k がモード表示を出す。
bindkey -v
export KEYTIMEOUT=1                          # Esc の反応を速く（10ms）
# 挿入モードでも最低限の便利キーは残す（tmux 外での行頭/行末・履歴・補完受け入れ）
bindkey -M viins '^a' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins '^f' autosuggest-accept     # ↑の既存設定を vi モードでも維持
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M viins '^p' up-line-or-history
bindkey -M viins '^n' down-line-or-history
bindkey -M vicmd '^f' autosuggest-accept

# ---- fzf-tab: プレビュー無し（高速のまま） ----
zstyle ':fzf-tab:*' fzf-preview ''

# ---- 補完のキャッシュ（体感を少し良くすることがある） ----
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"


# ---- eza のエイリアス設定 (managed block でカバーされるため最小限に) ----
alias projects='cd "/Users/hironobu/Library/CloudStorage/GoogleDrive-hironobu@nakafamily.com/その他のパソコン/マイ iMac/Desktop/Projects/"'
alias ayumi='cd "/Users/hironobu/Library/CloudStorage/GoogleDrive-hironobu@nakafamily.com/その他のパソコン/マイ iMac/Desktop/Ayumi/"'
alias manami='cd "/Users/hironobu/Library/CloudStorage/GoogleDrive-hironobu@nakafamily.com/その他のパソコン/マイ iMac/Desktop/Manami/"'

# --- eza aliases (managed) ---
alias ls='eza --classify'
alias ll='eza -lh --classify'
alias la='eza -lah --classify'
alias zl='eza -lh --classify'
alias za='eza -lah --classify'
alias zz='eza --tree --level=2 --classify'
alias zzz='eza --tree --level=3 --classify'
alias zzzz='eza --tree --level=4 --classify'


# --- direnv hook (managed) ---
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
export PATH=~/.npm-global/bin:$PATH

# --- SAPIX-sync aliases ---
# Mac → Ubuntu (192.168.10.134) 教材アップデート反映 & 運用
alias sapix-sync='~/Desktop/Projects/Infrastructure/SAPIX-sync/sync.sh'
alias sapix-status='~/Desktop/Projects/Infrastructure/SAPIX-sync/status.sh'
alias sapix-logs='~/Desktop/Projects/Infrastructure/SAPIX-sync/logs.sh'
alias sapix-restart='~/Desktop/Projects/Infrastructure/SAPIX-sync/restart.sh'
alias sapix-pull-records='~/Desktop/Projects/Infrastructure/SAPIX-sync/pull-records.sh'

# Google Drive マイドライブへの移動
alias google-my='cd "/Users/hironobu/Library/CloudStorage/GoogleDrive-hironobu@nakafamily.com/マイドライブ"'

# uv スタンドアロンインストーラの env（Homebrew 版 uv では存在しないので存在時のみ読み込む）
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# tmux Claude ワークスペース用スクリプト (cc-workspace.sh 等)
export PATH="$HOME/.config/tmux/scripts:$PATH"

# ---- projcmd: ~/Projects 横断コマンドランチャ（Ctrl-G）----
# 各プロジェクトの README/DEPLOY/CLAUDE.md・*.sh・pyproject・memory から
# 「演習アプリ起動／Ubuntuデプロイ／クロップ画面／PDF-OCR／M4へrsync」等を集めて
# fzf で絞り込み、選んだものを *実行せず* コマンドラインに書き出す（確認・編集してから Enter）。
#   Tab で複数選択 → && で連結 / Ctrl-R で再スキャン / 一覧は `projcmd list`
projcmd-widget() {
  local out
  out="$(projcmd pick --pwd "$PWD" < /dev/tty)" || { zle reset-prompt; return 0 }
  [[ -z "$out" ]] && { zle reset-prompt; return 0 }
  BUFFER="$out"
  CURSOR=${#BUFFER}
  zle reset-prompt
}
zle -N projcmd-widget
bindkey '^g' projcmd-widget
bindkey -M viins '^g' projcmd-widget
bindkey -M vicmd '^g' projcmd-widget

# ---- herdr: WezTerm から TUI を開いたら窓をフルスクリーンにする ----
# herdr 自身は外側の端末窓を操作できない（0.7.5 にそういう設定は無い）。
# そこで TUI を起動する直前に WezTerm の user-var WEZTERM_FULLSCREEN を立て、
# ~/.config/wezterm/wezterm.lua の user-var-changed → toggle_fullscreen に任せる。
# （tmux の claude-layout.sh が WEZTERM_MAXIMIZE でやっているのと同じ仕組み）
#   - 発火するのは TUI を開く形だけ。`herdr pane list` 等の CLI では出さない。
#   - herdr ペインの中（HERDR_ENV=1）や WezTerm 以外の端末では何もしない。
#   - 既にフルスクリーンなら WezTerm 側が無視する（トグルで抜けたりしない）。
#   - herdr を終了したら元の窓に戻す。ただし「こちらが入れた」フルスクリーンだけ
#     （手でフルスクリーンにしていた窓は WezTerm 側の記録が無いので解除されない）。

# 引数が「TUI を開く形」か。herdr --help の Usage に対応:
#   herdr / herdr --session <name> / herdr --remote <target> /
#   herdr --no-session / herdr session attach <name>
_herdr_opens_tui() {
  case "${1-}" in
    ""|--session|--remote|--no-session|--remote-keybindings|--handoff) return 0 ;;
    session) [[ "${2-}" == "attach" ]] ;;
    *) return 1 ;;
  esac
}

# user-var は「値が変わったとき」だけイベントになるので、毎回違う値を送る。
# 値は base64（OSC 1337 SetUserVar の仕様）。tmux の中なら passthrough で包む。
typeset -gi _wezterm_uservar_seq=0
_wezterm_send_user_var() {   # $1 = user-var 名。値は毎回変わる nonce
  # 連番と $RANDOM はカレントシェルで確定させる。$(...) の中で評価すると
  # 副シェルなので加算が捨てられ、2回目以降も同じ値＝イベントが発火しない。
  local seq=$(( ++_wezterm_uservar_seq )) rnd=$RANDOM nonce
  nonce="$(printf '%s-%s-%s' "$$" "$seq" "$rnd" | base64 | tr -d '\n')"
  if [[ -n "${TMUX-}" ]]; then
    printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' "$1" "$nonce"
  else
    printf '\033]1337;SetUserVar=%s=%s\007' "$1" "$nonce"
  fi
}

herdr() {
  local went_fullscreen=0
  if [[ "${TERM_PROGRAM-}" == "WezTerm" && "${HERDR_ENV-}" != "1" && -t 1 ]] \
     && _herdr_opens_tui "$@"; then
    _wezterm_send_user_var WEZTERM_FULLSCREEN
    went_fullscreen=1
  fi
  command herdr "$@"
  local ret=$?          # status は zsh の予約変数（$? の別名）なので使わない
  (( went_fullscreen )) && _wezterm_send_user_var WEZTERM_FULLSCREEN_RESTORE
  return $ret
}
