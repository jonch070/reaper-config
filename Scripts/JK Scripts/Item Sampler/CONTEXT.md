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

## Planned Features / Future Ideas

### F0-Based Pitch Matching (not started)
- **Concept**: instead of relying on note names/numbers in the filename, analyze the actual audio content of each candidate item to detect its fundamental frequency (f0) and match on that instead. Would help with libraries that don't encode pitch in the filename, or to sanity-check/override a mislabeled filename.
- **Why not yet**: needs a pitch-detection routine (autocorrelation/YIN or similar) run over each item's audio, which is nontrivially more work than the filename-based matcher above (reading audio samples from REAPER via `reaper.GetMediaItemTake_Source` + `reaper.PCM_Source_GetPeaks` or similar, plus picking an analysis window per item). Reasonable follow-up once the filename-based matcher above has been used for a while.
- **Where this would plug in**: `GetItemPitchFromName(item)` in `General Functions.lua` would gain a sibling (e.g. `GetItemPitchFromAudio(item)`), and `Place_Sequence()` would try filename match, then f0 match, before falling back — same `pitch_map`/`FindPitchCandidates` machinery could likely be reused if the f0 pass just fills in map entries for items the filename parser couldn't resolve.

## Architecture Notes
- Main script loads dependencies via `dofile(script_path .. 'filename.lua')`
- `Groups` table holds per-group settings and item sequences
- `Settings` is the active group's settings during placement
- `ListMidi` holds the MIDI items to read notes from
- `list_sequence` holds the audio items to place
- `CopyMediaItemToTrack()` in `General Functions.lua` copies via chunk (preserves all item properties)
- `TrimItem()` in `General Functions.lua` handles post-placement trimming
