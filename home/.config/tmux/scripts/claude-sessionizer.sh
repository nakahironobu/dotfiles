#!/usr/bin/env bash
# tmux: prefix + W のプロジェクト選択ピッカー。
#   fd で候補フォルダを集め → fzf で1つ選ぶ → claude-layout.sh <選んだフォルダ> に渡し、
#   そのフォルダに claude 作業場（左=会話ログ / 右上=claude / 右下=shell）を作る。
#   （kickstart.nvim の Telescope find_files と同じく fd をファインダに使う発想。）
#
# 候補ルール:
#   - ROOTS 直下のフォルダは必ず出す（MATH のような「コンテナ」も選べる）。
#   - その配下でも MARKERS（.git/.claude/CLAUDE.md/pyproject.toml など）を持つフォルダは
#     「サブプロジェクト」として出す（例: MATH/SEG）。ただし入れ子は外側だけ（内側は刈る）。
#   - EXTRAS のフォルダは「そのフォルダ自身」を候補に足す（配下は走査しない）。
#   - PRUNE のフォルダ（作業用・vendored 等）は候補にも走査にも含めない。
#
# 使い方: prefix + W
set -uo pipefail
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 設定（ここを編集すれば範囲・判定を変えられる）──────────────────────────────
ROOTS=("$HOME/Projects")                                   # 候補を探す起点。足せば範囲が広がる
# 単体で候補に足すフォルダ（ROOTS のように配下を掘らず、そのフォルダ自身だけを出す）。
#   dotfiles は ~/Projects の外にあり、かつ中を掘ると home/.config/tmux/plugins/* のような
#   .git 持ちの vendored フォルダまで候補に混ざるため、ここで「自分自身だけ」を足す。
EXTRAS=("$HOME/dotfiles")
MARKERS=(.git .claude CLAUDE.md pyproject.toml package.json go.mod Cargo.toml)  # 「プロジェクト」の目印
PRUNE=(.git node_modules .venv venv vendor __pycache__ .obsidian dist build .next .cache)  # 除外フォルダ名
MAXDEPTH=6                                                 # ROOT からの最大走査深さ
# ──────────────────────────────────────────────────────────────────────────────

if [ -z "${TMUX:-}" ]; then echo "tmux 内で実行してください（prefix + W）"; exit 1; fi
command -v fd  >/dev/null 2>&1 || { echo "fd が必要です（brew install fd）";  exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf が必要です（brew install fzf）"; exit 1; }

# fd の --exclude 引数を PRUNE から組み立てる（走査中にそのフォルダへ降りない）
fd_excludes=(); for p in "${PRUNE[@]}"; do fd_excludes+=(--exclude "$p"); done

depth1()   { fd -t d -a "${fd_excludes[@]}" -d 1 . "$1"; }             # 直下フォルダ（絶対パス）
walkdirs() { fd -H -t d -a "${fd_excludes[@]}" -d "$MAXDEPTH" . "$1"; } # 配下フォルダを走査
has_marker() { local d="$1" m; for m in "${MARKERS[@]}"; do [ -e "$d/$m" ] && return 0; done; return 1; }
# 入れ子のマーカーは外側だけ残す（sort 済み前提: 祖先が先に来る）
filter_outermost() {
  awk '{ keep=1
         for (i=1;i<=n;i++) if (index($0, kept[i]"/")==1) { keep=0; break }
         if (keep) { kept[++n]=$0; print } }'
}

d1=""; mk=""
for r in "${ROOTS[@]}"; do
  [ -d "$r" ] || continue
  d1+="$(depth1 "$r")"$'\n'
  mk+="$(walkdirs "$r" | while IFS= read -r d; do has_marker "$d" && printf '%s\n' "$d"; done)"$'\n'
done
ex=""
if [ "${#EXTRAS[@]}" -gt 0 ]; then
  for e in "${EXTRAS[@]}"; do [ -d "$e" ] && ex+="$e"$'\n'; done
fi
mk_out="$(printf '%s' "$mk"  | sed 's:/*$::; /^$/d' | sort | filter_outermost)"
cands="$(printf '%s\n%s\n%s\n' "$d1" "$mk_out" "$ex" | sed 's:/*$::; /^$/d' | sort -u)"

[ -n "$cands" ] || { echo "候補が見つかりません（ROOTS: ${ROOTS[*]}）"; exit 0; }

# 表示は ~ 短縮（1列目）、選択時に絶対パス（2列目）へ戻す。プレビューに中身を出す。
sel="$(printf '%s\n' "$cands" \
  | awk -v home="$HOME" '{ disp=$0; sub("^"home, "~", disp); print disp "\t" $0 }' \
  | fzf --reverse --delimiter='\t' --with-nth=1 \
        --prompt='project> ' \
        --header='claude 作業場を作るプロジェクトを選択 (Enter) / Esc で中止' \
        --preview 'eza -la --git --color=always {2} 2>/dev/null || ls -la {2}' \
        --preview-window='right,50%,border-left' \
  | cut -f2)"

[ -n "${sel:-}" ] || exit 0   # Esc / 未選択なら何もしない
exec "$SDIR/claude-layout.sh" "$sel"
