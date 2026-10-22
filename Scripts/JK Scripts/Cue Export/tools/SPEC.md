# Cue Export: external tools spec

Hand-off spec for the pieces that live outside REAPER. Claude owns the Lua in
`../jk_export.lua`; do not edit it. Everything here is plain Python 3 (numpy and
soundfile are installed; `mido` is not, so write a small MIDI reader or use a venv)
and shell. Nothing here has been run against real exports yet, so treat the file
naming below as a contract and report anything that does not match real files.

## 0. Ground rules
- No console spam on success; one summary at the end. Non-zero exit on failure.
- Never delete or overwrite anything outside a temp dir until the new copy is complete.
- Put code in this `tools/` folder. One file per tool, plus `tests/` with synthetic fixtures
  (generate small WAVs and MIDI files in the tests, do not commit audio).
- Do not touch `reaper.ini`, `reaper-*.ini`, or any file outside `tools/`.

## 1. What the Lua scripts write (the contract)
`<exports>` is `<project folder>/exports/<project>/`. `<tc>` is a timecode like
`10.01.05.17` (dots; the project has a 10:00:00:00 offset). `<project>` looks like
`1M01 - Grey Ghost - v01.01.08 TEST_002`.

IMPROVE and ORCH (`<exports>/<project> IMPROVE/` and `... ORCH/`):
- `<project> - <tc> - <track>.wav` : one stem per marked track, un-normalized
- `_<project> - <tc> - MASTER.wav` : normalized per the Film Master preset
- `_<project> - <tc> - MIX MINUS.wav` : master with the marked stems muted, un-normalized
- `_<project> - <tc> - CLICK.wav`
- `_<project> - <tc> - IMPROVE.mid` or `ORCH.mid` : one multichannel MIDI file

MULTITRACK (`<exports>/<project> MULTITRACK/`):
- top level: `_<project> - <tc> - MASTER REF.wav` (un-normalized), `_... CLICK.wav`,
  `_... TEMPO MAP.mid`, `_... MIDI.mid` (type 1, one MTrk per MIDI track)
- `DRY/` and `WET/`: one stem per leaf track, named `<parent folders>_<track>.wav`-style
  (REAPER `$folder[_]_$track`); `DRY/` also has `<project> - <tc> - FX RETURN.wav`
- Anything starting with `_` is a reference file, not a stem.
- Dry/wet relationship: sum of DRY stems + FX RETURN should null against MASTER REF
  (up to gain); sum of WET stems should too.
- The click must never be audible in MASTER, MIX MINUS, MASTER REF or any stem.

## 2. Tool A: stem checker (`check_stems.py`)
Usage: `check_stems.py <export folder> [--report report.md] [--json report.json]`.
Accepts an IMPROVE/ORCH folder, a MULTITRACK folder, or a parent containing several.
Per folder it reports PASS / WARN / FAIL:

1. Inventory: expected reference files present; stems listed; stray files (for example a
   file named `_dry - ...` or an unnamed stem) flagged.
2. Format: sample rate, bit depth, channel count, and length per file; all stems in a
   folder must match each other and the references. Length mismatch FAIL.
3. Empty stems: peak below -90 dBFS FAIL, below -60 dBFS WARN; list the file.
4. Clipping: any sample at or beyond full scale WARN.
5. Normalization: stems whose peak sits at the same level (within 0.1 dB) across many
   files WARN as "looks normalized"; MASTER's level reported (target is -24 per preset,
   but report peak and integrated RMS and do not hard-fail).
6. Null test, IMPROVE/ORCH: stems + MIX MINUS against MASTER, with best-fit gain
   (MASTER is normalized, so solve least squares for one gain). Report residual in dB
   relative to MASTER; under -60 dB PASS, under -40 WARN, else FAIL.
7. Null test, MULTITRACK: sum(DRY stems) + FX RETURN against MASTER REF (no gain needed,
   but still report best-fit gain), same for sum(WET stems).
8. Click bleed: project CLICK onto MASTER, MIX MINUS, MASTER REF and every stem
   (normalized cross-correlation at lag 0 after aligning start, or least squares gain).
   Gain above 0.02 WARN, above 0.1 FAIL.
9. MIDI: parse every `.mid`; report track count, channel use, note count, tempo changes,
   time signatures, markers, and a SMPTE offset event; FAIL if the file has no tempo or no notes
   where notes are expected (`TEMPO MAP.mid` is allowed to have no notes).

Output: a short markdown table per folder, plus the JSON. Exit 0 PASS or WARN, 1 on FAIL.
There is an old click-projection script at
`/private/tmp/claude-501/-Users-jonathankawchuk-Library-Application-Support-REAPER-Scripts-JK-Scripts/a0304d90-0dc1-4e0b-93eb-0fbf969628ae/scratchpad/analyze.py`
(scratchpad, may be gone) as a starting point for step 8.

## 3. Tool B: Dropbox backup (`dropbox_backup.py`)
Dropbox root: `/Users/jonathankawchuk/Library/CloudStorage/Dropbox`.

Layout, per film (a config entry, see section 5):
```
<root>/<Film>/MASTER PROJECT/<Film> - MASTER.rpp
<root>/<Film>/MASTER PROJECT/_previous/<Film> - MASTER <YYYY-MM-DD>.rpp   (keep newest 3)
<root>/<Film>/CUES/<cue number> - <cue name>/<latest project>.rpp
<root>/<Film>/CUES/<cue number> - <cue name>/MULTITRACK/...                (replaced each run)
<root>/<Film>/CUES/<cue number> - <cue name>/IMPROVE/ and ORCH/           (optional, per config)
```
Rules:
- Cue number is the leading token of the project name matching `^\d+M\d+[A-Za-z]?`
  (`1M01`, `2M03B`). The rest of the cue folder name is the text between the cue number
  and the version token (`v01.01.08`): `1M01 - Grey Ghost`. If a cue folder already exists
  for that number, reuse it.
- "Latest project" for a cue number = newest modified `.rpp` in the film's cue-projects
  folder whose name starts with that cue number, ignoring `-bak`, `.rpp-bak`, `Backups/`.
  Only that RPP is kept in the Dropbox cue folder (older RPPs there are removed after
  the new one is in place).
- Replace safely: copy into `<cue folder>/.incoming-<random>/`, verify file count and
  sizes, rename the old folder to `.old-<random>`, rename the new folder into place,
  then delete the old. If anything fails, leave the previous backup untouched and exit 1.
- Only run a cue's replace if that cue's export folder exists and the checker report (if
  one was produced) has no FAIL. `--force` overrides.
- Never copy video files or anything over a size limit in the config (`max_file_mb`).
- Master project: just the RPP, via the same copy-then-swap, plus the `_previous` rotation.
- `--dry-run` prints what would happen. `--film <name>` limits to one film.

## 4. Tool C: nightly supervisor (`nightly.py` + launchd plist)
Goal: render the most recent version of each project that changed today, then back it up.

Flow per run (manual `nightly.py --now`, scheduled, or watch-triggered):
1. Read the config. For each film, find cue projects modified since the last successful
   run (state file `tools/state.json`).
2. For each project, write `Cue Export/batch/job.json` (below), launch REAPER on that
   project, wait for `Cue Export/batch/done.json` or the timeout, then quit REAPER.
3. If REAPER exits early, hangs past the timeout, or `done.json` says failed: kill REAPER,
   log it, retry once, then mark the project failed and continue with the next.
4. After a successful render, run the checker, then the Dropbox backup for that cue.
5. At the end: write `tools/logs/<date>.log` and send a macOS notification (osascript)
   listing succeeded and failed projects.

REAPER launch: `/Applications/REAPER.app/Contents/MacOS/REAPER -nosplash <project.rpp>`
(or `open -a`; test which behaves). Unknowns to test before trusting unattended:
(a) crash-recovery prompt on the next launch, (b) whether a second instance is opened if
the user already has REAPER running (refuse to run if REAPER is already running unless
`--allow-running`), (c) macOS permission prompts.

`job.json` (written by the supervisor, read by Claude's Lua startup action, TODO on the
Lua side; build the supervisor against this contract with a fake Lua side for tests):
```json
{ "project": "/abs/path/1M01 - Grey Ghost - v01.01.08.rpp",
  "jobs": ["improve", "orch", "multitrack_dry", "multitrack_wet"],
  "midi": true, "done_file": "/abs/path/Cue Export/batch/done.json" }
```
`done.json`: `{ "status": "ok" | "failed", "message": "...", "folders": ["/abs/export/dir"] }`.

Scheduling: a LaunchAgent plist (`~/Library/LaunchAgents/`) with `StartCalendarInterval`
for the nightly time, optional `WatchPaths` for the cue-projects folder, and a note on
`pmset repeat wakeorpoweron` to wake the Mac a few minutes earlier. Provide `install.sh`
and `uninstall.sh`; do not load anything into launchd yourself without being asked.
Delays and timeouts live in the config, not in REAPER render templates.

## 5. Config (`tools/config.json`)
```json
{
  "dropbox_root": "/Users/jonathankawchuk/Library/CloudStorage/Dropbox",
  "reaper_app": "/Applications/REAPER.app",
  "nightly_time": "02:00",
  "project_load_wait_s": 60,
  "project_timeout_s": 1800,
  "retries": 1,
  "max_file_mb": 2000,
  "films": [
    { "name": "Hunt for the Grey Ghost",
      "cue_projects_dir": "/Users/jonathankawchuk/Documents/Projects/Film/Hunt for the Grey Ghost/HGG Reaper Projects",
      "master_project": "/path/to/master video project.rpp",
      "backup_improve_orch": false }
  ]
}
```
Ship a `config.example.json`; the real `config.json` is git-ignored. Validate it with clear
errors. Film folders are one subfolder per cue (for example `1M01 - Grey Ghost/`) holding
the `.rpp` files, with exports under `<cue folder>/exports/`.

## 6. Order of work
1. `check_stems.py` + tests (no dependencies on the rest).
2. `dropbox_backup.py` + tests using a temp dir as the fake Dropbox.
3. `nightly.py` with a fake REAPER executable and fake Lua side, then plist + install scripts.
Report what you assumed whenever the real files differ from section 1.
