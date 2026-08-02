# Reader Capture CLI

`kindle-capture` と `legend-capture` を統合した、macOS用のページキャプチャCLIです。
会話形式で対象（Kindle / Legend・Libry / BlueChart・sviewer）を選び、表示中のページを指定範囲の連番PNGとして保存します。
DRM解除・ファイル抽出・認証回避は行いません。自分のアカウントで閲覧中の資料を学習用に保存するためのものです。

- **Kindle** … Amazon Kindleアプリ（`com.amazon.Lassen`）の表示ページを撮影し、`crop_black_borders` で上部バー等を除外します。
- **Legend / Libry** … Chrome上のLibryビューア（https://app.libry.jp/book/text/view/）の表示ページを、JavaScriptで取得した画面矩形どおりに撮影し、`page_click` で余白を実クリックしてページを送ります。
- **BlueChart / sviewer** … Chrome上のsviewerビューア（https://sviewer.jp/books/viewer.html）の見開きページを、左右別々のPNGとして保存します（1実ページ=1PNG）。ページ送りはクリックではなく `location.hash` で目的の見開きへ直接移動します。

## 使い方

どのフォルダからでも `reader_capture` と打ち込めば、会話形式で順に質問します。

```zsh
reader_capture
```

質問される項目:

1. どのビューアか（`1) Kindle` / `2) Legend・Libry` / `3) BlueChart・sviewer`）
2. 開始ページ / 終了ページ
3. ファイル名のprefix（Enterで Kindle→`kindle` / Legend→`legend` / BlueChart→`honpen`）
4. 保存先フォルダ（Enterで現在のフォルダ）
5. ページ送り方向 `right` / `left`（Enterで `right`。BlueChartでは聞きません）

ファイル名は `<prefix>_p0014.png` のようにゼロ埋め4桁になります。

### 引数でまとめて指定する

会話をスキップしたい項目は、位置引数・オプションで先に渡せます。指定済みの項目は質問されません。

```zsh
reader_capture kindle 188 220 --prefix taizen --output ~/Documents/KindlePNG --direction left
reader_capture legend 14 20  --prefix legend2b --output ~/Documents/LegendPNG --direction right
reader_capture bluechart 515 594 --prefix honpen --output ~/Projects/MATH/Blue-chart/scans/1a/honpen
```

オプション:

| オプション | 説明 |
| --- | --- |
| `-o, --output DIR` | 保存先フォルダ |
| `-p, --prefix NAME` | ファイル名の先頭文字 |
| `-d, --delay SEC` | ページ送り後の待機秒数（Kindle既定 1.3 / Legend既定 1.2 / BlueChart既定 0.8） |
| `--direction DIR` | `right` または `left`（BlueChartでは使いません） |
| `--mode MODE` | （Kindleのみ）`page`（左右余白も除外）/ `margin`（上部バーのみ除外・既定） |
| `--countdown SEC` | 開始前の待機秒数（Kindle既定 2 / Legend・BlueChart既定 3） |
| `--check` | （Legend / BlueChart）連携と撮影座標の確認だけ行い、保存しない |
| `--page-offset N` | （BlueChartのみ）紙面ページ = 画像番号 − N（既定 3） |
| `--window BOUNDS` | （BlueChartのみ）Chromeを `左,上,右,下` に設定（既定は標準サイズ） |
| `--no-window` | （BlueChartのみ）ウインドウサイズを変更しない |
| `-h, --help` | 説明を表示 |

Legend・BlueChartは初回に一度、撮影座標を確認しておくと安心です:

```zsh
reader_capture legend --check
reader_capture bluechart --check
```

## BlueChart（sviewer）モードの詳細

sviewerは**常に見開き2ページ**で表示しますが、DOM上は `img.pageL` / `img.pageR` の**別要素**になっています。
そのため中央での機械的な分割ではなく、**要素の矩形どおりに左右を個別撮影**します（`~/Projects/CLAUDE.md` の
「見開き＝2実ページ」パターン）。読み順は 左→右 です。

### ページ番号の指定は「紙面に印刷されたページ番号」

sviewer内部の画像番号（`.../page/img/518.jpg`）と紙面のページ番号はずれます。対応は

```
紙面ページ = 画像番号 − page-offset      （青チャート数学I+A は 3）
見開き #page=N  ↔  左 = 画像 2N−1 / 右 = 画像 2N
```

`reader_capture bluechart 515 594` のように**紙面のページ番号**で指定すると、該当の見開きへ自動で移動し、
範囲外の面（開始見開きの左ページ・終了見開きの右ページ）は保存しません。
保存後のファイル名も紙面ページ番号（`honpen_p0515.png`）です。

移動のたびに実際の画像番号を照合してから撮影するので、「送りそこねて同じページを2枚保存」「番号が1つずれる」
といった事故は構造的に起きません。想定と違えばその場で止まります。

別の本を取り込むときは `--page-offset` を測り直してください（`--check` で表示中の見開きの画像番号と
紙面ページ番号の対応が出ます）。

### 解像度は「標準ウインドウサイズ」で固定する

sviewerはウインドウサイズに合わせてページを拡縮するため、**ウインドウの大きさがそのまま取り込み解像度**になります。
取り込み時期をまたいで解像度がばらつかないよう、キャプチャ開始前にChromeを標準サイズへ自動設定します。

```
標準サイズ  : 138,30,2416,1397（AppleScriptのbounds＝左,上,右,下・ポイント）
1ページ実寸 : 797x1131pt → 1594x2262px（Retina 2倍）
```

標準サイズは `--window` か環境変数 `BLUECHART_WINDOW_BOUNDS` で変更できます。`--no-window` を付けると
現在のウインドウのまま撮ります。いずれの場合も、標準と実寸が違えば警告を出します。

なお、この表示状態でsviewerが配信するページ画像は 1259x1786px です。撮影される 1594x2262px はそれを
拡大したものなので、**実質的な情報量は1259x1786相当**です（本文・数式のOCRには十分な水準）。

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
