#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERR] Kindle Capture CLIはmacOS専用です。" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/tools/kindle-capture"
INSTALL_DIR="${KINDLE_CAPTURE_INSTALL_DIR:-$HOME/Projects/PDF-tools/kindle_capture}"
BIN_DIR="${KINDLE_CAPTURE_BIN_DIR:-$HOME/.local/bin}"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx13.0"

for source_file in kindle-capture crop_black_borders.swift README.md; do
  if [[ ! -f "$SOURCE_DIR/$source_file" ]]; then
    echo "[ERR] 必要なファイルがありません: $SOURCE_DIR/$source_file" >&2
    exit 1
  fi
done

if ! xcode-select -p >/dev/null 2>&1; then
  echo "[ERR] Xcode Command Line Toolsが必要です。先に次を実行してください。" >&2
  echo "      xcode-select --install" >&2
  exit 1
fi

SWIFTC="$(xcrun --find swiftc)"
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

cp "$SOURCE_DIR/kindle-capture" "$INSTALL_DIR/kindle-capture"
cp "$SOURCE_DIR/README.md" "$INSTALL_DIR/README.md"
chmod +x "$INSTALL_DIR/kindle-capture"

echo "[INFO] 黒余白・タイトルバー切り抜きプログラムをビルドします。"
xcrun swiftc \
  -target "$TARGET" \
  -O \
  "$SOURCE_DIR/crop_black_borders.swift" \
  -o "$INSTALL_DIR/crop_black_borders" \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework UniformTypeIdentifiers
chmod +x "$INSTALL_DIR/crop_black_borders"
codesign --force --sign - "$INSTALL_DIR/crop_black_borders" >/dev/null

cat > "$BIN_DIR/kindle-capture" <<EOF
#!/bin/zsh
exec "${INSTALL_DIR}/kindle-capture" "\$@"
EOF
chmod +x "$BIN_DIR/kindle-capture"

"$INSTALL_DIR/kindle-capture" --help >/dev/null
codesign --verify --strict "$INSTALL_DIR/crop_black_borders"

echo "[OK] Kindle Capture CLIをインストールしました。"
echo "     本体: $INSTALL_DIR"
echo "     コマンド: $BIN_DIR/kindle-capture"
echo
echo "新しいシェルを開くか、次を実行してください:"
echo "  exec zsh"
echo
echo "使用例:"
echo "  kindle-capture 188 220"
echo
echo "初回はシステム設定でWezTermに次の権限を与えてください:"
echo "  - プライバシーとセキュリティ → アクセシビリティ"
echo "  - プライバシーとセキュリティ → 画面収録"
