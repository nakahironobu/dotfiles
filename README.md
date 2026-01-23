# dotfiles（macOS 一撃セットアップ）

このリポジトリは、macOS を「新しいMacでも一撃で同じ環境」にするための dotfiles です。

やっていること（要約）:

- Xcode Command Line Tools の導入（未導入ならGUIインストールを促して一旦終了→再実行）
- Homebrew 導入 + パッケージ（git/fzf/neovim/rg/fd/eza/stow/python 等）
- zsh（Antidote + powerlevel10k）とプラグイン設定の整備
- WezTerm（フォント導入、CLI symlink、レイアウト注入、font fallback）
- Neovim（headless で Lazy sync / TSUpdateSync / checkhealth）
- dotfiles 反映は **GNU stow** で実施（`~/dotfiles/home -> ~`）

---

## クイックスタート（新しいMac）

### 推奨：HTTPS で clone（SSH鍵なしでOK）

```sh
xcode-select --install 2>/dev/null || true

git clone https://github.com/nakahironobu/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap_mac_full_auto.sh
```

#### Xcode CLT のダイアログが出た場合
インストールを完了したら、もう一度実行してください:

```sh
cd ~/dotfiles
./scripts/bootstrap_mac_full_auto.sh
```

#### 完了後の推奨アクション
- WezTerm を一度再起動（フォントを新規導入した場合）
- 新しいタブを開く（または `exec zsh`）

---

## 何が行われるか（詳細）

### 1) Homebrew
Homebrew をインストールし、以下などを導入します（スクリプト内 `BREW_FORMULAE / BREW_CASKS` 参照）:

- formula: `git`, `fzf`, `neovim`, `ripgrep`, `fd`, `eza`, `stow`, `python`
- cask: `wezterm`

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
./scripts/bootstrap_mac_full_auto.sh
```

- Homebrew の追加導入やアップデートがあれば適用されます
- stow によりリンクが維持/更新されます
- Neovim の headless 同期が走り、プラグイン等が追随します

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

---

## リポジトリ構成

- `home/` : stow の package（ここが `~` にリンクされる）
- `scripts/bootstrap_mac_full_auto.sh` : 一撃セットアップ本体
