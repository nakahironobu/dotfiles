#!/usr/bin/env bash
# tmux: prefix + F のドキュメントピッカー。
#   関連する md（会話ログ／プロジェクト内の md／ハーネス doc）を fzf で選び、
#   左ペインの nvim に開く。左 nvim は claude-log.sh が --listen で起動した RPC
#   サーバなので --remote でバッファとして開ける＝履歴画面と同じ nvim・同じ設定
#   （render-markdown 等）でそのまま閲覧・編集できる。会話ログは残り :b# で戻れる。
#
# 使い方: prefix + F
set -uo pipefail

command -v fd  >/dev/null 2>&1 || { echo "fd が必要です（brew install fd）";  exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf が必要です（brew install fzf）"; exit 1; }

# ── 左ペイン（左端に接するペイン）を特定 ─────────────────────────────────────
read -r LEFT_ID LEFT_CMD < <(tmux list-panes -F '#{pane_id} #{pane_at_left} #{pane_current_command}' \
  | awk '$2==1 { print $1, $3; exit }')
[ -n "${LEFT_ID:-}" ] || { tmux display-message "左ペインが見つかりません"; exit 0; }

PROJ="$(tmux display -p -t "$LEFT_ID" '#{pane_current_path}')"
LOG="$HOME/.claude/conversation-exports/$(basename "$PROJ").md"

# ── 候補: 会話ログ + プロジェクト内 md + ハーネス doc（ここを編集すれば範囲を変えられる）──
ROOTS=("$PROJ")
EXTRA=("$HOME/.config/tmux/HARNESS.md" "$HOME/.config/tmux/KEYBINDINGS.md")
PRUNE=(.git node_modules .venv venv vendor __pycache__ .obsidian)
fd_excludes=(); for p in "${PRUNE[@]}"; do fd_excludes+=(--exclude "$p"); done

list() {
  [ -f "$LOG" ] && printf '%s\n' "$LOG"                       # 会話ログを先頭に
  for r in "${ROOTS[@]}"; do [ -d "$r" ] && fd -t f -e md -e markdown "${fd_excludes[@]}" . "$r"; done
  for f in "${EXTRA[@]}"; do [ -f "$f" ] && printf '%s\n' "$f"; done
}

SEL="$(list | awk '!seen[$0]++' \
  | awk -v h="$HOME" '{ d=$0; sub("^"h,"~",d); print d "\t" $0 }' \
  | fzf --reverse --delimiter='\t' --with-nth=1 \
        --prompt='doc> ' \
        --header='左ペインで開くドキュメントを選択 (Enter) / Esc で中止' \
        --preview 'glow -s dark {2} 2>/dev/null || bat --color=always {2} 2>/dev/null || cat {2}' \
        --preview-window='right,55%,border-left' \
  | cut -f2)"
[ -n "${SEL:-}" ] || exit 0   # Esc / 未選択なら何もしない

SOCK="$(tmux show-option -wqv @claude_log_sock)"
if [ -n "$SOCK" ] && [ -S "$SOCK" ] && { [ "$LEFT_CMD" = nvim ] || [ "$LEFT_CMD" = vim ]; }; then
  # ① 通常経路: 既存の左 nvim(RPC サーバ)にバッファとして開く。
  #    会話ログのバッファは残るので :b# / :ls で戻れる（非破壊）。
  nvim --server "$SOCK" --remote "$SEL"
elif [ "$LEFT_CMD" = nvim ] || [ "$LEFT_CMD" = vim ]; then
  # ② 左は生きた nvim だが RPC サーバではない（この機能の導入前の作業場、
  #    または過去に会話ログを閉じた後 等でソケットが無い）。ここで
  #    respawn-pane -k すると“開いている会話ログごと nvim を殺す”＝バッファ
  #    全消失になる（← これが「F の後に元の履歴へ戻れない」不具合の正体）。
  #    絶対に殺さず、send-keys で既存 nvim に :edit させる。会話ログのバッファは
  #    残り :b# で戻れる（サーバが無くても非破壊）。
  esc="$(printf '%s' "$SEL" | sed 's/[ \\%#|]/\\&/g')"  # :edit 用に空白・特殊文字をエスケープ
  tmux send-keys -t "$LEFT_ID" Escape
  tmux send-keys -t "$LEFT_ID" -l ":edit $esc"
  tmux send-keys -t "$LEFT_ID" Enter
else
  # ③ 左ペインが nvim ですらない（会話ログを閉じてシェルに戻った 等）。
  #    ここには壊す会話ログが無いので左ペインを nvim で開き直す。その際
  #    --listen で RPC サーバとして起動し、ソケットをウィンドウ変数に記録して
  #    以後の prefix+F を ① の非破壊経路へ復帰させる。
  _tmp="${TMPDIR:-/tmp}"; _tmp="${_tmp%/}"
  NEWSOCK="$_tmp/claude-log-nvim-$(printf '%s' "$LEFT_ID" | tr -cd '0-9').sock"
  rm -f "$NEWSOCK"
  tmux set-option -w @claude_log_sock "$NEWSOCK" 2>/dev/null || true
  tmux respawn-pane -k -t "$LEFT_ID" \
    "nvim -n --listen '$NEWSOCK' -c 'set autoread' \"$SEL\""
fi
tmux select-pane -t "$LEFT_ID"
