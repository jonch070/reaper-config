# JK FX: Script Reference

| File | Type | Purpose | Status |
|------|------|---------|--------|
| `outdated/midi_discrete_output_router` | JSFX | Route each note to one random MIDI channel | Superseded by v2 |
| `outdated/midi_discrete_output_router_multi` | JSFX | Route each note to multiple channels at once | Superseded by v2 |
| `midi_discrete_output_router_v2` | JSFX | Chord-aware routing with per-channel polyphony control | Current |
| `midi_random_poly_filter.jsfx` | JSFX | Filter a chord down to N random notes (same channels) | Current |
| `midi_randomize_note_length.jsfx` | JSFX | Randomize note durations; legato mode; tempo-sync | Current |
| `midi_note_chance.jsfx` | JSFX | Percentage chance each note-on passes through or is dropped | Current |
| `OctaveFoldRange.jsfx` | JSFX | Force notes into a range by octave-folding | Current |
| `OctaveSpread.jsfx` | JSFX | Spread a chord across a range with voice leading | Current |
| `ChordVoiceGlide.jsfx` | JSFX | Glide every chord tone to the matched tone of the next chord (MPE) | Current |
| `seldon_black.jsfx` | JSFX | Stochastic orchestral note generator (transport-synced) | Current |
| `Tintinnabulator.jsfx` | JSFX | Tintinnabuli T-voice generator (Arvo Pärt), port of the Max `Tintinnabulator 1.3.amxd` | Current |
| `outdated/claude jsfx-random-arp.jsfx.lua` | JSFX (misnamed) | Debug-build arpeggiator | Outdated |
| `OctaveFoldRange.jsfx.rpl` | Preset | Saved preset for OctaveFoldRange | n/a |

---

## Router family

These three scripts share the same core idea, randomly assigning incoming notes to MIDI output channels, but each generation adds capability.

### `midi_discrete_output_router` (v1)

Each note-on is routed to exactly **one** randomly chosen channel. On note-off, the note goes back to the same channel it was sent on. The channel is then held busy for a configurable time before it's available again.

**Sliders:** Channels (2–16), Skip channel (e.g. LFE on ch4), No Repeat (history depth), Hold (ms).

**Limitation:** one channel per note, no awareness of chords arriving together.

**Superseded by v2.** Useful only if you want the absolute simplest version with no overhead.

---

### `midi_discrete_output_router_multi`

Extends v1 by routing each note to **multiple** channels simultaneously (Min Copies–Max Copies). On note-off, the note-off is fanned out to all channels the note was sent on.

**Added sliders:** Min Copies, Max Copies.  
Uses partial Fisher-Yates to pick a random subset of channels without replacement.

**Limitation:** still processes notes individually, so notes arriving as a chord are treated as separate events. No per-channel polyphony tracking.

**Superseded by v2,** which handles chords correctly and controls how many notes each channel receives.

---

### `midi_discrete_output_router_v2` (current, most capable)

Buffers notes that arrive within a **Chord Window** (ms), then routes the entire chord at once. Independently controls:

- **How many channels** the chord is spread across (Min/Max Channels; Fixed or Random mode)
- **How many notes per channel** (Min/Max Poly; Fixed or Random mode)

Tracks live note count per channel so it respects the polyphony ceiling even when notes overlap. Handles All Sound Off / All Notes Off CC messages. Live channel activity display in the GFX panel.

**Added sliders:** Min/Max Channels, Channel Mode, Min/Max Poly/ch, Poly Mode, Chord Window (ms).

**Use this one.** It is a strict superset of both v1 and multi. You are not missing any functionality by discarding them.

To replicate v1 in v2: Channel Mode = Fixed, Max Channels = 1, Poly Mode = Fixed, Max Poly = 1, Chord Window = 1ms.  
To replicate multi in v2: Channel Mode = Random, Min/Max Channels = your old Min/Max Copies, Poly Mode = Fixed, Max Poly = 1, Chord Window = 1ms.

---

## Other processors

### `midi_random_poly_filter.jsfx`

Does **not** reroute to different channels. Instead, it buffers notes arriving within a Chord Window and randomly selects a subset to **pass through**, discarding the rest. Note-offs are suppressed for notes that were filtered out.

- Fixed mode: exactly Max notes pass.
- Random mode: a random count between Min and Max passes.

Pair with the v2 router if you want to thin a dense chord before spreading it across instruments.

---

### `midi_randomize_note_length.jsfx`

Intercepts note-ons and schedules a synthetic note-off at a random time between Min and Max length. The original note-off from the keyboard is always suppressed, so note duration is entirely controlled by this plugin.

- Min and Max can each be set independently in **ms** or a **tempo-synced grid division** (1/1 through 1/128).
- **Legato mode:** when a new note arrives outside the Chord Window, all currently active notes are cut immediately (phrase boundary behaviour). Notes within the window are treated as a chord and don't cut each other.

Pitch, velocity, and channel pass through unchanged.

---

### `OctaveFoldRange.jsfx`

Constrains all incoming notes to a user-defined MIDI note range by octave-folding: notes below the floor are shifted up by 12 semitones repeatedly until they're in range; notes above the ceiling are shifted down. If the range is smaller than an octave, the result is clamped to the nearest boundary.

Simple and deterministic, no randomness. `OctaveFoldRange.jsfx.rpl` is a saved preset file for this plugin.

---

### `OctaveSpread.jsfx`

Opposite of OctaveFoldRange. Takes a compact chord and spreads each voice across a defined note range by choosing the best octave for each pitch class.

**First chord:** voices are distributed evenly across the range (e.g. C4/E4/G4 with range C2–C7 → C2, E4, G6).

**Subsequent chords:** each voice moves to the nearest available octave of its pitch class, minimising semitone movement, so voice leading emerges automatically across chord changes.

**Sliders:** Min Note, Max Note (shown as note names in the GFX), Chord Window (ms).

The range display in the GFX panel shows note names (e.g. `C2 – C7`). The top voice reaches as high as the highest in-range octave of its pitch class. If your top note is G and the range ceiling is C7, the top voice goes to G6 (91), not C7 (96). This is correct: the ceiling is the hard limit, not a target.

Note-offs are remapped to the dispatched pitch. Original note-ons are suppressed. All Notes Off resets voice leading history so the next chord gets the even-spread treatment again.

---

### `ChordVoiceGlide.jsfx`

Polyphonic pedal steel. Hold a chord, play the next one, and every voice of the old chord glides to a tone of the new one, matched by voice leading rather than by the synth's voice-steal order. Output is MPE: one voice per member channel, each with its own pitch bend ramp.

Sibling to `OctaveSpread`, which solves the same voice-leading problem by re-articulating at a new octave. This one solves it by bending, so nothing retriggers.

**Signal path.** Place it before an MPE-capable synth in the same FX chain (Serum 2, Surge XT, Vital, Pigments, Diva, Omnisphere 2.6+). Input notes arrive on any channel. Three things to set on the synth side:

1. Put the synth in MPE mode.
2. Match its per-note bend range to Synth Bend Range. 48 semitones is the MPE default and gives the most headroom.
3. Turn the synth's own portamento **off**. This plugin does the gliding.

**Matching.** Both chords are sorted by pitch and matched in order. For points on a line that is provably the minimum-total-distance pairing, and it cannot produce voice crossings, so no permutation search is needed. Unequal chord sizes run through an alignment DP that can also release a voice or articulate a new one mid-sequence.

**Max Glide Interval is the musical control,** not a safety limit. A voice glides when the move is smaller than it, otherwise the voice is released and the new tone starts fresh:

| C major → A minor | result |
|---|---|
| 3 | hold C and E, release G, articulate A (classical voice leading) |
| 12 | C→A, E→C, G→E, whole chord slides (pedal steel) |

Default is 12. Higher values slide more of the chord in parallel; lower values hold common tones and rearticulate only the voice that actually moves.

**Sliders:** Voice Mode (Legato / Latch), Glide Timing (ms or tempo-synced), Glide Time, Glide Time (synced), Glide Shape (Linear / Smooth S / Ease out / Ease in), Chord Detect Window (ms), Max Glide Interval, Synth Bend Range, First Voice Channel, Voice Count, Send MPE Config, Pass CC to master ch, Panic.

Behaviour notes:

- **Bend accumulates** across chord changes rather than resetting. A long stepwise climb stays on one voice until it approaches the bend ceiling, at which point the alignment DP rejects the pairing and that voice rearticulates on a fresh channel.
- **Channel allocation is round robin,** so a channel is never reused the instant it is freed. This avoids an MPE synth applying the new bend to a still-releasing note.
- **Legato mode** ends all voices when every key is up and the sustain pedal is off. **Latch mode** holds voices until the next chord; sustain pedal release or CC 120/123 stops them.
- Playing the same chord twice does nothing audible. This is a glide device, it does not retrigger.
- Chords commit after the detect window expires, so there is latency equal to that window. Lower it if you play tight, raise it if you spread.
- New tones past the Voice Count are dropped silently.
- The player's own pitch wheel and channel pressure are forwarded to the MPE master channel, so they still work globally without fighting the per-voice bends.

GFX shows every sounding voice: channel, root note, live bend in semitones, target, and a glide progress bar.

---

### `seldon_black.jsfx`

A stochastic **note generator** rather than a processor. It reads held MIDI notes as pitch material and fires events at a tempo-synced rate, scattering each event across random octaves and random channels.

Key controls:

- **Bottom/Top Octave** offset: range of octaves to scatter across (relative to input note octave)
- **Rate**: step speed (subdivisions per beat, or beats per note)
- **Probability**: chance each step fires at all
- **Channels per Trigger**: how many channels fire simultaneously each step
- **Voices per Channel**: polyphony per channel per step
- **Mono Ch**: each channel kills its previous note before firing a new one
- **Jitter**: timing randomisation in ms
- **Unique Notes**: prevent the same pitch appearing on two channels in one step
- **No Ch Repeat**: avoid re-using channels from the previous step
- **Note Length**: as % of step or ms; randomised between Min and Max
- **Fallback Note**: used when no MIDI is held

Requires transport to be running. All non-note MIDI (CC, pitch bend) passes through unchanged.

---

### `Tintinnabulator.jsfx`

Port of the Max for Live device **Tintinnabulator 1.3** (miltonline). You play the M-voice (melody); the plugin derives a T-voice that only plays notes of a fixed triad spread across the keyboard, landing on the nearest chord-tone note(s) to each M-voice note.

- **Mode** = T-voice position relative to the melody: 2 Below / 1 Below / 1 Above / 2 Above (the original's 2inf / 1inf / 1sup / 2sup), plus **Orbit** (alternates 1 Below / 1 Above per note, the device's ± control) and **Random** (random position each note, the device's ? control).
- **Chord** = Minor (0-3-7) or Major (0-4-7); **Root** = the triad's base note (note-name shown in GFX).
- **Delay (beats)** = tempo-synced delay before the T-voice sounds (0 = immediate). T-note-offs track the input note lifetime, including retriggers and ultra-short notes.
- **Manual T** = played keys are emitted directly as the T-voice (no generation, no M passthrough). Play the T-voice by hand.
- **T Input Channel** (0=off, sidechain): notes arriving on that MIDI channel are emitted directly as the T-voice, while notes on other channels keep driving the melody/generator. Works independently of Manual T; keyswitches only apply on melody channels.
- **T Channel** = route the T-voice to a fixed MIDI channel, or Follow the input.
- **Keyswitch Lo** (0=off): every note *below* it is swallowed as a control key. Octave 1 = root pitch class, octave 2 = mode / chord / manual-T / M-mute, octave 3 = delay beats.
- **M-Voice Mute** / **T-Voice Mute** silence either voice independently.
- All Notes Off / All Sound Off flush pending delayed notes.
- GFX shows the tone set strip with M (blue) and T (orange) highlighted, plus a live keyswitch legend.

---

## Outdated / draft

### `claude jsfx-random-arp.jsfx.lua` (outdated)

A debug-build arpeggiator generated by Claude (note the `claude` prefix and `[DEBUG BUILD]` in the description). It is JSFX code with a `.lua` extension appended by mistake.

Functional concept: holds a set of input notes, fires them one at a time in random order with note/channel history lockout, velocity humanization, and timing jitter. Has a Hold Mode (latch) and an extensive in-plugin debug log display.

**Why outdated:**

- The debug scaffolding (`debug_log` calls on every code path, GUI debug panel) was never stripped, so it runs overhead every sample and block.
- Uses a hand-rolled LCG random (`my_rand()`) instead of REAPER's built-in `rand()`.
- Incorrect file extension (`.jsfx.lua`) means REAPER may not recognise it as a JSFX plugin.
- The arpeggiator use case is partially covered by `seldon_black.jsfx` with more controls.

Safe to delete or archive once you've confirmed nothing depends on it.
