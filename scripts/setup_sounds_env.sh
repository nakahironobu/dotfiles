#!/usr/bin/env bash
set -euo pipefail

########################################
# Sounds Project Setup (uv-based)
#
# Replicates the English audio processing environment
# on a new machine (e.g., macmini-m4).
########################################

log()  { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*"; }

# 1. Install ffmpeg via brew
if ! command -v ffmpeg >/dev/null 2>&1; then
    log "Installing ffmpeg via Homebrew..."
    brew install ffmpeg
else
    log "ffmpeg is already installed."
fi

# 2. Run dotfiles base bootstrap
if [[ -f ~/dotfiles/scripts/bootstrap_python_base.sh ]]; then
    log "Running ~/dotfiles/scripts/bootstrap_python_base.sh..."
    ~/dotfiles/scripts/bootstrap_python_base.sh || warn "Base bootstrap finished with minor issues (stow)."
else
    warn "~/dotfiles/scripts/bootstrap_python_base.sh not found. Ensuring uv..."
    if ! command -v uv >/dev/null 2>&1; then
        brew install uv
    fi
fi

# 3. Target directory initialization
TARGET_DIR="${1:-$HOME/Desktop/Projects/Sounds}"
log "Initializing project in $TARGET_DIR"

if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
fi
cd "$TARGET_DIR"

# 4. Run dotfiles project bootstrap
if [[ -f ~/dotfiles/scripts/bootstrap_python_project.sh ]]; then
    log "Running ~/dotfiles/scripts/bootstrap_python_project.sh 3.12..."
    ~/dotfiles/scripts/bootstrap_python_project.sh 3.12
else
    log "Initializing uv project (manual fallback)..."
    uv init --no-workspace
    uv python pin 3.12
fi

# 5. Add specific dependencies
log "Adding faster-whisper and pydub..."
uv add faster-whisper pydub
uv sync

log "=========================================="
log " Environment Setup Complete"
log " Location: $TARGET_DIR"
log " You can now process audio files."
log "=========================================="
