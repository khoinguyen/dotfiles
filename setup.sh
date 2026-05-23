#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  setup.sh — macOS machine bootstrap
#  Usage: ./setup.sh
# ─────────────────────────────────────────────

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "  ▸ $*"; }
success() { echo "  ✔ $*"; }
section() {
  echo
  echo "── $* ──────────────────────────────────────"
}

# ─────────────────────────────────────────────
section "Homebrew"
# ─────────────────────────────────────────────

if ! command -v brew &>/dev/null; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  success "Homebrew installed"
else
  success "Homebrew already installed"
fi

if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
  log "Installing from Brewfile..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  success "Brewfile packages installed"
else
  log "No Brewfile found, skipping"
fi

# ─────────────────────────────────────────────
section "macOS defaults"
# ─────────────────────────────────────────────

log "Disabling press-and-hold (enable key repeat)..."
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

log "Setting scrollbar click to jump to position..."
defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true

success "macOS defaults applied (logout may be required)"

# ─────────────────────────────────────────────
section "Touch ID for sudo"
# ─────────────────────────────────────────────

SUDO_LOCAL="/etc/pam.d/sudo_local"
PAM_LINE="auth       sufficient     pam_tid.so"

if [[ -f "$SUDO_LOCAL" ]] && grep -q "pam_tid.so" "$SUDO_LOCAL"; then
  success "Touch ID for sudo already configured"
else
  log "Enabling Touch ID for sudo..."
  echo "$PAM_LINE" | sudo tee "$SUDO_LOCAL" >/dev/null
  success "Touch ID for sudo enabled"
fi

# ─────────────────────────────────────────────
section "Remote Login (sshd)"
# ─────────────────────────────────────────────

if sudo launchctl print system/com.openssh.sshd 2>/dev/null | grep -q "state = running"; then
  success "sshd already running"
else
  log "Enabling Remote Login (sshd)..."
  sudo launchctl enable system/com.openssh.sshd
  sudo launchctl start com.openssh.sshd
  success "sshd enabled"
fi

# ─────────────────────────────────────────────
section "Dotfiles (tuckr)"
# ─────────────────────────────────────────────

if command -v tuckr &>/dev/null; then
  log "Symlinking dotfiles with tuckr..."
  tuckr add \* --force
  success "Dotfiles linked"
else
  log "tuckr not found — install it first or add to Brewfile"
  log "  cargo install tuckr  OR  brew install tuckr"
fi

# ─────────────────────────────────────────────
echo
echo "✔ Setup complete. Restart your shell (or logout) for all changes to take effect."
