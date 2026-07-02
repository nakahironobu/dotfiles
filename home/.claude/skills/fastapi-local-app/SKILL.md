# FastAPI ローカル CLI アプリ パターン

Safari/AppleScript バックグラウンドスクレイパー付きのローカル CLI ウェブアプリを
`uv` + FastAPI + Jinja2 で構成するパターン。`kono-import` プロジェクトで確立。

---

## ディレクトリ構成

```
my-app/
├── my_app/
│   ├── __init__.py
│   ├── models.py          # Pydantic v2 データモデル
│   ├── catalog.py         # data/catalog.json 読み書き
│   ├── scraper.py         # バックグラウンドスレッドスクレイパー
│   ├── app.py             # FastAPI + main() エントリポイント
│   └── templates/
│       └── index.html     # Jinja2 テンプレート
├── data/
│   └── .gitkeep
└── pyproject.toml
```

---

## pyproject.toml テンプレート

```toml
[project]
name = "my-app"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.110.0",
    "uvicorn[standard]>=0.29.0",
    "jinja2>=3.1.0",
    "pydantic>=2.6.0",
]

[project.scripts]
my-app = "my_app.app:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["my_app"]
```

---

## CLI エントリポイント（app.py 末尾）

```python
def main() -> None:
    import threading, webbrowser, uvicorn
    threading.Timer(1.5, lambda: webbrowser.open("http://127.0.0.1:8765")).start()
    uvicorn.run("my_app.app:app", host="127.0.0.1", port=8765, reload=False)

if __name__ == "__main__":
    main()
```

---

## バックグラウンドスクレイパーパターン（scraper.py）

```python
import threading

_state = {"status": "idle", "message": "", "progress": 0, "total": 0}

def get_state() -> dict:
    return dict(_state)

def _scrape_thread(save_fn):
    try:
        _state.update({"status": "running", "message": "開始...", "progress": 0})
        # ... 処理 ...
        _state.update({"status": "done", "message": "完了"})
    except Exception as e:
        _state.update({"status": "error", "message": str(e)})

def start_scrape(save_fn) -> bool:
    if _state["status"] == "running":
        return False
    threading.Thread(target=_scrape_thread, args=(save_fn,), daemon=True).start()
    return True
```

フロントエンドは `GET /api/scrape/status` を 2 秒ごとにポーリングしてプログレスバーを更新。
完了時は `location.reload()` でページを再描画。

---

## セットアップ（初回のみ）

```zsh
cd /path/to/project
uv sync
uv tool install --editable .
```

以降、どのディレクトリからでも `my-app` で起動できる（`~/.local/bin/` に配置される）。

---

## Safari から JS を実行するヘルパー（AppleScript temp ファイル方式）

→ `feedback_applescript_js` を参照。

---

## 落とし穴・再利用ノウハウ

### Python 3.14 + Jinja2Templates が落ちる
`Jinja2Templates(...).TemplateResponse(...)` がテンプレキャッシュで
`TypeError: cannot use 'tuple' as a dict key (unhashable type: 'dict')` を出すこと
がある（Python 3.14 / 新しめの starlette）。**回避策**: テンプレに動的変数が無い
SPA なら Jinja を介さず HTML を直接返す。

```python
INDEX_HTML = (Path(__file__).parent / "templates" / "index.html").read_text(encoding="utf-8")

@app.get("/", response_class=HTMLResponse)
def index():
    return HTMLResponse(INDEX_HTML)
```

### 内容DBと進捗DBを分ける（再生成で進捗を失わない）
スクレイプ等で**再生成される内容**(`content.sqlite`)と、**ユーザーが貯める状態**
(`progress.sqlite`: 進捗・SRS・フラグ)を別ファイルに分離する。両者は
オートインクリメント id ではなく**安定キー pkey で紐付ける**（pkey = 内容の同定情報の
sha1 等。`hashlib.sha1(repr(key)).hexdigest()[:16]`）。これで内容DBを作り直しても
id がズレず進捗が生き残る。内容DBは読み取り専用接続(`file:...?mode=ro`)で開く。

### Anki風 SRS を内蔵する場合
`srs.py` に「状態+評価→次状態」関数を置き、`progress.sqlite` に
`review`(現在状態) と `review_log`(全試行を実施時刻つき) の2表を持つと、
履歴バッジ表示・スケジューリング・日別集計がやりやすい。周期ルールは
プロジェクト要件で大きく変わるので関数1つに隔離しておく。

### プレビュー/起動
`.claude/launch.json`（リポジトリ直下）に `uv run --directory <app> uvicorn ...` を
書くと preview_start から起動できる。配布用 CLI は `uv tool install --editable .`。

### 実例
- `kono-import`: KONO塾の講義動画・PDF カタログ管理 + LaCie 照合ダッシュボード
- `kobetsuba-app`: コベツバ×SAPIX 算数 演習アプリ（内容DB/進捗DB分離・Anki風SRS・YouTube埋め込み）
