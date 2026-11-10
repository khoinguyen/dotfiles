# Herdr app customisation

Where to customise the Herdr desktop app (`herdr-app`) from this repo. Herdr's own reference is
`~/.config/herdr-app/AGENTS.md`; Herdr rewrites that file on every start, so don't edit or
track it.

## How it is wired

- Repo folder: `Configs/herdr-app/.config/herdr-app/`, linked to `~/.config/herdr-app/` by
  `tuckr add herdr-app`.
- Tuckr links individual files, not folders. Herdr's own files sit next to ours in
  `~/.config/herdr-app/` and stay out of git.
- Herdr saves into the links, not over them. Zoom keys and the Settings screen change the repo
  copy, so check `git diff` before committing.

## What is tracked now

| File | What it sets |
|---|---|
| `settings.json` | zoom, sounds, fonts, `theme: {light: gruvbox-light, dark: gruvbox-dark}` |
| `themes/gruvbox-dark.json` | gruvbox dark terminal colours (panel colours are derived from them) |
| `themes/gruvbox-light.json` | gruvbox light terminal colours |

## Where to customise later

| To change | Repo path (under `Configs/herdr-app/.config/herdr-app/`) | Notes |
|---|---|---|
| Look: fonts, sizes, colours, sounds | `settings.json` | Already tracked. Used wherever the layout sets nothing; the `main` layout sets nothing. |
| A colour theme | `themes/<name>.json` | `{background, foreground, selection, cursor, ansi[16], colors?}` |
| Keys | `keys.json` | Not tracked yet: see "Taking over a Herdr-owned file" below. |
| Window structure | `layouts/<name>.json` | Never edit a shipped layout (`main`, `terminals`, `win98`). Clone it first: `herdr-app do layout.clone '{"name":"main","as":"mine"}'`. |
| A panel (mod) | `mods/<name>/main.js` + `mod.json` | Shipped mods are read-only. Clone one with `mod.clone`, or write a new one. |
| Program names and icons, agent launch commands | `programs.json` | Adds to Herdr's built-in table. |

## Taking over a Herdr-owned file

`keys.json` and the clones that `layout.clone` / `mod.clone` create first appear as plain files in
`~/.config/herdr-app/`. To bring one into the repo:

```bash
d=~/dotfiles/Configs/herdr-app/.config/herdr-app
mkdir -p "$d/mods"                                          # only for a mod
mv ~/.config/herdr-app/keys.json "$d/"                      # or mods/<name>, layouts/<name>.json
cd ~/dotfiles && tuckr add herdr-app
herdr-app status                                            # "errors": [] means it loaded
```

Tuckr links each file inside a mod folder individually, so add new files to the repo copy and
run `tuckr add herdr-app` again.

## Never track

`AGENTS.md`, `*.d.ts`, `frame/`, `icons/`, shipped `layouts/` and `mods/`, `view.json`,
`window.json`, `shared.json`, `seen.json`, `installed.json`, `data/`, `layouts/.state/`. Herdr
writes all of these itself.

## Gotchas

- **`keys.json` upgrades:** an untouched `keys.json` gets new default shortcuts when Herdr
  updates. After any edit, even whitespace, the whole file is yours and new defaults must be added
  by hand.
- **Theme picker:** choosing a theme in Herdr's menu replaces the `settings.json` theme on that
  layout, and the light/dark auto-switch stops.
- **Errors:** a broken edit keeps the old version running and writes `<name>.error` next to the
  file. Check `herdr-app status` after every change.
- **Escape hatch:** `ctrl-alt-shift-escape` puts the shown layout and `keys.json` aside as
  `*.reset-<time>` and returns to `main`. A taken-over `keys.json` then becomes a plain file again,
  so the repo link has to be restored with `tuckr add herdr-app`.

## Checking a change

```bash
herdr-app status                        # errors: []
herdr-app check ~/.config/herdr-app/mods/<name>   # for a mod
herdr-app shot "$TMPDIR/herdr.png"      # picture of the window
```
