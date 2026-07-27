# Font installation in setup.sh

## Problem

Some fonts are Homebrew casks (already handled by `brew bundle --file=Brewfile`,
e.g. `font-fira-code-nerd-font`). Others (Carlito, Inter, Lato) have no brew
cask and must be downloaded from Google Fonts. Need an easy-to-edit list of
non-brew fonts + URLs, without digging through setup.sh logic.

## Design

### Font list: `fonts.txt` (repo root)

Plain text, one font per line: `Name|URL`

```
# Non-brew fonts, fetched from Google Fonts.
# Format: Name|download-url
Carlito|https://fonts.google.com/download?family=Carlito
Inter|https://fonts.google.com/download?family=Inter
Lato|https://fonts.google.com/download?family=Lato
```

Lines starting with `#` and blank lines are skipped. Adding a font = adding
one line, no bash editing.

### setup.sh: new "Fonts" section

Placed after the Homebrew section (brew-cask fonts are already installed by
`brew bundle` at that point).

Steps per line in `fonts.txt`:

1. Parse `name` and `url` (split on `|`).
2. Idempotency check: skip if `~/Library/Fonts/*${name}*` already matches a
   file.
3. Otherwise: download the zip to a temp dir (`mktemp -d`), unzip it, copy
   all `*.ttf`/`*.otf` files into `~/Library/Fonts/`, remove the temp dir.
4. Log success (`success "Name installed"`) or failure (`warn "Name failed
   to download/install (skipping)"`) per font. A single font failure does
   not abort the rest of setup.sh (matches existing pattern, e.g. SSH key
   fetch, 1Password steps).

### Out of scope

- Brew-cask fonts (`font-fira-code-nerd-font`, etc.) — already handled via
  Brewfile, untouched by this change.
- Font activation/verification beyond copying files into `~/Library/Fonts`.
