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
# バーの幅は3つとも同じ BAR_W にそろえてある。幅が違うと同じ長さの棒が別の割合を
# 意味してしまい、3つを見比べられない（ctx だけ10桁・レート制限は5桁、では読めない）。
#
# 概算コスト（.cost.total_cost_usd）は出さない方針。定額プランでは金額よりも
# 「あと何割使えるか」＝レート制限のほうが行動を決める指標なので、幅をそちらに回す。
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

input="$(cat)"

# jq は1回だけ。レート制限は API キー利用時など、そもそも来ないことがあるので
# -1 を「データ無し」の目印にして、後段で項目ごと出さない判断に使う。
#
# ※ 空文字のフィールドを作らないこと。IFS のタブは「IFS 空白類」扱いなので、
#   連続するタブが1個に畳まれ、以降の変数が全部ズレる。無い値は "-" や -1 で埋める。
row="$(printf '%s' "$input" | jq -r '[
  (.context_window.used_percentage      // 0  | floor),
  ((.context_window.total_input_tokens  // 0) + (.context_window.total_output_tokens // 0)),
  (.context_window.context_window_size  // 0),
  (.rate_limits.five_hour.used_percentage // -1 | floor),
  (.rate_limits.five_hour.resets_at       // 0),
  (.rate_limits.seven_day.used_percentage // -1 | floor),
  (.rate_limits.seven_day.resets_at       // 0)
] | @tsv' 2>/dev/null)"

# jq が落ちた／JSON が想定外なら、黙って何も出さない（壊れた行を出すよりマシ）
[ -z "$row" ] && exit 0
IFS=$'\t' read -r PCT USED SIZE H5 H5RESET D7 D7RESET <<<"$row"

# 桁を k / M に丸める。ペイン幅が狭いので絶対値は短く出す。
human() {
  local n="$1"
  if   [ "$n" -ge 1000000 ]; then printf '%d.%dM' "$((n / 1000000))" "$(((n % 1000000) / 100000))"
  elif [ "$n" -ge 1000 ];    then printf '%dk' "$((n / 1000))"
  else                            printf '%d' "$n"
  fi
}

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
BAR_W=10
bar() {
  local p="$1" i filled out=''
  filled=$((p * BAR_W / 100))
  [ "$filled" -gt "$BAR_W" ] && filled="$BAR_W"
  [ "$filled" -lt 0 ] && filled=0
  for ((i = 0; i < BAR_W; i++)); do
    if [ "$i" -lt "$filled" ]; then out+='█'; else out+='░'; fi
  done
  printf '%s' "$out"
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

out="ctx ${E}[$(hue "$PCT")m$(bar "$PCT") ${PCT}%${R} $(human "$USED")/$(human "$SIZE")"

if [ "$H5" -ge 0 ]; then
  reset=''
  # 5時間枠は必ず当日中に明けるので時刻だけで足りる
  [ "$H5RESET" -gt 0 ] && reset=" till $(date -r "$H5RESET" +%H:%M 2>/dev/null)"
  out+="   5h ${E}[$(hue "$H5")m$(bar "$H5") ${H5}%${R}${reset}"
fi

if [ "$D7" -ge 0 ]; then
  reset=''
  # 週次枠は数日先なので「何月何日(何曜)何時」まで出す
  [ "$D7RESET" -gt 0 ] && reset=" till $(when "$D7RESET")"
  out+="   7d ${E}[$(hue "$D7")m$(bar "$D7") ${D7}%${R}${reset}"
fi

# 末尾に今日の日付と現在時刻。レート制限の「till …」が何日後なのかを、
# 目を動かさず同じ行で引き算できるようにするため（till だけだと基準が要る）。
today="$(date '+%Y/%-m/%-d %w %H:%M' 2>/dev/null)"
if [ -n "$today" ]; then
  read -r td tw thm <<<"$today"
  out+="   ${td} ${WDAY[$tw]} ${thm}"
fi

printf '%s\n' "$out"
