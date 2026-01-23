#!/usr/bin/env bash
set -euo pipefail

########################################
# macOS Full Bootstrap (AUTO, dotfiles-based, STOW)
#
# Includes:
# - Xcode CLT (prompts GUI install if missing; exits -> re-run)
# - Homebrew + packages (git fzf neovim ripgrep fd eza stow python)
# - WezTerm (cask + CLI path + font fallback + window layout injection + font_size)
#     NOTE: If /Applications/WezTerm.app already exists, skip cask install and continue.
# - zsh (Antidote + p10k already in your dotfiles) + plugins + aliases
#     - eza aliases with --classify (managed block appended/updated in dotfiles .zshrc)
#     - zsh-syntax-highlighting (ensure last in .zsh_plugins.txt)
#     - iCloud cd aliases (managed block appended)
# - Dotfiles linking via GNU stow:
#     stow -t ~ home   (home/ is your package directory)
# - Neovim (headless Lazy sync + TSUpdateSync + checkhealth, pin treesitter to master)
#
# Typical "one-shot" on a new Mac:
#   xcode-select --install 2>/dev/null || true
#   git clone https://github.com/nakahironobu/dotfiles.git ~/dotfiles
#   cd ~/dotfiles
#   ./scripts/bootstrap_mac_full_auto.sh
#
########################################

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_HOME_DIR="${DOTFILES_HOME_DIR:-$DOTFILES_DIR/home}"

# Default to HTTPS for frictionless first-run on new Macs (SSH key not required)
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/nakahironobu/dotfiles.git}"

ANTIDOTE_DIR="${ANTIDOTE_DIR:-$HOME/.local/share/antidote}"

BREW_FORMULAE=( git fzf neovim ripgrep fd eza stow python )
BREW_CASKS=( wezterm )

MESLO_FONT_BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"

# WezTerm layout knobs (override if desired)
WEZTERM_FONT_SIZE="${WEZTERM_FONT_SIZE:-16.0}"
WEZTERM_Y_OFFSET_RATIO="${WEZTERM_Y_OFFSET_RATIO:-0.08}"  # slightly above center
WEZTERM_WIDTH_RATIO="${WEZTERM_WIDTH_RATIO:-0.6666667}"   # 2/3
WEZTERM_HEIGHT_RATIO="${WEZTERM_HEIGHT_RATIO:-0.5}"       # 1/2

timestamp() { date +"%Y%m%d_%H%M%S"; }
log()  { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

require_manual_then_exit() {
  local msg="$1"
  echo
  echo "=================================================="
  echo "[MANUAL STEP REQUIRED]"
  echo "$msg"
  echo
  echo "After finishing the manual step, RE-RUN:"
  echo "  $0"
  echo "=================================================="
  echo
  exit 2
}

ensure_macos() {
  if ! is_macos; then err "This script is for macOS only."; exit 1; fi
  log "macOS detected."
}

install_xcode_clt_if_needed() {
  if ! need_cmd xcode-select; then err "xcode-select not found"; exit 1; fi
  if xcode-select -p >/dev/null 2>&1; then log "Xcode CLT already installed."; return; fi
  warn "Xcode CLT not found. Triggering installer..."
  xcode-select --install || true
  require_manual_then_exit "Complete Xcode Command Line Tools installation dialog, then re-run."
}

ensure_brew_in_path_for_this_shell() {
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
}

install_homebrew_if_needed() {
  if need_cmd brew; then log "Homebrew already installed."; ensure_brew_in_path_for_this_shell; return; fi
  warn "Homebrew not found. Installing (may prompt for password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ensure_brew_in_path_for_this_shell
  if ! need_cmd brew; then
    require_manual_then_exit "brew installed but not on PATH yet. Open a NEW terminal tab and re-run."
  fi
  log "Homebrew installed."
}

install_brew_packages() {
  if ! need_cmd brew; then err "brew missing"; exit 1; fi
  log "brew update..."; brew update

  for pkg in "${BREW_FORMULAE[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      log "brew formula already installed: $pkg"
    else
      log "Installing brew formula: $pkg"
      brew install "$pkg"
    fi
  done

  for cask in "${BREW_CASKS[@]}"; do
    # --- Special-case: WezTerm already exists in /Applications ---
    # Homebrew cask can error out if the app bundle already exists.
    # Requirement: skip wezterm install and continue with the rest.
    if [[ "$cask" == "wezterm" && -d "/Applications/WezTerm.app" ]]; then
      warn "WezTerm.app already exists at /Applications/WezTerm.app; skipping 'brew install --cask wezterm' and continuing."
      continue
    fi

    if brew list --cask "$cask" >/dev/null 2>&1; then
      log "brew cask already installed: $cask"
    else
      log "Installing brew cask: $cask"
      # Use if/else so failure doesn't trigger set -e termination.
      if brew install --cask "$cask"; then
        log "brew cask installed: $cask"
      else
        warn "brew cask install failed: $cask (skipping and continuing)"
      fi
    fi
  done

  if brew list --formula fzf >/dev/null 2>&1; then
    local fzf_install; fzf_install="$(brew --prefix)/opt/fzf/install"
    if [[ -x "$fzf_install" ]]; then
      log "Running fzf install (no rc changes)..."
      "$fzf_install" --key-bindings --completion --no-update-rc >/dev/null || true
    fi
  fi
}

clone_or_update_dotfiles() {
  if ! need_cmd git; then err "git missing"; exit 1; fi

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log "dotfiles exists: $DOTFILES_DIR"
    (cd "$DOTFILES_DIR" && git pull --ff-only) || warn "dotfiles git pull failed."
    return
  fi

  if [[ -d "$DOTFILES_DIR" && ! -d "$DOTFILES_DIR/.git" ]]; then
    err "DOTFILES_DIR exists but is not a git repo: $DOTFILES_DIR"
    exit 1
  fi

  log "Cloning dotfiles into $DOTFILES_DIR ..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
}

ensure_dotfiles_layout() {
  [[ -d "$DOTFILES_HOME_DIR" ]] || { err "Missing: $DOTFILES_HOME_DIR"; exit 1; }
  [[ -f "$DOTFILES_HOME_DIR/.zshrc" ]] || { err "Missing: $DOTFILES_HOME_DIR/.zshrc"; exit 1; }
  [[ -f "$DOTFILES_HOME_DIR/.zsh_plugins.txt" ]] || { err "Missing: $DOTFILES_HOME_DIR/.zsh_plugins.txt"; exit 1; }
  [[ -f "$DOTFILES_HOME_DIR/.p10k.zsh" ]] || { err "Missing: $DOTFILES_HOME_DIR/.p10k.zsh"; exit 1; }
  [[ -d "$DOTFILES_HOME_DIR/.config" ]] || { err "Missing dir: $DOTFILES_HOME_DIR/.config"; exit 1; }
  log "dotfiles layout OK (stow)."
}

ensure_zshrc_path_local_bin() {
  local zshrc="$DOTFILES_HOME_DIR/.zshrc"
  if grep -q 'HOME/.local/bin' "$zshrc"; then
    log "PATH (~/.local/bin) already in .zshrc"
    return
  fi
  warn "Injecting PATH (~/.local/bin) into dotfiles .zshrc"
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$zshrc"
}

ensure_zshrc_eza_aliases() {
  local zshrc="$DOTFILES_HOME_DIR/.zshrc"
  local marker="# --- eza aliases (managed) ---"

  if grep -qF "$marker" "$zshrc"; then
    log "Updating eza alias block in dotfiles .zshrc (managed)"
    python3 - <<PY
from pathlib import Path
import re
p = Path(r"$zshrc")
s = p.read_text(encoding="utf-8")
block = r'''
# --- eza aliases (managed) ---
alias z1='eza --classify'
alias zz='eza -lah --classify'
alias z2='eza --tree --level=2 --classify'
'''.strip() + "\n"
pat = re.compile(r"(?ms)^# --- eza aliases \(managed\) ---\n.*?(?=\n\n|\Z)")
s2, n = pat.subn(block, s, count=1)
if n == 0:
    s2 = s + "\n\n" + block
p.write_text(s2, encoding="utf-8")
print("OK: eza alias block updated")
PY
    return
  fi

  log "Adding eza aliases to dotfiles .zshrc"
  cat >> "$zshrc" <<'EOF'

# --- eza aliases (managed) ---
alias z1='eza --classify'
alias zz='eza -lah --classify'
alias z2='eza --tree --level=2 --classify'
EOF
}

ensure_zshrc_icloud_cd_aliases() {
  local zshrc="$DOTFILES_HOME_DIR/.zshrc"
  local marker="# --- iCloud cd aliases (managed) ---"
  if grep -qF "$marker" "$zshrc"; then
    log "iCloud cd alias block already present in dotfiles .zshrc"
    return
  fi
  log "Adding iCloud cd aliases to dotfiles .zshrc"
  cat >> "$zshrc" <<'EOF'

# --- iCloud cd aliases (managed) ---
alias icloud='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs'
alias desktop='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop'
alias ayumi='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi'
alias manami='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Manami'
alias sapix='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Manami/Manami-Sapix'
alias seg='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi/SEG'
alias kono='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi/KonoJuku'
EOF
}

ensure_syntax_highlighting_plugin_last() {
  local plugins="$DOTFILES_HOME_DIR/.zsh_plugins.txt"
  local plugin="zsh-users/zsh-syntax-highlighting"
  [[ -f "$plugins" ]] || { err "Missing plugins file: $plugins"; exit 1; }

  if grep -qFx "$plugin" "$plugins"; then
    log "zsh-syntax-highlighting already listed; ensuring it's last"
    python3 - <<PY
from pathlib import Path
p = Path(r"$plugins")
lines = [ln.rstrip("\n") for ln in p.read_text(encoding="utf-8").splitlines()]
target = "$plugin"
kept = [ln for ln in lines if ln.strip() and ln.strip() != target]
out = kept + [target]
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("OK: ensured plugin last")
PY
  else
    log "Adding zsh-syntax-highlighting to .zsh_plugins.txt (as last line)"
    printf "\n%s\n" "$plugin" >> "$plugins"
  fi
}

stow_apply_home() {
  if ! need_cmd stow; then
    err "stow not found (should have been installed by brew)."
    exit 1
  fi

  local ts; ts="$(timestamp)"
  local backup_root="$HOME/.dotfiles-backup/$ts"
  mkdir -p "$backup_root"

  # Back up only “likely conflict” paths (real files/dirs only; symlinks are OK)
  local candidates=(
    "$HOME/.zshrc"
    "$HOME/.zsh_plugins.txt"
    "$HOME/.p10k.zsh"
    "$HOME/.config/nvim"
    "$HOME/.config/wezterm"
  )

  for p in "${candidates[@]}"; do
    if [[ -e "$p" && ! -L "$p" ]]; then
      mkdir -p "$backup_root/$(dirname "${p#$HOME/}")"
      mv -f "$p" "$backup_root/$(dirname "${p#$HOME/}")/"
      warn "Backed up: $p -> $backup_root/$(dirname "${p#$HOME/}")/"
    fi
  done

  log "Applying stow: $DOTFILES_DIR/home -> ~"
  (cd "$DOTFILES_DIR" && stow -v -t "$HOME" --restow home)

  log "stow done. backup: $backup_root"
}

install_or_update_antidote() {
  if [[ -f "$ANTIDOTE_DIR/antidote.zsh" ]]; then
    log "Antidote exists."
    (cd "$ANTIDOTE_DIR" && git pull --ff-only) || warn "antidote git pull failed."
    return
  fi
  log "Installing Antidote..."
  mkdir -p "$(dirname "$ANTIDOTE_DIR")"
  git clone https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
}

generate_antidote_bundle() {
  log "Generating antidote bundle..."
  zsh -lc 'source ~/.zshrc >/dev/null 2>&1 || exit 1'
  [[ -f "$HOME/.cache/zsh/antidote_bundle.zsh" ]] || { err "bundle not generated"; exit 1; }
  log "Antidote bundle OK."
}

install_meslo_fonts_if_needed() {
  local fonts_dir="$HOME/Library/Fonts"
  mkdir -p "$fonts_dir"
  local marker="$fonts_dir/MesloLGS NF Regular.ttf"
  if [[ -f "$marker" ]]; then log "MesloLGS NF fonts already installed."; return; fi

  log "Installing MesloLGS NF fonts..."
  local tmpdir; tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -fsSL "$MESLO_FONT_BASE_URL/MesloLGS%20NF%20Regular.ttf"       -o "$tmpdir/MesloLGS NF Regular.ttf"
  curl -fsSL "$MESLO_FONT_BASE_URL/MesloLGS%20NF%20Bold.ttf"          -o "$tmpdir/MesloLGS NF Bold.ttf"
  curl -fsSL "$MESLO_FONT_BASE_URL/MesloLGS%20NF%20Italic.ttf"        -o "$tmpdir/MesloLGS NF Italic.ttf"
  curl -fsSL "$MESLO_FONT_BASE_URL/MesloLGS%20NF%20Bold%20Italic.ttf" -o "$tmpdir/MesloLGS NF Bold Italic.ttf"

  cp -f "$tmpdir/"*.ttf "$fonts_dir/"
  log "Fonts copied."
}

ensure_wezterm_cli() {
  if need_cmd wezterm; then log "wezterm CLI OK: $(command -v wezterm)"; return; fi
  local app="/Applications/WezTerm.app/Contents/MacOS/wezterm"
  if [[ -x "$app" ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$app" "$HOME/.local/bin/wezterm"
    log "wezterm CLI linked to ~/.local/bin/wezterm"
    return
  fi
  warn "wezterm CLI not found; GUI may still work."
}

choose_wezterm_font_name() {
  local cli="${HOME}/.local/bin/wezterm"
  if need_cmd wezterm; then cli="$(command -v wezterm)"; fi
  [[ -x "$cli" ]] || { echo ""; return; }
  local out; out="$("$cli" ls-fonts 2>/dev/null || true)"
  if echo "$out" | grep -Fq "MesloLGS NF"; then echo "MesloLGS NF"; return; fi
  if echo "$out" | grep -Fq "MesloLGS Nerd Font Mono"; then echo "MesloLGS Nerd Font Mono"; return; fi
  if echo "$out" | grep -Fq "MesloLGS Nerd Font"; then echo "MesloLGS Nerd Font"; return; fi
  echo ""
}

patch_wezterm_lua_font_and_layout() {
  local wz="$DOTFILES_HOME_DIR/.config/wezterm/wezterm.lua"
  [[ -f "$wz" ]] || { warn "wezterm.lua not found at $wz"; return; }

  local best; best="$(choose_wezterm_font_name)"
  local primary="${best:-MesloLGS NF}"
  log "Patching wezterm.lua (font fallback + layout). primary font: $primary"

  python3 - <<PY
from pathlib import Path
import re

p = Path(r"$wz")
s = p.read_text(encoding="utf-8")

primary = r"$primary"
font_size = r"$WEZTERM_FONT_SIZE"
wr = float(r"$WEZTERM_WIDTH_RATIO")
hr = float(r"$WEZTERM_HEIGHT_RATIO")
yoff = float(r"$WEZTERM_Y_OFFSET_RATIO")

managed = f"""
-- BEGIN OAI MANAGED: WEZTERM LAYOUT
local FONT_SIZE = {font_size}

wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {{}})
  local gui = window:gui_window()

  local screens = wezterm.gui.screens()
  local s = screens.active or screens[1]
  local w = s.width
  local h = s.height

  local inner_w = math.floor(w * {wr})
  local inner_h = math.floor(h * {hr})

  local x = math.floor(w - inner_w)
  local y = math.floor((h - inner_h) / 2 - (h * {yoff}))
  if y < 0 then y = 0 end

  gui:set_position(x, y)
  gui:set_inner_size(inner_w, inner_h)
end)
-- END OAI MANAGED: WEZTERM LAYOUT
""".strip() + "\n"

if "local wezterm = require(\"wezterm\")" not in s and "local wezterm = require('wezterm')" not in s:
    s = 'local wezterm = require("wezterm")\\n\\n' + s

block_re = re.compile(r"-- BEGIN OAI MANAGED: WEZTERM LAYOUT.*?-- END OAI MANAGED: WEZTERM LAYOUT\\n?", re.S)
if block_re.search(s):
    s = block_re.sub(managed, s)
else:
    m = re.search(r"local wezterm\\s*=\\s*require\\([\"']wezterm[\"']\\)\\s*\\n+", s)
    if m:
        s = s[:m.end()] + managed + s[m.end():]
    else:
        s = managed + s

fallback_block = f'''font = wezterm.font_with_fallback({{
    "{primary}",
    "MesloLGS Nerd Font Mono",
    "MesloLGS Nerd Font",
    "MesloLGS NF",
    "Menlo",
  }}),'''

if re.search(r"font\\s*=\\s*wezterm\\.font_with_fallback\\(", s):
    s = re.sub(r"font\\s*=\\s*wezterm\\.font_with_fallback\\(\\{.*?\\}\\)\\s*,", fallback_block, s, flags=re.S)
else:
    s = re.sub(r'font\\s*=\\s*wezterm\\.font\\([^\\)]*\\)\\s*,', fallback_block, s)

if re.search(r"font_size\\s*=", s):
    s = re.sub(r"font_size\\s*=\\s*[^,\\n]+\\s*,", "font_size = FONT_SIZE,", s)
else:
    s = re.sub(r"(font\\s*=\\s*wezterm\\.font_with_fallback\\(\\{.*?\\}\\)\\s*,)",
               r"\\1\\n  font_size = FONT_SIZE,", s, flags=re.S)

p.write_text(s, encoding="utf-8")
print("OK: wezterm.lua patched (managed layout + font)")
PY
}

pin_treesitter_master_if_needed() {
  local init="$DOTFILES_HOME_DIR/.config/nvim/init.lua"
  [[ -f "$init" ]] || { warn "nvim init.lua not found"; return; }
  if grep -q "nvim-treesitter/nvim-treesitter" "$init" && grep -q "branch *= *['\"]master['\"]" "$init"; then
    log "nvim-treesitter already pinned to master."
    return
  fi
  log "Pinning nvim-treesitter to master..."
  python3 - <<'PY'
from pathlib import Path
import re
p = Path.home()/"dotfiles/home/.config/nvim/init.lua"
s = p.read_text(encoding="utf-8")
if "nvim-treesitter/nvim-treesitter" not in s:
    print("SKIP: treesitter spec not found"); raise SystemExit(0)
if re.search(r"branch\s*=\s*['\"]master['\"]", s):
    print("OK: already pinned"); raise SystemExit(0)
pat = r"(['\"])nvim-treesitter/nvim-treesitter\1\s*,"
m = re.search(pat, s)
if not m:
    print("ERR: pattern not found"); raise SystemExit(1)
s2 = re.sub(pat, m.group(0) + "\n      branch = 'master',", s, count=1)
p.write_text(s2, encoding="utf-8")
print("OK: pinned nvim-treesitter to master")
PY
}

nvim_headless_sync() {
  rm -rf "$HOME/.cache/nvim/luac" || true
  log "Neovim headless: Lazy sync..."
  nvim --headless "+Lazy! sync" +qa || require_manual_then_exit "Neovim Lazy sync failed. Run: nvim -V1 -v"
  log "Neovim headless: TSUpdateSync..."
  nvim --headless "+silent! TSUpdateSync" +qa || true
  log "Neovim headless: checkhealth..."
  nvim --headless "+silent! checkhealth" +qa || true
}

ensure_default_shell_zsh() {
  local current_shell
  current_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}' || true)"
  [[ "$current_shell" == "/bin/zsh" ]] && { log "Default shell already /bin/zsh"; return; }
  warn "Setting default shell to /bin/zsh (may prompt password)..."
  chsh -s /bin/zsh || warn "chsh failed; run manually: chsh -s /bin/zsh"
}

summary() {
  echo
  echo "================ Summary ================"
  echo "Dotfiles linked via GNU stow: ~/dotfiles/home -> ~"
  echo "Installed: eza + zsh-syntax-highlighting"
  echo "eza aliases (with classify):"
  echo "  z1='eza --classify'"
  echo "  zz='eza -lah --classify'"
  echo "  z2='eza --tree --level=2 --classify'"
  echo "iCloud cd aliases: icloud / desktop / ayumi / manami / sapix / seg / kono"
  echo "WezTerm layout injected: right aligned, w=2/3, h=1/2, y slightly above center"
  echo "font_size = ${WEZTERM_FONT_SIZE}"
  echo "========================================"
  echo
  echo "If fonts were newly installed, restart WezTerm once."
  echo "Open a NEW terminal tab (or run: exec zsh) to load updated zsh config."
}

main() {
  ensure_macos
  install_xcode_clt_if_needed
  install_homebrew_if_needed
  install_brew_packages

  clone_or_update_dotfiles
  ensure_dotfiles_layout

  # Keep your dotfiles content consistent (managed blocks)
  ensure_zshrc_path_local_bin
  ensure_zshrc_eza_aliases
  ensure_zshrc_icloud_cd_aliases
  ensure_syntax_highlighting_plugin_last

  # Apply dotfiles to ~ via stow (backs up conflicting real files first)
  stow_apply_home

  install_or_update_antidote
  generate_antidote_bundle

  install_meslo_fonts_if_needed
  ensure_wezterm_cli
  patch_wezterm_lua_font_and_layout

  pin_treesitter_master_if_needed
  nvim_headless_sync

  ensure_default_shell_zsh
  summary
}

main "$@"

