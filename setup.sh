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
section "Fonts (non-brew)"
# ─────────────────────────────────────────────

FONTS_LIST="$DOTFILES_DIR/fonts.txt"

if [[ -f "$FONTS_LIST" ]]; then
  while IFS='|' read -r font_name font_url; do
    [[ -z "$font_name" || "$font_name" == \#* ]] && continue

    if compgen -G "$HOME/Library/Fonts/*${font_name// /}*" &>/dev/null; then
      success "${font_name} already installed"
      continue
    fi

    log "Installing ${font_name}..."
    manifest="$(curl -fsSL "$font_url" 2>/dev/null | tail -n +2)" || manifest=""
    if [[ -n "$manifest" ]] && printf '%s' "$manifest" | jq -e '.manifest.fileRefs' &>/dev/null; then
      while IFS=$'\t' read -r file_name file_url; do
        curl -fsSL "$file_url" -o "$HOME/Library/Fonts/$file_name" || warn "  could not download ${file_name}"
      done < <(printf '%s' "$manifest" | jq -r '.manifest.fileRefs[] | select(.filename | test("\\.(ttf|otf)$")) | "\(.filename | split("/") | last)\t\(.url)"')
      success "${font_name} installed"
    else
      warn "Could not install ${font_name} (skipping)"
    fi
  done <"$FONTS_LIST"
else
  log "No fonts.txt found, skipping"
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
section "Android SDK components"
# ─────────────────────────────────────────────

# Deliberately NOT installed: frida-tools / objection. They are only useful for
# demonstrating that certificate pinning can be bypassed on a rooted device,
# which is a known property of pinning rather than a test of any fix. Proxy
# interception testing (mitmproxy) plus apktool/jadx cover the real verification.

# The android-commandlinetools cask only ships sdkmanager/avdmanager; SDK
# components are installed into ANDROID_HOME (shared with Android Studio).
#
# Prefer an OLDER cmdline-tools for the package installs. Versions 19+ write SDK
# metadata at repository schema 4, while Android Gradle Plugin 8.7.x (pinned by React
# Native 0.77) bundles an sdklib that reads only up to 3. That mismatch produces a
# noisy warning on every Gradle invocation:
#   This version only understands SDK XML versions up to 3 but an SDK XML file of
#   version 4 was encountered
# It is only a warning — builds still work — but pinning keeps the output readable.
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
CMDLINE_TOOLS_PINNED="16.0"
SDKMANAGER="/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
SDKMANAGER_PINNED="$ANDROID_HOME/cmdline-tools/$CMDLINE_TOOLS_PINNED/bin/sdkmanager"

# Emulator system images must be google_apis (NOT google_apis_playstore) —
# only that variant allows `adb root`, needed to install a proxy CA into the
# system trust store for MITM testing.
#
# Two AVDs on purpose:
#   api35 — matches the app's targetSdk; functional/regression testing.
#   api33 — Android 13 is the last release with the system CA store at
#           /system/etc/security/cacerts. Android 14+ moved it into the
#           Conscrypt APEX, which breaks the standard CA-injection technique.
#           Use this one for proxy interception / cert pinning tests.
IMAGE_API35="system-images;android-35;google_apis;arm64-v8a"
IMAGE_API33="system-images;android-33;google_apis;arm64-v8a"
AVDS=(
  "pixel6_api35:${IMAGE_API35}:pixel_6"
  "pixel6_api33_mitm:${IMAGE_API33}:pixel_6"
)
SDK_PACKAGES=(
  "platform-tools"
  "emulator"
  "platforms;android-35"
  "build-tools;35.0.0"
  "$IMAGE_API35"
  "$IMAGE_API33"
)

if [[ -x "$SDKMANAGER" ]]; then
  if [[ -z "${JAVA_HOME:-}" ]] && [[ -d /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home ]]; then
    export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
  fi

  if ! command -v java &>/dev/null && [[ -z "${JAVA_HOME:-}" ]]; then
    warn "No JDK found — install temurin@17 first, skipping Android SDK"
  else
    mkdir -p "$ANDROID_HOME"

    # Errors are captured to a log and printed on failure rather than discarded.
    # A bootstrap step that reports "could not install X" without saying why just
    # moves the debugging cost onto whoever runs it next.
    sdk_log="$(mktemp)"
    run_sdk() { # run_sdk <description> <command...>
      local desc="$1"
      shift
      if "$@" >"$sdk_log" 2>&1; then
        success "$desc"
      else
        warn "$desc failed:"
        sed 's/^/      /' "$sdk_log" | tail -12
        return 1
      fi
    }

    log "Accepting SDK licenses..."
    yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true

    # Install the pinned cmdline-tools first, then use it for everything else so
    # package metadata stays readable by AGP 8.7.x (see note above).
    if [[ ! -x "$SDKMANAGER_PINNED" ]]; then
      log "Installing cmdline-tools;$CMDLINE_TOOLS_PINNED (AGP-compatible)..."
      run_sdk "cmdline-tools;$CMDLINE_TOOLS_PINNED installed" \
        "$SDKMANAGER" --sdk_root="$ANDROID_HOME" "cmdline-tools;$CMDLINE_TOOLS_PINNED" || true
    else
      success "cmdline-tools;$CMDLINE_TOOLS_PINNED already installed"
    fi

    installer="$SDKMANAGER"
    [[ -x "$SDKMANAGER_PINNED" ]] && installer="$SDKMANAGER_PINNED"

    log "Installing SDK packages..."
    run_sdk "SDK packages installed" \
      "$installer" --sdk_root="$ANDROID_HOME" "${SDK_PACKAGES[@]}" || true

    # avdmanager lives beside whichever sdkmanager we used. Note it accepts NO
    # --sdk-root flag (unlike sdkmanager) — it locates the SDK via ANDROID_HOME,
    # so that must be exported rather than passed.
    #
    # ANDROID_AVD_HOME must also be pinned: newer avdmanager honours XDG_CONFIG_HOME
    # and would write to ~/.config/.android/avd, but the emulator only searches
    # $ANDROID_AVD_HOME, $ANDROID_SDK_HOME/avd and ~/.android/avd. Without this the
    # AVD is created successfully and then fails to launch with "Unknown AVD name".
    AVDMANAGER="$(dirname "$installer")/avdmanager"
    export ANDROID_HOME
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export ANDROID_AVD_HOME="$HOME/.android/avd"
    mkdir -p "$ANDROID_AVD_HOME"

    for spec in "${AVDS[@]}"; do
      IFS=':' read -r avd_name avd_image avd_device <<<"$spec"
      if "$AVDMANAGER" list avd 2>/dev/null | grep -q "Name: ${avd_name}"; then
        success "AVD ${avd_name} already exists"
      else
        log "Creating AVD ${avd_name}..."
        # `echo no` declines the "custom hardware profile?" prompt.
        if echo no | "$AVDMANAGER" --silent create avd \
          --name "$avd_name" --package "$avd_image" --device "$avd_device" \
          >"$sdk_log" 2>&1; then
          success "AVD ${avd_name} created (rootable — adb root works)"
        else
          warn "Could not create AVD ${avd_name}:"
          sed 's/^/      /' "$sdk_log" | tail -12
        fi
      fi
    done

    rm -f "$sdk_log"
  fi
else
  warn "sdkmanager not found — install the android-commandlinetools cask first"
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
