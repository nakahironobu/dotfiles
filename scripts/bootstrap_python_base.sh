#!/usr/bin/env bash
set -euo pipefail

########################################
# Python Base Bootstrap (macOS, dotfiles-based)
#
# Goals:
# - Install Python dev toolchain:
#     - uv (core)
#     - direnv (optional but recommended)
#     - ruff / pre-commit / ipython via "uv tool"
# - Set uv-managed "default python3" to 3.14 (Plan: base default = 3.14)
#     - This will make `python3` resolve to ~/.local/bin/python3 (if PATH prefers it)
# - Ensure direnv hook exists in dotfiles .zshrc (managed block)
# - Restow dotfiles home package
#
# NOTE:
# - This script uses /usr/bin/python3 for internal file patching to avoid
#   dependency on uv-managed python while bootstrapping.
########################################

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_HOME_DIR="${DOTFILES_HOME_DIR:-$DOTFILES_DIR/home}"

# Base python version managed by uv (default python3)
UV_BASE_PYVER="${UV_BASE_PYVER:-3.14}"

BREW_FORMULAE=( uv direnv )

log()  { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

ensure_macos() {
  if ! is_macos; then err "This script is for macOS only."; exit 1; fi
  log "macOS detected."
}

ensure_brew_in_path_for_this_shell() {
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
}

require_brew() {
  ensure_brew_in_path_for_this_shell
  if ! need_cmd brew; then
    err "brew not found. Run scripts/bootstrap_mac_full_auto.sh first."
    exit 1
  fi
  log "brew OK: $(command -v brew)"
}

ensure_dotfiles_layout() {
  [[ -d "$DOTFILES_HOME_DIR" ]] || { err "Missing: $DOTFILES_HOME_DIR"; exit 1; }
  [[ -f "$DOTFILES_HOME_DIR/.zshrc" ]] || { err "Missing: $DOTFILES_HOME_DIR/.zshrc"; exit 1; }
  log "dotfiles layout OK."
}

install_brew_packages() {
  log "brew update..."; brew update

  for pkg in "${BREW_FORMULAE[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      log "brew formula already installed: $pkg"
    else
      log "Installing brew formula: $pkg"
      brew install "$pkg"
    fi
  done
}

ensure_zshrc_direnv_hook() {
  local zshrc="$DOTFILES_HOME_DIR/.zshrc"
  log "Ensuring direnv hook block in dotfiles .zshrc"

  /usr/bin/python3 - <<PY
from pathlib import Path
import re

p = Path(r"$zshrc")
s = p.read_text(encoding="utf-8")

block = r'''
# --- direnv hook (managed) ---
if command -v direnv >/dev/null 2>&1; then
  eval "\$(direnv hook zsh)"
fi
'''.strip() + "\n"

pat = re.compile(r"(?ms)^# --- direnv hook \(managed\) ---\n.*?(?=\n\n|\Z)")
if pat.search(s):
    s2 = pat.sub(block, s, count=1)
else:
    s2 = s.rstrip() + "\n\n" + block

p.write_text(s2, encoding="utf-8")
print("OK: direnv hook block ensured")
PY
}

restow_home() {
  if ! need_cmd stow; then
    err "stow not found. Run scripts/bootstrap_mac_full_auto.sh first."
    exit 1
  fi
  log "Applying stow --restow home"
  (cd "$DOTFILES_DIR" && stow -v -t "$HOME" --restow home)
  log "stow done."
}

set_uv_default_python() {
  if ! need_cmd uv; then err "uv not found"; exit 1; fi

  log "Installing uv-managed Python ${UV_BASE_PYVER} and setting as default (python3)"
  # This will place python/python3 shims in ~/.local/bin (PATH should already prefer it)
  if ! uv python install "${UV_BASE_PYVER}" --default; then
    err "Failed to install/set default Python ${UV_BASE_PYVER} via uv."
    warn "Try updating uv:  brew upgrade uv"
    echo
    echo "uv python list:"
    uv python list || true
    exit 1
  fi
  log "uv default python set to ${UV_BASE_PYVER}"
}

install_uv_tools() {
  if ! need_cmd uv; then err "uv not found"; exit 1; fi
  log "Installing dev tools via uv tool (idempotent)"
  uv tool install ruff || true
  uv tool install pre-commit || true
  uv tool install ipython || true
}

verify() {
  echo
  echo "---- Verify ----"
  echo "which python3: $(command -v python3 || true)"
  python3 --version || true
  echo "uv: $(command -v uv || true)"
  uv --version || true
  echo "ruff: $(command -v ruff || true)"
  ruff --version || true
  echo "--------------"
}

summary() {
  echo
  echo "================ Summary ================"
  echo "Installed (brew): ${BREW_FORMULAE[*]}"
  echo "uv default python3: ${UV_BASE_PYVER} (via uv python install --default)"
  echo "Installed (uv tool): ruff / pre-commit / ipython"
  echo "Updated dotfiles .zshrc: direnv hook block (managed)"
  echo "========================================"
  echo
  echo "Next:"
  echo "  exec zsh"
  echo "  which python3 && python3 --version"
  echo "Project setup:"
  echo "  ~/dotfiles/scripts/bootstrap_python_project.sh        # default 3.14"
  echo "  ~/dotfiles/scripts/bootstrap_python_project.sh 3.14   # explicit"
}

main() {
  ensure_macos
  require_brew
  install_brew_packages

  ensure_dotfiles_layout
  ensure_zshrc_direnv_hook
  restow_home

  set_uv_default_python
  install_uv_tools

  verify
  summary
}

main "$@"

