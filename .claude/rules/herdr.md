Whenever I ask to change anything about the Herdr desktop app (`herdr-app`) — its look, theme, keys, layouts, mods, programs or settings — run `herdr-app --skill` first, once per session, before reading or editing any Herdr file.

## Steps
1. If `herdr-app --skill` has not run yet in this session, run it and follow it. It points to `~/.config/herdr-app/AGENTS.md`; read the sections the change needs.
2. Read `docs/herdr.md` for where the change lives in this repo (tracked files under `Configs/herdr-app/.config/herdr-app/`, and how to take over a Herdr-owned file).
3. Make the change in the repo copy, then check `herdr-app status` shows `"errors": []`. For a mod, also run `herdr-app check`.

Skip steps 2–3 for tasks that only drive the window (opening tabs or splits, focusing agents) without changing config.
