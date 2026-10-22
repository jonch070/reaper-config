"""Tests for the minimal SMF reader in `smf.py`."""

from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fixtures  # noqa: E402


class ReadMidiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def test_reads_a_format_1_file(self) -> None:
        path = fixtures.write_midi(self.dir / "a.mid", bpm=90.0, note_tracks=2,
                                   notes_per_track=3, markers=("Cue 1",))
        from smf import read_midi

        mid = read_midi(str(path))
        self.assertEqual(mid.format, 1)
        self.assertEqual(mid.track_count, 3)  # tempo track + 2 note tracks
        self.assertEqual(len(mid.tracks), 3)
        self.assertEqual(mid.ticks_per_beat, 480)
        self.assertEqual(mid.note_count, 6)
        self.assertEqual(mid.channels, [1, 2])
        self.assertEqual(len(mid.tempos), 1)
        self.assertAlmostEqual(mid.tempos[0][1], 90.0, places=3)
        self.assertEqual(len(mid.time_signatures), 1)
        self.assertEqual(mid.time_signatures[0][1:], (4, 4))
        self.assertEqual([m[1] for m in mid.markers], ["Cue 1"])
        self.assertEqual(mid.smpte_offset, "10:01:05:17")

    def test_reads_a_format_0_file(self) -> None:
        # format 0, one track, tempo + notes in the same track
        body = bytearray()
        body += fixtures._vlq(0) + fixtures._tempo_event(120.0)
        body += fixtures._vlq(0) + fixtures._meta(0x03, b"Track")
        body += fixtures._vlq(0) + bytes([0x90, 60, 100])
        body += fixtures._vlq(240) + bytes([0x80, 60, 0])
        body += fixtures._vlq(0) + fixtures._meta(0x2F, b"")
        smf = fixtures._chunk(b"MThd", struct.pack(">HHH", 0, 1, 96))
        smf += fixtures._chunk(b"MTrk", bytes(body))
        path = self.dir / "f0.mid"
        path.write_bytes(smf)

        from smf import read_midi

        mid = read_midi(str(path))
        self.assertEqual(mid.format, 0)
        self.assertEqual(mid.note_count, 1)
        self.assertEqual(mid.channels, [1])
        self.assertAlmostEqual(mid.tempos[0][1], 120.0, places=3)
        self.assertIsNone(mid.smpte_offset)

    def test_running_status(self) -> None:
        # two note-ons for the same channel, the second with no status byte
        body = bytearray()
        body += fixtures._vlq(0) + bytes([0x90, 60, 100])
        body += fixtures._vlq(10) + bytes([62, 100])
        body += fixtures._vlq(0) + bytes([0x80, 60, 0])
        body += fixtures._vlq(0) + bytes([62, 0])
        body += fixtures._vlq(0) + fixtures._meta(0x2F, b"")
        smf = fixtures._chunk(b"MThd", struct.pack(">HHH", 0, 1, 96))
        smf += fixtures._chunk(b"MTrk", bytes(body))
        path = self.dir / "run.mid"
        path.write_bytes(smf)

        from smf import read_midi

        mid = read_midi(str(path))
        self.assertEqual(mid.note_count, 2)
        self.assertEqual([ev.note for ev in mid.notes], [60, 62])

    def test_rejects_a_non_midi_file(self) -> None:
        from smf import MidiError, read_midi

        path = self.dir / "nope.mid"
        path.write_bytes(b"not a midi file at all")
        with self.assertRaises(MidiError):
            read_midi(str(path))

    def test_missing_smpte_offset(self) -> None:
        path = fixtures.write_midi(self.dir / "b.mid", with_smpte=False)
        from smf import read_midi

        self.assertIsNone(read_midi(str(path)).smpte_offset)


if __name__ == "__main__":
    unittest.main()
