#!/usr/bin/env bash
# Claude Code のステータス行。トークンの消費状況を常時表示する。
#
# 呼ばれ方:
#   ~/.claude/settings.json の statusLine から起動され、stdin にセッション JSON が来る。
#   標準出力に出した1行がそのまま画面下部（フッターバッジの1行上）に出る。
#   実行タイミングは「アシスタントの応答ごと」＋ settings の refreshInterval 秒ごと。
#   ＝ 頻繁に走るので、プロセス起動は jq 1回だけに抑えてある。
#
# 表示するもの:
#   ctx  … いまのコンテキスト使用率。会話が伸びるほど増える（/compact の判断材料）
#   5h   … 5時間レート制限の消費率と、その枠が明ける時刻（当日中なので時刻だけ）
#   7d   … 週次レート制限の消費率と、明ける日時（数日先なので月/日(曜)まで出す）
#   末尾 … 今日の日付（曜日つき）と現在時刻
#
# バーの幅は3つとも同じにそろえてある。幅が違うと同じ長さの棒が別の割合を
# 意味してしまい、3つを見比べられない（ctx だけ10桁・レート制限は5桁、では読めない）。
#
# 概算コスト（.cost.total_cost_usd）は出さない方針。定額プランでは金額よりも
# 「あと何割使えるか」＝レート制限のほうが行動を決める指標なので、幅をそちらに回す。
#
# ctx の実トークン数（45k/200k のような分子分母）も出さない。割合が出ていれば
# 判断はできるのに 9〜10桁を食い、そのぶん行末の現在日時が端で切れてしまうため。
# 幅は「常に見えていること」を優先して、右端の時計に回す。
#
# ペイン幅への追従:
#   行が COLUMNS に収まらないときは、末尾の日時が必ず残るように前から削る。
#   バー幅 10→8→6→5→4→3→2→0 と痩せさせ、それでも足りなければ「till …」を落とす。
#   バーは割合の数字と同じことを言っているので最初に削り、日時は最後まで残す。
#   （この追従を入れる前は 118桁固定で、幅119のペインで末尾が切れていた）
#
# 末尾の時計は settings.json の refreshInterval（秒）で更新される。イベント駆動
# （応答ごと）だけだと、待っている間ずっと時刻が止まって見えるため。
#
# 色について:
#   ANSI 16色の「名前」（31=赤 / 33=黄 / 32=緑）だけを使い、hex は直書きしない。
#   settings.json が theme = dark-ansi ＝端末の配色に追従する設定なので、ここで hex を
#   書くとこの行だけ端末テーマから取り残される。ANSI 名なら WezTerm 側の
#   rose-pine-moon（黄→#f6c177 等）がそのまま効く。
#
# 項目を足したいときは jq の配列と read の変数を同じ順・同じ個数で増やすこと。
# 使えるフィールドの一覧は https://code.claude.com/docs/en/statusline を参照。
# 例: モデル名を出すなら (.model.display_name // "?") を足す。
set -uo pipefail

shopt -s extglob   # 桁数を測るとき ANSI エスケープを剥がすのに使う

input="$(cat)"

# jq は1回だけ。レート制限は API キー利用時など、そもそも来ないことがあるので
# -1 を「データ無し」の目印にして、後段で項目ごと出さない判断に使う。
#
# ※ 空文字のフィールドを作らないこと。IFS のタブは「IFS 空白類」扱いなので、
#   連続するタブが1個に畳まれ、以降の変数が全部ズレる。無い値は "-" や -1 で埋める。
row="$(printf '%s' "$input" | jq -r '[
  (.context_window.used_percentage      // 0  | floor),
  (.rate_limits.five_hour.used_percentage // -1 | floor),
  (.rate_limits.five_hour.resets_at       // 0),
  (.rate_limits.seven_day.used_percentage // -1 | floor),
  (.rate_limits.seven_day.resets_at       // 0)
] | @tsv' 2>/dev/null)"

# jq が落ちた／JSON が想定外なら、黙って何も出さない（壊れた行を出すよりマシ）
[ -z "$row" ] && exit 0
IFS=$'\t' read -r PCT H5 H5RESET D7 D7RESET <<<"$row"

# 使用率 → ANSI 色。「まだ余裕 / そろそろ / 危ない」の3段。
hue() {
  if   [ "$1" -ge 85 ]; then printf '31'   # red
  elif [ "$1" -ge 60 ]; then printf '33'   # yellow
  else                       printf '32'   # green
  fi
}

# 使用率バー。█/░ は East Asian Width が Ambiguous だが、WezTerm の既定は
# 「Ambiguous は半角」なので桁ズレしない。
# 幅は ctx / 5h / 7d で共通（＝同じ棒の長さが常に同じ割合を意味する）。
#
# 組み立て中はマルチバイトの █/░ ではなく1バイトの制御文字を置く。こうすると
# 行全体が ASCII のみになり、${#s} がロケール設定に関係なく「表示桁数」と一致する
# （UTF-8 ロケールでないと bash の ${#} はバイト数を返し、バー1本で20桁ぶん誤る）。
# 実際の █/░ への差し替えは、幅を決めきった最後に1回だけ行う。
BLK=$'\001'; DOT=$'\002'
bar() {
  local p="$1" w="$2" i filled out=''
  filled=$((p * w / 100))
  [ "$filled" -gt "$w" ] && filled="$w"
  [ "$filled" -lt 0 ] && filled=0
  for ((i = 0; i < w; i++)); do
    if [ "$i" -lt "$filled" ]; then out+="$BLK"; else out+="$DOT"; fi
  done
  printf '%s' "$out"
}

# 行の表示桁数。ANSI エスケープ（\033[…m）だけ剥がして数える。
# この時点でバーはまだ1バイトの制御文字なので、中身は全部 ASCII。
vislen() {
  local s="${1//$'\033'\[*([0-9;])m/}"
  printf '%s' "${#s}"
}

# 曜日はロケール依存の date %a を使わず、%w(0-6) を添字にしてこの表から引く。
# statusline を起動するプロセスのロケールは不定で、%a だと環境によって Tue / 火 が
# 入れ替わってしまう（LC_ALL=C を都度付けるより、表を持つほうが確実で速い）。
WDAY=(Sun Mon Tue Wed Thu Fri Sat)

# unix epoch 秒 → "8/3 Mon 14:00"。date 呼び出しは1回にまとめる
# （この行はアシスタントの応答ごとに走るのでプロセス起動を増やさない）。
# -r は BSD date（macOS）で「引数を epoch 秒として解釈する」の意味。
when() {
  local s d w hm
  s="$(date -r "$1" '+%-m/%-d %w %H:%M' 2>/dev/null)" || return 1
  [ -z "$s" ] && return 1
  read -r d w hm <<<"$s"
  printf '%s %s %s' "$d" "${WDAY[$w]}" "$hm"
}

E=$'\033'; R="${E}[0m"

# date の呼び出しはここで済ませる。行を何通りか組み直して幅を試すので、
# 組み立て関数の中で date を呼ぶと同じ値を何度も取り直すことになる。
H5TILL=''; [ "$H5" -ge 0 ] && [ "$H5RESET" -gt 0 ] && H5TILL="$(date -r "$H5RESET" +%H:%M 2>/dev/null)"
D7TILL=''; [ "$D7" -ge 0 ] && [ "$D7RESET" -gt 0 ] && D7TILL="$(when "$D7RESET")"

TODAY=''
today="$(date '+%Y/%-m/%-d %w %H:%M' 2>/dev/null)"
if [ -n "$today" ]; then
  read -r td tw thm <<<"$today"
  TODAY="${td} ${WDAY[$tw]} ${thm}"
fi

# $1=バー幅（0 ならバーを出さない） / $2=till を出すか(1/0)
build() {
  local w="$1" till="$2" o b

  b=''; [ "$w" -gt 0 ] && b="$(bar "$PCT" "$w") "
  o="ctx ${E}[$(hue "$PCT")m${b}${PCT}%${R}"

  if [ "$H5" -ge 0 ]; then
    b=''; [ "$w" -gt 0 ] && b="$(bar "$H5" "$w") "
    o+="   5h ${E}[$(hue "$H5")m${b}${H5}%${R}"
    # 5時間枠は必ず当日中に明けるので時刻だけで足りる
    [ "$till" -eq 1 ] && [ -n "$H5TILL" ] && o+=" till $H5TILL"
  fi

  if [ "$D7" -ge 0 ]; then
    b=''; [ "$w" -gt 0 ] && b="$(bar "$D7" "$w") "
    o+="   7d ${E}[$(hue "$D7")m${b}${D7}%${R}"
    # 週次枠は数日先なので「何月何日(何曜)何時」まで出す
    [ "$till" -eq 1 ] && [ -n "$D7TILL" ] && o+=" till $D7TILL"
  fi

  # 末尾に今日の日付と現在時刻。レート制限の「till …」が何日後なのかを、
  # 目を動かさず同じ行で引き算できるようにするため（till だけだと基準が要る）。
  # ここは何があっても落とさない ＝ 幅が足りなければ先にバーと till を削る。
  [ -n "$TODAY" ] && o+="   ${TODAY}"

  printf '%s' "$o"
}

# ペイン幅に収める。Claude Code は statusline のプロセスに COLUMNS を渡してくる
# （tput cols も同じ値を返すが、こちらはプロセス起動が要らない）。
# 1桁ぶん余裕を取るのは、ちょうど幅いっぱいだと端の1文字が欠けるため
# （実測: 幅119 のペインで118桁の行の末尾が切れていた）。
COLS="${COLUMNS:-0}"
[ "$COLS" -le 0 ] && COLS="$(tput cols 2>/dev/null || echo 0)"
[ "$COLS" -le 0 ] && COLS=120
LIMIT=$((COLS - 1))

# 削る順番＝惜しくないものから。バーは割合の数字と重複した情報なので先に痩せさせ、
# それでも足りなければ till（明ける時刻）を落とす。日時は最後まで残る。
out=''
for step in "10 1" "8 1" "6 1" "5 1" "4 1" "3 1" "2 1" "0 1" "0 0"; do
  read -r w till <<<"$step"
  out="$(build "$w" "$till")"
  [ "$(vislen "$out")" -le "$LIMIT" ] && break
done

# ここまで幅計算のためにバーは1バイトの制御文字だった。最後に本物へ差し替える。
out="${out//$BLK/█}"
out="${out//$DOT/░}"

printf '%s\n' "$out"
