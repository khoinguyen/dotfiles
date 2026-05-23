# dotfiles

macOS dotfiles managed with [tuckr](https://github.com/RaphGL/Tuckr) for
symlinking and [Homebrew](https://brew.sh) for packages.

## Bootstrap a new machine

```bash
git clone <this-repo> ~/.dotfiles
cd ~/.dotfiles
./setup.sh
```

`setup.sh` is idempotent — safe to re-run any time. It does, in order:

1. **Homebrew** — installs it if missing, then `brew bundle` from the `Brewfile`
2. **macOS defaults** — key repeat, scrollbar paging
3. **Touch ID for sudo** — adds `pam_tid.so` to `/etc/pam.d/sudo_local`
4. **SSH authorized_keys** — pulls public keys from `https://sshid.io/khoinguyen`
   (dedupes; skips with a warning if offline)
5. **Remote Login (sshd)** — enables it via `systemsetup -setremotelogin on`
6. **Dotfiles** — `tuckr add \* --force` to symlink everything

## Dotfile management (tuckr)

Tuckr maps `Configs/<Name>/` → `~/`. Each subtree mirrors the home directory:

| Repo path | Linked to |
|-----------|-----------|
| `Configs/zsh/.zshrc` | `~/.zshrc` |
| `Configs/nvim/.config/nvim/` | `~/.config/nvim/` |
| `Configs/tmux/.config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |

Re-link after changes:

```bash
tuckr add \* --force
```

## Packages

All packages live in the [`Brewfile`](Brewfile), grouped into sections
(Taps, Shell & Terminal, Editors, CLI Utilities, Kubernetes & Cloud, Fonts,
Apps, Mac App Store). App Store apps are managed via `mas`.

Sync packages (install missing, remove anything not in the Brewfile):

```bash
brew bundle --cleanup
```

## Remote access (Tailscale)

Both Mac and phone are on the same [Tailscale](https://tailscale.com) network,
so SSH works from anywhere using the MagicDNS hostname:

```bash
ssh khoinguyen@khoi-mbp
```

The Mac's Tailscale IP/hostname is stable per device. `setup.sh` enables sshd
and trusts your keys, so a freshly bootstrapped machine is reachable
immediately after setup.

## Scripts

`scripts/` is a standalone [uv](https://docs.astral.sh/uv/)-managed Python
project (Python ≥ 3.11) for macOS Photos utilities. Run from inside that
directory with `uv run`. See its own files for usage.
