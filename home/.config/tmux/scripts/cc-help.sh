#!/usr/bin/env bash
# KEYBINDINGS.md を HTML に変換して Chrome で開く

MD="$HOME/.config/tmux/KEYBINDINGS.md"
OUT="/tmp/cc-help.html"

if [ ! -f "$MD" ]; then
  echo "Error: $MD が見つかりません"
  exit 1
fi

# ─── Python スクリプトを一時ファイルに書き出して実行 ─────────────────────────
TMP_PY=$(mktemp /tmp/cc-help-XXXX.py)

cat > "$TMP_PY" << 'PYEOF'
import sys
import markdown as md_lib

in_file, out_file = sys.argv[1], sys.argv[2]

with open(in_file, encoding='utf-8') as f:
    content = f.read()

parser = md_lib.Markdown(extensions=['tables', 'fenced_code'])
body = parser.convert(content)

css = """
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #1e1e2e;
    color: #cdd6f4;
    font-family: -apple-system, "Hiragino Sans", "Yu Gothic UI", sans-serif;
    font-size: 15px;
    line-height: 1.7;
    max-width: 860px;
    margin: 48px auto;
    padding: 0 24px 80px;
  }
  h1 {
    color: #cba6f7;
    font-size: 1.7em;
    border-bottom: 2px solid #313244;
    padding-bottom: 10px;
    margin: 32px 0 16px;
  }
  h2 {
    color: #89b4fa;
    font-size: 1.25em;
    margin: 36px 0 12px;
    padding-left: 10px;
    border-left: 3px solid #89b4fa;
  }
  h3 {
    color: #74c7ec;
    font-size: 1.05em;
    margin: 24px 0 8px;
  }
  p { margin: 10px 0; }
  table {
    border-collapse: collapse;
    width: 100%;
    margin: 14px 0 20px;
    font-size: 0.95em;
  }
  th {
    background: #313244;
    color: #cba6f7;
    padding: 9px 14px;
    text-align: left;
    font-weight: 600;
    letter-spacing: 0.02em;
  }
  td {
    padding: 8px 14px;
    border-bottom: 1px solid #2a2a3d;
    vertical-align: top;
  }
  tr:hover td { background: #181825; }
  code {
    background: #313244;
    color: #a6e3a1;
    padding: 2px 7px;
    border-radius: 4px;
    font-family: "MesloLGS NF", "SF Mono", Menlo, monospace;
    font-size: 0.88em;
  }
  pre {
    background: #181825;
    border: 1px solid #313244;
    border-radius: 8px;
    padding: 16px 20px;
    overflow-x: auto;
    margin: 12px 0;
  }
  pre code {
    background: none;
    padding: 0;
    color: #cdd6f4;
    font-size: 0.9em;
  }
  blockquote {
    border-left: 3px solid #cba6f7;
    padding-left: 14px;
    color: #a6adc8;
    margin: 12px 0;
  }
  strong { color: #f9e2af; }
  em { color: #f5c2e7; }
  hr {
    border: none;
    border-top: 1px solid #313244;
    margin: 32px 0;
  }
  a { color: #89b4fa; text-decoration: none; }
  a:hover { text-decoration: underline; }
"""

html = f"""<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Claude Code キーバインド</title>
  <style>{css}</style>
</head>
<body>
{body}
</body>
</html>"""

with open(out_file, 'w', encoding='utf-8') as f:
    f.write(html)
PYEOF

# ─── 変換実行 ────────────────────────────────────────────────────────────────
if uv run --quiet --with markdown python3 "$TMP_PY" "$MD" "$OUT" 2>/dev/null; then
  rm -f "$TMP_PY"
  echo "HTML 生成: $OUT"
  open -a "Google Chrome" "$OUT" 2>/dev/null \
    || open "$OUT"  # Chrome がなければデフォルトブラウザで開く
else
  rm -f "$TMP_PY"
  echo "変換失敗。Markdown をそのまま表示します。"
  open "$MD"
fi
