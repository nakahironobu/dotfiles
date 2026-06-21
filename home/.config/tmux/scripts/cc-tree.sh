#!/usr/bin/env bash
# ライブファイルツリービューア
# eza → tree → find の順でフォールバック

DIR="${1:-$(pwd)}"
PROJECT=$(basename "$DIR")

show_tree() {
  local d="${1:-$DIR}"
  if command -v eza &>/dev/null; then
    eza --tree --level=4 --icons --color=always \
        --ignore-glob=".git|node_modules|.DS_Store|__pycache__|*.pyc|.venv|venv|.next|dist|build" \
        "$d"
  elif command -v tree &>/dev/null; then
    tree -C -L 4 \
         -I ".git|node_modules|.DS_Store|__pycache__|*.pyc|.venv|venv|.next|dist|build" \
         "$d"
  else
    find "$d" -maxdepth 4 \
         -not -path "*/.git/*" \
         -not -path "*/node_modules/*" \
         -not -path "*/__pycache__/*" \
         -not -name ".DS_Store" \
         | sort | while IFS= read -r path; do
           local rel="${path#$d/}"
           local depth=$(echo "$rel" | tr -cd '/' | wc -c)
           local indent=""
           for ((i=0; i<depth; i++)); do indent="  $indent"; done
           printf "%s%s\n" "$indent" "$(basename "$path")"
         done
  fi
}

while true; do
  clear
  printf '\033[1;35m◆ %s\033[0m  \033[2m%s\033[0m\n\n' "$PROJECT" "$(date '+%H:%M:%S')"
  show_tree "$DIR"
  printf '\n\033[2m[3秒ごと自動更新 | q: 終了]\033[0m'

  # 3秒待機、その間にキー入力があれば処理
  if read -r -s -n 1 -t 3 key 2>/dev/null; then
    case "$key" in
      q|Q) exit 0 ;;
    esac
  fi
done
