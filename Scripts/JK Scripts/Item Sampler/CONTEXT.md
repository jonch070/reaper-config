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

## Planned Features

### MIDI Note Matches Item by Pitch in Name
- **Concept**: Instead of MIDI note changing the item's pitch property, the script looks at the pitch/note name embedded in the item/filename (e.g. "Violin_C3.wav", "Kick_A1.wav") and selects the matching item from the sequence
- **Use case**: Kontakt libraries and sample libraries where note names are in filenames. Drag samples in, and the script auto-matches them to the correct MIDI notes
- **Behavior**:
  - Parse item/take/source filename for note name patterns (C0-G9, with sharps/flats)
  - When placing, match MIDI note pitch to the closest item whose filename contains that note
  - If multiple items match the same note, cycle through them
  - Should be a separate mode/checkbox, not replacing existing pitch behavior
- **Relevant existing code**:
  - `NumberToNote()` and `NoteToNumber()` functions already exist in `GUI Functions.lua` for note<->number conversion
  - Pitch handling is in `ChangePitch()` function (~line 217)
  - Item selection logic is in `Place_Sequence()` (~line 299-321) - this is where matching logic would go
  - `list_sequence` is the array of source items to choose from

## Architecture Notes
- Main script loads dependencies via `dofile(script_path .. 'filename.lua')`
- `Groups` table holds per-group settings and item sequences
- `Settings` is the active group's settings during placement
- `ListMidi` holds the MIDI items to read notes from
- `list_sequence` holds the audio items to place
- `CopyMediaItemToTrack()` in `General Functions.lua` copies via chunk (preserves all item properties)
- `TrimItem()` in `General Functions.lua` handles post-placement trimming
