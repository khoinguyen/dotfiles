# Font Installation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Fonts" section to `setup.sh` that downloads and installs non-brew Google Fonts (Carlito, Inter, Lato, Libertinus Serif, Libertinus Math) into `~/Library/Fonts`, driven by an easy-to-edit `fonts.txt` list.

**Architecture:** A new plain-text file `fonts.txt` at repo root holds `Name|manifest-url` pairs, where the URL is Google Fonts' JSON manifest endpoint (`fonts.google.com/download/list?family=<Name>`) — the "Download family" zip endpoint no longer serves a real zip (it now returns the web app's HTML shell), but the manifest endpoint returns a `)]}'`-prefixed JSON body with a `manifest.fileRefs` array of direct `{filename, url}` pairs to individual font files. `setup.sh` gains a "Fonts" section, placed after the Homebrew section, that reads `fonts.txt` line by line, skips a font if already installed (glob match on `~/Library/Fonts`), and otherwise fetches the manifest, validates it with `jq`, and downloads each `.ttf`/`.otf` file straight into `~/Library/Fonts` — no zip/unzip step.

**Tech Stack:** bash (matches existing `setup.sh`), `curl`, `jq` (already a Brewfile dependency, installed earlier in the same run).

## Global Constraints

- No test framework in this repo (per `CLAUDE.md`: "No build step. No tests."). Verification is manual: run the section and inspect `~/Library/Fonts`.
- Script uses `set -euo pipefail` (setup.sh:2) — a single font's curl/jq failure must not abort the whole script, so those commands must be guarded (`if` / `||` fallback as appropriate), matching the existing pattern used for the SSH key fetch (setup.sh:83) and 1Password steps (setup.sh:185-237).
- Follow existing log helpers: `log()`, `success()`, `warn()`, `section()` (setup.sh:11-17). Don't invent new output helpers.
- `fonts.txt` format: one `Name|manifest-url` per line; blank lines and lines starting with `#` are comments, skipped.
- Pass the manifest JSON to `jq` via `printf '%s'`, never `echo` — `echo` can reinterpret backslash-escaped sequences embedded in the manifest (e.g. `\r\n` inside bundled license text) and corrupt the JSON before `jq` sees it.
- `compgen` (used for the idempotency glob check) is a bash builtin, not available under zsh — this is fine since `setup.sh` always runs via `bash` (shebang `#!/usr/bin/env bash`), but don't test the snippet by pasting it into an interactive zsh shell expecting the same result.
- Multi-word family names in `fonts.txt` (e.g. `Libertinus Serif`) need `+` for spaces in the URL query param — Google Fonts rejects a literal space (`curl: (3) URL rejected`). The `Name` field itself keeps its real space; only the URL is encoded.
- The idempotency glob must strip spaces from `name` before matching (`*${name// /}*`, not `*${name}*`) — Google's actual filenames drop spaces from multi-word families (`Libertinus Serif` → `LibertinusSerif-Regular.ttf`), so an unstripped glob never matches and the font re-downloads every run. Caught and fixed while adding Libertinus Serif/Math — Carlito/Inter/Lato never exposed it since they're single-word.

---

### Task 1: Add `fonts.txt` and the Fonts section in `setup.sh`

**Files:**
- Create: `fonts.txt` (repo root)
- Modify: `setup.sh` — insert new section after the Homebrew section (currently ends at `setup.sh:42`, right before the `# macOS defaults` section header at `setup.sh:44`)

**Interfaces:**
- Consumes: `DOTFILES_DIR` (already defined at `setup.sh:9`), `log`/`success`/`warn`/`section` helpers (`setup.sh:11-17`)
- Produces: nothing consumed by later tasks — this is the only task

- [x] **Step 1: Create `fonts.txt`**

Create `fonts.txt` at the repo root:

```
# Non-brew fonts, fetched from Google Fonts.
# Format: Name|manifest-url (fonts.google.com/download/list?family=<Name>)
Carlito|https://fonts.google.com/download/list?family=Carlito
Inter|https://fonts.google.com/download/list?family=Inter
Lato|https://fonts.google.com/download/list?family=Lato
```

(The original plan draft used `fonts.google.com/download?family=X`, the
browser "Download family" zip URL. Verified during implementation that
this now returns the Google Fonts SPA's HTML shell, not a zip. Switched
to `fonts.google.com/download/list?family=X`, the JSON manifest endpoint
the web app itself uses, which returns direct per-file URLs.)

- [x] **Step 2: Insert the Fonts section into `setup.sh`**

Insert this block into `setup.sh` immediately after line 42 (the `fi` that closes the Brewfile `if`, right before the `# macOS defaults` section comment block on line 44):

```bash
# ─────────────────────────────────────────────
section "Fonts (non-brew)"
# ─────────────────────────────────────────────

FONTS_LIST="$DOTFILES_DIR/fonts.txt"

if [[ -f "$FONTS_LIST" ]]; then
  while IFS='|' read -r font_name font_url; do
    [[ -z "$font_name" || "$font_name" == \#* ]] && continue

    if compgen -G "$HOME/Library/Fonts/*${font_name}*" &>/dev/null; then
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
```

Notes on why this avoids tripping `set -euo pipefail`:
- `compgen -G` glob-miss (exit 1) is consumed by the `if` conditional, not propagated.
- `manifest="$(... )" || manifest=""` — the pipeline's exit status is subject to `pipefail`; the trailing `|| manifest=""` makes the whole assignment succeed (exit 0) even when `curl` fails, and resets `manifest` to empty so the next `if` correctly routes to the `warn` branch.
- The `jq -e` validity check is itself an `if` condition, exempt from `set -e`.
- The per-file `curl` inside the `while` loop body is **not** exempt (it's a plain statement, not a condition) — hence the explicit `|| warn ...` on that line, so one bad file doesn't abort the script.
- The manifest is piped to `jq` via `printf '%s'`, never `echo` — the manifest JSON contains literal backslash-escaped sequences (e.g. `\r\n` inside the bundled `OFL.txt`/`README.txt` license text) that `echo` can reinterpret as real escape sequences, corrupting the JSON before `jq` parses it. Confirmed by reproducing the exact `jq: parse error: Invalid string: control characters...` failure with `echo` and fixing it by switching to `printf '%s'`.

- [x] **Step 3: Verify the section runs standalone**

Verified by extracting just this block into an isolated `bash -c '...'` snippet (defining the same `log`/`success`/`warn`/`section` helpers as `setup.sh:11-17`) and running it directly — not by running `./setup.sh` itself, which also runs Homebrew/macOS-defaults/sudo/SSH/tuckr/mise/LaunchAgent steps and should not be triggered just to test one section.

Expected and observed: `▸ Installing Carlito...` / `✔ Carlito installed` (same for Inter, Lato), and `ls ~/Library/Fonts | grep -i carlito` (and Inter, Lato) shows real `.ttf` files — confirmed 70 total font files across all three families, `file` reports them as genuine `TrueType Font data`.

- [x] **Step 4: Re-run to verify idempotency**

Re-ran the same isolated snippet via explicit `bash -c '...'` (not the default interactive shell — `compgen` is a bash builtin, absent under zsh, which gave a false "not found" the first time this was tried under zsh directly).

Expected and observed: `✔ Carlito already installed` / `✔ Inter already installed` / `✔ Lato already installed` — no re-download.

- [x] **Step 5: (skipped) Full `./setup.sh` end-to-end run**

Deliberately **not** run as part of this task — `setup.sh` also performs Homebrew bundle installs, macOS defaults writes, Touch ID/sudo config, SSH key fetches, Remote Login (sshd) enabling requiring interactive `sudo`, tuckr symlinking, mise installs, and 1Password-gated steps. Running the whole script is out of scope for verifying a single new section and risks side effects (e.g. it will block on an interactive `sudo` password prompt at the Remote Login step, or worse, silently fail past it) if run non-interactively. Section 3 syntax-checks with `bash -n setup.sh`, and Steps 3-4 exercise the new section's real behavior in isolation — sufficient verification here.

- [x] **Step 6: Update `CLAUDE.md` key config locations table**

Modify `CLAUDE.md` — add a row to the "Key config locations" table (the table currently ends with the `packages` row for `Brewfile`):

```markdown
| non-brew fonts | `fonts.txt` |
```

- [x] **Step 7: Commit**

```bash
git add fonts.txt setup.sh CLAUDE.md
git commit -m "$(cat <<'EOF'
feat(setup): install non-brew Google Fonts from fonts.txt

Brew casks cover some fonts already; Carlito/Inter/Lato have no cask
and are fetched straight from Google Fonts. fonts.txt keeps the list
editable without touching setup.sh logic.
EOF
)"
```
