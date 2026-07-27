# Font installation in setup.sh

## Problem

Some fonts are Homebrew casks (already handled by `brew bundle --file=Brewfile`,
e.g. `font-fira-code-nerd-font`). Others (Carlito, Inter, Lato) have no brew
cask and must be downloaded from Google Fonts. Need an easy-to-edit list of
non-brew fonts + URLs, without digging through setup.sh logic.

## Design

### Font list: `fonts.txt` (repo root)

Plain text, one font per line: `Name|manifest-url`

```
# Non-brew fonts, fetched from Google Fonts.
# Format: Name|manifest-url (fonts.google.com/download/list?family=<Name>)
Carlito|https://fonts.google.com/download/list?family=Carlito
Inter|https://fonts.google.com/download/list?family=Inter
Lato|https://fonts.google.com/download/list?family=Lato
Libertinus Serif|https://fonts.google.com/download/list?family=Libertinus+Serif
Libertinus Math|https://fonts.google.com/download/list?family=Libertinus+Math
```

Multi-word family names: use `+` for spaces in the URL query param (Google
Fonts rejects a literal space; `curl: (3) URL rejected`). The `Name` field
itself keeps its real space (`Libertinus Serif`) — only the URL is encoded.

Lines starting with `#` and blank lines are skipped. Adding a font = adding
one line, no bash editing.

Note: `fonts.google.com/download?family=X` (the browser "Download family"
button URL) no longer serves a real zip — it now returns the SPA's HTML
shell. `fonts.google.com/download/list?family=X` is the JSON manifest
endpoint the Google Fonts web app itself calls to build that zip; it
returns a `)]}'`-prefixed JSON body (anti-JS-hijacking prefix, stripped
with `tail -n +2`) containing a `manifest.fileRefs` array of
`{filename, url}` pairs pointing at individual font files on
`fonts.gstatic.com`. No zip/unzip needed — each file is fetched directly.

### setup.sh: new "Fonts" section

Placed after the Homebrew section (brew-cask fonts are already installed by
`brew bundle` at that point). Requires `jq` (already a Brewfile dependency,
installed earlier in the same run).

Steps per line in `fonts.txt`:

1. Parse `name` and `url` (split on `|`).
2. Idempotency check: skip if `~/Library/Fonts/*${name// /}*` already
   matches a file — spaces are stripped from `name` before globbing,
   because Google Fonts' actual filenames drop spaces from multi-word
   family names (e.g. family "Libertinus Serif" → file
   `LibertinusSerif-Regular.ttf`, no space). A glob against the raw
   `name` (with its space) would never match and the font would be
   re-downloaded on every run.
3. Otherwise: `curl` the manifest URL, strip the `)]}'` prefix line, and
   validate it's parseable JSON with a `manifest.fileRefs` array (via
   `jq -e`). Note: pass the manifest to `jq` with `printf '%s'`, not
   `echo` — the manifest contains literal backslash-escaped sequences
   (e.g. `\r\n` inside the bundled `OFL.txt`/`README.txt` contents) that
   `echo` can reinterpret and corrupt, breaking JSON parsing.
4. For each `fileRefs` entry whose `filename` ends in `.ttf`/`.otf`,
   `curl` its `url` directly into `~/Library/Fonts/<basename of filename>`.
5. Log success (`success "Name installed"`) or failure (`warn "Name failed
   to download/install (skipping)"`) per font, and `warn` per-file if an
   individual font-file download fails. A single font (or file) failure
   does not abort the rest of setup.sh (matches existing pattern, e.g. SSH
   key fetch, 1Password steps).

### Out of scope

- Brew-cask fonts (`font-fira-code-nerd-font`, etc.) — already handled via
  Brewfile, untouched by this change.
- Font activation/verification beyond copying files into `~/Library/Fonts`.
