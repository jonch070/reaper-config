# Item Sampler (Snap Offset Mod) - Development Context

## Overview
Fork of Daniel Lumertz's Item Sampler v1.3.6 for REAPER.
Located in: `JK Scripts/Item Sampler/`
Original: `Daniel Lumertz Scripts/Items/Item Sampler/`

## Completed Features

### Snap Offset Support (v1.3.6-mod1)
- **Files changed**: `groups.lua` (added `UseSnapOffset` setting), `Item Sampler (Snap Offset Mod).lua` (checkbox UI + placement logic)
- **How it works**: When enabled, items are placed at `midi_note_time - item_snap_offset` so the snap offset point aligns with the MIDI note
- **Key code location**: `Item Sampler (Snap Offset Mod).lua` ~line 324-329 (placement logic), ~line 581-584 (GUI checkbox)
- **Commit**: d70f61d5 on jonch070/reaper-config

## Completed Features (cont.)

### MIDI Note Matches Item by Pitch in Name (v1.3.6-mod2)
- **Concept**: Instead of (or as well as) changing the item's pitch property, the script parses the pitch/note name embedded in the item's take name or source filename (e.g. "Violin_C3.wav", "Kick_A#1_v2.wav") and picks the matching item from `list_sequence` for that MIDI note, unshifted.
- **Settings** (`groups.lua`): `MatchByName` (bool, off by default), `MatchByName_OctaveSearch` (int, default 2 — how many octaves up/down to search, nearest first, if no item matches the exact octave), `MatchByName_Fallback` (bool, default true — if no match at all, use the normal sequence/random order for that note instead of skipping it).
- **Parsing** (`General Functions.lua`):
  - `ExtractNoteNumberFromString(str)` — finds a note name (letter A-G, optional `#`/`b`, optional octave, delimiter-bounded so it won't false-positive inside ordinary words like "ADC3") and converts via the existing `NoteToNumber()`. Falls back to an explicitly tagged MIDI number: `midi60`, `note60`, `key60`, or `#60`.
  - `GetItemPitchFromName(item)` — tries the take name first, then the source filename.
  - `BuildPitchIndex(list_sequence)` — builds `{ [pitch] = {indices...} }` once per placement pass.
  - `FindPitchCandidates(pitch_map, pitch, octave_search)` — exact pitch first, then ±1 octave, ±2, etc.
- **Placement logic** (`Place_Sequence()` in the main script): when `Settings.MatchByName` is on, item selection for each MIDI note tries the pitch match first; ties among multiple matching items cycle in order (like "Place in Sequence") or pick randomly (like "Place Random"), reusing the same `is_random` flag the two placement buttons already pass in. `ChangePitch()` is skipped whenever an item was chosen this way ("without repitching"). If nothing matches and `MatchByName_Fallback` is true, it falls through to the normal sequence/random/reverse logic (and normal `Settings.Pitch` repitching applies in that fallback case).
- **Known limitations**: octave-naming convention follows this script's existing `NumberToNote`/`NoteToNumber` (C4 = MIDI 60, not scientific-pitch C5=60) — matches whatever the Range sliders already show. The "no-repeat until exhausted" random variant (Ctrl+Place Random) isn't reproduced per-pitch-group, only plain cycle/random.
- **Commit**: 73d49763 on main

### Round-Robin / Don't-Reuse for Match-By-Name Ties (v1.3.6-mod3)
- **Problem fixed**: when multiple items matched the same note, "Place in Sequence" already cycled through them deterministically (round-robin by construction), but "Place Random" picked with plain `math.random(#candidates)` each time, so it could place the exact same file twice in a row.
- **New default behavior (always on, no setting needed)**: every candidate for a given note is used once before any of them repeat, for both Place in Sequence and Place Random. Implemented via `PickFromPool(pools, candidates, no_reuse, is_random)` in `General Functions.lua` — draws from (and removes from) a per-candidate-group pool, refilling it once it's empty. The pool is keyed by the `candidates` list *object itself* (not by the requesting MIDI pitch), so two different MIDI notes whose octave search both resolve to the same underlying named-item group correctly share one exhaustion pool instead of each independently repeating the same file.
- **New setting**: `MatchByName_NoReuse` (bool, default false) — "Don't Reuse Samples" checkbox. When on, an exhausted pool is never refilled (`PickFromPool` returns nil instead), so once every item matching a note has been placed once, that note is treated as unmatched for the rest of the run (falls through to `MatchByName_Fallback` like any other unmatched note).
- **Verified** with a standalone Lua harness (not part of the repo) exercising: sequence-mode order/wrap, random-mode exhaust-before-repeat, no-reuse-never-refills, and shared-pool-across-different-requesting-pitches.
- **Relevant for the still-unbuilt chaining feature below**: this same `PickFromPool`/pools mechanism is exactly what "chain multiple items to fill a long note" should reuse when it needs a 2nd/3rd item for one note — that was an open question in that section below and is now resolved.

### Settings Migration / Backfill Fix
- **Bug found**: `salvar()` (~line 786) is registered via `reaper.atexit(salvar)` despite its stale `-- OFF Right now` comment — it *does* run, saving `Groups` (incl. `Settings`) into the project's `ItemSampler` ProjExtState on every script close. A project saved before `MatchByName`/etc. existed restores `Settings` missing those keys as `nil`, which then gets passed straight into `reaper.ImGui_Checkbox`/`ImGui_SliderInt` (which want bool/number) — this is a real, hit-in-practice failure mode for any newly added group setting, not just this one.
- **Fix** (`groups.lua`, `presets.lua`): `BlankGroup.NewDefaultSettings()` is now the single source of truth for a group's default settings shape (used by `BlankGroup:Create`). `FillMissingSettings(settings)` back-fills any nil keys from that shape. Called in `presets.lua`'s `LoadInitialPreseetGroups()` right after `Groups = load_table.Groups`, for every loaded group.
- **Takeaway for future settings additions**: adding a new key to `BlankGroup.NewDefaultSettings()` is automatically migration-safe — no extra work needed per new setting.
- **Commit**: ab384aec on main

## Current Placement Behavior (context for planned features below)
- `Place_Sequence()` picks one source item per MIDI note (Sequence: cycles `list_sequence` in order/reverse via a counter; Random: `math.random`, optionally no-repeat-until-exhausted with Ctrl; MatchByName: pitch-matched candidates, cycling/random among ties the same way) then does ONE `CopyMediaItemToTrack()` call per note.
- **Destination track today**: `paste_track = reaper.GetMediaItemTrack(list_sequence[list_idx])` — i.e. whatever track that specific source item currently lives on. There is no destination-track setting; output scatters across wherever the sequence's source items happen to sit. Confirmed upstream 1.8.1 (`Daniel Lumertz Scripts/Items/Item Sampler/Item Sampler.lua` ~line 455) does exactly the same thing — this isn't solved for free by rebasing.
- **Note-length handling today**: one item is pasted per note, then `TrimItem()` trims it to the shortest of (item's own end / next note's start / this note's end). If the source item is *shorter* than the note, nothing fills the remainder — it just plays out and the rest of the note is silent. No chaining/looping of multiple items exists.

## Planned Features / Future Ideas

### F0-Based Pitch Matching (not started)
- **Concept**: instead of relying on note names/numbers in the filename, analyze the actual audio content of each candidate item to detect its fundamental frequency (f0) and match on that instead. Would help with libraries that don't encode pitch in the filename, or to sanity-check/override a mislabeled filename.
- **Why not yet**: needs a pitch-detection routine (autocorrelation/YIN or similar) run over each item's audio, which is nontrivially more work than the filename-based matcher above (reading audio samples from REAPER via `reaper.GetMediaItemTake_Source` + `reaper.PCM_Source_GetPeaks` or similar, plus picking an analysis window per item). Reasonable follow-up once the filename-based matcher above has been used for a while.
- **Where this would plug in**: `GetItemPitchFromName(item)` in `General Functions.lua` would gain a sibling (e.g. `GetItemPitchFromAudio(item)`), and `Place_Sequence()` would try filename match, then f0 match, before falling back — same `pitch_map`/`FindPitchCandidates` machinery could likely be reused if the f0 pass just fills in map entries for items the filename parser couldn't resolve.

### Destination Track = Parent Folder's Child Track (not started, medium effort)
- **Concept**: option to place all of a group's items onto their own dedicated track, inserted as a child of a chosen parent folder track, instead of today's behavior (pasting back onto whatever track the source item itself sits on).
- **Open design question, needs an answer before implementing**: granularity of "own track" — one new track shared by the whole placement run, one per matched name/pitch group (natural fit alongside MatchByName), or one per distinct source item?
- **Implementation shape**: new per-group setting (which parent folder track to target — a track picker), a track-insertion helper that inserts a new last-child track under that folder and correctly maintains REAPER's `I_FOLDERDEPTH` bookkeeping (the parent's depth, and shifting the "closes N folders" negative depth from the current last child onto the new one) — this depth math is the main source of bugs in this kind of feature.
- **Not a rebase freebie**: confirmed upstream 1.8.1 has the identical same-track-as-source behavior (`Item Sampler.lua` ~line 455) — this has to be built regardless of which base we're on.

### Chain Multiple Items to Fill a Note Longer Than the Sample (not started, medium effort)
- **Concept**: when the chosen item is shorter than the MIDI note it's filling, keep placing additional items end-to-end (advancing the normal selection state each time) until the note's duration is covered, instead of leaving the remainder silent.
- **Selection for the 2nd/3rd/... item on the same note - resolved**: reuse `PickFromPool`/`MatchByName_NoReuse` from the "Round-Robin / Don't-Reuse" section above. Default: comb through every unused candidate for that note before repeating (round-robin). With "Don't Reuse Samples" on: never reuse a sample at all, even across the whole chain/run - once candidates run out, stop chaining (leave that portion silent) rather than repeat. This same mechanism should extend to the plain (non-MatchByName) sequence/random pool too, once this feature is built, so chaining behaves consistently either way.
- **Open design question, needs an answer before implementing**: does each chained item honor its own snap offset (like the first one does today), or only the first item in the chain?
- **Implementation shape**: a loop inside (or wrapping) the per-note body in `Place_Sequence()` that keeps calling the existing selection logic (sequence/random/match-by-name — reuse as-is, just called repeatedly) and pasting items back-to-back until covered length >= note length, with a max-iteration safety guard. `TrimItem()` currently assumes one pasted item per note; it needs to only trim the *last* chained item at the note/next-note boundary, not every chained item.

### Rebase onto Upstream Item Sampler 1.8.1 (not started, large effort — the biggest item here)
- **Why considered**: to pick up upstream's newer bug fixes / grid editor / multi-sequencer UX, and because the user wondered if it'd resolve unrelated issues (it did not — the actual bug was the settings-migration issue above, unrelated to versioning).
- **Why it's the biggest lift**: upstream (`Daniel Lumertz Scripts/Items/Item Sampler/Item Sampler.lua`, 1817 lines vs. our 806) reworked the core signature — `Place_Sequence(group, sequencer, is_random, sequence_reverse, isrand_sequence)` takes explicit args instead of mutating global `list_sequence`/`Settings` per group like ours does — plus it added a whole "sequencer" object layer (`CheckGroups(sequencers)`, `IsItemPastedFromSequencer`, `UntagSelectedItems`, `CleanAreas(proj, sequencers)`) and a drag-based grid editor. Porting the Snap Offset mod and MatchByName feature onto this isn't a mechanical copy-paste — both hook exactly the parts that changed shape, so it's closer to re-implementing the mod against a new foundation than syncing one.
- **Confirmed NOT a shortcut for the two features above**: upstream 1.8.1 has neither folder-track destinations nor note-length chaining, and uses the identical same-track-as-source placement logic we have. Building #2/#3 above on the current codebase, then rebasing later, avoids doing that plumbing work twice.
- **Recommended sequencing** (per conversation with user): build the folder-track and note-chaining features on the current codebase first (self-contained, testable now); treat the 1.8.1 rebase as a separate, later project.

## Architecture Notes
- Main script loads dependencies via `dofile(script_path .. 'filename.lua')`
- `Groups` table holds per-group settings and item sequences
- `Settings` is the active group's settings during placement
- `ListMidi` holds the MIDI items to read notes from
- `list_sequence` holds the audio items to place
- `CopyMediaItemToTrack()` in `General Functions.lua` copies via chunk (preserves all item properties)
- `TrimItem()` in `General Functions.lua` handles post-placement trimming
