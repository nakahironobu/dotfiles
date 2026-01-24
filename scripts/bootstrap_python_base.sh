#!/usr/bin/env bash
set -euo pipefail

########################################
# Python Base Bootstrap (macOS, dotfiles-based)
#
# Goals:
# - Keep macOS "system python3" untouched (Plan A2)
# - Install Python dev toolchain:
#     - uv (core)
#     - direnv (optional but recommended)
#     - ruff / pre-commit / ipython via "uv tool"
# - Ensure direnv hook exists in dotfiles .zshrc (managed block)
# - Restow dotfiles home package
#
# After this:
# - Use per-project: scripts/bootstrap_python_project.sh
# - Run code via: uv run ...
########################################

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_HOME_DIR="${DOTFILES_HOME_DIR:-$DOTFILES_DIR/home}"

BREW_FORMULAE=( uv direnv )

timestamp() { date +"%Y%m%d_%H%M%S"; }
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
  local marker="# --- direnv hook (managed) ---"

  log "Ensuring direnv hook block in dotfiles .zshrc"
  python3 - <<PY
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

install_uv_tools() {
  if ! need_cmd uv; then err "uv not found"; exit 1; fi

  log "Installing dev tools via uv tool (idempotent)"
  uv tool install ruff || true
  uv tool install pre-commit || true
  uv tool install ipython || true
}

verify_system_python() {
  log "Verifying macOS system python3 (should be /usr/bin/python3 stub -> CLT)"
  local p
  p="$(command -v python3 || true)"
  echo "python3: $p"
  python3 -c "import sys; print('sys.executable:', sys.executable)"
}

summary() {
  echo
  echo "================ Summary ================"
  echo "Installed (brew): ${BREW_FORMULAE[*]}"
  echo "Installed (uv tool): ruff / pre-commit / ipython"
  echo "Updated dotfiles .zshrc: direnv hook block (managed)"
  echo "========================================"
  echo
  echo "Next:"
  echo "  exec zsh"
  echo "  uv --version"
  echo "  ruff --version"
  echo
  echo "Project setup:"
  echo "  ~/dotfiles/scripts/bootstrap_python_project.sh 3.12"
  echo "  (then run via: uv run ...)"
}

main() {
  ensure_macos
  require_brew
  install_brew_packages

  ensure_dotfiles_layout
  ensure_zshrc_direnv_hook
  restow_home

  install_uv_tools
  verify_system_python
  summary
}

main "$@"

