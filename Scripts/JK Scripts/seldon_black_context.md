# Seldon Black JSFX — Session Context

## File
`Effects/JK fx/seldon_black.jsfx`

## What it does
Recreates Bear McCreary's "Seldon Black" algorithmic orchestra effect from Foundation.
- Receives MIDI note input → tracks held notes (for pitch source) → scatters notes across random octaves on random channels
- Pitch class always preserved from input (not chromatic random) — stays musical
- If no MIDI input is held, uses the Fallback Note slider (standalone mode)
- Does NOT pass through note-ons/offs — only generated notes go to destinations
- Non-note MIDI (CC, pitch bend) does pass through

## Parameters (sliders) — current: 18 sliders

| # | Slider | Default | Range | Purpose |
|---|---|---|---|---|
| 1 | Bottom Octave | 0 | -4 to 4 | Min octave offset from input note |
| 2 | Top Octave | 0 | -4 to 4 | Max octave offset. Notes pick random octave between Bottom and Top |
| 3 | Rate | 16 | 0.25–64, step 0.25 | Steps per beat (Sub mode) or beats per note (Slow mode) |
| 4 | Probability | 70 | 0–100% | Chance each step fires |
| 5 | Note Len Min (% of step) | 10 | 1–100 | Shortest note as % of step (used when Mode=0) |
| 6 | Note Len Max (% of step) | 40 | 1–100 | Longest note as % of step (used when Mode=0) |
| 7 | Instruments (MIDI ch 1-N) | 16 | 1–16 | How many MIDI channels to spread notes across |
| 8 | Max Velocity | 90 | 1–127 | Upper velocity bound |
| 9 | Min Velocity | 30 | 1–127 | Lower velocity bound |
| 10 | Fallback Note | 60 | 0–127 | MIDI note used when no input held (standalone, default C4) |
| 11 | Jitter Min | 0 | 0–200ms | Min timing offset per note onset |
| 12 | Jitter Max | 50 | 0–200ms | Max timing offset. 63–128ms matches original v0.1 feel |
| 13 | Rate Mode | 0 | 0 or 1 | 0=Sub/beat (rate_val steps per beat), 1=Beats/note (rate_val beats between notes) |
| 14 | Note Len Mode | 0 | 0 or 1 | 0=% of step (sliders 5/6), 1=absolute ms (sliders 15/16) |
| 15 | Note Len Min (ms) | 100 | 1–2000ms | Shortest note in ms (used when Mode=1) |
| 16 | Note Len Max (ms) | 500 | 1–2000ms | Longest note in ms (used when Mode=1) |
| 17 | Voices per Trigger | 1 | 1–8 | Notes fired per step (each voice independently random) |
| 18 | Mono Ch | 0 | 0 or 1 | 0=poly (stack), 1=mono per channel (releases existing note before firing) |

## Rate formula
- Mode 0 (Sub/beat): `step = 4.0 / rate_val` — higher rate_val = faster (e.g. 16 = 16th notes)
- Mode 1 (Beats/note): `step = rate_val` — higher rate_val = slower (e.g. 4 = one note per bar)

## Note Length formula
- Mode 0 (% of step): `ne = sb + step * random(len_min, len_max)`
- Mode 1 (ms): `ne = sb + len_ms / 1000 * tempo / 60`

## REAPER routing (user's setup — track 18 "seldon")
- Sends to track 19: MIDI ch 1 → All
- Sends to track 20: MIDI ch 2 → All
- Sends to track 21: MIDI ch 3 → All
- Track channels: 4, Master send: All → 1-4

## Known issues / resolved

### 1. MIDI passthrough — FIXED
The JSFX was passing all note-ons/offs through alongside generated notes, causing
instruments to double-trigger. Fixed: only non-note MIDI passes through now.
`(st != 0x90 && st != 0x80) ? midisend(moff, msg1, msg2, msg3);`

### 2. Channel display stale — FIXED
@gfx now reads `slider7` directly (disp_ch) instead of `num_ch`, which avoids the
@slider/@gfx threading lag that showed wrong channel count.

### 3. 1e-9 syntax error in EEL2 — FIXED
EEL2 does not support scientific notation with negative exponents.
Replaced `1e-9` with literal `0.000000001`.

### 4. MIDI even channels — UNDER INVESTIGATION
User observed channels appear as even numbers in REAPER channel strip.
JSFX outputs on consecutive channels 1–N. Likely REAPER maps MIDI channels to
stereo audio output pairs. Separate tracks (19, 20, 21) with MIDI ch 1, 2, 3 filters
look correct — "even channels" observation may have been about something else.

## Original reference
- Bear McCreary + Jonathan Snipes (prototype) + Jacob Moss (plugin port)
- Two known fan implementations: "The Moss Mod v2" (Logic), "Seldon Black v0.1"
- Moss Mod: Bottom Ch, Top Ch, Bottom Octave, Top Octave, CC1 Velocity, Length, Probability, Tempo Sync, Time Sync, Sync Switch
- v0.1: jitter (ms range), octave (range), length (ms range), velocity, probability, note, modifier, output midi channels (range), sync type (ms/note)

## Sandstorm starting point
Rate 32, Prob 65%, Len Min 5% / Max 20%, Octave -2/+2, Jitter 63–128ms

## EEL2 / JSFX notes
- No scientific notation: use `0.000000001` not `1e-9`
- `@block` and `@gfx` run on different threads — avoid reading @slider vars in @gfx
- `beat_position`, `tempo`, `srate`, `samplesblock`, `play_state` are built-ins
- `play_state == 1 || play_state == 5` = playing or recording
- MIDI channels are 0-indexed internally: `0x90 | ch` where ch is 0–15
- Note buffer: `note_buf[i*3]` = note, `[i*3+1]` = channel, `[i*3+2]` = end_beat
- Held buffer starts at offset `MAX_NOTES * 3` in JSFX memory
