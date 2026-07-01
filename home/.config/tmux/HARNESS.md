# Claude ハーネス — 何をすれば何ができるか

WezTerm + tmux + Neovim + Claude Code を束ねた、**プロジェクト単位の作業環境（ハーネス）**のリファレンスです。tmux のプレフィックスキーは **`Ctrl-a`**。

---

## 1. 全体像

| 層 | 役割 |
|----|------|
| **WezTerm** | 端末。作業場の窓の最大化、改行キー、フォント。 |
| **tmux** | ウィンドウ/ペイン管理、作業場の生成、会話ログ操作。prefix = `Ctrl-a`。 |
| **Neovim** | 会話ログ(md)の閲覧・編集。表・見出しなどを整形表示。 |
| **Claude Code** | 各作業場で動く本体。 |
| **スクリプト** | 作業場の生成・会話ログの整形（`~/.config/tmux/scripts/`）。 |

用語：**作業場（workspace）= tmux の1ウィンドウ = 1プロジェクト分の3ペイン**。1プロジェクトは1つの作業場（別プロジェクトは別ウィンドウ／必要なら別 tmux セッション）で扱います。

---

## 2. コアワークフロー：プロジェクトの作業場を立てる

| やること | できること |
|----------|-----------|
| `Ctrl-a` → `W` | **fzf のプロジェクト選択ポップアップ**が開く → 選んだフォルダに新しい作業場（3ペイン）を作る |

作業場のレイアウト：

```
┌──────────────┬────────────────┐
│              │  右上: claude  │  ← 毎回まっさらな claude を自動起動
│ 左: 会話ログ  ├────────────────┤
│  (nvim/md)   │  右下: shell   │  ← 作業用シェル
└──────────────┴────────────────┘
```

- 選択と同時に、右上で claude が起動し、左に会話ログが開き、**WezTerm の窓が最大化**されます。
- 今の作業ウィンドウは触りません。別タスク／別プロジェクトの claude を増やせます（WezTerm 再起動は不要）。

**候補に出るフォルダ**（`claude-sessionizer.sh` が `fd` で収集）：

- `~/Projects` 直下すべて（`MATH` などのコンテナも選べる）
- その配下でも、`.git` / `.claude` / `CLAUDE.md` / `pyproject.toml` などの目印を持つ**サブプロジェクト**（例: `MATH/SEG`）
- `docs` / `scripts` / `.venv` / `vendor` 等の作業用フォルダは除外
- 範囲・判定は `claude-sessionizer.sh` 冒頭の `ROOTS` / `MARKERS` / `PRUNE` で調整

---

## 3. 会話ログ（プロジェクト単位の固定ログ）

会話ログは **1プロジェクト = 1ファイル**に集約され、セッションを跨いでも同じファイルに伸び続けます。

- 保存先：`~/.claude/conversation-exports/<プロジェクト名>.md`
- 区切りには `🔄 新しいセッション` 見出しが入り、記録は途切れません。
- 元データは Claude の `.jsonl`。`render_transcript.py` が読みやすい md へ整形します（**再生成可能**）。手編集した内容は追記時も保持されます。

| やること | できること |
|----------|-----------|
| `Ctrl-a` → `A` | 現在の会話の**続きを固定ログ末尾に追記**（手編集は保持・nvim へ自動反映） |
| `Ctrl-a` → `W` の左ペイン | 固定ログを nvim で開く（無ければ現行セッションから生成） |
| 左ペインで `gg` | 先頭へ（過去分を含む全履歴を確認） |
| 左ペインで `:e!` | ディスクから再読込（表示が古い/短いとき全履歴を戻す） |

**閲覧のコツ（整形表示）**

- `.md` を開くと render-markdown が見出し・箇条書き・**表**などを整形表示します。カーソルのある行だけ生の markdown に戻り、その場で編集できます。
- 横に長い表は狭い左ペインだと折り返して崩れます → **`Ctrl-a` → `z` でペインを全幅にズーム**すると崩れず表示（もう一度で戻る）。本文は常に折り返しで読めます。
- 整形/生の切替：nvim 内で `:RenderMarkdown toggle`。

**関連ドキュメントを左ペインで開く**

| やること | できること |
|----------|-----------|
| `Ctrl-a` → `F` | 関連 md（会話ログ・プロジェクト内の md・`HARNESS.md` 等）を fzf で選び、**左ペインの nvim にバッファとして開く** |

- 会話ログと**同じ nvim・同じ設定**（render-markdown 等）で閲覧・編集できます。会話ログのバッファは残るので `:b#` / `:bnext` で行き来できます。
- 仕組み：左ペインの nvim は `--listen` で RPC サーバとして起動しており、`Ctrl-a F` が `--remote` で同じ nvim に開きます（別 nvim を殺さず、未保存も失いません）。
- 候補の範囲は `claude-open-doc.sh` の `ROOTS` / `EXTRA` で調整できます。
- ※ この機能を導入する前に作った作業場では左 nvim がサーバでないため、`Ctrl-a W` で作業場を作り直すと有効になります。

---

## 4. Neovim の表示強化

| 機能 | 何が起きるか |
|------|-------------|
| **noice** | `:`（コマンド）や `/`（検索）が、入力欄＋候補をまとめた**コマンドパレット風ポップアップ**で表示される |
| **render-markdown** | `.md` を開くと表・見出し・箇条書き等を整形表示（`.sh` 等の非 markdown は対象外） |

---

## 5. キーバインド早見表

### tmux — Claude ワークフロー（prefix `Ctrl-a`）

| キー | 機能 |
|------|------|
| `W` | 作業場を作成（**fzf でプロジェクト選択**）＋ WezTerm 最大化 |
| `A` | 会話を固定ログに追記（Append） |
| `F` | 関連ドキュメント(md)を fzf で選び、**左ペインの nvim で開く**（履歴と同じく閲覧・編集） |
| `G` | Git ログ（graph・popup） |
| `S` | セッション切替（fzf・popup） |
| `z` | ペイン全幅ズーム（横長の表の閲覧に便利） |
| `r` | tmux 設定を再読込 |
| `?` | キー一覧（tmux 標準） |
| `d` | デタッチ（tmux 標準） |

### tmux — ウィンドウ / ペイン

| キー | 機能 |
|------|------|
| `Alt+1`〜`Alt+5` | ウィンドウ 1〜5 へジャンプ（プレフィックスなし） |
| `Alt+p` / `Alt+n` | 前 / 次のウィンドウ（プレフィックスなし） |
| `Ctrl+h/j/k/l` | ペイン移動（プレフィックスなし・vim/nvim/fzf 内では素通し） |
| `Alt+h/j/k/l` | ペイン移動（プレフィックスなし・**常に**移動。ログ↔claude の往復用） |
| `Ctrl-a` → `h/j/k/l` | ペイン移動（プレフィックスあり） |
| `Ctrl-a` → `\|` / `-` | 縦分割 / 横分割（現在パスを引き継ぎ） |
| `Ctrl-a` → `c` | 新しいウィンドウ（現在パスを引き継ぎ） |
| `Ctrl-a` → `H/J/K/L` | ペインサイズ変更（5単位・連打可） |
| `Ctrl-a` → `z` | ペインのズームトグル |

### tmux — コピー・ペースト

| キー | 機能 |
|------|------|
| `Ctrl-a` → `Enter` | コピーモード開始 |
| `v` / `Ctrl-v` / `y` / `Escape` | 選択 / 矩形選択 / コピー(pbcopy) / 終了（コピーモード内） |

### Neovim（会話ログの閲覧）

| キー | 機能 |
|------|------|
| `:RenderMarkdown toggle` | 整形表示 ⇔ 生 markdown の切替 |
| `:` / `/` | コマンド / 検索（noice のパレット表示） |
| `gg` / `G` | 先頭 / 末尾へ |
| `:e!` | ディスクから再読込 |

### WezTerm

| キー | 機能 |
|------|------|
| `Shift+Return` | **改行**（Claude Code 等のプロンプトで改行を入れる） |
| `Cmd+T` / `Cmd+W` | 新規タブ / タブを閉じる |
| `Cmd+1`〜`Cmd+5` | タブ 1〜5 へ |
| `Cmd+Shift+[` / `]` | 前 / 次のタブ |
| `Cmd+C` / `Cmd+V` | コピー / ペースト |
| `Cmd++` / `Cmd+-` / `Cmd+0` | フォント 拡大 / 縮小 / リセット |

> Claude Code プロンプトの改行は `Shift+Return` のほか、`\` → `Return`、`Ctrl+J` でも入れられます。

---

## 6. ファイル / スクリプト

| パス | 内容 |
|------|------|
| `~/.config/tmux/tmux.conf` | tmux 設定 |
| `~/.config/tmux/scripts/claude-sessionizer.sh` | `Ctrl-a W` のプロジェクト選択（`fd` → `fzf`） |
| `~/.config/tmux/scripts/claude-layout.sh [dir]` | 3ペインの作業場を生成（引数のフォルダ、無ければ現ペインの cwd） |
| `~/.config/tmux/scripts/claude-log.sh [PROJ] [--fresh\|--update]` | 会話ログを md 整形して nvim で開く（左 nvim を `--listen` サーバ化）／`--update` で追記／`--fresh` で作り直し |
| `~/.config/tmux/scripts/claude-open-doc.sh` | `Ctrl-a F` の md ピッカー。選んだ md を左 nvim に `--remote` で開く |
| `~/.config/tmux/scripts/render_transcript.py` | Claude の `.jsonl` → Markdown 整形 |
| `~/.config/wezterm/wezterm.lua` | WezTerm 設定 |
| `~/.config/nvim/init.lua` | Neovim 設定（noice / render-markdown 等） |
| `~/.claude/conversation-exports/<proj>.md` | プロジェクト単位の固定会話ログ |

設定はすべて dotfiles（GNU stow で `~/dotfiles/home` → `~` に配置）で管理しています。

---

## 7. 前提ツール

`tmux`（3.3+ / passthrough 使用） · `neovim` · `fzf` · `fd` · `claude` · `base64`（WezTerm 最大化トリガ）。
