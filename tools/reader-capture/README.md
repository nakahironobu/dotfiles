# Reader Capture CLI

`kindle-capture` と `legend-capture` を統合した、macOS用のページキャプチャCLIです。
会話形式で対象（Kindle / Legend・Libry）を選び、表示中のページを指定範囲の連番PNGとして保存します。
DRM解除・ファイル抽出・認証回避は行いません。自分のアカウントで閲覧中の資料を学習用に保存するためのものです。

- **Kindle** … Amazon Kindleアプリ（`com.amazon.Lassen`）の表示ページを撮影し、`crop_black_borders` で上部バー等を除外します。
- **Legend / Libry** … Chrome上のLibryビューア（https://app.libry.jp/book/text/view/）の表示ページを、JavaScriptで取得した画面矩形どおりに撮影し、`page_click` で余白を実クリックしてページを送ります。

## 使い方

どのフォルダからでも `reader_capture` と打ち込めば、会話形式で順に質問します。

```zsh
reader_capture
```

質問される項目:

1. どのビューアか（`1) Kindle` / `2) Legend・Libry`）
2. 開始ページ / 終了ページ
3. ファイル名のprefix（Enterで Kindle→`kindle` / Legend→`legend`）
4. 保存先フォルダ（Enterで現在のフォルダ）
5. ページ送り方向 `right` / `left`（Enterで `right`）

ファイル名は `<prefix>_p0014.png` のようにゼロ埋め4桁になります。

### 引数でまとめて指定する

会話をスキップしたい項目は、位置引数・オプションで先に渡せます。指定済みの項目は質問されません。

```zsh
reader_capture kindle 188 220 --prefix taizen --output ~/Documents/KindlePNG --direction left
reader_capture legend 14 20  --prefix legend2b --output ~/Documents/LegendPNG --direction right
```

オプション:

| オプション | 説明 |
| --- | --- |
| `-o, --output DIR` | 保存先フォルダ |
| `-p, --prefix NAME` | ファイル名の先頭文字 |
| `-d, --delay SEC` | ページ送り後の待機秒数（Kindle既定 1.3 / Legend既定 1.2） |
| `--direction DIR` | `right` または `left` |
| `--mode MODE` | （Kindleのみ）`page`（左右余白も除外）/ `margin`（上部バーのみ除外・既定） |
| `--countdown SEC` | 開始前の待機秒数（Kindle既定 2 / Legend既定 3） |
| `--check` | （Legendのみ）連携と撮影座標の確認だけ行い、保存しない |
| `-h, --help` | 説明を表示 |

Legendは初回に一度、撮影座標を確認しておくと安心です:

```zsh
reader_capture legend --check
```

## インストール（dotfiles管理）

このツールは dotfiles で管理されます。ソースは `~/dotfiles/tools/reader-capture/` にあり、
インストーラーがビルド・配置します。

```zsh
~/dotfiles/scripts/install-reader-capture.sh
```

インストーラーは各Mac上で2つのSwiftヘルパーをビルドし、次を作成します。

- `~/Projects/PDF-tools/reader_capture/reader-capture`（本体）
- `~/Projects/PDF-tools/reader_capture/crop_black_borders`（Kindleの切り抜き）
- `~/Projects/PDF-tools/reader_capture/page_click`（Legendのページ送りクリック）
- `~/.local/bin/reader_capture`（コマンド。`~/.local/bin` は dotfiles の `.zshrc` で PATH に追加済み）

`bootstrap_mac_full_auto.sh` からも自動でインストールされます。

## 仕組み・補助プログラム

自己完結型で、補助プログラムを自分のフォルダに同梱します。

- Kindleの切り抜き … `crop_black_borders`（`crop_black_borders.swift` からビルド）
- Legendのページ送りクリック … `page_click`（`page_click.swift` からビルド）

自分のフォルダに見つからない場合は、旧 `../kindle_capture/crop_black_borders` /
`../legend_capture/page_click` にフォールバックします。別の場所を使いたい場合は環境変数
`READER_CROP_HELPER` / `READER_CLICK_HELPER` で上書きできます。

## ファイル

- `reader-capture` … 本体（zshスクリプト）
- `crop_black_borders.swift` … Kindleの切り抜き用Swiftヘルパーのソース
- `page_click.swift` … Legendのページ送り用Swiftヘルパーのソース
- `README.md` … この説明

## macOSの権限（初回のみ）

`reader_capture` を実行するターミナル（WezTerm等）に、システム設定 → プライバシーとセキュリティ で次を許可してください。権限はmacOSの仕様上、自動では付与できません。

共通:

- **アクセシビリティ** … ページ送り（Kindleはキー送出、Legendはマウスクリック）
- **画面収録** … `screencapture` でページを撮影

Legend（Libry）追加分:

- Chromeメニュー「表示 → デベロッパ → **Apple EventからのJavaScriptを許可**」をオン
- **オートメーション** で、ターミナルに **Google Chrome** の操作を許可
- `swiftc`（`page_click` が未ビルドのときのみ。無ければ `xcode-select --install`）

権限を変更したらターミナルを完全に終了して開き直してください。

## うまくいかないとき

- 「切り抜きプログラムが見つかりません」→ インストーラーを実行して `crop_black_borders` をビルド（`READER_CROP_HELPER` で上書き可）。
- 「swiftc が見つかりません」→ `xcode-select --install`。
- 「Apple EventからのJavaScriptが無効です」/「Chromeを操作する権限がありません」→ 上記の権限設定を確認。
- 「前ページと同じ画像になりました」→ 送り方向（`--direction`）が逆、または待機時間（`--delay`）が短い可能性。
- 実行中はChromeウインドウを動かさないでください（クリック座標がずれます）。
