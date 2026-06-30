#!/usr/bin/env python3
"""Claude Code の transcript(.jsonl) を「読みやすい Markdown」に忠実変換する。

使い方:
    render_transcript.py <transcript.jsonl> [--skip N] [--no-header] [--state FILE]
      → Markdown を標準出力へ
    --skip N      : 先頭 N 行（raw 行）を飛ばす＝追記モードで「続きだけ」を出す
    --no-header   : タイトル等の見出しを出さない（追記モード用）
    --state FILE  : 読み終えた raw 行数を FILE に書く（次回の --skip に使う透かし）

方針:
- 会話本体（あなた=user / Claude=assistant）を時系列で忠実に出す。要約しない。
- 読みやすさのための整理だけ行う:
    * 連続する同じ役割のイベントは1つの見出しにまとめる
    * ツール呼び出しは「何をしたか」が分かる1行に（Bashは説明、編集はパス）
    * ツール結果・思考(thinking)・ハーネス挿入の <system-reminder> は会話では
      ないので出さない（人間が読むためのログに不要なノイズ）
- 中身の取捨選択は人間が nvim で手編集する前提。消しやすい素直な Markdown で出す。

依存なし（Python 標準ライブラリのみ）。"""
import json
import os
import re
import sys
from datetime import datetime

HOME = os.path.expanduser("~")
SYSREMINDER = re.compile(r"<system-reminder>.*?</system-reminder>", re.DOTALL)


def hhmm(ts):
    return ts[11:16] if isinstance(ts, str) and len(ts) >= 16 else ""


def clean(text):
    return SYSREMINDER.sub("〔システムリマインダー省略〕", text).strip()


def oneline(s, n=90):
    s = " ".join(str(s).split())
    return s[:n] + ("…" if len(s) > n else "")


def short_path(p):
    if not p:
        return p
    return "~" + p[len(HOME):] if p.startswith(HOME) else p


def short_name(name):
    return "mcp:" + name.split("__")[-1] if name.startswith("mcp__") else name


def parse_content(content):
    """message.content → (本文テキスト, [(tool名, input辞書)...])。"""
    if isinstance(content, str):
        return content.strip(), []
    texts, tools = [], []
    if isinstance(content, list):
        for it in content:
            if not isinstance(it, dict):
                continue
            t = it.get("type")
            if t == "text":
                texts.append((it.get("text") or "").strip())
            elif t == "tool_use":
                tools.append((it.get("name", "tool"), it.get("input", {}) or {}))
            # thinking / tool_result は出さない
    return "\n".join(t for t in texts if t), tools


def format_tool(name, inp):
    """ツール呼び出しを『何をしたか』が分かる1行に整形する。"""
    if name == "Bash":
        return "▶ " + oneline(inp.get("description") or inp.get("command", ""))
    if name == "Edit":
        return "✏️ 編集 " + short_path(inp.get("file_path", ""))
    if name == "Write":
        return "📝 作成 " + short_path(inp.get("file_path", ""))
    if name == "Read":
        return "📖 読む " + short_path(inp.get("file_path", ""))
    if name in ("Glob", "Grep"):
        return "🔎 検索 " + oneline(inp.get("pattern", ""))
    if name in ("Task", "Agent"):
        return "🤖 サブエージェント: " + oneline(inp.get("description", ""))
    if name == "AskUserQuestion":
        return "❓ ユーザーに質問"
    if name == "Skill":
        return "🧩 skill " + str(inp.get("skill", ""))
    if name == "ToolSearch":
        return "🔧 ツール検索"
    if name.startswith("mcp__"):
        for k in ("query", "name", "file_id", "path", "owner"):
            if inp.get(k):
                return f"🔧 {short_name(name)} " + oneline(inp[k])
        return "🔧 " + short_name(name)
    return "🔧 " + short_name(name)


def parse_args(argv):
    path = None
    skip = 0
    state = None
    header = True
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--skip":
            skip = int(argv[i + 1]); i += 2; continue
        if a == "--state":
            state = argv[i + 1]; i += 2; continue
        if a == "--no-header":
            header = False; i += 1; continue
        path = a; i += 1
    return path, skip, state, header


def main():
    path, skip, state, header = parse_args(sys.argv[1:])
    if not path:
        sys.exit("usage: render_transcript.py <transcript.jsonl> "
                 "[--skip N] [--no-header] [--state FILE]")

    events = []
    total = 0
    with open(path, encoding="utf-8") as f:
        for idx, line in enumerate(f):
            total = idx + 1
            if idx < skip:          # 追記モード: 既出の行は飛ばす
                continue
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("type") in ("user", "assistant"):
                events.append(o)

    sid = re.sub(r"\.jsonl$", "", path.split("/")[-1])
    gen = datetime.now().strftime("%Y-%m-%d %H:%M")
    if header:
        out = [
            f"# 会話ログ — `{sid}`",
            f"_生成 {gen} ／ {len(events)} イベント_",
            "",
            "> 過去ログのスナップショットです。自由に編集してください。"
            "一部を直してほしいときは、その範囲（行番号や選択）を指定して依頼を。",
        ]
    elif events:
        # 追記モード: どこから続きか分かる区切りを入れる
        out = ["", "---", f"_↓ 続き（追記 {gen}）_"]
    else:
        out = []

    last_role = None
    for o in events:
        typ = o["type"]
        msg = o.get("message", {})
        if not isinstance(msg, dict):
            continue
        body, tools = parse_content(msg.get("content"))
        body = clean(body)

        if typ == "user":
            if not body:        # tool_result だけの user イベントは出さない
                continue
            if last_role != "user":
                out += ["", f"## 🧑 あなた · {hhmm(o.get('timestamp'))}"]
                last_role = "user"
            out += ["", body]
        elif typ == "assistant":
            if not body and not tools:
                continue
            if last_role != "assistant":
                out += ["", f"## 🤖 Claude · {hhmm(o.get('timestamp'))}"]
                last_role = "assistant"
            if body:
                out += ["", body]
            for name, inp in tools:
                out.append("  - " + format_tool(name, inp))

    if out:
        sys.stdout.write("\n".join(out) + "\n")
    if state:                      # 次回の --skip 用に読んだ raw 行数を記録
        with open(state, "w", encoding="utf-8") as s:
            s.write(str(total))


if __name__ == "__main__":
    main()
