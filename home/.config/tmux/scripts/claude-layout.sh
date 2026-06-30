#!/usr/bin/env bash
# tmux: 「新しいウィンドウ」に claude の作業場を1つ作る。
#   左   = 会話ログ（nvim・読みやすい Markdown）
#   右上 = claude（新規に起動）
#   右下 = 作業 shell
#
# 用途: いまの作業ウィンドウは触らず、別タスク/別プロジェクト用の claude を
#       もう一つ立ち上げる。wezterm を起動し直す必要がない。
#   ※ claude は「今いるペインの作業ディレクトリ」で起動する。別プロジェクトを
#     始めたいときは、そのフォルダに cd してから prefix + W を押す。
# 使い方: prefix + W
set -euo pipefail
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${TMUX:-}" ]; then
  echo "tmux セッションの中で実行してください（prefix + W）。"
  exit 1
fi

# 起動元ペインの作業ディレクトリ＝対象プロジェクト
PROJ="$(tmux display-message -p '#{pane_current_path}')"

# 新規ウィンドウ。最初の1ペインがこのあと「右上の claude」になる
tmux new-window -c "$PROJ" -n claude
# 左に会話ログ(nvim)を 42% 幅で切り出す（-b = 新ペインを左側に）
tmux split-window -h -b -l 42% -c "$PROJ" "$SDIR/claude-log.sh '$PROJ'"
# 右の列へ移動して上下に分割（下＝作業 shell・高さ 30%）
tmux select-pane -R
tmux split-window -v -l 30% -c "$PROJ"
# 右上（claude 用ペイン）に戻して claude を起動。フォーカスもここで終わる
tmux select-pane -U
tmux send-keys "claude" Enter
