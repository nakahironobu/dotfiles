# dotfiles（macOS 一撃セットアップ）

このリポジトリは、macOS を「新しいMacでも一撃で同じ環境」にするための dotfiles です。

## 方針（重要）
- **Mac の土台セットアップ**は `bootstrap_mac_full_auto.sh` で実施します（Homebrew / zsh / WezTerm / Neovim / stow 等）。
- **Python開発のベース環境**は **別スクリプト** `bootstrap_python_base.sh` に一本化します。
- **プロジェクトごとのPython実行環境**は `bootstrap_python_project.sh` で作成します（`.venv` / `uv sync` 等）。

> NOTE: macOS 付属の `python3`（`/usr/bin/python3` → Command Line Tools 側）を“初期状態”として保持し、プロジェクト実行は `uv run ...` を標準にします。

> 既定の方針: `bootstrap_python_base.sh` は **uv の default python3 を 3.14** に設定します。

---

## クイックスタート（新しいMac）

### 推奨：HTTPS で clone（SSH鍵なしでOK）

```sh
xcode-select --install 2>/dev/null || true

git clone https://github.com/nakahironobu/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 1) Mac土台
./scripts/bootstrap_mac_full_auto.sh

# 2) Python開発ベース（uv/direnv/ruff/pre-commit 等）
./scripts/bootstrap_python_base.sh

```

#### Xcode CLT のダイアログが出た場合
インストールを完了したら、もう一度実行してください:

```sh
cd ~/dotfiles
./scripts/bootstrap_mac_full_auto.sh
./scripts/bootstrap_python_base.sh
```

#### 完了後の推奨アクション
- WezTerm を一度再起動（フォントを新規導入した場合）
- 新しいタブを開く（または `exec zsh`）

---

## Python（ベース / プロジェクト）

### 1) Python開発ベース（全プロジェクト共通）

- `bootstrap_python_base.sh` は **uv の default python3 を 3.14** に設定します。

`./scripts/bootstrap_python_base.sh` が行うこと（要約）:

- Homebrew で `uv` / `direnv` を導入
- `uv tool` で `ruff` / `pre-commit` / `ipython` を導入（pipを汚さない）
- dotfiles 側の `.zshrc` に `direnv` hook（managed block）を反映し、`stow --restow home` で適用

確認:

```sh
uv --version
ruff --version
```

> NOTE: macOS付属の `python3` は置き換えません。プロジェクト実行は `uv run ...` を推奨します。

### 2) プロジェクトごとの環境作成
リポジトリ（プロジェクト）直下で実行:

```sh
~/dotfiles/scripts/bootstrap_python_project.sh 3.12
```

このスクリプトが行うこと（要約）:
- `.venv` を作成（`uv venv`）
- `pyproject.toml` が無ければ最小のものを生成
- `uv sync`（依存と lock の入口）
- `direnv` があれば `.envrc` を生成し `direnv allow`

動作確認:

```sh
uv run python -V
uv run python -c "import sys; print(sys.executable)"
uv run ruff check .
```

---

## 何が行われるか（詳細）

### 1) Homebrew（macOS土台）
`bootstrap_mac_full_auto.sh` は Homebrew をインストールし、以下などを導入します（スクリプト内 `BREW_FORMULAE / BREW_CASKS` 参照）:

- formula: `git`, `fzf`, `neovim`, `ripgrep`, `fd`, `eza`, `stow`
- cask: `wezterm`

> NOTE: **Python はここでは導入しません**（Pythonは `bootstrap_python_base.sh` に一本化）。

### 2) dotfiles 反映（GNU stow）
`home/` を stow の package として、ホームディレクトリに symlink を張ります:

```sh
stow -v -t ~ home
```

例:
- `~/dotfiles/home/.zshrc` → `~/.zshrc`
- `~/dotfiles/home/.config/nvim` → `~/.config/nvim`
- `~/dotfiles/home/.config/wezterm` → `~/.config/wezterm`

### 3) 既存設定の退避（バックアップ）
stow 適用前に、衝突しやすい既存ファイル/ディレクトリが **実体（symlink ではない）**の場合は退避します。

退避先:
- `~/.dotfiles-backup/<timestamp>/...`

退避対象（スクリプトの candidates により変わる）:
- `~/.zshrc`
- `~/.zsh_plugins.txt`
- `~/.p10k.zsh`
- `~/.config/nvim`
- `~/.config/wezterm`

> 重要: 既に symlink の場合は基本的に退避せず、そのまま stow の管理下として扱います。

### 4) zsh 設定の“管理ブロック”
スクリプトは `home/.zshrc` を以下の目的で最小限メンテします（＝リポジトリ側のファイルを更新する場合があります）:

- `~/.local/bin` を PATH に入れる
- `eza` alias（managed block）
- iCloud の cd alias（managed block）
- `.zsh_plugins.txt` の末尾に `zsh-syntax-highlighting` を配置する
- `direnv` hook（managed block） ※ `bootstrap_python_base.sh` が反映

### 5) WezTerm
- MesloLGS NF フォントを `~/Library/Fonts` に導入（無ければ）
- `wezterm` CLI を `~/.local/bin/wezterm` に用意（App内バイナリへの symlink）
- `home/.config/wezterm/wezterm.lua` に以下を自動注入/更新:
  - font fallback
  - managed window layout（起動時の位置/サイズ）
  - `font_size`（`WEZTERM_FONT_SIZE`）

### 6) Neovim（headless）
以下を headless で実行します:
- `Lazy! sync`
- `TSUpdateSync`
- `checkhealth`

---

## dotfiles を更新したとき（既存Mac / 新Mac 共通）

このリポジトリを更新したら、基本は「pull → bootstrap 再実行」で反映します。

```sh
cd ~/dotfiles
git pull --ff-only

# Mac土台
./scripts/bootstrap_mac_full_auto.sh

# Python開発ベース（必要に応じて）
./scripts/bootstrap_python_base.sh
```

- Homebrew の追加導入やアップデートがあれば適用されます
- stow によりリンクが維持/更新されます
- Neovim の headless 同期が走り、プラグイン等が追随します
- Python 開発ツール（uv/ruff等）は python_base 側で追随します

---

## トラブルシューティング（最小）

### Neovim headless sync が失敗する
一度 verbose で起動して原因を確認します:

```sh
nvim -V1 -v
```

### stow の状態確認（実行前の確認）
どんなリンクが張られるか確認できます:

```sh
cd ~/dotfiles
stow -n -v -t ~ home
```

### python3 の向き先を確認する（uv default / Homebrew / macOS 付属）
方針としては、**ベースは uv の default python3（既定 3.14）**、プロジェクトは `uv run ...` を使います。  
もし `which -a python3` の先頭に `/opt/homebrew/bin/python3` が出る場合は、Homebrew の Python が優先されている可能性があります。

方針としては macOS 付属の `python3` を維持し、プロジェクトは `uv run ...` を使います。  
もし `which -a python3` の先頭に `/opt/homebrew/bin/python3` が出る場合は、Homebrew の Python が入っている可能性があります。

確認:

```sh
which -a python3
python3 -c "import sys; print(sys.executable)"
```

必要なら（Homebrew python を使わない方針の場合）:

```sh
brew list --formula | egrep '^python($|@)' || true
brew unlink python 2>/dev/null || true
brew unlink python@3.12 2>/dev/null || true
brew unlink python@3.13 2>/dev/null || true
brew unlink python@3.14 2>/dev/null || true
hash -r
exec zsh
```

---

### uv の default python3 が意図通りか確認

```sh
which python3
python3 --version
uv python list
```

- `which python3` が `~/.local/bin/python3` なら uv default が優先されています。

## リポジトリ構成

- `home/` : stow の package（ここが `~` にリンクされる）
- `scripts/bootstrap_mac_full_auto.sh` : macOS土台の一撃セットアップ本体（Pythonは入れない）
- `scripts/bootstrap_python_base.sh` : Python開発ベース（uv/direnv/ruff/pre-commit 等）
- `scripts/bootstrap_python_project.sh` : プロジェクト用Python環境作成（`.venv` / `uv sync`）
