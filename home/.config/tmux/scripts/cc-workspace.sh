#!/usr/bin/env bash
# Claude Code ワークスペース起動スクリプト
# 使い方: cc-workspace [ディレクトリ]  または  tmux prefix + W
#
# ウィンドウ構成:
#   1. claude  — メインチャット (空ターミナル、claude コマンドを自分で起動)
#   2. dash    — 左:ファイルツリー / 右:ダッシュボード
#   3. work    — 3ペイン並行作業エリア
#   4. agent   — エージェント並行実行用 (2ペイン)

set -euo pipefail

DIR="${1:-$(pwd)}"
PROJECT=$(basename "$DIR")
SESSION="cc-${PROJECT}"
SCRIPTS="$HOME/.config/tmux/scripts"

# ─── 既存セッションがあれば切替/アタッチ ────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "既存セッション '$SESSION' に切替..."
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach-session -t "$SESSION"
  fi
  exit 0
fi

# ─── セッション作成 ──────────────────────────────────────────────────────────
echo "ワークスペース '$SESSION' を作成中..."

# Window 1: claude (セッション作成時の初期ウィンドウ)
tmux new-session -d -s "$SESSION" -c "$DIR" -n "claude"

# Window 2: dash — ツリー(左60%) + ダッシュボード(右40%)
tmux new-window -t "$SESSION" -c "$DIR" -n "dash"
tmux split-window -t "${SESSION}:dash" -h -l 40% -c "$DIR"
tmux send-keys -t "${SESSION}:dash.left"  "$SCRIPTS/cc-tree.sh" Enter
tmux send-keys -t "${SESSION}:dash.right" "$SCRIPTS/cc-dashboard.sh" Enter

# Window 3: work — 横2分割 + 右ペインをさらに縦2分割
tmux new-window -t "$SESSION" -c "$DIR" -n "work"
tmux split-window -t "${SESSION}:work" -h -c "$DIR"
tmux split-window -t "${SESSION}:work.right" -v -c "$DIR"

# Window 4: agent — 横2分割
tmux new-window -t "$SESSION" -c "$DIR" -n "agent"
tmux split-window -t "${SESSION}:agent" -h -c "$DIR"

# ─── フォーカスを claude ウィンドウに戻す ────────────────────────────────────
tmux select-window -t "${SESSION}:claude"

# ─── アタッチ ────────────────────────────────────────────────────────────────
printf '\n\033[1;35m◆ ワークスペース: %s\033[0m\n' "$SESSION"
printf '\033[2mウィンドウ: claude(1) / dash(2) / work(3) / agent(4)\033[0m\n'
printf '\033[2mキー: Alt+1〜4 で直接ジャンプ / prefix+T D M G W S\033[0m\n\n'

if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi
