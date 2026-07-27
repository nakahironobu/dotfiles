#!/usr/bin/env bash
# tmux: prefix + ? のキーバインド一覧ポップアップ。
#
# なぜ tmux 標準の ? を差し替えるか:
#   標準の ? は list-keys -N ＝「ノートが付いたキーだけ」を表示する。tmux 同梱の
#   バインドには最初から英語ノートが付いているが、自作バインドはノート無しなので
#   一覧に一切載らない。つまり「自分で足したキーほど思い出せない」状態になっていた。
#   → tmux.conf の自作 bind には -N "◆ 説明" を付ける約束にし、ここでその ◆ を見て
#     「このハーネス独自」と「tmux 標準」に仕分けして出す。
#
# 新しいキーを足したくなったら: tmux.conf に -N "◆ …" 付きで bind するだけ。
# このスクリプトは触らなくてよい（一覧に自動で載る）。
#
# 使い方: prefix + ?  （文字を打つと絞り込み / Esc で閉じる）
set -uo pipefail

TAG='◆'   # 自作バインドの目印（tmux.conf の -N と対で使う）

# list-keys -N の出力形式: "<キー><空白>...<ノート>"
mine()   { tmux list-keys -N -T "$1" 2>/dev/null | grep -F -- "$TAG" | sed "s/$TAG //"; }
theirs() { tmux list-keys -N -T "$1" 2>/dev/null | grep -vF -- "$TAG"; }

section() { # section <見出し> <本文>
  [ -n "$2" ] || return 0
  printf '\n  %s\n  %s\n%s\n' "$1" "────────────────────────────────────────────────" "$2"
}

body="$(
  cat <<'EOS'

  困ったとき
  ────────────────────────────────────────────────
    配置が入れ替わった → prefix + Space で標準レイアウトに戻す
    ペインが消えた     → prefix + z (ズーム) をもう一度。ズーム中は status に Z が出る
    ペインが飛んだ     → prefix + ! (break-pane) は別ウィンドウへ移す。Alt+n / Alt+p で探す
    設定を変えた       → prefix + r で再読込
EOS
  section "このハーネス独自（prefix = Ctrl-a のあとに押す）" "$(mine prefix)"
  section "このハーネス独自（prefix 不要・そのまま押す）"     "$(mine root)"
  section "このハーネス独自（コピーモード中）"                "$(mine copy-mode-vi)"
  section "tmux 標準（prefix = Ctrl-a のあとに押す）"         "$(theirs prefix)"
)"

if command -v fzf >/dev/null 2>&1; then
  printf '%s\n' "$body" \
    | fzf --reverse --no-sort --info=inline \
          --prompt='keys> ' \
          --header='キーバインド一覧 — 文字を打つと絞り込み / Esc で閉じる' \
    >/dev/null || true
else
  printf '%s\n' "$body" | less -R
fi
