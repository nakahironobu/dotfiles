# batch-extract

教材の紙面PNG/PDFを **OCR で一次抽出**するバッチの入口です。会話形式で「どの教材か」から順に選ばせ、
各プロジェクトの抽出パイプラインへ委譲します。

`reader_capture`（取り込み）と対になるコマンドで、操作感を揃えてあります。

```
reader_capture   … ビューアの表示ページを PNG にする      → scans/<本>/<部分>/
batch_extract    … その PNG を OCR して素材バンドルにする → extract/<本>/outputs/pipeline/<部分>/
```

## 使い方

どのフォルダからでも `batch_extract` と打てば、会話形式で順に質問します。

```zsh
batch_extract
```

質問される項目:

1. どの教材か（`1) Legend` / `2) Blue-chart` / `3) SAPIX`）
2. どの本か（数学I+A / 数学II+B / 数学III+C）※Legend・Blue-chart
3. どの部分か（本編 / 別冊問題編 / 解答編 / 巻頭）※Legend・Blue-chart
4. ページ範囲（取り込み済みの範囲を既定で提示します）

### 引数でまとめて指定する

```zsh
batch_extract bluechart --book 1a --section honpen --range 297-380
batch_extract legend    --book 1a --section honpen --range 332-449
batch_extract bluechart --check          # ツール導通確認だけ
batch_extract sapix --all                # SAPIX は引数をそのまま batch_extract.py へ渡す
```

| オプション | 説明 |
| --- | --- |
| `-b, --book CODE` | `1a` / `2b` / `3c` |
| `-s, --section NAME` | `honpen` / `problems` / `answers` / `intro` |
| `-r, --range SPEC` | ページ範囲。`297-380` や `5,7,9-12` |
| `--check` | ツール導通確認だけ行い、抽出しない |
| `--conf N` | DocLayout 信頼度しきい値（既定 0.4） |
| `--no-yomitoku` | 表のHTML化を行わない |
| `--no-latex` | 数式のLaTeX化を行わない（画像は残す） |
| `-h, --help` | 説明を表示 |

上記以外のオプションは、そのまま各パイプラインへ渡します。

## 委譲先

| 教材 | パイプライン | 入力 |
| --- | --- | --- |
| Legend | `Legend/extract/legend_pipeline.py` | 単ページPNG（Libry由来） |
| Blue-chart | `Blue-chart/extract/bluechart_pipeline.py` | 単ページPNG（sviewer由来・見開きは取り込み時に左右分割済み） |
| SAPIX | `SAPIX/extract/batch_extract.py` | `input/` のPDFを自分で走査 |

Legend と Blue-chart のパイプラインは同一実装（Blue-chart 側は複写）で、**検出仕様・モデル・出力構造が同じ**です。
将来 Blue-chart を Legend へ統合するとき、素材バンドルをそのまま持ち込めます。

## 使うモデル

| ツール | 役割 |
| --- | --- |
| NDL-OCR Lite | 日本語**平文**の一次抽出（漢字・かな） |
| DocLayout-YOLO | 図・表・数式の**領域検出**→ 図の自動クロップ |
| YomiToku | **表 → セル結合込み HTML** |
| LaTeX-OCR（pix2tex） | **数式領域 → LaTeX**。未導入なら画像を残しAIが起こす |

役割分担は `~/Projects/CLAUDE.md` の共通ワークフローどおりです。
**平文＝NDLが一次／数式・記号・図＝AI／最終照合＝AI。** NDL は `x^2`→`x2`、`±`→`土` のように崩れるため、
数式を NDL の出力から起こしてはいけません。

導通確認:

```zsh
batch_extract bluechart --check
```

## ⚠ Terminal.app から実行すること

抽出は macOS ローカルのモデル群に依存します。**Claude Code の Bash から起動すると Claude.app の
サンドボックス権限を継承し**、外部ボリュームや保護フォルダにアクセスできません
（`~/.claude/CLAUDE.md` の「Claude.app 内で長時間プロセスを起動しない」）。

## 実行環境について

OCRスタック（onnxruntime / opencv / pillow）は `~/Projects` の **uv workspace 共有venv（Python 3.14）**にあります。
Blue-chart は Flask アプリ用に独自 venv を持つため、抽出のときだけ `uv run --project ~/Projects` で
workspace 側を借りています。このコマンドが自動でそうするので、意識する必要はありません。

## インストール（dotfiles管理）

```zsh
~/dotfiles/scripts/install-batch-extract.sh
```

- `~/Projects/PDF-tools/batch_extract/batch-extract`（本体）
- `~/.local/bin/batch_extract`（コマンド）

プロジェクトの場所は環境変数 `LEGEND_ROOT` / `BLUECHART_ROOT` / `SAPIX_ROOT` で変えられます。
