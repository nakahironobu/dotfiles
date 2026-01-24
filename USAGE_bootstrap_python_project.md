# `bootstrap_python_project.sh` 使い方ガイド

このスクリプトは **「プロジェクト単位のPython開発環境（.venv / uv lock / Python pin）」を一発で整える**ための初期化ツールです。  
基本は **プロジェクト直下で1回実行して土台を作り、以後は依存を足しながら育てる**運用になります。

---

## 前提（base 側が済んでいること）

`bootstrap_python_base.sh` を実行済みで、`uv` が使える状態にします。

```sh
uv --version
python3 --version
```

---

## 典型的な使い方（新規プロジェクト）

### 1) プロジェクトを作って、その直下で実行

```sh
mkdir -p ~/Projects/scrape_app
cd ~/Projects/scrape_app
git init

~/dotfiles/scripts/bootstrap_python_project.sh
```

- **必ずプロジェクト直下で実行**してください（`.venv` や `pyproject.toml` などがその場所に作られます）
- 引数なしの場合、スクリプトのデフォルトPythonバージョン（例：3.14）で作成されます

### 2) 動作確認（最重要）

```sh
uv run python -V
uv run python -c "import sys; print(sys.executable)"
```

ここで **期待するPythonバージョン**になっていればOKです。

---

## このスクリプトが作る/整えるもの

プロジェクト直下に主に以下を作成/更新します（あなたの版の挙動）:

- `.python-version`  
  このプロジェクトで使うPythonバージョンを固定（pin）します
- `.venv/`  
  プロジェクト専用の仮想環境（venv）
- `pyproject.toml`（存在しなければ最小生成）  
- `uv.lock`（`uv sync` により作成/更新）  
- `.envrc`（`direnv` が入っている場合のみ）  
  プロジェクトに入った瞬間に `.venv` を有効化（auto-activate）

> つまり「プロジェクトのPython環境がディレクトリに閉じる」ので、他PCでも再現しやすくなります。

---

## 依存を追加していく（日常運用）

スクリプト実行後は、必要なライブラリを `uv add` で追加していきます。

例：スクレイピング + DB + API の最小セット

```sh
cd ~/Projects/scrape_app

# スクレイピング
uv add playwright beautifulsoup4 lxml httpx

# DB/ORM
uv add sqlalchemy alembic

# API（必要なら）
uv add fastapi uvicorn

# 開発用
uv add --dev pytest ruff
```

Playwright はブラウザ実体も必要です:

```sh
uv run playwright install
```

---

## 実行方法（2択）

### A) 常に `uv run ...`（最も確実）

```sh
uv run python your_script.py
uv run pytest
uv run uvicorn app.api.main:app --reload
```

### B) `direnv` で自動activate（快適）

`direnv` が有効なら、プロジェクトに入った瞬間 `.venv` が有効化されます。  
ただし、環境のブレを減らすため **`uv run` 併用**を推奨します。

---

## 既存プロジェクトで使う場合

既存リポジトリでも、ルートで実行してOKです。

```sh
cd /path/to/existing-repo
~/dotfiles/scripts/bootstrap_python_project.sh
```

- すでに `pyproject.toml` がある場合は、それを前提に `.venv` と lock を整える動きになります

---

## 再実行するタイミング

次のときは **再実行が効きます**（復旧が速い）:

- `.venv` が壊れた / 依存がこんがらがった
- Pythonのバージョンを変えたい（例：3.14.x → 3.14.y）
- 他PCにプロジェクトを持ってきた（最重要）

---

## 推奨ルール（これで一生壊れにくい）

- **プロジェクト直下に `.venv` と `uv.lock` を置く**
- 実行は基本 `uv run ...`
- 依存追加は `uv add`（手でpipしない）

---

## よくある確認コマンド

```sh
# 使われているPythonの確認
uv run python -V
uv run python -c "import sys; print(sys.executable)"

# 依存同期
uv sync

# Lint/Format（ruffを入れている場合）
uv run ruff check .
uv run ruff format .
```
