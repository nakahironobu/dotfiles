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

# 対象プロジェクト: 第1引数があればそれ（sessionizer が fzf で選んだフォルダ）。
# 無ければ従来どおり起動元ペインの作業ディレクトリ。
PROJ="${1:-$(tmux display-message -p '#{pane_current_path}')}"
if [ ! -d "$PROJ" ]; then
  tmux display-message "claude-layout: フォルダが見つかりません: $PROJ"
  exit 1
fi

# 新規ウィンドウ。最初の1ペイン = 「右上の claude」。pane id を明示保持して
# 以降は -t で確実に対象ペインを指す（display-popup 経由でも active pane に依存しない）。
# ウィンドウ名は "claude-<プロジェクト名>"。作業場を複数開いたとき、ステータスバーの
# 一覧が "2:claude 3:claude" だとどれがどの案件か判別できないため。
# （-n を付けると tmux はそのウィンドウの automatic-rename を切るので、名前は固定される）
claude_pane="$(tmux new-window -c "$PROJ" -n "claude-$(basename "$PROJ")" -P -F '#{pane_id}')"
# 先に claude（毎回まっさらな新セッション）を起動しておく。
#   こうすると、続く左ペインの claude-log.sh は「いま起動した現行セッション」を掴め、
#   prefix + A の追記先（固定ログ）と必ず一致する。新規プロジェクトでも jsonl 生成を待てる。
tmux send-keys -t "$claude_pane" "claude" Enter
# 左に会話ログ(nvim)を 42% 幅で切り出す（-b = 新ペインを左側に）。固定ログを開く。
tmux split-window -h -b -l 42% -c "$PROJ" -t "$claude_pane" "$SDIR/claude-log.sh '$PROJ'"
# 右下 = 作業 shell（claude ペインを縦分割・高さ 30%）。id を控える
#   （後で「最大化トリガ」をこの idle ペインの tty へ送る）。
shell_pane="$(tmux split-window -v -l 30% -c "$PROJ" -t "$claude_pane" -P -F '#{pane_id}')"
# 右上（claude）にフォーカスを戻して終了
tmux select-pane -t "$claude_pane"

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
