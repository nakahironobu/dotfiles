# Claude Code ワークスペース — キーバインド & 使い方

> プレフィックスキー: **`Ctrl-a`**（デフォルトの `Ctrl-b` から変更）
>
> ハーネス全体の「何をすれば何ができるか」は [`HARNESS.md`](./HARNESS.md) を参照。本ファイルは tmux のキー詳細。

## 基本の流れ

claude の作業場は「tmux のウィンドウ」を1つの単位として増やす。

| 操作 | 結果 |
|------|------|
| `Ctrl-a` → `W` | **fzf でプロジェクトを選び、そのフォルダに claude 作業場を1つ追加**。今の作業ウィンドウは触らない。 |

`Ctrl-a → W` で開くウィンドウのレイアウト（`claude-layout.sh`）：

```
┌────────────┬───────────────┐
│            │  右上: claude │  ← 新規に毎回まっさらな claude を起動
│ 左: 会話ログ ├───────────────┤
│ (nvim/md)  │  右下: shell  │  ← 作業用シェル
└────────────┴───────────────┘
```

- `Ctrl-a → W` を押すと **fzf のプロジェクト選択ポップアップ**が開き、選んだフォルダで claude 作業場を作る（候補ルールは `claude-sessionizer.sh` 参照）。
- ウィンドウを開いた直後に **WezTerm の窓を最大化**する（`claude-layout.sh` が WezTerm の user-var を立てる → `wezterm.lua` の `user-var-changed` → `window:maximize()`）。

---

## tmux — Claude ワークフロー（プレフィックス `Ctrl-a`）

| キー | 機能 |
|------|------|
| `Ctrl-a` → `W` | fzf でプロジェクトを選び、その作業場を作成（左=会話ログ / 右上=claude / 右下=shell）＋ WezTerm 窓を最大化 |
| `Ctrl-a` → `A` | 現在の会話を固定ログ(md)に**追記**（Append・手編集は保持・nvim へ自動反映） |
| `Ctrl-a` → `G` | Git ログ（グラフ表示・popup） |
| `Ctrl-a` → `S` | セッション切替（fzf・popup） |
| `Ctrl-a` → `r` | tmux 設定を再読込（`✓ Config reloaded`） |
| `Ctrl-a` → `?` | tmux のキー一覧を表示（`list-keys`・tmux 標準） |
| `Ctrl-a` → `d` | デタッチ（tmux 標準） |

> 会話ログ（`Ctrl-a → A` の追記先）はプロジェクト単位の固定ファイル
> `~/.claude/conversation-exports/<プロジェクト名>.md`。セッションを跨いでも同じファイルに伸び続ける。

---

## tmux — ウィンドウ・ペイン管理

### ウィンドウ切替（プレフィックスなし）

| キー | 機能 |
|------|------|
| `Alt+1` 〜 `Alt+5` | ウィンドウ 1〜5 へ直接ジャンプ |
| `Alt+p` | 前のウィンドウ |
| `Alt+n` | 次のウィンドウ |

### ペイン移動

| キー | 機能 |
|------|------|
| `Ctrl+h / j / k / l` | ペイン移動（プレフィックスなし・vim/nvim/fzf の中では素通し） |
| `Alt+h / j / k / l` | ペイン移動（プレフィックスなし・**常に**移動。会話ビューア↔claude の往復用） |
| `Ctrl-a` → `h / j / k / l` | ペイン移動（プレフィックスあり） |

### ペイン操作（プレフィックス `Ctrl-a`）

| キー | 機能 |
|------|------|
| `Ctrl-a` → `\|` | 縦分割（現在パスを引き継ぎ） |
| `Ctrl-a` → `-` | 横分割（現在パスを引き継ぎ） |
| `Ctrl-a` → `c` | 新しいウィンドウ（現在パスを引き継ぎ） |
| `Ctrl-a` → `z` | ペインのズームトグル（全画面 ⇔ 元に戻す） |
| `Ctrl-a` → `H / J / K / L` | ペインサイズ変更（5単位・連打可） |

---

## コピー・ペースト

| キー | 機能 |
|------|------|
| `Ctrl-a` → `Enter` | コピーモード開始 |
| `v` | 選択開始（コピーモード内） |
| `Ctrl-v` | 矩形選択（コピーモード内） |
| `y` | コピーしてクリップボードへ送る（pbcopy） |
| `Escape` | コピーモード終了 |

---

## WezTerm

| キー | 機能 |
|------|------|
| `Cmd+T` | 新しいタブ |
| `Cmd+W` | タブを閉じる（確認あり） |
| `Cmd+1` 〜 `Cmd+5` | タブ 1〜5 へジャンプ |
| `Cmd+Shift+[` | 前のタブ |
| `Cmd+Shift+]` | 次のタブ |
| `Cmd+C` / `Cmd+V` | コピー / ペースト |
| `Cmd++` / `Cmd+-` | フォントサイズ拡大 / 縮小 |
| `Cmd+0` | フォントサイズリセット |
| `Cmd+\`` | 別の WezTerm ウィンドウに切替（macOS 標準） |

---

## tpm プラグイン操作（tmux 内で）

| キー | 機能 |
|------|------|
| `Ctrl-a` → `I` | プラグインインストール |
| `Ctrl-a` → `U` | プラグインアップデート |
| `Ctrl-a` → `Alt+u` | 未使用プラグイン削除 |

導入プラグイン: `tpm` / `tmux-sensible` / `tmux-resurrect` / `tmux-continuum`（自動保存 ON・**自動復元 OFF**。作業場は `Ctrl-a W` を押したときだけ作る方針のため）。

---

## スクリプト一覧

`~/.config/tmux/scripts/` にあるスクリプト：

| スクリプト | 説明 |
|-----------|------|
| `claude-sessionizer.sh` | `Ctrl-a → W` が呼ぶ。`fd`→`fzf` でプロジェクトを選び `claude-layout.sh` に渡す。 |
| `claude-layout.sh [dir]` | 指定フォルダ（無ければ現ペインの cwd）に claude 作業場を作成。最後に WezTerm 窓を最大化。 |
| `claude-log.sh [PROJ] [--fresh\|--update]` | 会話ログを読みやすい md にして nvim で開く（左ペイン）。`--update` で固定ログ末尾に追記（`Ctrl-a → A`）。`--fresh` で作り直し。 |
| `render_transcript.py` | Claude の `.jsonl` 会話ログ → Markdown 整形（`claude-log.sh` が内部利用） |

---

## 設定ファイル

| パス | 内容 |
|------|------|
| `~/.config/tmux/tmux.conf` | tmux 本体設定（dotfiles を stow で配置） |
| `~/.config/tmux` | → `~/dotfiles/home/.config/tmux`（GNU stow が生成） |
| `~/.config/tmux/scripts/` | 各種スクリプト |
| `~/.config/wezterm/wezterm.lua` | WezTerm 設定 |

---

## セットアップ確認

```bash
tmux -V        # tmux 3.x 以上（passthrough を使うため 3.3 以上）
nvim --version # 会話ログ表示に必須（claude-log.sh）
fzf --version  # セッション切替 (Ctrl-a S) に必須
base64 --help  # WezTerm 最大化トリガに使用（macOS 標準で同梱）
```
