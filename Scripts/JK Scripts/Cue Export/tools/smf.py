"""Minimal Standard MIDI File reader.

`mido` is not installed in this environment, and the checker only needs to look
at the handful of things a cue export writes (tempo, time signature, markers,
SMPTE offset, notes, channels), so this is a small hand-rolled reader.

Reference: Standard MIDI File 1.0 specification.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field

__all__ = [
    "MidiError",
    "MidiEvent",
    "MidiTrack",
    "MidiFile",
    "read_midi",
]


class MidiError(Exception):
    """Raised when a file is not a readable Standard MIDI File."""


# Meta event types we care about.
META_TEXT = 0x01
META_COPYRIGHT = 0x02
META_TRACK_NAME = 0x03
META_INSTRUMENT = 0x04
META_MARKER = 0x06
META_CUE = 0x07
META_SMPTE_OFFSET = 0x54
META_TEMPO = 0x51
META_TIME_SIGNATURE = 0x58
META_KEY_SIGNATURE = 0x59
META_END_OF_TRACK = 0x2F


@dataclass
class MidiEvent:
    """One event inside a track."""

    tick: int
    kind: str  # "meta" | "note_on" | "note_off" | "control" | "program" | "other"
    meta_type: int | None = None
    data: bytes = b""
    channel: int | None = None

    # -- convenience accessors -------------------------------------------
    @property
    def is_note_on(self) -> bool:
        return self.kind == "note_on" and len(self.data) > 1 and self.data[1] > 0

    @property
    def is_note_off(self) -> bool:
        if self.kind == "note_off":
            return True
        return self.kind == "note_on" and len(self.data) > 1 and self.data[1] == 0

    @property
    def note(self) -> int | None:
        return self.data[0] if self.data else None

    @property
    def velocity(self) -> int | None:
        return self.data[1] if len(self.data) > 1 else None

    @property
    def text(self) -> str:
        try:
            return self.data.decode("utf-8", errors="replace").rstrip("\x00")
        except Exception:  # pragma: no cover - defensive
            return ""

    @property
    def bpm(self) -> float:
        """Tempo in BPM (only meaningful for META_TEMPO)."""
        if self.meta_type != META_TEMPO or len(self.data) < 3:
            return 0.0
        micros = (self.data[0] << 16) | (self.data[1] << 8) | self.data[2]
        return 60_000_000.0 / micros if micros else 0.0

    @property
    def time_signature(self) -> tuple[int, int] | None:
        """(numerator, denominator) for META_TIME_SIGNATURE."""
        if self.meta_type != META_TIME_SIGNATURE or len(self.data) < 2:
            return None
        return self.data[0], 2 ** self.data[1]

    @property
    def smpte_offset(self) -> str | None:
        """SMPTE offset as HH:MM:SS:FF, or None when the event is absent."""
        if self.meta_type != META_SMPTE_OFFSET or len(self.data) < 5:
            return None
        hr, mn, sec, fr, _ = self.data[:5]
        return f"{hr:02d}:{mn:02d}:{sec:02d}:{fr:02d}"


@dataclass
class MidiTrack:
    """One MTrk chunk."""

    index: int
    events: list[MidiEvent] = field(default_factory=list)

    @property
    def name(self) -> str:
        for ev in self.events:
            if ev.meta_type == META_TRACK_NAME:
                return ev.text
        return ""

    @property
    def notes(self) -> list[MidiEvent]:
        return [ev for ev in self.events if ev.is_note_on]


@dataclass
class MidiFile:
    """A parsed Standard MIDI File."""

    path: str
    format: int
    track_count: int
    division: int  # ticks per quarter note, or negative for SMPTE division
    tracks: list[MidiTrack] = field(default_factory=list)

    @property
    def is_smpte_division(self) -> bool:
        return self.division < 0

    @property
    def ticks_per_beat(self) -> int:
        return abs(self.division) if self.division > 0 else 0

    @property
    def notes(self) -> list[MidiEvent]:
        return [ev for tr in self.tracks for ev in tr.notes]

    @property
    def note_count(self) -> int:
        return len(self.notes)

    @property
    def channels(self) -> list[int]:
        """Channels that carry notes, 1-based (1-16) as shown in a DAW."""
        return sorted({ev.channel + 1 for ev in self.notes if ev.channel is not None})

    @property
    def tempos(self) -> list[tuple[int, float]]:
        """(tick, bpm) for every tempo event."""
        out = []
        for tr in self.tracks:
            for ev in tr.events:
                if ev.meta_type == META_TEMPO:
                    out.append((ev.tick, ev.bpm))
        return sorted(out)

    @property
    def time_signatures(self) -> list[tuple[int, int, int]]:
        """(tick, numerator, denominator) for every time signature."""
        out = []
        for tr in self.tracks:
            for ev in tr.events:
                sig = ev.time_signature
                if sig:
                    out.append((ev.tick, sig[0], sig[1]))
        return sorted(out)

    @property
    def markers(self) -> list[tuple[int, str]]:
        """(tick, name) for every marker / cue point."""
        out = []
        for tr in self.tracks:
            for ev in tr.events:
                if ev.meta_type in (META_MARKER, META_CUE):
                    out.append((ev.tick, ev.text))
        return sorted(out)

    @property
    def smpte_offset(self) -> str | None:
        for tr in self.tracks:
            for ev in tr.events:
                off = ev.smpte_offset
                if off is not None:
                    return off
        return None

    @property
    def duration_seconds(self) -> float:
        """Length in seconds, when the file uses ticks per quarter note."""
        if not self.ticks_per_beat:
            return 0.0
        last_tick = 0
        for tr in self.tracks:
            for ev in tr.events:
                last_tick = max(last_tick, ev.tick)
        # A file whose only tempo event sits at tick 0 sets the beat length.
        tempos = self.tempos
        bpm = tempos[0][1] if tempos else 120.0
        return (last_tick / self.ticks_per_beat) * (60.0 / bpm) if bpm else 0.0


def _read_vlq(data: bytes, pos: int) -> tuple[int, int]:
    """Read a variable-length quantity. Returns (value, new_pos)."""
    value = 0
    for _ in range(4):
        if pos >= len(data):
            raise MidiError("truncated variable-length quantity")
        byte = data[pos]
        pos += 1
        value = (value << 7) | (byte & 0x7F)
        if not byte & 0x80:
            return value, pos
    raise MidiError("variable-length quantity too long")


def _parse_track(data: bytes, index: int) -> MidiTrack:
    track = MidiTrack(index=index)
    pos = 0
    tick = 0
    running_status = 0
    while pos < len(data):
        delta, pos = _read_vlq(data, pos)
        tick += delta
        if pos >= len(data):
            break
        status = data[pos]
        if status == 0xFF:  # meta event
            pos += 1
            if pos >= len(data):
                break
            meta_type = data[pos]
            pos += 1
            length, pos = _read_vlq(data, pos)
            payload = data[pos:pos + length]
            pos += length
            track.events.append(
                MidiEvent(tick=tick, kind="meta", meta_type=meta_type, data=payload)
            )
            if meta_type == META_END_OF_TRACK:
                break
            continue
        if status in (0xF0, 0xF7):  # sysex
            pos += 1
            length, pos = _read_vlq(data, pos)
            pos += length
            continue
        if status < 0x80:  # running status
            if not running_status:
                raise MidiError(f"running status without a preceding status byte")
            status = running_status
        else:
            pos += 1
            running_status = status

        kind_byte = status & 0xF0
        channel = status & 0x0F
        if kind_byte in (0xC0, 0xD0):  # program change, channel pressure
            length = 1
        else:
            length = 2
        payload = data[pos:pos + length]
        pos += length
        if kind_byte == 0x90:
            kind = "note_on"
        elif kind_byte == 0x80:
            kind = "note_off"
        elif kind_byte == 0xB0:
            kind = "control"
        elif kind_byte == 0xC0:
            kind = "program"
        else:
            kind = "other"
        track.events.append(
            MidiEvent(tick=tick, kind=kind, data=payload, channel=channel)
        )
    return track


def read_midi(path: str) -> MidiFile:
    """Read a Standard MIDI File from disk."""
    with open(path, "rb") as fh:
        data = fh.read()
    if len(data) < 14 or data[:4] != b"MThd":
        raise MidiError("not a Standard MIDI File (no MThd header)")
    header_len = struct.unpack(">I", data[4:8])[0]
    fmt, ntrks, division = struct.unpack(">HHh", data[8:14])
    pos = 8 + header_len

    tracks: list[MidiTrack] = []
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4]
        length = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        pos += 8
        if tag == b"MTrk":
            tracks.append(_parse_track(data[pos:pos + length], len(tracks)))
        elif tag == b"MTrk"[0:1]:  # pragma: no cover - defensive
            pass
        pos += length
        if len(tracks) >= ntrks and ntrks:
            break
    return MidiFile(
        path=path,
        format=fmt,
        track_count=ntrks,
        division=division,
        tracks=tracks,
    )
