# Cue Export tools: notes and findings

Working notes for the tools in this folder.  Everything here was checked against
the real exports that exist on disk, not only against SPEC.md.

## The export that was used

    /Users/jonathankawchuk/Documents/Projects/Film/Hunt for the Grey Ghost/
      HGG Reaper Projects/1M01 - Grey Ghost/exports/
        1M01 - Grey Ghost - v01.01.08/
          1M01 - Grey Ghost - v01.01.08 IMPROVE/
          1M01 - Grey Ghost - v01.01.08 MULTITRACK/
          1M01 - Grey Ghost - v01.01.08 ORCH/

96 kHz, PCM_24, stereo, 7 647 648 frames (79.663 s).  Rendered 2026-10-17.

Note that the render predates the current `jk_export.lua` (committed
2026-10-20), so a couple of the differences below are "old export" artefacts
rather than things the Lua still does.

## Where the real files differ from SPEC.md section 1

1. **The click carries a timecode one frame later than everything else.**
   Every stem and reference is `10.01.05.17`; the click is `10.01.05.18`, in
   all three folders.  The checker has a `timecode` check for it (WARN).

2. **MULTITRACK stem names are not `<parent folders>_<track>.wav`.**
   The real names are
   `<folders>_<track> dry|wet - <project> - <tc>[-NNN].wav`, because the
   `Film Multitrack Dry` / `Film Multitrack Wet` presets use the pattern
   `$folder[_]_$track dry - $project - $starttc` and the Lua only overrides the
   directory.  REAPER also appends `-001`, `-002`, `-003` when several items in
   one folder produce the same file name (three "Marimba 7" items here).

3. **The MIDI file is optional.**  `MIDI.mid` is only written when the cue has
   MIDI in range, and the `IMPROVE.mid` / `ORCH.mid` files likewise.  A missing
   MIDI file is a WARN, not a FAIL.

4. **The project file name and the export folder name do not match.**
   The project on disk is `1M01 - Grey Ghost - v01.01.08 TEST_002.RPP` (upper
   case extension) next to `TEST_001.RPP`, but the export folder and every
   file inside it use `1M01 - Grey Ghost - v01.01.08`, with no `TEST_002`.
   SPEC.md says `<project>` "looks like `1M01 - Grey Ghost - v01.01.08
   TEST_002`", so either the export predates the rename, or the Lua strips the
   suffix.  **The nightly supervisor and the Dropbox backup need to agree on
   this before they can match a cue project to its export folder.**

5. **There are `peaks/` sub-folders, `*.reapeaks` files and `.DS_Store`
   files** next to the renders.  The checker ignores them.

6. **The click render is 8 samples shorter than the stems**
   (7 647 640 vs 7 647 648 frames).  The checker allows 1 ms of difference
   (`LENGTH_TOLERANCE_S`).

7. **The MIDI files in this export have no SMPTE offset event**, and the tempo
   map's first time signature decodes as 8/64 (num 8, dd 6) although the
   project is `BEATLEN 4` (4/4).  The current `jk_export.lua` does write an
   SMPTE offset (`smpte_offset()` in the tempo track), so this is an old-export
   artefact; the time-signature byte looks like the old Lua wrote the
   denominator straight into the `dd` byte instead of `log2(denominator)`.

8. **The MASTER is not at the preset's -24 dBFS target.**  The `Film Master`
   preset normalizes to -24 dBFS peak with a brickwall limiter; the real
   MASTER peaks at **-7.88 dBFS** with an integrated RMS of -27.58 dBFS.
   Per the spec this is reported, not failed.

## The null test cannot pass sample-accurately on this project

`1M01 - Grey Ghost - v01.01.08 TEST_002.RPP` contains MIDI-randomizing
plugins: `JK fx/midi_random_poly_filter.jsfx`,
`JK fx/midi_randomize_note_length.jsfx`, `IX/MIDI_Tool II`,
`pandabot/gaussian_humanization` and `schwa/midi_humanizer`.  Every render
therefore differs from every other render sample by sample, so a
sample-accurate null between two renders of the same material is impossible by
construction.

Measured on the real files:

| pair | sample correlation |
| --- | --- |
| MASTER vs MIX MINUS | 0.08 |
| MASTER vs (stems + MIX MINUS) | 0.08 (best-fit gain -21.8 dB) |
| DRY render vs WET render of the same MIDI track | 0.000 - 0.067 |
| DRY render vs WET render of the same recorded-audio track | 1.0000 |

In the envelope domain (10 ms RMS) the nulls hold:

| null | env corr | env gain | env residual |
| --- | --- | --- | --- |
| IMPROVE: (stems + MIX MINUS) vs MASTER | 0.928 | -1.87 dB | -11.2 dB |
| ORCH: (stems + MIX MINUS) vs MASTER | 0.928 | -2.18 dB | -11.2 dB |
| MULTITRACK: (DRY + FX RETURN) vs MASTER REF | 0.928 | -0.59 dB | -11.2 dB |
| MULTITRACK: WET vs MASTER REF | 0.934 | -0.40 dB | -11.2 dB |

The -1.87 dB is the Film Master normalization gain, which is exactly what the
least-squares fit is supposed to recover.

**What the checker does:** the sample-accurate residual is still the metric the
spec asks for, but when it fails and the envelope test passes
(`corr >= 0.90`, `|gain| <= 3 dB`) the result is downgraded to WARN with the
reason spelled out.  `--strict` grades the sample-accurate residual only, as
the spec describes it.

## Click bleed

The click is a **train** of ~117 clicks over 79.66 s (1 kHz, ~4 ms decay,
peak 0.5, RMS -34.5 dBFS), not a single impulse, so it is projected onto each
target with a least-squares gain at a small set of candidate lags (0 and one
frame either side at 24/25/30 fps).

Searching thousands of candidate lags and keeping the best one is *not* safe
here: picking the noisiest lag inflates the measured gain by an order of
magnitude.  With the fixed lag set the measured gain on the real export is
0.0000 - 0.0026, i.e. no bleed, against thresholds of 0.02 (WARN) and 0.1
(FAIL).

## Things still to settle

- The click's one-frame timecode offset: is it only the timecode string, or is
  the click actually rendered a frame late?  The checker allows for both.
- `<project>` with or without the `TEST_002` suffix (finding 4).
- Whether the 8/64 time signature in the tempo map is a Lua bug (the current
  Lua converts the denominator with `log2`, which looks right).
