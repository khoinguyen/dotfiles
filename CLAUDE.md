# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

macOS dotfiles managed with **tuckr** for symlinking and **Homebrew** for packages. No build step. No tests.

## Bootstrap a new machine

```bash
./setup.sh
```

Does in order: installs Homebrew → runs `brew bundle --file=Brewfile` → applies macOS defaults → enables Touch ID for sudo → runs `tuckr add \* --force` to symlink all configs.

## Dotfile management (tuckr)

Tuckr maps `Configs/<Name>/` → `~/`. Each `Configs/<Name>/` subtree mirrors the home directory structure. For example:

- `Configs/zsh/.zshrc` → `~/.zshrc`
- `Configs/nvim/.config/nvim/` → `~/.config/nvim/`
- `Configs/tmux/.config/tmux/dot-tmux.conf` → `~/.config/tmux/.tmux.conf` (note: tuckr strips `dot-` prefix → `.tmux.conf`)

To re-link after changes:
```bash
tuckr add \* --force
```

## Key config locations

| Config | Path in repo |
|--------|-------------|
| zsh rc | `Configs/zsh/.zshrc` |
| zsh aliases | `Configs/zsh/.zalias` |
| zsh plugins | `Configs/zsh/.zsh_plugins.txt` (antidote) |
| zsh extras | `Configs/zsh/.zshrc.d/*.sh` (auto-sourced) |
| neovim | `Configs/nvim/.config/nvim/` (LazyVim) |
| tmux | `Configs/tmux/.config/tmux/dot-tmux.conf` |
| tmux sessions | `Configs/tmux/.config/tmux-layouts/*.session.sh` |
| starship | `Configs/starship/.config/starship.toml` |
| mise | `Configs/mise/.config/mise/config.toml` |
| packages | `Brewfile` |

## Architecture notes

**Shell**: zsh with antidote for plugin management. Plugins declared in `.zsh_plugins.txt`; antidote compiles to `.zsh_plugins.zsh` (static bundle, regenerated when txt is newer). Extra configs in `.zshrc.d/` are sourced automatically — add new tool configs there.

**Neovim**: LazyVim distro. Entry point is `init.lua` → `config/lazy`. Custom plugins in `lua/plugins/`. Plugin list locked in `lazy-lock.json`.

**Tmux**: TPM-managed. Catppuccin theme. vim-tmux-navigator for pane navigation (shared with neovim). Session layouts in `tmux-layouts/` are shell scripts to recreate named tmux sessions.

**Runtime versions**: mise manages `gh` and `node` globally (`Configs/mise/.config/mise/config.toml`).

**`run.sh`**: Legacy stow-based script — superseded by `tuckr` in `setup.sh`. Do not use.
