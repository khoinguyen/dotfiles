#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  setup.sh — macOS machine bootstrap
#  Usage: ./setup.sh
# ─────────────────────────────────────────────

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "  ▸ $*"; }
success() { echo "  ✔ $*"; }
warn() { echo "  $(tput setaf 1)✖ $*$(tput sgr0)"; }
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

log "Setting key repeat rate (fast)..."
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

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
section "SSH authorized_keys"
# ─────────────────────────────────────────────

mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

log "Fetching public keys from sshid.io..."
if keys=$(curl -fs https://sshid.io/khoinguyen); then
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    grep -qF "$key" ~/.ssh/authorized_keys || echo "$key" >>~/.ssh/authorized_keys
  done <<<"$keys"
  success "SSH keys updated"
else
  warn "Could not fetch keys from sshid.io (skipping)"
fi

# ─────────────────────────────────────────────
section "Remote Login (sshd)"
# ─────────────────────────────────────────────

if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
  success "sshd already enabled"
else
  log "Enabling Remote Login (sshd)..."
  sudo systemsetup -setremotelogin on
  success "sshd enabled"
fi

# ─────────────────────────────────────────────
section "Dotfiles (tuckr)"
# ─────────────────────────────────────────────

if command -v tuckr &>/dev/null; then
  # tuckr expects dotfiles at ~/.dotfiles; create a symlink if the repo lives elsewhere.
  if [[ ! -e "$HOME/.dotfiles" ]]; then
    ln -s "$DOTFILES_DIR" "$HOME/.dotfiles"
    log "Linked ~/.dotfiles -> $DOTFILES_DIR"
  fi
  log "Symlinking dotfiles with tuckr..."
  tuckr add \* --force --assume-yes --only-files
  success "Dotfiles linked"
else
  log "tuckr not found — install it first or add to Brewfile"
  log "  cargo install tuckr  OR  brew install tuckr"
fi

# ─────────────────────────────────────────────
section "mise (runtime versions)"
# ─────────────────────────────────────────────

if command -v mise &>/dev/null; then
  log "Installing mise-managed runtimes..."
  mise install
  success "mise runtimes installed"
else
  warn "mise not found — skipping runtime installs"
fi

# ─────────────────────────────────────────────
section "LaunchAgents"
# ─────────────────────────────────────────────

LAUNCH_AGENTS=(
  #com.khoi.gemini-allow
  com.khoi.brew-upgrade-remind
)

for agent in "${LAUNCH_AGENTS[@]}"; do
  plist="$HOME/Library/LaunchAgents/${agent}.plist"
  if launchctl print "gui/$(id -u)/${agent}" &>/dev/null 2>&1; then
    success "${agent} already loaded"
  elif [[ -f "$plist" ]]; then
    log "Loading ${agent}..."
    launchctl bootstrap "gui/$(id -u)" "$plist"
    success "${agent} loaded"
  else
    warn "${agent}.plist not found (skipping)"
  fi
done

# ─────────────────────────────────────────────
echo
echo "┌─────────────────────────────────────────────┐"
echo "│           Action required: 1Password         │"
echo "├─────────────────────────────────────────────┤"
echo "│                                             │"
echo "│  1. Open 1Password and sign in              │"
echo "│  2. Settings → Developer → Enable CLI       │"
echo "│  3. Settings → Developer → SSH Agent →      │"
echo "│       enable + Use key names                │"
echo "│  4. Run: op account add  (if not signed in) │"
echo "│  5. Run: eval \$(op signin)                  │"
echo "│                                             │"
echo "│       Then come back here and press         │"
echo "│              SPACE to continue              │"
echo "│                                             │"
echo "└─────────────────────────────────────────────┘"
echo
read -r -s -d ' ' -p "" _
echo

# ─────────────────────────────────────────────
section "SSH keys, host config + git config (1Password)"
# ─────────────────────────────────────────────

# Sensitive configs are not committed (public repo). They live as 1Password
# documents and are fetched here. 1Password is the source of truth —
# local edits are overwritten on re-run.
if command -v op &>/dev/null && op account list &>/dev/null 2>&1; then
  mkdir -p ~/.ssh/config.d && chmod 700 ~/.ssh/config.d

  log "Fetching SSH public keys from 1Password..."
  for pair in "khoi-ed25519:khoi-ed25519.pub" "id_khoinguyen:id_khoinguyen@github.pub"; do
    item="${pair%%:*}"
    pubkey_file=~/.ssh/"${pair##*:}"
    if pubkey=$(op item get "$item" --account my.1password.com --fields label="public key" 2>/dev/null); then
      echo "$pubkey" >"$pubkey_file"
      chmod 644 "$pubkey_file"
      success "${pair##*:}"
    else
      warn "Could not fetch public key for $item (skipping)"
    fi
  done

  log "Fetching SSH host configs from 1Password..."
  for doc in ssh-config-personal ssh-config-ampup; do
    out=~/.ssh/config.d/"${doc#ssh-config-}".conf
    if op document get "$doc" --account my.1password.com --out-file "$out" --force &>/dev/null; then
      success "${doc#ssh-config-}.conf"
    else
      warn "Could not fetch $doc (skipping)"
    fi
  done

  # Ensure the base config includes config.d (idempotent).
  if [[ ! -f ~/.ssh/config ]] || ! grep -qF 'Include ~/.ssh/config.d/*.conf' ~/.ssh/config; then
    echo 'Include ~/.ssh/config.d/*.conf' >>~/.ssh/config
    chmod 600 ~/.ssh/config
  fi

  log "Fetching git configs from 1Password..."
  for doc in gitconfig gitconfig-ampup; do
    out=~/".$doc"
    if op document get "$doc" --account my.1password.com --out-file "$out" --force &>/dev/null; then
      success "$out"
    else
      warn "Could not fetch $doc (skipping)"
    fi
  done

  log "Fetching AWS config from 1Password..."
  mkdir -p ~/.aws && chmod 700 ~/.aws
  if op document get "aws-config" --account my.1password.com --out-file ~/.aws/config --force &>/dev/null; then
    chmod 600 ~/.aws/config
    success "~/.aws/config"
  else
    warn "Could not fetch aws-config (skipping)"
  fi
else
  warn "1Password CLI not available/signed in — skipping SSH keys, host config and git config"
fi

# ─────────────────────────────────────────────
echo
echo "✔ Setup complete. Restart your shell (or logout) for all changes to take effect."
