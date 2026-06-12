#!/usr/bin/env bash
# install-ndlocr-lite.sh
# NDLOCR-Lite（国立国会図書館の ONNX 軽量OCR・GPU不要）を ~/tools に構築する。
# dotfiles で共有するのはこの「構築スクリプト」と「ラッパー(~/.local/bin/ndlocr-lite)」だけ。
# 本体コード＋ONNXモデル(約150M)＋venv(約290M) は Git に入れず、各PCでここから再構築する。
#
# 使い方:
#   scripts/install-ndlocr-lite.sh
#   NDLOCR_SRC=/path/to/existing/ndlocr-lite scripts/install-ndlocr-lite.sh   # 既存コピー元を指定
#
# 役割分担(共通ルール): 日本語の本文抽出は NDL-OCR が一次、数式・記号・図は AI。詳細は ~/Projects/CLAUDE.md。
set -euo pipefail

TOOL="$HOME/tools/ndlocr-lite"
REPO_URL="https://github.com/ndl-lab/ndlocr-lite"

log() { printf '\033[1;34m[ndlocr]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[ndlocr] %s\033[0m\n' "$*" >&2; }

command -v uv >/dev/null 2>&1 || { err "uv が必要です。先に bootstrap_python_base.sh を実行してください。"; exit 1; }

mkdir -p "$HOME/tools"

# 1) 本体を取得（既存があればスキップ。NDLOCR_SRC 指定があればそこからコピー）
if [ -f "$TOOL/src/ocr.py" ]; then
  log "既存の $TOOL を使用（取得スキップ）"
elif [ -n "${NDLOCR_SRC:-}" ]; then
  log "NDLOCR_SRC からコピー: $NDLOCR_SRC -> $TOOL"
  mkdir -p "$TOOL"
  cp -R "$NDLOCR_SRC/src" "$TOOL/src"
  for f in requirements.txt README.md pyproject.toml LICENCE LICENCE_DEPENDENCEIES; do
    cp "$NDLOCR_SRC/$f" "$TOOL/" 2>/dev/null || true
  done
else
  log "公式リポジトリを clone: $REPO_URL"
  git clone --depth 1 "$REPO_URL" "$TOOL"
fi

# 2) ONNXモデルの存在確認（公式 clone にモデルが含まれない場合は案内）
if ! ls "$TOOL"/src/model/*.onnx >/dev/null 2>&1; then
  err "ONNXモデルが $TOOL/src/model に見つかりません。"
  err "  対処: 公式リリース or 既存環境の src/model/*.onnx を配置するか、"
  err "  既存マシンの ~/tools/ndlocr-lite を NDLOCR_SRC に指定して再実行してください。"
  exit 1
fi

# 3) 専用 uv venv（flet は GUI 用なので CLI では除外）
log "uv venv を作成して依存をインストール"
uv venv --python 3.12 "$TOOL/.venv"
VIRTUAL_ENV="$TOOL/.venv" uv pip install \
  "dill==0.3.8" "lxml==5.4.0" "networkx==3.3" "onnxruntime==1.23.2" \
  "pillow==12.1.1" "ordered-set==4.1.0" "protobuf==6.31.1" "pyparsing==3.1.2" \
  "PyYAML==6.0.1" "tqdm==4.66.4" "reportlab==4.2.5" "pypdfium2==4.30.0" \
  "numpy==2.2.2" "opencv-python-headless==4.11.0.86"

# 4) ラッパー（~/.local/bin/ndlocr-lite）は dotfiles の stow で配置済みの想定。
if [ -x "$HOME/.local/bin/ndlocr-lite" ]; then
  log "ラッパー有効: ~/.local/bin/ndlocr-lite"
else
  err "ラッパー ~/.local/bin/ndlocr-lite が未配置です。dotfiles を stow 適用してください（stow -t ~ home）。"
fi

log "完了。動作確認: ndlocr-lite <画像|ディレクトリ> <出力dir>"
