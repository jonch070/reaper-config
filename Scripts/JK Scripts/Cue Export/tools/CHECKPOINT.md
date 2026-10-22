# Cue Export Tools — Implementation Checkpoint

Quick context for a fresh Claude session. Everything is in `Cue Export/tools/` and untracked by git.

## Quick Verify
```bash
cd "/Users/jonathankawchuk/Library/Application Support/REAPER/Scripts/JK Scripts/Cue Export/tools"
python3 -m unittest discover -s tests  # should be 62 tests, OK
```

## Status
| Component | Status | Notes |
| --- | --- | --- |
| `check_stems.py` (Tool A) | Done | Verified against real export. Handles click +1 frame, null test envelope fallback, `--strict`. |
| `smf.py` | Done | Hand-rolled SMF reader (no `mido`). |
| `cueconfig.py` | Done | Shared config loader/validator. |
| `dropbox_backup.py` (Tool B) | Done | Safe copy-then-swap, staging dirs, verification, checker gating, master rotation. |
| `config.json` / `config.example.json` | Done | Real config git-ignored. |
| `tests/` | Done | 62 passing (fixtures generate synthetic WAV/MIDI). |
| `nightly.py` (Tool C) | Not started | Next up per SPEC §6. |
| Launchd plist + `install.sh`/`uninstall.sh` | Not started | Do not load into launchd without being asked. | 

## Key Files To Read
| File | Why |
| --- | --- |
| `SPEC.md` | Source of truth for contracts and order of work. |
| `NOTES.md` | Critical contract mismatches found against real files (click offset, MULTITRACK naming, export folder suffix, MIDI optional, null test non-determinism, etc). |
| `check_stems.py` | Reference for naming, classification, and report structure. |
| `dropbox_backup.py` | Reference for safe copy/swap pattern and Dropbox layout. |
| `cueconfig.py` | Config schema. |

## Important Gotchas
- **Click timecode**: Click is often +1 frame vs stems (allowed by checker).
- **MULTITRACK naming**: `REAPER $folder[_]_$track dry|wet - <project> - <tc>[-NNN].wav` (not `<parent folders>_<track>.wav`).
- **Project vs export folder**: Export folder may drop suffixes like `TEST_002` - match by prefix.
- **Null test**: MIDI randomizers make sample-accurate nulls impossible. Checker downgrades to WARN on envelope pass (`>=0.90` corr, `|gain|<=3dB`) unless `--strict`.
- **Ignore**: `peaks/`, `*.reapeaks`, `.DS_Store`, video files, files > `max_file_mb`, `-bak`, `.rpp-bak`, `Backups/`, `.RPP-PROX`.
- **Atomicity**: Never delete/overwrite outside temp/staging until copy is complete and verified.
- **Safety**: Don't touch `reaper.ini`, `reaper-*.ini`, or anything outside `tools/`. Don't edit `../jk_export.lua`.

## Next Steps
1. Implement `nightly.py` with fake REAPER + fake Lua for tests
2. Add launchd plist, `install.sh`, `uninstall.sh` (no auto-load)
3. Add tests for nightly flow (state tracking, retries, timeout, kill on hang)
4. Keep everything under `tools/`, follow the same patterns (no console spam on success, one summary, non-zero on failure)