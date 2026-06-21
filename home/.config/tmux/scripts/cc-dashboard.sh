#!/usr/bin/env bash
# Claude Code ダッシュボード
# 進捗・Git状態・Claudeメモリ・Markdownファイル・プロセスを一覧表示

DIR="${1:-$(pwd)}"
PROJECT=$(basename "$DIR")

# ─── 色定義 ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

sep() { printf "${DIM}%s${RESET}\n" "────────────────────────────────────"; }
hdr() { printf "\n${PURPLE}${BOLD} %s ${RESET}\n" "$1"; sep; }

show_dashboard() {
  clear

  printf "${PURPLE}${BOLD}◆ %s${RESET}  ${DIM}%s${RESET}\n" \
    "$PROJECT" "$(date '+%Y-%m-%d %H:%M:%S')"
  sep

  # ─── ディレクトリ概要 ──────────────────────────────────────────────────
  hdr "📁 Directory"
  printf "${DIM}%s${RESET}\n" "$DIR"
  local fc
  fc=$(find "$DIR" -maxdepth 3 -type f 2>/dev/null | grep -v "/.git/" | wc -l | tr -d ' ')
  printf "ファイル数: ${CYAN}%s${RESET}\n" "$fc"

  # ─── Git ───────────────────────────────────────────────────────────────
  if git -C "$DIR" rev-parse --git-dir &>/dev/null 2>&1; then
    hdr "🔀 Git"
    local branch
    branch=$(git -C "$DIR" branch --show-current 2>/dev/null || echo "(detached)")
    printf "Branch: ${GREEN}%s${RESET}\n" "$branch"

    local st
    st=$(git -C "$DIR" status --short 2>/dev/null)
    if [ -n "$st" ]; then
      printf "${YELLOW}変更あり:${RESET}\n"
      echo "$st" | head -8 | while IFS= read -r line; do
        printf "  %s\n" "$line"
      done
    else
      printf "${GREEN}Working tree clean${RESET}\n"
    fi

    printf "\n${DIM}最近のコミット:${RESET}\n"
    git -C "$DIR" log --oneline --color=always -6 2>/dev/null | \
      while IFS= read -r line; do printf "  %s\n" "$line"; done
  fi

  # ─── Claude メモリ (グローバル) ─────────────────────────────────────────
  local mem_dir="$HOME/.claude/projects"
  if [ -d "$mem_dir" ]; then
    # 現在のディレクトリに対応するメモリを探す
    local slug
    slug=$(echo "$DIR" | tr '/' '-' | sed 's/^-//')
    local proj_mem="$mem_dir/-${slug}/MEMORY.md"
    if [ -f "$proj_mem" ]; then
      hdr "🧠 Project Memory"
      grep "^-" "$proj_mem" 2>/dev/null | head -8 | while IFS= read -r line; do
        printf "  ${CYAN}%s${RESET}\n" "$line"
      done
    fi
  fi

  # ─── Markdown ファイル ─────────────────────────────────────────────────
  local md_list
  md_list=$(find "$DIR" -maxdepth 3 -name "*.md" 2>/dev/null | grep -v "/.git/" | sort | head -8)
  if [ -n "$md_list" ]; then
    hdr "📝 Markdown"
    echo "$md_list" | while IFS= read -r f; do
      printf "  ${BLUE}%s${RESET}\n" "${f#$DIR/}"
    done
    printf "${DIM}  prefix+M でビューア起動${RESET}\n"
  fi

  # ─── Claude/Python/Node 関連プロセス ────────────────────────────────────
  hdr "⚡ Active Processes"
  local procs
  procs=$(pgrep -la "claude|uv run|uvicorn|node|npm|pnpm" 2>/dev/null | head -5)
  if [ -n "$procs" ]; then
    echo "$procs" | while IFS= read -r line; do
      printf "  ${DIM}%s${RESET}\n" "$line"
    done
  else
    printf "  ${DIM}(none)${RESET}\n"
  fi

  sep
  printf "${DIM}q:終了  r:更新  prefix+ T:ツリー  M:Markdown  G:Git  W:新ワークスペース${RESET}\n"
}

show_dashboard

# ─── キーループ（10秒ごと自動更新）──────────────────────────────────────────
while true; do
  if read -r -s -n 1 -t 10 key 2>/dev/null; then
    case "$key" in
      q|Q) exit 0 ;;
      *)   show_dashboard ;;
    esac
  else
    show_dashboard
  fi
done
