"""Synthetic WAV and MIDI fixtures for the Cue Export tool tests.

Nothing here touches a real export: every file is generated into a temporary
directory so the tests can run anywhere and no audio is ever committed.

The levels are deliberately low.  The click-bleed estimator divides the click's
energy by the target's noise, so its precision depends on how much of the
target's energy the click carries; a fixture with hot, loud stems would make
the estimator noisier than it is on a real 80-second cue.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

# Make `check_stems` and `smf` importable from the tests.
TOOLS = Path(__file__).resolve().parent.parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

SR = 48000
DURATION = 4.0
FRAMES = int(DURATION * SR)
PROJECT = "1M01 - Test Cue - v01.01.08"
TIMECODE = "10.01.05.17"

# Peak levels (dBFS) used by the default fixtures.
STEM_A_DB = -30.0
STEM_B_DB = -36.0
MIX_MINUS_DB = -33.0
FX_RETURN_DB = -45.0


# ---------------------------------------------------------------------------
# audio
# ---------------------------------------------------------------------------
def tone(duration: float, freq: float = 220.0, sr: int = SR, amp: float = 0.5,
         phase: float = 0.0) -> np.ndarray:
    """A mono sine."""
    t = np.arange(int(round(duration * sr))) / sr
    return amp * np.sin(2.0 * np.pi * freq * t + phase)


def noise(duration: float, sr: int = SR, amp: float = 0.2, seed: int = 0) -> np.ndarray:
    """Mono noise."""
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, amp, int(round(duration * sr)))


def click_train(duration: float, every: float = 0.25, sr: int = SR, amp: float = 0.5,
                decay: float = 0.004) -> np.ndarray:
    """A train of clicks, like REAPER's click source: 1 kHz, 4 ms decay."""
    n = int(round(duration * sr))
    out = np.zeros(n)
    click_len = max(2, int(round(0.02 * sr)))
    env = np.exp(-np.arange(click_len) / max(1.0, decay * sr))
    step = max(1, int(round(every * sr)))
    for start in range(0, n, step):
        end = min(n, start + click_len)
        out[start:end] += amp * env[:end - start] * np.sin(
            2.0 * np.pi * 1000.0 * np.arange(end - start) / sr)
    return out


def stereo(mono: np.ndarray, sr: int = SR, pan: float = 0.0) -> np.ndarray:
    """Turn a mono signal into a stereo pair with a simple pan."""
    left = np.cos((pan + 1.0) * np.pi / 4.0)
    right = np.sin((pan + 1.0) * np.pi / 4.0)
    return np.column_stack([mono * left, mono * right])


def at_peak(data: np.ndarray, peak_dbfs: float) -> np.ndarray:
    """Scale a signal so its loudest sample sits at `peak_dbfs`."""
    loudest = float(np.abs(data).max())
    if loudest <= 0:
        return data
    return data * (10.0 ** (peak_dbfs / 20.0) / loudest)


def write_wav(path: Path, data: np.ndarray, sr: int = SR,
              subtype: str = "PCM_24") -> Path:
    """Write a WAV file and return its path."""
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(path), data, sr, subtype=subtype)
    return path


# ---------------------------------------------------------------------------
# MIDI
# ---------------------------------------------------------------------------
def _vlq(value: int) -> bytes:
    out = bytearray([value & 0x7F])
    value >>= 7
    while value:
        out.insert(0, (value & 0x7F) | 0x80)
        value >>= 7
    return bytes(out)


def _chunk(tag: bytes, body: bytes) -> bytes:
    return tag + struct.pack(">I", len(body)) + body


def _meta(meta_type: int, payload: bytes) -> bytes:
    return b"\xFF" + bytes([meta_type]) + _vlq(len(payload)) + payload


def _tempo_event(bpm: float) -> bytes:
    micros = int(round(60_000_000.0 / bpm))
    return _meta(0x51, bytes([(micros >> 16) & 0xFF, (micros >> 8) & 0xFF, micros & 0xFF]))


def _time_signature_event(numerator: int, denominator: int) -> bytes:
    dd = int(round(np.log2(denominator)))
    return _meta(0x58, bytes([numerator, dd, 24, 8]))


def _smpte_offset_event(hours: int = 10, minutes: int = 1,
                        seconds: int = 5, frames: int = 17) -> bytes:
    return _meta(0x54, bytes([hours, minutes, seconds, frames, 0]))


def write_midi(path: Path, *, bpm: float = 120.0, note_tracks: int = 1,
               notes_per_track: int = 4, with_tempo: bool = True,
               with_smpte: bool = True, with_notes: bool = True,
               markers: tuple[str, ...] = (), track_name: str = "Cue",
               division: int = 480) -> Path:
    """Write a format-1 Standard MIDI File and return its path."""
    path.parent.mkdir(parents=True, exist_ok=True)

    tempo_track = bytearray()
    if with_tempo:
        tempo_track += _vlq(0) + _tempo_event(bpm)
    tempo_track += _vlq(0) + _time_signature_event(4, 4)
    if with_smpte:
        tempo_track += _vlq(0) + _smpte_offset_event()
    for marker in markers:
        tempo_track += _vlq(0) + _meta(0x06, marker.encode("utf-8"))
    tempo_track += _vlq(0) + _meta(0x2F, b"")

    tracks = [bytes(tempo_track)]
    for index in range(note_tracks):
        body = bytearray()
        name = f"{track_name} {index + 1}"
        body += _vlq(0) + _meta(0x03, name.encode("utf-8"))
        if with_notes:
            for note in range(notes_per_track):
                channel = index % 16
                start = 480 * note
                length = 240
                body += _vlq(start) + bytes([0x90 | channel, 60 + note, 100])
                body += _vlq(length) + bytes([0x80 | channel, 60 + note, 0])
        body += _vlq(0) + _meta(0x2F, b"")
        tracks.append(bytes(body))

    smf = _chunk(b"MThd", struct.pack(">HHH", 1, len(tracks), division))
    smf += b"".join(_chunk(b"MTrk", t) for t in tracks)
    path.write_bytes(smf)
    return path


# ---------------------------------------------------------------------------
# export folders
# ---------------------------------------------------------------------------
def improve_folder(root: Path, *, stems: dict[str, np.ndarray] | None = None,
                   master: np.ndarray | None = None,
                   mix_minus: np.ndarray | None = None,
                   click: np.ndarray | None = None,
                   project: str = PROJECT, timecode: str = TIMECODE,
                   sr: int = SR, subtype: str = "PCM_24",
                   stem_subtype: str | None = None,
                   click_timecode: str | None = None) -> Path:
    """Build an IMPROVE-shaped export folder.

    The default values are consistent: MASTER is the normalized sum of the
    stems and MIX MINUS, so the null test passes.
    """
    folder = root / f"{project} IMPROVE"
    folder.mkdir(parents=True, exist_ok=True)

    if stems is None:
        stems = {"Track A": at_peak(noise(DURATION, sr=sr, amp=0.2, seed=1), STEM_A_DB),
                 "Track B": at_peak(tone(DURATION, 330.0, sr=sr, amp=0.2), STEM_B_DB)}
    if mix_minus is None:
        mix_minus = at_peak(noise(DURATION, sr=sr, amp=0.15, seed=2), MIX_MINUS_DB)
    if click is None:
        click = click_train(DURATION, every=0.25, sr=sr)
    if master is None:
        total = mix_minus.copy()
        for data in stems.values():
            total = total + data[:len(total)]
        master = 0.5 * total

    for name, data in stems.items():
        write_wav(folder / f"{project} - {timecode} - {name}.wav", data, sr,
                  stem_subtype or subtype)
    write_wav(folder / f"_{project} - {timecode} - MASTER.wav", master, sr, subtype)
    write_wav(folder / f"_{project} - {timecode} - MIX MINUS.wav", mix_minus, sr, subtype)
    write_wav(folder / f"_{project} - {click_timecode or timecode} - CLICK.wav",
              click, sr, subtype)
    write_midi(folder / f"_{project} - {timecode} - IMPROVE.mid")
    return folder


def multitrack_folder(root: Path, *, dry: dict[str, np.ndarray] | None = None,
                      wet: dict[str, np.ndarray] | None = None,
                      fx_return: np.ndarray | None = None,
                      master_ref: np.ndarray | None = None,
                      click: np.ndarray | None = None,
                      project: str = PROJECT, timecode: str = TIMECODE,
                      sr: int = SR, subtype: str = "PCM_24",
                      click_timecode: str | None = None) -> Path:
    """Build a MULTITRACK-shaped export folder."""
    folder = root / f"{project} MULTITRACK"
    (folder / "DRY").mkdir(parents=True, exist_ok=True)
    (folder / "WET").mkdir(parents=True, exist_ok=True)

    if dry is None:
        dry = {"Folder_Track A dry": at_peak(noise(DURATION, sr=sr, amp=0.2, seed=3),
                                             STEM_A_DB),
               "Folder_Track B dry": at_peak(noise(DURATION, sr=sr, amp=0.2, seed=5),
                                             STEM_B_DB)}
    if wet is None:
        # The wet stems carry the effect return, the dry ones do not, so
        # sum(DRY) + FX RETURN == sum(WET) == MASTER REF.
        fx_default = at_peak(noise(DURATION, sr=sr, amp=0.05, seed=4), FX_RETURN_DB)
        wet = {"Folder_Track A wet": dry["Folder_Track A dry"] + fx_default,
               "Folder_Track B wet": dry["Folder_Track B dry"]}
    if fx_return is None:
        fx_return = at_peak(noise(DURATION, sr=sr, amp=0.05, seed=4), FX_RETURN_DB)
    if click is None:
        click = click_train(DURATION, every=0.25, sr=sr)

    total_wet = None
    for data in wet.values():
        total_wet = data.copy() if total_wet is None else total_wet + data[:len(total_wet)]
    if master_ref is None:
        master_ref = total_wet

    for name, data in dry.items():
        write_wav(folder / "DRY" / f"{name} - {project} - {timecode}.wav", data, sr, subtype)
    for name, data in wet.items():
        write_wav(folder / "WET" / f"{name} - {project} - {timecode}.wav", data, sr, subtype)
    write_wav(folder / "DRY" / f"{project} - {timecode} - FX RETURN.wav",
              fx_return, sr, subtype)
    write_wav(folder / f"_{project} - {timecode} - MASTER REF.wav", master_ref, sr, subtype)
    write_wav(folder / f"_{project} - {click_timecode or timecode} - CLICK.wav",
              click, sr, subtype)
    write_midi(folder / f"_{project} - {timecode} - TEMPO MAP.mid",
               with_notes=False, track_name="Tempo")
    write_midi(folder / f"_{project} - {timecode} - MIDI.mid")
    return folder
