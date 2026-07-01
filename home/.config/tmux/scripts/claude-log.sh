#!/usr/bin/env bash
# 現在のプロジェクトの Claude 会話ログを「読みやすい Markdown」に書き出して nvim で開く。
# ログは「プロジェクト単位の固定ファイル」に継続追記する（セッションを跨いでも同じファイルが伸びる）。
#
# モード:
#   claude-log.sh [PROJ]            通常: 固定ログを nvim で開く（無ければ現行セッションから作成）。既存は再生成しない
#   claude-log.sh [PROJ] --fresh    固定ログを作り直して開く（手編集は破棄）
#   claude-log.sh [PROJ] --update   現行セッションの続きを固定ログ末尾に追記（手編集は保持・nvim は開かない）
#
# 設計:
# - 固定ログ = 1プロジェクト1ファイル（~/.claude/conversation-exports/<proj名>.md）。
#   セッションが変わっても同じファイルに追記し続ける（切れ目には『新しいセッション』見出しを入れる）。
# - append-only。手で編集した内容は --fresh 以外では消えない。
# - render は stdlib のみの render_transcript.py を shebang 直起動（uv の sync ハング回避）。
# - PROJ 省略時は tmux の現ペインの作業ディレクトリ（無ければ $PWD）。
set -euo pipefail
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER="$SDIR/render_transcript.py"

PROJ=""; FRESH=0; UPDATE=0
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

OUTDIR="$HOME/.claude/conversation-exports"
mkdir -p "$OUTDIR"
OUT="$OUTDIR/$(basename "$PROJ").md"   # ★ プロジェクト単位の固定ログ
STATE="$OUT.state"                     # render が見た raw 行数（透かし）
SIDF="$OUT.sid"                        # 最後に追記したセッションID

latest_jsonl() { ls -t "$TDIR"/*.jsonl 2>/dev/null | head -1; }

render() {  # $1 = 対象jsonl, 残り = render オプション
  local jsonl="$1"; shift
  "$RENDER" "$jsonl" "$@" 2>/dev/null || python3 "$RENDER" "$jsonl" "$@"
}

create_fresh() {  # $1 = 対象jsonl。ヘッダ付きで固定ログを作り直し、状態を記録
  local jsonl="$1"
  render "$jsonl" --state "$STATE" > "$OUT"
  basename "$jsonl" .jsonl > "$SIDF"
}

append_new() {  # $1 = 対象jsonl。現行セッションの続き（or 新セッション全体）を末尾に追記
  local jsonl="$1" sid last_sid skip tmp
  sid="$(basename "$jsonl" .jsonl)"
  last_sid="$(cat "$SIDF" 2>/dev/null || true)"
  tmp="$(mktemp)"
  if [ "$sid" = "$last_sid" ]; then
    skip="$(cat "$STATE" 2>/dev/null || echo 0)"
    render "$jsonl" --skip "$skip" --no-header --state "$STATE" > "$tmp"
  else
    # セッションが変わった（または初回追記）: 新セッションを頭から、見出し付きで
    render "$jsonl" --skip 0 --no-header --break-label "$sid" --state "$STATE" > "$tmp"
    printf '%s\n' "$sid" > "$SIDF"
  fi
  if [ -s "$tmp" ]; then
    cat "$tmp" >> "$OUT"
    printf '✓ %s に追記（+%s 行）。nvim は autoread で自動反映。\n' "$OUT" "$(wc -l < "$tmp" | tr -d ' ')"
  else
    echo "新しい会話はありません（追記なし）。"
  fi
  rm -f "$tmp"
}

# 現行セッションを少し待って取得（新規プロジェクトで claude 起動直後でも掴めるように）
wait_latest() {
  local latest i
  latest="$(latest_jsonl)"
  [ -n "$latest" ] && { printf '%s' "$latest"; return 0; }
  for i in $(seq 1 60); do
    sleep 0.5
    latest="$(latest_jsonl)"
    [ -n "$latest" ] && { printf '%s' "$latest"; return 0; }
  done
  return 1
}

# ============================ 追記モード（prefix + A） ============================
if [ "$UPDATE" = 1 ]; then
  latest="$(latest_jsonl)"
  if [ -z "$latest" ]; then echo "会話(.jsonl)が見つかりません: $TDIR"; exit 0; fi
  if [ ! -f "$OUT" ]; then
    create_fresh "$latest"           # 固定ログが無ければ新規開始（＝新しいログ開始）
    echo "✓ 固定ログを新規作成: $OUT"
  else
    append_new "$latest"
  fi
  exit 0
fi

# ====================== 通常 / --fresh モード（左ペイン起動） ======================
if [ ! -f "$OUT" ] || [ "$FRESH" = 1 ]; then
  if ! latest="$(wait_latest)"; then
    echo "このプロジェクトの会話ログ(.jsonl)がまだありません: $TDIR"
    exec "${SHELL:-/bin/zsh}"
  fi
  create_fresh "$latest"
fi

# 固定ログは「複数の作業場ウィンドウが同じ1ファイルを開く」前提（OUT はプロジェクト単位で共有）。
# nvim のスワップファイルは衝突して E325/W325『swapfile from Nvim process …』を左ペインに出すだけで
# 害しかない（このログは再生成可能な閲覧・追記用）。-n でスワップを完全に無効化して衝突を消す。
# autoread + 定期チェックで、--update の追記を自動で取り込む。
# 左ペインの nvim を RPC サーバとして起動し、ソケットをこのウィンドウの変数に記録する。
# これで prefix + F（claude-open-doc.sh）が --remote で「この nvim」に md を開ける
# ＝履歴画面と同じ nvim・同じ設定（render-markdown 等）で閲覧・編集できる。
NVIM_SOCK="${TMPDIR:-/tmp}/claude-log-nvim-$(tmux display -p '#{pane_id}' | tr -cd '0-9').sock"
rm -f "$NVIM_SOCK"
tmux set-option -w @claude_log_sock "$NVIM_SOCK" 2>/dev/null || true
nvim -n --listen "$NVIM_SOCK" \
     -c 'set autoread' \
     -c 'autocmd CursorHold,CursorHoldI,FocusGained,BufEnter * silent! checktime' \
     "$OUT"
# nvim を閉じてもペインを残す
exec "${SHELL:-/bin/zsh}"
