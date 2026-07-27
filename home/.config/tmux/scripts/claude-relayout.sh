#!/usr/bin/env bash
# tmux: 作業場のレイアウトを標準形に戻す。
#   左 = 会話ログ(nvim・幅42%) / 右上 = claude / 右下 = shell(高さ30%)
#   ＝ claude-layout.sh が新規作成するのと同じ比率。
#
# なぜ必要か:
#   prefix のあとに押し間違えると配置が入れ替わるキーが複数ある。
#     prefix + Space        next-layout（プリセットを順に切替）
#     prefix + Alt+1〜5     select-layout（even-horizontal / main-horizontal 等）
#                           ※ Alt+1〜5 は prefix 無しだとウィンドウ切替なので特に踏みやすい
#     prefix + C-o          rotate-window（ペインを回転）
#   押し間違い自体は避けられないので「一発で戻せる」手段を用意する。
#   tmux.conf では prefix + Space をこのスクリプトに差し替えてある
#   （＝一番踏みやすいキーが、壊す側ではなく直す側になる）。
#
# 使い方: prefix + Space  （または claude-relayout.sh [window]）
set -uo pipefail

W="${1:-$(tmux display-message -p '#{window_index}')}"

list_panes() { tmux list-panes -t "$W" -F '#{pane_index}	#{pane_current_command}	#{pane_start_command}'; }

panes="$(list_panes)"
n="$(printf '%s\n' "$panes" | grep -c .)"
if [ "$n" -lt 2 ]; then
  tmux display-message "ペインが1つなので戻す必要はありません"
  exit 0
fi

first="$(printf '%s\n' "$panes" | head -1 | cut -f1)"
last="$(printf '%s\n' "$panes"  | tail -1 | cut -f1)"

# 会話ログのペインは必ず先頭（＝main-vertical で左の大ペインになる位置）に置く。
# claude-log.sh で起動しているので pane_start_command で確実に見分けられる。
log="$(printf '%s\n' "$panes" | awk -F'\t' '$3 ~ /claude-log\.sh/ {print $1; exit}')"
if [ -n "${log:-}" ] && [ "$log" != "$first" ]; then
  tmux swap-pane -d -s "$W.$log" -t "$W.$first"
  panes="$(list_panes)"   # 入れ替えたので採り直す
fi

# shell ペイン（対話シェルが直に動いていて、会話ログでもない）は最後＝右下へ。
sh="$(printf '%s\n' "$panes" | awk -F'\t' '$3 == "" && $2 ~ /^(zsh|bash|sh|fish)$/ {print $1; exit}')"
if [ -n "${sh:-}" ] && [ "$sh" != "$last" ]; then
  tmux swap-pane -d -s "$W.$sh" -t "$W.$last"
fi

tmux set-window-option -t "$W" main-pane-width 42% >/dev/null
# select-layout の -t は「target-window」ではなく **target-pane**。"$W" だけ渡すと
# 別ウィンドウの指定にならず、現在ウィンドウの pane $W と解釈されて別の窓が壊れる。
# 必ず window.pane 形式で渡すこと。
tmux select-layout -t "$W.$first" main-vertical >/dev/null
[ "$n" -ge 3 ] && tmux resize-pane -t "$W.$last" -y 30%

tmux display-message "✓ レイアウトを標準に戻しました（左=会話ログ / 右上=claude / 右下=shell）"
