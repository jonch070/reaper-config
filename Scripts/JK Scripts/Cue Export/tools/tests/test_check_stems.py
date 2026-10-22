"""Tests for the cue export stem checker."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fixtures  # noqa: E402
from check_stems import (  # noqa: E402
    FAIL,
    PASS,
    WARN,
    check_folder,
    classify_folder,
    discover_export_folders,
    main,
    parse_name,
)


def check_by_id(report, check_id):
    for check in report.checks:
        if check.id == check_id:
            return check
    raise AssertionError(f"no check called {check_id!r} in {[c.id for c in report.checks]}")


class ParseNameTest(unittest.TestCase):
    def test_stem_name(self) -> None:
        info = parse_name("1M01 - Grey Ghost - v01.01.08 - 10.01.05.17 - IM mm")
        self.assertEqual(info["project"], "1M01 - Grey Ghost - v01.01.08")
        self.assertEqual(info["timecode"], "10.01.05.17")
        self.assertEqual(info["rest"], "IM mm")
        self.assertFalse(info["reference"])

    def test_reference_name(self) -> None:
        info = parse_name("_1M01 - Grey Ghost - v01.01.08 - 10.01.05.17 - MASTER")
        self.assertTrue(info["reference"])
        self.assertEqual(info["rest"], "MASTER")

    def test_multitrack_name(self) -> None:
        info = parse_name("Orchestra_Pitched Percussion_Organs_REC SampledOrgan dry"
                          " - 1M01 - Grey Ghost - v01.01.08 - 10.01.05.17-001")
        self.assertEqual(info["project"], "1M01 - Grey Ghost - v01.01.08")
        self.assertEqual(info["timecode"], "10.01.05.17")
        self.assertEqual(info["head"], "Orchestra_Pitched Percussion_Organs_REC SampledOrgan dry")

    def test_unparseable_name(self) -> None:
        info = parse_name("just-a-file")
        self.assertIsNone(info["project"])
        self.assertIsNone(info["timecode"])


class DiscoveryTest(unittest.TestCase):
    def test_classify_folder(self) -> None:
        self.assertEqual(classify_folder(Path("/x/1M01 - Cue IMPROVE")),
                         ("stems", "IMPROVE"))
        self.assertEqual(classify_folder(Path("/x/1M01 - Cue ORCH")), ("stems", "ORCH"))
        self.assertEqual(classify_folder(Path("/x/1M01 - Cue MULTITRACK")),
                         ("multitrack", "MULTITRACK"))
        self.assertIsNone(classify_folder(Path("/x/1M01 - Cue")))

    def test_discover_export_folders(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixtures.improve_folder(root)
            fixtures.multitrack_folder(root)
            (root / "not an export").mkdir()
            found = {p.name for p in discover_export_folders(root)}
            self.assertEqual(found, {"1M01 - Test Cue - v01.01.08 IMPROVE",
                                     "1M01 - Test Cue - v01.01.08 MULTITRACK"})


class ImproveFolderTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def test_a_good_folder_passes(self) -> None:
        folder = fixtures.improve_folder(self.root)
        report = check_folder(folder)
        self.assertEqual(check_by_id(report, "inventory").status, PASS)
        self.assertEqual(check_by_id(report, "format").status, PASS)
        self.assertEqual(check_by_id(report, "levels").status, PASS)
        self.assertEqual(check_by_id(report, "null").status, PASS)
        self.assertEqual(check_by_id(report, "click").status, PASS)
        self.assertEqual(check_by_id(report, "timecode").status, PASS)
        self.assertEqual(report.status, PASS)

    def test_silent_stem_fails(self) -> None:
        import numpy as np

        stems = {"Track A": np.zeros(fixtures.FRAMES),
                 "Track B": fixtures.tone(fixtures.DURATION)}
        folder = fixtures.improve_folder(self.root, stems=stems)
        report = check_folder(folder)
        levels = check_by_id(report, "levels")
        self.assertEqual(levels.status, FAIL)
        self.assertIn("silent stems", levels.detail)

    def test_quiet_stem_warns(self) -> None:
        import numpy as np

        quiet = np.full(fixtures.FRAMES, 10 ** (-70 / 20))
        stems = {"Track A": quiet, "Track B": fixtures.tone(fixtures.DURATION)}
        folder = fixtures.improve_folder(self.root, stems=stems)
        report = check_folder(folder)
        levels = check_by_id(report, "levels")
        self.assertEqual(levels.status, WARN)
        self.assertIn("very quiet stems", levels.detail)

    def test_clipped_stem_warns(self) -> None:
        import numpy as np

        loud = np.clip(fixtures.tone(fixtures.DURATION, amp=2.0), -1.0, 1.0)
        stems = {"Track A": loud, "Track B": fixtures.tone(fixtures.DURATION)}
        folder = fixtures.improve_folder(self.root, stems=stems)
        report = check_folder(folder)
        levels = check_by_id(report, "levels")
        self.assertEqual(levels.status, WARN)
        self.assertIn("clipping", levels.detail)

    def test_normalized_stems_warn(self) -> None:
        import numpy as np

        stems = {f"Track {i}": np.full(fixtures.FRAMES, 0.5) for i in range(4)}
        folder = fixtures.improve_folder(self.root, stems=stems)
        report = check_folder(folder)
        levels = check_by_id(report, "levels")
        self.assertEqual(levels.status, WARN)
        self.assertIn("looks normalized", levels.detail)

    def test_length_mismatch_fails(self) -> None:
        import numpy as np

        folder = fixtures.improve_folder(self.root)
        short = folder / "1M01 - Test Cue - v01.01.08 - 10.01.05.17 - Track A.wav"
        fixtures.write_wav(short, np.zeros(fixtures.FRAMES // 2), fixtures.SR)
        report = check_folder(folder)
        fmt = check_by_id(report, "format")
        self.assertEqual(fmt.status, FAIL)
        self.assertIn("different lengths", fmt.detail)

    def test_format_mismatch_fails(self) -> None:
        folder = fixtures.improve_folder(self.root)
        odd = folder / "1M01 - Test Cue - v01.01.08 - 10.01.05.17 - Track B.wav"
        fixtures.write_wav(odd, fixtures.tone(fixtures.DURATION), 44100)
        report = check_folder(folder)
        fmt = check_by_id(report, "format")
        self.assertEqual(fmt.status, FAIL)
        self.assertIn("disagree on format", fmt.detail)

    def test_missing_reference_fails(self) -> None:
        folder = fixtures.improve_folder(self.root)
        (folder / "_1M01 - Test Cue - v01.01.08 - 10.01.05.17 - MASTER.wav").unlink()
        report = check_folder(folder)
        inventory = check_by_id(report, "inventory")
        self.assertEqual(inventory.status, FAIL)
        self.assertIn("MASTER", inventory.detail)

    def test_stray_file_warns(self) -> None:
        folder = fixtures.improve_folder(self.root)
        fixtures.write_wav(folder / "_dry - 1M01 - Test Cue - v01.01.08 - 10.01.05.17.wav",
                           fixtures.tone(fixtures.DURATION), fixtures.SR)
        report = check_folder(folder)
        inventory = check_by_id(report, "inventory")
        self.assertEqual(inventory.status, WARN)
        self.assertIn("stray files", inventory.detail)

    def test_click_timecode_mismatch_warns(self) -> None:
        folder = fixtures.improve_folder(self.root, click_timecode="10.01.05.18")
        report = check_folder(folder)
        tc = check_by_id(report, "timecode")
        self.assertEqual(tc.status, WARN)
        self.assertIn("10.01.05.18", tc.detail)

    def test_click_bleed_fails(self) -> None:
        click = fixtures.click_train(fixtures.DURATION, every=0.25)
        stem = fixtures.at_peak(fixtures.noise(fixtures.DURATION, amp=0.2, seed=1),
                                fixtures.STEM_A_DB)
        mix_minus = fixtures.at_peak(fixtures.noise(fixtures.DURATION, amp=0.15, seed=2),
                                     fixtures.MIX_MINUS_DB)
        master = 0.5 * (mix_minus + stem) + 0.3 * click
        folder = fixtures.improve_folder(self.root, stems={"Track A": stem},
                                         mix_minus=mix_minus, master=master,
                                         click=click)
        report = check_folder(folder)
        click_check = check_by_id(report, "click")
        self.assertEqual(click_check.status, FAIL)
        gains = {t["label"]: t["gain"] for t in click_check.data["targets"]}
        self.assertAlmostEqual(gains["MASTER"], 0.3, places=2)

    def test_click_bleed_is_quiet_without_a_click(self) -> None:
        click = fixtures.click_train(fixtures.DURATION, every=0.25)
        stem = fixtures.at_peak(fixtures.noise(fixtures.DURATION, amp=0.2, seed=1),
                                fixtures.STEM_A_DB)
        mix_minus = fixtures.at_peak(fixtures.noise(fixtures.DURATION, amp=0.15, seed=2),
                                     fixtures.MIX_MINUS_DB)
        master = 0.5 * (mix_minus + stem)
        folder = fixtures.improve_folder(self.root, stems={"Track A": stem},
                                         mix_minus=mix_minus, master=master,
                                         click=click)
        report = check_folder(folder)
        click_check = check_by_id(report, "click")
        self.assertEqual(click_check.status, PASS, click_check.detail)
        gains = {t["label"]: abs(t["gain"]) for t in click_check.data["targets"]}
        self.assertLess(max(gains.values()), 0.02)


class MultiTrackFolderTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def test_a_good_folder_passes(self) -> None:
        folder = fixtures.multitrack_folder(self.root)
        report = check_folder(folder)
        self.assertEqual(check_by_id(report, "inventory").status, PASS)
        self.assertEqual(check_by_id(report, "format").status, PASS)
        null = check_by_id(report, "null")
        self.assertEqual(null.status, PASS, null.detail)
        self.assertEqual(check_by_id(report, "click").status, PASS)
        self.assertEqual(report.status, PASS)

    def test_dry_and_wet_are_reported_separately(self) -> None:
        folder = fixtures.multitrack_folder(self.root)
        report = check_folder(folder)
        subsets = {s["subset"] for s in check_by_id(report, "null").data["subsets"]}
        self.assertEqual(subsets, {"DRY", "WET"})

    def test_missing_fx_return_warns(self) -> None:
        folder = fixtures.multitrack_folder(self.root)
        (folder / "DRY" / "1M01 - Test Cue - v01.01.08 - 10.01.05.17 - FX RETURN.wav").unlink()
        report = check_folder(folder)
        inventory = check_by_id(report, "inventory")
        self.assertEqual(inventory.status, WARN)
        self.assertIn("FX RETURN", inventory.detail)


class MainTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def run_main(self, argv):
        """Run the CLI without letting it print to the test output."""
        import contextlib
        import io

        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = main(argv)
        self.stdout = buffer.getvalue()
        return code

    def test_exit_code_zero_on_pass(self) -> None:
        folder = fixtures.improve_folder(self.root)
        self.assertEqual(self.run_main([str(folder), "--quiet"]), 0)

    def test_exit_code_one_on_fail(self) -> None:
        import numpy as np

        stems = {"Track A": np.zeros(fixtures.FRAMES),
                 "Track B": fixtures.tone(fixtures.DURATION)}
        folder = fixtures.improve_folder(self.root, stems=stems)
        self.assertEqual(self.run_main([str(folder), "--quiet"]), 1)

    def test_missing_path_is_an_error(self) -> None:
        self.assertEqual(self.run_main([str(self.root / "nope"), "--quiet"]), 1)

    def test_writes_a_report(self) -> None:
        folder = fixtures.improve_folder(self.root)
        md = self.root / "out" / "report.md"
        js = self.root / "out" / "report.json"
        self.run_main([str(folder), "--report", str(md), "--json", str(js)])
        self.assertIn("# Cue export check", md.read_text())
        self.assertIn('"tool": "check_stems"', js.read_text())


if __name__ == "__main__":
    unittest.main()
