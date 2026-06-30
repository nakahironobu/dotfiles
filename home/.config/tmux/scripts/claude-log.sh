#!/usr/bin/env bash
# 現在のプロジェクトの Claude 会話ログを「読みやすい Markdown」に書き出して nvim で開く。
#
# モード:
#   claude-log.sh [PROJ]            通常: 無ければ書き出して nvim で開く（既存は再生成しない）
#   claude-log.sh [PROJ] --fresh    最初から作り直して開く（手編集は破棄）
#   claude-log.sh [PROJ] --update   続きの会話だけを末尾に追記する（手編集は保持・nvim は開かない）
#
# - スナップショット方式。手で編集した内容は --fresh 以外では消えない。
# - PROJ 省略時は tmux の現ペインの作業ディレクトリ（無ければ $PWD）。
set -euo pipefail
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJ=""
FRESH=0
UPDATE=0
for a in "$@"; do
  case "$a" in
    --fresh)  FRESH=1 ;;
    --update) UPDATE=1 ;;
    *)        PROJ="$a" ;;
  esac
done
if [ -z "$PROJ" ]; then
  PROJ="$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || true)"
  [ -z "$PROJ" ] && PROJ="$PWD"
fi

# プロジェクト絶対パス → Claude transcript ディレクトリ名（非英数字を - に）
KEY="$(printf '%s' "$PROJ" | sed 's#[^a-zA-Z0-9]#-#g')"
TDIR="$HOME/.claude/projects/$KEY"
LATEST="$(ls -t "$TDIR"/*.jsonl 2>/dev/null | head -1 || true)"

if [ -z "$LATEST" ]; then
  echo "このプロジェクトの会話ログ(.jsonl)が見つかりません: $TDIR"
  [ "$UPDATE" = 1 ] && exit 0
  exec "${SHELL:-/bin/zsh}"
fi

OUTDIR="$HOME/.claude/conversation-exports"
mkdir -p "$OUTDIR"
OUT="$OUTDIR/$(basename "$PROJ")-$(basename "$LATEST" .jsonl).md"
STATE="$OUT.state"

# uv 優先（標準ライブラリのみなので python3 にフォールバック可）
render() {  # 引数: render に渡す追加オプション
  if ! ( cd "$PROJ" && uv run python "$SDIR/render_transcript.py" "$LATEST" "$@" ) 2>/dev/null; then
    python3 "$SDIR/render_transcript.py" "$LATEST" "$@"
  fi
}

if [ "$UPDATE" = 1 ]; then
  # === 追記モード: 続きの会話だけを末尾に足す（手編集は触らない） ===
  [ -f "$OUT" ] || { echo "先に通常モードで作成してください: claude-log.sh"; exit 0; }
  SKIP="$(cat "$STATE" 2>/dev/null || echo 0)"
  TMP="$(mktemp)"
  render --skip "$SKIP" --no-header --state "$STATE" > "$TMP"
  if [ -s "$TMP" ]; then
    cat "$TMP" >> "$OUT"
    echo "✓ 続きを $OUT に追記（+$(wc -l < "$TMP") 行）。nvim は autoread で自動反映されます。"
  else
    echo "新しい会話はありません（追記なし）。"
  fi
  rm -f "$TMP"
  exit 0
fi

# === 通常モード ===
if [ ! -f "$OUT" ] || [ "$FRESH" = 1 ]; then
  render --state "$STATE" > "$OUT"
fi

# autoread + 定期チェックで、--update の追記を自動で取り込む
nvim -c 'set autoread' \
     -c 'autocmd CursorHold,CursorHoldI,FocusGained,BufEnter * silent! checktime' \
     "$OUT"
# nvim を閉じてもペインを残す
exec "${SHELL:-/bin/zsh}"
