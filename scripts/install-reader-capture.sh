#!/usr/bin/env bash
set -euo pipefail

# install-reader-capture.sh
# reader-capture（kindle-capture と legend-capture を統合したページキャプチャCLI）を、
# dotfiles のソースから各Mac上にビルド・配置する。install-kindle-capture.sh の後継。

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERR] Reader Capture CLIはmacOS専用です。" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/tools/reader-capture"
INSTALL_DIR="${READER_CAPTURE_INSTALL_DIR:-$HOME/Projects/PDF-tools/reader_capture}"
BIN_DIR="${READER_CAPTURE_BIN_DIR:-$HOME/.local/bin}"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx13.0"

for source_file in reader-capture crop_black_borders.swift page_click.swift README.md; do
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

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

cp "$SOURCE_DIR/reader-capture" "$INSTALL_DIR/reader-capture"
cp "$SOURCE_DIR/README.md" "$INSTALL_DIR/README.md"
cp "$SOURCE_DIR/crop_black_borders.swift" "$INSTALL_DIR/crop_black_borders.swift"
cp "$SOURCE_DIR/page_click.swift" "$INSTALL_DIR/page_click.swift"
chmod +x "$INSTALL_DIR/reader-capture"

echo "[INFO] 黒余白・タイトルバー切り抜きプログラム(crop_black_borders)をビルドします。"
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

echo "[INFO] ページ送りクリック(page_click)をビルドします。"
xcrun swiftc \
  -target "$TARGET" \
  -O \
  "$SOURCE_DIR/page_click.swift" \
  -o "$INSTALL_DIR/page_click"
chmod +x "$INSTALL_DIR/page_click"
codesign --force --sign - "$INSTALL_DIR/page_click" >/dev/null

cat > "$BIN_DIR/reader_capture" <<EOF
#!/bin/zsh
exec "${INSTALL_DIR}/reader-capture" "\$@"
EOF
chmod +x "$BIN_DIR/reader_capture"

"$INSTALL_DIR/reader-capture" --help >/dev/null
codesign --verify --strict "$INSTALL_DIR/crop_black_borders"
codesign --verify --strict "$INSTALL_DIR/page_click"

echo "[OK] Reader Capture CLIをインストールしました。"
echo "     本体    : $INSTALL_DIR"
echo "     コマンド: $BIN_DIR/reader_capture"
echo
echo "新しいシェルを開くか、次を実行してください:"
echo "  exec zsh"
echo
echo "使用例:"
echo "  reader_capture               # 会話形式（Kindle/Legendを選んで入力）"
echo "  reader_capture kindle 188 220"
echo "  reader_capture legend 14 20"
echo
echo "初回はシステム設定でWezTerm(実行するターミナル)に次の権限を与えてください:"
echo "  - プライバシーとセキュリティ → アクセシビリティ"
echo "  - プライバシーとセキュリティ → 画面収録"
echo "  - (Legendのみ) オートメーションでGoogle Chromeの操作を許可"
echo "  - (Legendのみ) Chrome: 表示 > デベロッパ > Apple EventからのJavaScriptを許可"
