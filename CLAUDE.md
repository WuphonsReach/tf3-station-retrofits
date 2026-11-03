# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A planned Transport Fever 3 script mod: stations get levels (catchment radius, pollution, noise, upkeep), bought in the station's window. It is the sibling of Depot Retrofits, the same author's released mod for depots, checked out next to this repo at `../tf3-depot-retrofits` ([WuphonsReach/tf3-depot-retrofits](https://github.com/WuphonsReach/tf3-depot-retrofits), MIT, mod.io id 6495416). This repo starts from that mod's method and code.

**Status: design only.** Read these first, in this order:

1. [TODO.md](TODO.md): where it stands and what comes next.
2. [docs/design/findings.md](docs/design/findings.md): what is known about stations, with source files, and the unknowns. Read it before changing mechanics.
3. [docs/design/probe-plan.md](docs/design/probe-plan.md): the in-game probes to run before the spec is fixed.
4. [docs/design/spec.md](docs/design/spec.md): the draft retrofits and its open decisions.
5. In `../tf3-depot-retrofits`: its `CLAUDE.md` (architecture of the released mod), `docs/design/findings.md` (the tested facts this plan builds on) and `docs/design/spec.md`.
6. `local/machine.md` (gitignored, may be missing on another machine): the game paths, saves and screenshot folder on this machine.

The repo is public on GitHub ([WuphonsReach/tf3-station-retrofits](https://github.com/WuphonsReach/tf3-station-retrofits), MIT); the mod is not on mod.io yet. `main` takes changes only through a pull request: branch from `origin/main` as `<YYYY-MM-DD>-<slug>`, and push or open a PR only when the user asks.

## CI and repo rules

Copied from Depot Retrofits (its `CLAUDE.md`, "CI and repo rules"), which has the detail. `.github/workflows/checks.yml` runs on every PR and every push to `main`: `python-checks` (`check_content_list.py`, `check_repo.py --strict`, `py_compile` of `tools/`) and `teal-syntax` (`tl gen` on each `.tl` under `content/`; `tl check` stays local, as the game's type definitions are not in the repo). Actions are pinned to full commit SHAs with the version in a trailing comment.

The rulesets have no bypass actors, so they bind the owner too: `main` and `pr-checks` (changes reach `main` only through a PR; `pr-checks` requires `python-checks` and `teal-syntax`, so renaming a job means updating the ruleset in the same change), `trunks` (`main` cannot be deleted or force-pushed), `version-tags` (tags `v*.*` cannot be moved or deleted). Releases are immutable.

## Reusing Depot Retrofits

Depot Retrofits is MIT and by the same author, so its code may be copied. Its 1.2 layout, and what each file is likely to become here:

| Depot Retrofits (`depot_retrofits_1/content/`) | Here |
|---|---|
| `levels.tl` (trees, formulas) | new trees: radius, pollution, noise, upkeep; same price ladder |
| `company_rank.tl` (rank gate) | as is |
| `settings.tl` (`logLevel`) | as is |
| `mod.script.tl` (`loadConstruction` modifier, depot detection) | `loadConstruction` only for the hidden params; a `loadScript` modifier wraps the base station scripts' `updateFn` and the `terminateConstructionHook` it returns (findings, "Seen in other mods' code") |
| `construction.script.tl` (wrapper) | scale the station subconstruction after the original hook; upkeep may go negative (probe 1) |
| `retrofits.gs.lua`, `retrofits.script.tl` (buy queue, rebuild, charge) | mostly as is; journal category and the station's carrier |
| `retrofit_window.script.tl` (Retrofit tab, "Not rebuilt") | a card in the station window's `StationGroupEowExtensionPoint`, not a tab: `entityWindowScript` would stop the station window opening; same widgets |

Keep the copies independent: this mod must not load files from Depot Retrofits, and neither mod may wrap a construction the other wraps (airports have a hangar depot; see findings).

## Commands

```bash
# Type check (needs gitignored tlconfig.lua copied from tlconfig.example.lua, with <tf3_install_folder> filled in)
export PATH="$HOME/.luarocks/bin:$PATH"; eval "$(luarocks path --local)"
tl check station_retrofits_1/content/<file>.tl
```

There is no build step and no unit tests; the only checks are the type checker, the CI checks once they exist, and testing in the game. The user runs every in-game test. Run `tl check` on each script you touch.

Base game sources are `.tl` and `.lua` files inside zips under the game's `base/content/` (stations in `stations/{rail,street,water,air}.zip`, helpers in `scripts.zip`, emissions in `game_mechanics.zip`, windows in `gui.zip`). Unpack them into the session scratchpad, never into the repo.

## In-game test loop

- Symlink the mod folder into the game's `staging_area/`; edits show up without copying, but scripts and `mod.json` reload only on a game restart.
- The game log is `crash_dump/stdout.txt`, overwritten at each launch and written live. Copy it to `local/logs/` before reading it. Log times are UTC; the user's screenshots are named in local time.
- Every log line the mod writes starts with `STATION_RETROFITS` and carries `key=value` fields. At `logLevel` `"full"`, log the state before and after every action (entity ids, values); keep `"summary"` to start-up lines, errors and one line per player action. `"summary"` ships.
- Test sessions run with `logLevel = "full"` as an uncommitted local edit; stage files by name and commit `settings.tl` only when the change needs it.
- After a change that adds a load or an API call, check the first log lines after the save loads for `Error while loading game script` before the user plays at speed: a broken load in a sibling mod raised an error every update and froze the game.
- Test on a copy of a manual save. A probe acts by itself when loaded, with a small cap on what it does; no safeguards or confirmations are needed on test saves.
- When the user shares a series of screenshots, read all of them and tabulate them against the log. A missing screenshot is not proof that something never showed.
- Read screenshots through the screenshot index in the sibling repo `../tf3-save-format` first (`tools/screenshot_index.py`, workflow in its `.claude/skills/screenshot-index/SKILL.md`, the command for this machine in `local/machine.md`): OCR them by day, search the text, then open only crops. Picked crops of the mod at work, full resolution, go in the gitignored `local/screenshots/` with a `README.md` index.

## Conventions

- Wrap constructions; do not replace base game scripts. A replacement is last-wins and clashes with other mods.
- Put unverified API calls and optional loads under `pcall`, with a log line as the fallback. Reach base game files with the `::/` form; a leading `/` resolves inside the mod.
- Game scripts: module variables do not persist, so state lives in `state:get()`/`state:set()`. `sendCommand` cannot be called from `handleEvent` and cannot take a callback; send from `update`. State is written from several threads, so treat cross-call state as possibly racy.
- Reuse the game's own look: stock icons and widgets, cart buy buttons, drawn level boxes, the base notification card, as Depot Retrofits' tab does.
- Players see "retrofit" and "level", never "tree". Player-facing text (user guide, listing) uses the simplest wording that is still exact.
- Cite base game facts by the source file inside the game's archives (for example `game_mechanics/emission/emissions.script.tl`), never by pasting code. Public docs carry no home paths or Steam ids (those go in `local/`).
- Licences: copy only from MIT, BSD, Apache or CC0 code. The Industry Upgrades mod has no licence: its method may be reused, its code may not be copied.
- The mod ships no game files. `all_def.tl` and `tlconfig.example.lua` are for type checking only.
- Docs: every doc opens with an "In short" section (key drivers, how it works, how sure, what is unknown), then detail, with test results and logs at the bottom. Docs state the current status only; history belongs in git. Keep the README short.

## Working with the user

- The user is WuphonsReach, who has released two TF3 script mods (Best Before, Depot Retrofits). Explain construction and station mechanics briefly; no need to explain the toolchain.
- When the user asks for a plan only, make no edits until they say go.
- Branch names start with the date: `<YYYY-MM-DD>-<slug>`. Once the GitHub repo exists, `main` takes changes only through a PR.
- Ask before any GitHub write (push, PR, repo creation, tag, release). `gh` needs the sandbox off and its output piped to `cat`.
- Dependent work goes in stacked branches as separate PRs, but one in-game session tests the whole stack.
- The user may run several agents in one checkout: check the branch and the staged diff before committing, and stage only your own hunks.
- Stay in this repo: read `../tf3-depot-retrofits` freely, but change it (or file anything against it) only when asked.
