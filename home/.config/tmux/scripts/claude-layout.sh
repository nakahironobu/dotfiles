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

# 新規ウィンドウ。最初の1ペインが「右上の claude」になる
tmux new-window -c "$PROJ" -n claude
# 先に claude（毎回まっさらな新セッション）を起動しておく。
#   こうすると、続く左ペインの claude-log.sh は「いま起動した現行セッション」を掴め、
#   prefix + A の追記先（固定ログ）と必ず一致する。新規プロジェクトでも jsonl 生成を待てる。
tmux send-keys "claude" Enter
# 左に会話ログ(nvim)を 42% 幅で切り出す（-b = 新ペインを左側に）。固定ログを開く。
tmux split-window -h -b -l 42% -c "$PROJ" "$SDIR/claude-log.sh '$PROJ'"
# 右の列へ移動して上下に分割（下＝作業 shell・高さ 30%）。
# shell ペインの id を控える（後で「最大化トリガ」をこの idle ペインの tty へ送る）
tmux select-pane -R
shell_pane="$(tmux split-window -v -l 30% -c "$PROJ" -P -F '#{pane_id}')"
# 右上（claude）にフォーカスを戻して終了
tmux select-pane -U

# ─── 外側の WezTerm 窓を最大化 ───────────────────────────────────────────────
# tmux の中からは外側の WezTerm を直接操作できない。WezTerm の user-var
# `WEZTERM_MAXIMIZE` を立てると wezterm.lua の user-var-changed → window:maximize()
# が発火する。OSC 1337(SetUserVar) を tmux passthrough(allow-passthrough on)で素通しする。
#   - 値は毎回ユニーク(nonce)にして、確実にイベントを発火させる。
#   - idle な shell ペインの tty へ書く: claude(TUI)の出力と混じらず、可視ペインなので確実に転送される。
#   - WezTerm 以外の端末や passthrough 無効時は単に無視される（害なし）。
if command -v base64 >/dev/null 2>&1; then
  shell_tty="$(tmux display-message -p -t "$shell_pane" '#{pane_tty}')"
  nonce="$(printf 'max-%s' "${RANDOM:-0}" | base64 | tr -d '\n')"
  printf '\033Ptmux;\033\033]1337;SetUserVar=WEZTERM_MAXIMIZE=%s\007\033\\' "$nonce" > "$shell_tty"
fi
