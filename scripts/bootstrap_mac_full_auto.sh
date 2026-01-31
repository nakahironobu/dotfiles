#!/usr/bin/env bash
set -euo pipefail

########################################
# macOS Full Bootstrap (AUTO, dotfiles-based, STOW)
#
# Includes:
# - Xcode CLT (prompts GUI install if missing; exits -> re-run)
# - Homebrew + packages (git fzf neovim ripgrep fd eza stow)
# - WezTerm (cask + CLI path + font fallback + window layout injection + font_size)
# - zsh (Antidote + p10k already in your dotfiles) + plugins + aliases
#     - eza aliases with --classify (managed block appended/updated in dotfiles .zshrc)
#     - zsh-syntax-highlighting (ensure last in .zsh_plugins.txt)
#     - iCloud cd aliases (managed block appended)
# - Dotfiles linking via GNU stow:
#     stow -t ~ home   (home/ is your package directory)
# - Neovim (headless Lazy sync + TSUpdateSync + checkhealth, pin treesitter to master)
#
# NOTE:
# - Python is intentionally NOT installed here (Plan A2).
#   Use scripts/bootstrap_python_base.sh for Python dev toolchain.
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

# Plan A2: DO NOT install python here
BREW_FORMULAE=( git fzf neovim ripgrep fd eza stow )
BREW_CASKS=( wezterm )

MESLO_FONT_BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"

# WezTerm layout knobs (override if desired)
WEZTERM_FONT_SIZE="${WEZTERM_FONT_SIZE:-16.0}"
WEZTERM_Y_OFFSET_RATIO="${WEZTERM_Y_OFFSET_RATIO:-0.08}"  # slightly above center
WEZTERM_WIDTH_RATIO="${WEZTERM_WIDTH_RATIO:-0.4}"   # 2/5
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
    if brew list --cask "$cask" >/dev/null 2>&1; then
      log "brew cask already installed: $cask"
    else
      log "Installing brew cask: $cask"
      brew install --cask "$cask"
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
alias ls='eza --classify'
alias ll='eza -lh --classify'
alias la='eza -lah --classify'
alias zl='eza -lh --classify'
alias za='eza -lah --classify'
alias zz='eza --tree --level=2 --classify'
alias zzz='eza --tree --level=3 --classify'
alias zzzz='eza --tree --level=4 --classify'
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
alias ls='eza --classify'
alias ll='eza -lh --classify'
alias la='eza -lah --classify'
alias zl='eza -lh --classify'
alias za='eza -lah --classify'
alias zz='eza --tree --level=2 --classify'
alias zzz='eza --tree --level=3 --classify'
alias zzzz='eza --tree --level=4 --classify'
EOF
}

ensure_zshrc_icloud_cd_aliases() {
  local zshrc="$DOTFILES_HOME_DIR/.zshrc"
  local marker="# --- iCloud cd aliases (managed) ---"
  
  if grep -qF "$marker" "$zshrc"; then
    log "Updating iCloud cd alias block in dotfiles .zshrc (managed)"
    python3 - <<PY
from pathlib import Path
import re
p = Path(r"$zshrc")
s = p.read_text(encoding="utf-8")
block = r'''
# --- iCloud cd aliases (managed) ---
alias icloud='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs'
alias desktop='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop'
alias projects='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Projects'
alias ayumi='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi'
alias manami='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Manami'
alias sapix='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Manami/Manami-Sapix'
alias seg='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi/SEG'
alias kono='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Ayumi/KonoJuku'
'''.strip() + "\n"
pat = re.compile(r"(?ms)^# --- iCloud cd aliases \(managed\) ---\n.*?(?=\n\n|\Z)")
s2, n = pat.subn(block, s, count=1)
if n == 0:
    s2 = s + "\n\n" + block
p.write_text(s2, encoding="utf-8")
print("OK: iCloud alias block updated")
PY
    return
  fi

  log "Adding iCloud cd aliases to dotfiles .zshrc"
  cat >> "$zshrc" <<'EOF'

# --- iCloud cd aliases (managed) ---
alias icloud='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs'
alias desktop='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop'
alias projects='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Desktop/Projects'
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
  # Pre-create deeply nested directories to ensure stow symlinks only files
  mkdir -p "$HOME/Library/Application Support/Antigravity/User"
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
""".strip() + "\\n"

# Ensure wezterm is required at the top
if 'local wezterm = require("wezterm")' not in s and "local wezterm = require('wezterm')" not in s:
    s = 'local wezterm = require("wezterm")\\n\\n' + s

# 1) Remove any existing managed block (we will re-insert exactly one)
block_re = re.compile(r"""-- BEGIN OAI MANAGED: WEZTERM LAYOUT.*?-- END OAI MANAGED: WEZTERM LAYOUT\\s*\\n?""", re.S)
s = block_re.sub("", s)

# 2) Remove ANY gui-startup handler (prevents multiple windows spawning)
#    Use triple-quoted raw regex to avoid quote escaping issues entirely.
startup_re = re.compile(r'''wezterm\.on\(\s*['"]gui-startup['"]\s*,\s*function\(cmd\).*?\nend\)\s*\n?''', re.S)
s = startup_re.sub("", s)

# 3) Insert managed block right after local wezterm = require("wezterm")
m = re.search(r"""local wezterm\s*=\s*require\(["']wezterm["']\)\s*\n+""", s)
if m:
    s = s[:m.end()] + managed + s[m.end():]
else:
    s = managed + s

# Font fallback patch
fallback_block = f'''font = wezterm.font_with_fallback({{
    "{primary}",
    "MesloLGS Nerd Font Mono",
    "MesloLGS Nerd Font",
    "MesloLGS NF",
    "Menlo",
  }}),'''

if re.search(r"font\s*=\s*wezterm\.font_with_fallback\(", s):
    s = re.sub(
        r"font\s*=\s*wezterm\.font_with_fallback\(\{.*?\}\)\s*,",
        fallback_block,
        s,
        flags=re.S
    )
else:
    s = re.sub(r"font\s*=\s*wezterm\.font\([^\)]*\)\s*,", fallback_block, s)

# Ensure font_size = FONT_SIZE
if re.search(r"font_size\s*=", s):
    s = re.sub(r"font_size\s*=\s*[^,\n]+\s*,", "font_size = FONT_SIZE,", s)
else:
    s = re.sub(
        r"(font\s*=\s*wezterm\.font_with_fallback\(\{.*?\}\)\s*,)",
        r"\\1\\n  font_size = FONT_SIZE,",
        s,
        flags=re.S
    )

p.write_text(s, encoding="utf-8")
print("OK: wezterm.lua patched (managed layout + font; gui-startup deduped)")
PY
}

pin_treesitter_master_if_needed() {
  local init_lua="$DOTFILES_HOME_DIR/.config/nvim/init.lua"
  [[ -f "$init_lua" ]] || return 0

  if grep -q "branch = 'master'" "$init_lua" || grep -q 'branch = "master"' "$init_lua"; then
    log "Treesitter already pinned to master in init.lua"
    return 0
  fi

  warn "Patching init.lua to pin nvim-treesitter to master..."
  python3 - <<PY
from pathlib import Path
import re
p = Path(r"$init_lua")
s = p.read_text(encoding="utf-8")
pat = re.compile(r"(['\"]nvim-treesitter/nvim-treesitter['\"])\s*,")
s2 = pat.sub(r"\1,\n    branch = 'master',", s)
p.write_text(s2, encoding="utf-8")
PY
}

nvim_headless_sync() {
  rm -rf "$HOME/.cache/nvim/luac" || true
  log "Neovim headless: Lazy sync..."
  nvim --headless "+Lazy! sync" +qa || require_manual_then_exit "Neovim Lazy sync failed. Run: nvim -V1 -v"
  log "Neovim headless: TSUpdateSync..."
  nvim --headless "+silent! TSUpdateSync" +qa || true
  nvim --headless "+silent! checkhealth" +qa || true
}

ensure_antigravity_settings() {
  local ag_settings="$HOME/Library/Application Support/Antigravity/User/settings.json"
  if [[ ! -d "$(dirname "$ag_settings")" ]]; then
     # App might not be installed or run yet, but we can set up the dir
     mkdir -p "$(dirname "$ag_settings")"
  fi
  
  log "Updating Antigravity settings.json (managed font/zoom)..."
  python3 - <<PY
import json
import platform
import os

target = "$ag_settings"
hostname = platform.node()

# Per-host sizing configuration
# Format: "Hostname": (FontSize, ZoomLevel)
host_configs = {
    "HironobunoMac-mini.local": (14, 0.5),
    # Examples for other machines:
    # "MacBookPro.local": (12, 0),
}

# Defaults
default_size = 14
default_zoom = 0.5
constant_font_family = "MesloLGS NF"

# Resolve settings
size, zoom = host_configs.get(hostname, (default_size, default_zoom))

# Desired settings (managed)
managed = {
    "terminal.integrated.fontFamily": constant_font_family,
    "editor.fontSize": size,
    "terminal.integrated.fontSize": size,
    "window.zoomLevel": zoom,
    "vim.useCtrlKeys": True,
    "vim.useSystemClipboard": True,
    "vim.hlsearch": True
}

current = {}
if os.path.exists(target):
    try:
        with open(target, "r", encoding="utf-8") as f:
            current = json.load(f)
    except Exception:
        pass

# Merge/Override
current.update(managed)

with open(target, "w", encoding="utf-8") as f:
    json.dump(current, f, indent=4)

print(f"OK: Antigravity settings updated (Host: {hostname}, Size: {size}, Zoom: {zoom})")
PY
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
  echo "eza aliases (ls/ll/la/za/zl, zz/zzz...)"
  echo "iCloud cd aliases: icloud / desktop / ayumi / manami / sapix / seg / kono"
  echo "WezTerm layout injected: right aligned, w=2/3, h=1/2, y slightly above center"
  echo "font_size = ${WEZTERM_FONT_SIZE}"
  echo "========================================"
  echo
  echo "If fonts were newly installed, restart WezTerm once."
  echo "Open a NEW terminal tab (or run: exec zsh) to load updated zsh config."
  echo
  echo "Python:"
  echo "  This script does NOT install Python (Plan A2)."
  echo "  Run: ./scripts/bootstrap_python_base.sh"
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

  ensure_antigravity_settings

  ensure_default_shell_zsh
  summary
}

main "$@"

