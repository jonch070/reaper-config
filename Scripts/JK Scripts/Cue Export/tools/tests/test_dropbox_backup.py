"""Tests for the Dropbox backup tool.

Everything happens inside a temporary directory: the temporary folder plays
the part of the Dropbox root and of the film's cue-projects directory, so no
test ever touches a real backup.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import dropbox_backup as db  # noqa: E402
from cueconfig import Config, Film  # noqa: E402

CUE = "1M01"
CUE_NAME = "Test Cue"
VERSION = "v01.01.08"
PROJECT = f"{CUE} - {CUE_NAME} - {VERSION}"
FILM = "Test Film"


def write(path: Path, text: str = "x") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def touch(path: Path, mtime: float) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(path.name, encoding="utf-8")
    os.utime(path, (mtime, mtime))
    return path


class BackupFixture:
    """A fake film: cue projects, an export folder and a Dropbox root."""

    def __init__(self, root: Path, *, improve_orch: bool = False,
                 master: bool = False) -> None:
        self.root = root
        self.projects = root / "projects"
        self.dropbox = root / "dropbox"
        self.cue_dir = self.projects / f"{CUE} - {CUE_NAME}"
        self.cue_dir.mkdir(parents=True)
        self.export_dir = self.cue_dir / "exports" / PROJECT
        self.config = Config(
            dropbox_root=self.dropbox,
            reaper_app=Path("/Applications/REAPER.app"),
            max_file_mb=2000,
            films=[Film(name=FILM, cue_projects_dir=self.projects,
                        backup_improve_orch=improve_orch)],
        )
        self.master_project = None
        if master:
            self.master_project = write(root / "master.rpp", "MASTER")

    # -- the source side ----------------------------------------------------
    def add_project(self, name: str = f"{PROJECT}.RPP", mtime: float = 1000.0) -> Path:
        return touch(self.cue_dir / name, mtime)

    def add_export(self, kinds=("MULTITRACK",), stem: str = "Track A") -> Path:
        for kind in kinds:
            folder = self.export_dir / f"{PROJECT} {kind}"
            (folder / "DRY").mkdir(parents=True, exist_ok=True)
            write(folder / "DRY" / f"{stem} dry - {PROJECT} - 10.01.05.17.wav", "stem")
            write(folder / f"_{PROJECT} - 10.01.05.17 - MASTER REF.wav", "master")
            write(folder / "peaks" / f"{stem}.reapeaks", "peak")
            write(folder / ".DS_Store", "junk")
            write(folder / "clip.mp4", "video")
        return self.export_dir

    def dropbox_cue(self) -> Path:
        return self.dropbox / FILM / "CUES" / f"{CUE} - {CUE_NAME}"


class NamingTests(unittest.TestCase):
    def test_cue_number(self):
        self.assertEqual(db.cue_number_of("1M01 - Grey Ghost"), "1M01")
        self.assertEqual(db.cue_number_of("2M03B - Something"), "2M03B")
        self.assertIsNone(db.cue_number_of("Grey Ghost"))
        self.assertIsNone(db.cue_number_of(""))

    def test_cue_number_must_be_a_whole_token(self):
        # `1M011` is a different cue, not `1M01`.
        self.assertIsNone(db.cue_number_of("1M011 - Grey Ghost"))

    def test_split_cue_label(self):
        number, name = db.split_cue_label(f"{PROJECT} TEST_002")
        self.assertEqual(number, "1M01")
        self.assertEqual(name, "Test Cue")

    def test_split_cue_label_without_version(self):
        number, name = db.split_cue_label("1M01 - Grey Ghost")
        self.assertEqual(number, "1M01")
        self.assertEqual(name, "Grey Ghost")

    def test_is_project_file(self):
        self.assertTrue(db.is_project_file(Path("a.RPP")))
        self.assertTrue(db.is_project_file(Path("a.rpp")))
        self.assertFalse(db.is_project_file(Path("a.rpp-bak")))
        self.assertFalse(db.is_project_file(Path("a-bak.rpp")))
        self.assertFalse(db.is_project_file(Path("a.RPP-PROX")))
        self.assertFalse(db.is_project_file(Path("a.txt")))


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def test_project_files_ignore_backups(self):
        cue = self.tmp / "cue"
        touch(cue / "1M01 - Test - v01.01.08.RPP", 1000)
        touch(cue / "1M01 - Test - v01.01.07.RPP", 900)
        touch(cue / "1M01 - Test - v01.01.06-bak.RPP", 800)
        touch(cue / "1M01 - Test - v01.01.05.rpp-bak", 800)
        touch(cue / "1M01 - Test - v01.01.04.RPP-PROX", 800)
        touch(cue / "Backups" / "1M01 - Test - v01.01.03.RPP", 800)
        touch(cue / "notes.txt", 800)
        found = [p.name for p in db.find_project_files(cue)]
        self.assertEqual(found, ["1M01 - Test - v01.01.08.RPP",
                                 "1M01 - Test - v01.01.07.RPP"])

    def test_latest_project_is_the_newest(self):
        cue = CueFolderStub(self.tmp / "cue", "1M01", "Test")
        touch(cue.path / "1M01 - Test - v01.01.01.RPP", 1000)
        touch(cue.path / "1M01 - Test - v01.01.02.RPP", 3000)
        touch(cue.path / "1M01 - Test - v01.01.03.RPP", 2000)
        self.assertEqual(db.latest_project(cue).name, "1M01 - Test - v01.01.02.RPP")

    def test_latest_project_ignores_other_cues(self):
        cue = CueFolderStub(self.tmp / "cue", "1M01", "Test")
        touch(cue.path / "1M01 - Test - v01.01.01.RPP", 1000)
        touch(cue.path / "2M03 - Other - v01.01.09.RPP", 9000)
        self.assertEqual(db.latest_project(cue).name, "1M01 - Test - v01.01.01.RPP")

    def test_find_export_dir_ignores_the_project_suffix(self):
        # The real export folder is `1M01 - Grey Ghost - v01.01.08` while the
        # project file is `... v01.01.08 TEST_002.RPP`.
        cue_dir = self.tmp / "cue"
        (cue_dir / "exports" / "1M01 - Grey Ghost - v01.01.08").mkdir(parents=True)
        project = Path("1M01 - Grey Ghost - v01.01.08 TEST_002.RPP")
        found = db.find_export_dir(cue_dir, project)
        self.assertIsNotNone(found)
        self.assertEqual(found.name, "1M01 - Grey Ghost - v01.01.08")

    def test_find_export_dir_exact_match_wins(self):
        cue_dir = self.tmp / "cue"
        (cue_dir / "exports" / "1M01 - Grey Ghost - v01.01.08").mkdir(parents=True)
        (cue_dir / "exports" / "1M01 - Grey Ghost - v01.01.08 TEST_002").mkdir(parents=True)
        project = Path("1M01 - Grey Ghost - v01.01.08 TEST_002.RPP")
        found = db.find_export_dir(cue_dir, project)
        self.assertEqual(found.name, "1M01 - Grey Ghost - v01.01.08 TEST_002")

    def test_find_render_folders(self):
        export = self.tmp / "export"
        (export / f"{PROJECT} MULTITRACK").mkdir(parents=True)
        (export / f"{PROJECT} ORCH").mkdir(parents=True)
        kinds = db.find_render_folders(export)
        self.assertEqual(sorted(kinds), ["MULTITRACK", "ORCH"])


class CueFolderStub:
    """A `db.CueFolder` without the need for a real folder."""

    def __init__(self, path: Path, number: str, name: str) -> None:
        self.path = path
        self.number = number
        self.name = name


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.fx = BackupFixture(self.tmp)

    def run_backup(self, **kwargs):
        return db.run(self.fx.config, **kwargs)

    def test_cue_is_copied_to_dropbox(self):
        self.fx.add_project()
        self.fx.add_export()
        results, failures = self.run_backup()
        self.assertEqual(failures, 0)
        cue = self.fx.dropbox_cue()
        self.assertTrue((cue / f"{PROJECT}.RPP").is_file())
        self.assertTrue((cue / "MULTITRACK" / "DRY" /
                         f"Track A dry - {PROJECT} - 10.01.05.17.wav").is_file())
        self.assertEqual(results[0][1][0].status, db.OK)

    def test_video_peak_and_junk_files_are_not_copied(self):
        self.fx.add_project()
        self.fx.add_export()
        self.run_backup()
        multitrack = self.fx.dropbox_cue() / "MULTITRACK"
        self.assertFalse((multitrack / "clip.mp4").exists())
        self.assertFalse((multitrack / "peaks").exists())
        self.assertFalse((multitrack / ".DS_Store").exists())

    def test_oversized_files_are_skipped(self):
        self.fx.config.max_file_mb = 1
        self.fx.add_project()
        self.fx.add_export()
        big = self.fx.export_dir / f"{PROJECT} MULTITRACK" / "huge.wav"
        write(big, "y" * (2 * 1024 * 1024))
        self.run_backup()
        multitrack = self.fx.dropbox_cue() / "MULTITRACK"
        self.assertFalse((multitrack / "huge.wav").exists())
        self.assertTrue((multitrack / "DRY" /
                         f"Track A dry - {PROJECT} - 10.01.05.17.wav").is_file())

    def test_a_cue_without_an_export_is_skipped(self):
        self.fx.add_project()
        results, failures = self.run_backup()
        self.assertEqual(failures, 0)
        self.assertEqual(results[0][1][0].status, db.SKIP)
        self.assertIn("no export folder", results[0][1][0].reason)
        self.assertFalse(self.fx.dropbox_cue().exists())

    def test_only_the_newest_project_is_kept(self):
        self.fx.add_project(f"{PROJECT}.RPP", 1000)
        self.fx.add_export()
        self.run_backup()
        cue = self.fx.dropbox_cue()
        # Something left over from an earlier run.
        write(cue / "1M01 - Test Cue - v01.01.07.RPP", "old")
        self.run_backup()
        remaining = sorted(p.name for p in cue.iterdir()
                          if p.is_file() and p.suffix.lower() == ".rpp")
        self.assertEqual(remaining, [f"{PROJECT}.RPP"])

    def test_an_existing_cue_folder_is_reused(self):
        self.fx.add_project()
        self.fx.add_export()
        old = self.fx.dropbox / FILM / "CUES" / f"{CUE} - Old Name"
        write(old / "keep.txt", "keep")
        self.run_backup()
        self.assertTrue((old / f"{PROJECT}.RPP").is_file())
        self.assertTrue((old / "keep.txt").is_file())

    def test_a_second_run_replaces_the_render(self):
        self.fx.add_project()
        self.fx.add_export()
        self.run_backup()
        stale = self.fx.dropbox_cue() / "MULTITRACK" / "stale.wav"
        write(stale, "stale")
        self.run_backup()
        self.assertFalse(stale.exists())
        self.assertTrue((self.fx.dropbox_cue() / "MULTITRACK" / "DRY" /
                         f"Track A dry - {PROJECT} - 10.01.05.17.wav").is_file())

    def test_no_staging_folders_are_left_behind(self):
        self.fx.add_project()
        self.fx.add_export()
        self.run_backup()
        leftovers = [p.name for p in self.fx.dropbox_cue().iterdir()
                     if p.name.startswith(".incoming-") or p.name.startswith(".old-")]
        self.assertEqual(leftovers, [])

    def test_dry_run_changes_nothing(self):
        self.fx.add_project()
        self.fx.add_export()
        results, failures = self.run_backup(dry_run=True)
        self.assertEqual(failures, 0)
        self.assertEqual(results[0][1][0].status, db.OK)
        self.assertFalse(self.fx.dropbox_cue().exists())

    def test_a_failed_copy_leaves_the_old_backup_alone(self):
        self.fx.add_project()
        self.fx.add_export()
        self.run_backup()
        cue = self.fx.dropbox_cue()
        before = sorted(str(p.relative_to(cue)) for p in cue.rglob("*") if p.is_file())
        old_stem = cue / "MULTITRACK" / "DRY" / f"Track A dry - {PROJECT} - 10.01.05.17.wav"
        old_content = old_stem.read_text()

        # Break the copy of the render, after the project file was replaced.
        real_copy2 = shutil.copy2

        def broken(src, dst, *args, **kwargs):
            if str(src).endswith(".wav"):
                raise OSError("disk on fire")
            return real_copy2(src, dst, *args, **kwargs)

        shutil.copy2 = broken
        try:
            results, failures = self.run_backup()
        finally:
            shutil.copy2 = real_copy2

        self.assertEqual(failures, 1)
        self.assertEqual(results[0][1][0].status, db.FAIL)
        self.assertEqual(old_stem.read_text(), old_content)
        self.assertTrue(before)

    def test_the_checker_report_stops_a_failed_cue(self):
        self.fx.add_project()
        self.fx.add_export()
        report = self.tmp / "report.json"
        report.write_text(json.dumps({
            "tool": "check_stems",
            "status": "FAIL",
            "folders": [{"path": str(self.fx.export_dir / f"{PROJECT} MULTITRACK"),
                         "status": "FAIL"}],
        }), encoding="utf-8")
        results, failures = self.run_backup(report_path=report)
        self.assertEqual(failures, 0)
        self.assertEqual(results[0][1][0].status, db.SKIP)
        self.assertIn("FAIL", results[0][1][0].reason)
        self.assertFalse(self.fx.dropbox_cue().exists())

    def test_force_overrides_the_checker_report(self):
        self.fx.add_project()
        self.fx.add_export()
        report = self.tmp / "report.json"
        report.write_text(json.dumps({
            "tool": "check_stems",
            "status": "FAIL",
            "folders": [{"path": str(self.fx.export_dir / f"{PROJECT} MULTITRACK"),
                         "status": "FAIL"}],
        }), encoding="utf-8")
        results, failures = self.run_backup(report_path=report, force=True)
        self.assertEqual(failures, 0)
        self.assertEqual(results[0][1][0].status, db.OK)
        self.assertTrue((self.fx.dropbox_cue() / f"{PROJECT}.RPP").is_file())

    def test_a_report_for_another_cue_does_not_block(self):
        self.fx.add_project()
        self.fx.add_export()
        other = self.tmp / "other" / "2M03 - Other - v01.01.01 MULTITRACK"
        other.mkdir(parents=True)
        report = self.tmp / "report.json"
        report.write_text(json.dumps({
            "tool": "check_stems",
            "status": "FAIL",
            "folders": [{"path": str(other), "status": "FAIL"}],
        }), encoding="utf-8")
        results, failures = self.run_backup(report_path=report)
        self.assertEqual(results[0][1][0].status, db.OK)

    def test_improve_and_orch_are_only_copied_on_request(self):
        self.fx.add_project()
        self.fx.add_export(kinds=("MULTITRACK", "IMPROVE", "ORCH"))
        self.run_backup()
        cue = self.fx.dropbox_cue()
        self.assertTrue((cue / "MULTITRACK").is_dir())
        self.assertFalse((cue / "IMPROVE").exists())
        self.assertFalse((cue / "ORCH").exists())

        self.fx.config.films[0].backup_improve_orch = True
        self.run_backup()
        self.assertTrue((cue / "IMPROVE").is_dir())
        self.assertTrue((cue / "ORCH").is_dir())

    def test_the_render_folders_are_renamed(self):
        self.fx.add_project()
        self.fx.add_export()
        self.run_backup()
        cue = self.fx.dropbox_cue()
        self.assertTrue((cue / "MULTITRACK").is_dir())
        self.assertFalse((cue / f"{PROJECT} MULTITRACK").exists())


class MasterTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.fx = BackupFixture(self.tmp, master=True)
        self.fx.config.films[0].master_project = self.fx.master_project

    def test_the_master_is_copied(self):
        results, failures = db.run(self.fx.config)
        self.assertEqual(failures, 0)
        master = self.fx.dropbox / FILM / "MASTER PROJECT" / f"{FILM} - MASTER.rpp"
        self.assertTrue(master.is_file())
        self.assertEqual(master.read_text(), "MASTER")

    def test_the_previous_master_is_rotated(self):
        db.run(self.fx.config)
        write(self.fx.master_project, "MASTER 2")
        db.run(self.fx.config)
        previous = self.fx.dropbox / FILM / "MASTER PROJECT" / "_previous"
        stamp = date.today().isoformat()
        self.assertTrue((previous / f"{FILM} - MASTER {stamp}.rpp").is_file())
        master = self.fx.dropbox / FILM / "MASTER PROJECT" / f"{FILM} - MASTER.rpp"
        self.assertEqual(master.read_text(), "MASTER 2")

    def test_only_the_three_newest_previous_ones_are_kept(self):
        previous = self.tmp / "_previous"
        previous.mkdir()
        now = 1_000_000.0
        for index in range(5):
            touch(previous / f"{FILM} - MASTER 2026-01-0{index + 1}.rpp", now + index)
        removed = db.prune_previous(previous, keep=3)
        self.assertEqual(len(removed), 2)
        remaining = sorted(p.name for p in previous.iterdir())
        self.assertEqual(remaining, [f"{FILM} - MASTER 2026-01-03.rpp",
                                     f"{FILM} - MASTER 2026-01-04.rpp",
                                     f"{FILM} - MASTER 2026-01-05.rpp"])

    def test_no_master_configured_is_skipped(self):
        self.fx.config.films[0].master_project = None
        results, failures = db.run(self.fx.config)
        self.assertEqual(failures, 0)
        self.assertEqual(results[0][1][-1].status, db.SKIP)


class ConfigTests(unittest.TestCase):
    def test_a_missing_film_is_an_error(self):
        from cueconfig import ConfigError
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        fx = BackupFixture(tmp)
        with self.assertRaises(ConfigError):
            db.run(fx.config, film_filter="No Such Film")

    def test_the_film_filter_picks_one_film(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        fx = BackupFixture(tmp)
        results, failures = db.run(fx.config, film_filter=FILM)
        self.assertEqual(failures, 0)
        self.assertEqual(len(results), 1)


if __name__ == "__main__":
    unittest.main()
