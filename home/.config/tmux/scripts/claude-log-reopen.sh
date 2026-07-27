#!/usr/bin/env bash
# tmux: 左の会話ログペイン（nvim）を起動し直す。
#
# なぜ必要か:
#   左ペインは claude-log.sh を「ペインのコマンド」として起動しているが、スクリプトの
#   末尾で exec zsh しているため、nvim を :q してもペインは閉じず shell だけが残る。
#   そこから戻るにはスクリプトをフルパスで打ち直すしかなく面倒だった。
#   nvim 側の設定（カラースキーム等）を変えたあと、起動中の nvim に反映させる手段としても使う。
#
# 使い方: prefix + O  （または claude-log-reopen.sh [window]）
set -uo pipefail

W="${1:-$(tmux display-message -p '#{window_index}')}"

# 会話ログのペインは pane_start_command で見分ける。
# pane_current_command ではなく start のほうを見るのが要点で、:q して zsh に落ちていても
# tmux が保持している「起動時のコマンド」は変わらないため確実に当たる
# （claude-relayout.sh が会話ログペインを探すのと同じ手口）。
start="$(tmux list-panes -t "$W" -F '#{pane_index}	#{pane_start_command}' \
         | awk -F'\t' '$2 ~ /claude-log\.sh/ {print; exit}')"

if [ -z "${start:-}" ]; then
  tmux display-message "会話ログのペインがありません（prefix + W で作業場を作り直してください）"
  exit 0
fi

idx="${start%%	*}"
cmd="${start#*	}"
# tmux は引数付きコマンドを二重引用符で包んで返すので、その1枚だけ剥がす。
# 中の '…'（プロジェクトパス）はそのまま respawn 側のシェルに渡す＝起動時と同じ引数になる。
cmd="${cmd#\"}"; cmd="${cmd%\"}"

# -k = いま動いているもの（nvim でも zsh でも）を落としてから起動し直す
tmux respawn-pane -k -t "$W.$idx" "$cmd"
# フォーカスは動かさない。このキーの主な用途は「claude ペインで作業したまま
# 左の表示だけ作り直す」ことなので、左へ飛ばされると打鍵が nvim に吸われて事故になる。
# :q した直後（＝自分が左ペインに居る）ときは、そのまま左に居続けるので不都合はない。
tmux display-message "✓ 会話ログを開き直しました"
