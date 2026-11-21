# Publishing on mod.io

## In short

- **Where it is.** On mod.io as [Station Retrofits](https://mod.io/g/transportfever3/m/station-retrofits), mod id 6544442, since 1.0 (21 Nov 2026; record at the bottom). The steps are the ones Depot Retrofits used for its first upload and six updates, and Best Before for four uploads (Depot Retrofits' `docs/publishing.md`, which keeps those upload records and the evidence for the rules below).
- **How it gets there.** Only through the game's own uploader: Mod Hub, My Mods, the mod's dialog. The mod.io website refuses uploads for Transport Fever 3, and the page text changes only through the uploader. The uploader reads the name, summary, description and tags from [modinfo.json](../station_retrofits_1/_metadata/modinfo.json) and the images from `station_retrofits_1/_metadata/`.
- **The mod id file.** The first upload writes `station_retrofits_1/_metadata/mod.io_fileid.txt` (the mod id). Commit it and never delete it: with it the dialog updates the existing mod, without it the next upload creates a second one.
- **What ships.** The whole `station_retrofits_1/` folder except `_metadata/`: `mod.json`, `_content.json` and `content/`. The game loads only the files `_content.json` lists, so `python3 tools/check_content_list.py` must pass before an upload.
- **Images.** `0.jpg` is the cover, and the gallery is `1-cover.jpg` onwards, in file-name order: a number for the place, a name for the picture. `1-cover.jpg` is a copy of the cover, so the gallery opens on it. Every image is 1920x1080. The pictures after it are listed under [Gallery](#gallery).
- **Version numbers.** mod.io labels every uploaded file "1.0", whatever the mod's number. The number that counts is `modVersion` in [mod.script.tl](../station_retrofits_1/content/mod.script.tl), which the log prints at every load as `STATION_RETROFITS version <number>`, and the matching entry in [CHANGELOG.md](../CHANGELOG.md).
- **Unknown.** How long the console file takes to run in a game; whether an update with one renamed gallery image sends only that image.

## Releasing a version

1. **In the repo, on a release branch** (`<YYYY-MM-DD>-release-<number>`).
   - The description in `modinfo.json` follows [user-guide.md](user-guide.md): change both together. Check its "Not checked yet", "Not covered" and "Not rebuilt" lines against the latest test results in [findings.md](design/findings.md).
   - Run `python3 tools/check_content_list.py`, `python3 tools/check_repo.py --strict` (`settings.tl` ships `logLevel = "summary"`) and `tl check` on every script.
   - Set `modVersion` in `mod.script.tl` to the release number (between releases it reads the next number with `-dev`, for example `1.1-dev`).
   - In [CHANGELOG.md](../CHANGELOG.md), give the "not released" entry its number and date, and check its "Release note:" line, the one-liner for the uploader's Changelog field.
   - Redraw the cover with the new number (`python3 tools/make_preview.py --version <number>`), which writes `0.jpg` and `1-cover.jpg`. A changed `1-cover.jpg` needs a new name (see [Gallery](#gallery)).
   - Merge the PR before uploading, so the upload is the code on `main`.
2. **Upload.** The uploader sends the working tree through the staging link, so first set `settings.tl` back to the repo's `logLevel = "summary"` (the local copy is otherwise kept at `"full"`; `local/settings.full.tl` holds it) and check that `git status` shows nothing under `station_retrofits_1/`. Start the game, open **Mod Hub**, then **My Mods**, and click the mod's card. In the dialog:
   - **Validation** should read "No Issues Found" (**Re-Validate** runs it again).
   - **Preview**: the cover. On the first upload click the slot (camera icon) and pick `0.jpg`; without a cover the card shows a "?".
   - **Gallery**: the files after `0.jpg`, in name order. See [Gallery](#gallery) before moving any.
   - Tick both **PC** and **Console** for the two files (Windows, Mac and Linux; Xbox Series X/S and PlayStation 5).
   - **Set Public** ticked. Unticked, the page is hidden from visitors.
   - **Update Metadata** ticked, so the page takes the name, summary, description and tags from `modinfo.json`.
   - **Changelog**: the version's "Release note" line. Left empty, the page shows "No release notes provided".
   - The button reads **Upload** ("A new mod will be created on mod.io") only the first time. After that it must read **Update** ("The existing mod on mod.io will be updated"); if it reads Upload, `mod.io_fileid.txt` is missing: stop and restore it.
3. **Press Upload or Update.** The dialog shows "Uploading... Please Wait" and a counter, then "Upload Successful". After the first upload, commit `mod.io_fileid.txt`.
4. **Check the page** (**Open Mod Page** in the dialog): text, images, files and their dates. The page is about a minute behind an upload, so reload it before judging the file list.
5. **Test the published copy.** Remove the `staging_area/station_retrofits_1` link: with both present the game loads the staging copy and logs `Multiple (2) mods with same id found`, so such a run says nothing about the published file. Subscribe, load a save with the mod active, and check the log for `STATION_RETROFITS version <number> logLevel=summary` and no `Error while loading game script`, and the downloaded folder (under `mod.io/common/10640/mods/<mod id>/`) for `mod.json`, `_content.json` and every file `_content.json` lists, byte for byte the tagged commit's. Buy a level or two and check each is charged once. A release counts as good only after this. Then unsubscribe, restore the link, and restore `logLevel = "full"` in the local `settings.tl` (`cp local/settings.full.tl station_retrofits_1/content/settings.tl`).
6. **Tag and release on GitHub.** Tag the merged commit `v<number>` and publish a GitHub release from it. Tags matching `v*.*` and releases cannot be changed once pushed (rulesets `version-tags` and immutable releases), so check both first; a mistake means a new version. Release notes have these parts: a bold one-line pitch, What changed, Good to know (including that mod.io calls every upload "1.0"), links to the CHANGELOG and docs pinned to the tag, Checked (with the published-copy test), and Not done yet.
7. **Record the upload** at the bottom of this page (dialog, page, published copy, tag), as Depot Retrofits does.
8. **Start the next version.** Set `modVersion` to the next number with `-dev` and open a "not released" entry at the top of the CHANGELOG.

## Gallery

What Depot Retrofits learned (its `docs/publishing.md`, "Gallery"):

- **The cover is in the gallery only as the first gallery image.** `0.jpg` fills the dialog's Preview slot and the mod's card; the gallery holds only the files after it and the large image opens on the first of them. So `1-cover.jpg` is a copy of the cover. `tools/make_preview.py` run without OUT_FILE writes both.
- **The order is the file names.** Reorder by renaming files in the repo, not with the dialog: its move buttons swap the files' contents on disk and leave the names, so a named file ends up holding another picture.
- **A changed picture needs a new name** (`3-not-rebuilt-2.jpg`). mod.io keeps old names, and an update does not send a gallery image whose name mod.io already has, so a picture changed under its old name never reaches the page.
- **An update for the images alone sends the mod file too**, as a new pair of files with the same code. A gallery fix is best sent with a release.
- **Thumbnails are cropped to 16:9**, so every image is 1920x1080. A game screenshot must leave room above and below the window, or be laid out on the cover's background with `tools/make_gallery.py`. That tool cuts each window along its outline, so its crops must be cut tight to the window: map left below or beside it shows as a strip under the card.

The 1.0 gallery, after `1-cover.jpg`:

| File | What it shows | Source |
|---|---|---|
| `2-retrofit-cards.jpg` | Four station windows in a pile, drawn by `tools/make_gallery.py` (its docstring has the command): a road station, a cargo rail station, a harbour (two rows) and a passenger rail station with "Not rebuilt" on top. Each window is cut just above its Statistics section, so the cards keep one scale. | Crops in `tools/gallery/`, from shots of 2026-11-15 |
| `3-not-rebuilt.jpg` | The "Not rebuilt" banner on a passenger rail station, with the station and its tracks on the map. | Screenshot 2026-11-15 05:02, 2560x1440 from the top right, scaled down |
| `4-road-station.jpg` | A levelled road station (catchment 2, pollution 7, noise 4, upkeep 13) with its catchment area shown on the map. | Screenshot 2026-11-15 05:08, cut the same way |
| `5-tooltip.jpg` | A row's tooltip: the level, what a level does, the upkeep it adds, the next price and the ">\|" total. | Screenshot 2026-11-13 07:22, the window's top at about full size |

The shots predate the arrow "→" (they show "->") and the shorter banner wording ("Not rebuilt: a building, road or track is in the way."); the arrow is too small a change to reshoot for.

## Hub search and tiles

From Depot Retrofits' page:

- **Search matches the name only.** In the Mod Hub, words that appear only in another mod's summary or description find nothing, so the name carries the search words: "station", "retrofits".
- **Tiles show the whole 16:9 cover, uncropped.** mod.io's tile adds the author, the summary cut after about 130 characters, the first tag and the size.
- **Downloads ship without `_metadata`.** The hub builds its page from mod.io's own copy of the text.

## First upload (1.0, 21 Nov 2026)

- **Dialog.** Validation "No Issues Found", PC and Console, Set Public and Update Metadata, the release note in Changelog; the button read Upload with "A new mod will be created on mod.io". It ran "Validating... Please Wait", then "Uploading... Please Wait"; afterwards the folder button read "Page" (Open Mod Page). Screenshots 20261121_165658 to 165841.
- **Files.** `mod.io_fileid.txt` appeared with the mod id (6544442); no tracked file changed.
- **Page.** Public within about four minutes, in the Mod Hub ("retro" finds it beside Depot Retrofits) and on mod.io: the cover, Script Mod tag, description as in `modinfo.json`, ID 6544442, date live Nov 21, 2026. Both files listed at once, each "Version: 1.0" with the release note: Windows, Mac and Linux 34.26 KB, Xbox Series X/S and PlayStation 5 34.37 KB. The hub showed 105.6 KB. Screenshots 20261121_170210 to 170322.
- **Published copy.** Subscribed in the Mod Hub with the staging link removed: `mods/6544442/` held `mod.json`, `_content.json` and the ten files in `content/`, byte for byte those of `2f6be05`, with no `_metadata`. A load of the "333" save logged `STATION_RETROFITS version 1.0 logLevel=summary`, no `Error while loading game script` and no duplicate of this mod. 39 rebuilds on four stations (three rail, one tram): 29 buys charged and 9 removals refunded once each, and one ">|" buy refused by the game ("Not rebuilt" after 10 seconds, given up after 30, nothing charged). Log `local/logs/2026-11-21-published-stdout.txt`, screenshots 20261121_170916 to 171147.
- **Tag and release.** `v1.0` is on `2f6be05`, the code that was uploaded; `mod.io_fileid.txt` and this record came after it. GitHub release "v1.0: first release, levels for stations" published from the tag.
