# Kindle Capture CLI

Amazon Kindleで通常表示されているページを、WezTermから指定範囲の連番PNGとして保存するmacOS用CLIです。DRM解除、Kindleファイルの抽出、認証回避は行いません。

## インストール

```zsh
~/dotfiles/scripts/install-kindle-capture.sh
```

インストーラーは、このディレクトリのSwiftソースを各Mac上でビルドし、次を作成します。

- `~/Projects/PDF-tools/kindle_capture/kindle-capture`
- `~/Projects/PDF-tools/kindle_capture/crop_black_borders`
- `~/.local/bin/kindle-capture`

`~/.local/bin`はdotfilesの`.zshrc`で`PATH`に追加されています。

## 使い方

Kindleで開始ページを表示してから、任意のフォルダで実行します。

```zsh
kindle-capture 188 220
```

WezTerm上でprefixと保存先を質問します。Enterだけを押した場合、prefixは`kindle`、保存先は現在のフォルダです。

既定値は次のとおりです。

- ページ送り：右矢印
- ページ送り後の待機：1.3秒
- 保存モード：`margin`（左右余白を残し、Kindleの上部バーだけ除外）
- 撮影開始前の待機：2秒

日本語書籍など左矢印で次ページへ進む場合：

```zsh
kindle-capture 188 220 --direction left
```

全オプション：

```zsh
kindle-capture --help
```

`--prefix`または`--output`を指定した場合、その項目については質問しません。

## macOSの権限

初回は「システム設定 → プライバシーとセキュリティ」でWezTermに次を許可します。

- アクセシビリティ
- 画面収録
- System Eventsのオートメーション確認が表示された場合は許可

権限変更後はWezTermを完全に終了して開き直します。これらの権限はmacOSの仕様上、dotfilesから自動付与できません。

## ファイル

- `kindle-capture`：ページ範囲、保存、ページ送りを管理するzshスクリプト
- `crop_black_borders.swift`：上部バーと必要に応じて左右の黒余白を除外する補助プログラム
