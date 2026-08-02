#!/usr/bin/env bash
set -euo pipefail

# install-batch-extract.sh
# batch-extract（教材の紙面PNG/PDFを OCR 一次抽出するバッチの入口）を、
# dotfiles のソースから各Mac上に配置する。install-reader-capture.sh と対になる。

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERR] batch-extract はmacOS専用です。" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/tools/batch-extract"
INSTALL_DIR="${BATCH_EXTRACT_INSTALL_DIR:-$HOME/Projects/PDF-tools/batch_extract}"
BIN_DIR="${BATCH_EXTRACT_BIN_DIR:-$HOME/.local/bin}"

for source_file in batch-extract README.md; do
  if [[ ! -f "$SOURCE_DIR/$source_file" ]]; then
    echo "[ERR] 必要なファイルがありません: $SOURCE_DIR/$source_file" >&2
    exit 1
  fi
done

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

cp "$SOURCE_DIR/batch-extract" "$INSTALL_DIR/batch-extract"
cp "$SOURCE_DIR/README.md" "$INSTALL_DIR/README.md"
chmod +x "$INSTALL_DIR/batch-extract"

cat > "$BIN_DIR/batch_extract" <<EOF
#!/bin/zsh
exec "${INSTALL_DIR}/batch-extract" "\$@"
EOF
chmod +x "$BIN_DIR/batch_extract"

"$INSTALL_DIR/batch-extract" --help >/dev/null

echo "[OK] batch-extract をインストールしました。"
echo "     本体    : $INSTALL_DIR"
echo "     コマンド: $BIN_DIR/batch_extract"
echo
echo "新しいシェルを開くか、次を実行してください:"
echo "  exec zsh"
echo
echo "使用例:"
echo "  batch_extract                # 会話形式（教材→本→部分→ページ範囲）"
echo "  batch_extract bluechart --book 1a --section honpen --range 297-380"
echo "  batch_extract bluechart --check"
echo
echo "抽出は macOS ローカルのモデル群に依存します。**Terminal.app から実行してください。**"
