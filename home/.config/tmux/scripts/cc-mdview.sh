#!/usr/bin/env bash
# Markdown ファイルビューア
# fzf でファイル選択 → glow / bat / less でレンダリング

DIR="${1:-$(pwd)}"

# MD ファイル一覧収集
mapfile -t md_files < <(
  find "$DIR" -maxdepth 4 -name "*.md" 2>/dev/null \
    | grep -v "/.git/" \
    | sort
)

if [ ${#md_files[@]} -eq 0 ]; then
  printf '\033[33mMarkdown ファイルが見つかりません: %s\033[0m\n' "$DIR"
  printf '\033[2m(任意のキーで閉じる)\033[0m'
  read -r -s -n 1
  exit 0
fi

# fzf プレビューコマンド
if command -v bat &>/dev/null; then
  preview_cmd='bat --style=plain --color=always --language=md {} 2>/dev/null | head -80'
else
  preview_cmd='cat {} 2>/dev/null | head -80'
fi

while true; do
  # fzf で選択
  selected=$(printf '%s\n' "${md_files[@]}" \
    | fzf --reverse --height 100% \
          --preview "$preview_cmd" \
          --preview-window "right:60%:wrap" \
          --header "  Markdown Viewer  |  Enter: 表示  Tab: プレビュー  Ctrl-C: 閉じる" \
          --prompt "  ")

  [ -z "$selected" ] && exit 0

  # ファイルを表示
  clear
  printf '\033[1;35m◆ %s\033[0m\n' "$(basename "$selected")"
  printf '\033[2m%s\033[0m\n\n' "$selected"

  if command -v glow &>/dev/null; then
    glow -p "$selected"
  elif command -v bat &>/dev/null; then
    bat --style=full --color=always "$selected" | less -R
  else
    less -R "$selected"
  fi

  # 表示後にリストに戻るか確認
  printf '\n\033[2m[b: リストに戻る  q: 終了]\033[0m '
  read -r -s -n 1 key
  case "$key" in
    q|Q) exit 0 ;;
    *)   continue ;;
  esac
done
