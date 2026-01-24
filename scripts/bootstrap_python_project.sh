#!/usr/bin/env bash
set -euo pipefail

########################################
# Python Project Bootstrap (uv-based)
#
# Default: Python 3.14 (per your plan)
#
# Creates:
# - .venv (uv venv)
# - .python-version (uv python pin) to lock project interpreter
# - pyproject.toml (if missing; minimal)
# - uv sync (uses/creates lock as needed)
# - .envrc for direnv (optional)
#
# Usage:
#   ~/dotfiles/scripts/bootstrap_python_project.sh        # => 3.14
#   ~/dotfiles/scripts/bootstrap_python_project.sh 3.14
########################################

PYVER="${1:-3.14}"

log()  { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

require_tools() {
  need_cmd uv || { err "uv not found. Run ~/dotfiles/scripts/bootstrap_python_base.sh first."; exit 1; }
}

ensure_pyproject() {
  if [[ -f pyproject.toml ]]; then
    log "pyproject.toml exists."
    return
  fi

  warn "pyproject.toml not found. Creating minimal pyproject.toml"
  cat > pyproject.toml <<TOML
[project]
name = "$(basename "$PWD")"
version = "0.1.0"
requires-python = ">=${PYVER}"
dependencies = []
TOML
  log "Created pyproject.toml"
}

pin_python() {
  log "Pinning project Python to ${PYVER} (creates/updates .python-version)"
  uv python install "${PYVER}" >/dev/null 2>&1 || true
  uv python pin "${PYVER}"
}

create_venv() {
  log "Recreating .venv with Python ${PYVER}"
  rm -rf .venv
  uv venv --python "${PYVER}"
  log ".venv ready."
}

sync_deps() {
  log "uv sync"
  uv sync
  log "uv sync OK."
}

setup_direnv() {
  if ! need_cmd direnv; then
    warn "direnv not installed; skipping .envrc"
    return
  fi

  if [[ -f .envrc ]]; then
    log ".envrc exists; skipping."
  else
    log "Creating .envrc (auto-activate .venv)"
    cat > .envrc <<'EOF'
# auto-generated
if [[ -d .venv ]]; then
  source .venv/bin/activate
fi
EOF
  fi

  log "direnv allow"
  direnv allow || warn "direnv allow failed; run manually: direnv allow"
}

maybe_install_precommit() {
  if [[ -f .pre-commit-config.yaml ]]; then
    log "Installing git hooks (pre-commit)"
    uv tool run pre-commit install || warn "pre-commit install failed (try: uv tool run pre-commit install)"
  fi
}

verify() {
  echo
  echo "---- Verify (project) ----"
  uv run python --version
  uv run python -c "import sys; print(sys.executable)"
  echo "--------------------------"
}

summary() {
  echo
  echo "================ Summary ================"
  echo "Project: $(basename "$PWD")"
  echo "Python pinned: ${PYVER}  (see .python-version)"
  echo "Venv: .venv (recreated)"
  echo "Next:"
  echo "  uv run python -V"
  echo "  uv run ruff check ."
  echo "========================================"
}

main() {
  require_tools
  ensure_pyproject
  pin_python
  create_venv
  sync_deps
  setup_direnv
  maybe_install_precommit
  verify
  summary
}

main "$@"

