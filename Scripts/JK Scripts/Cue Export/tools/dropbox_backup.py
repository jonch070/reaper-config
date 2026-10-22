#!/usr/bin/env python3
"""Back up the cue projects and their exports to Dropbox.

Usage:
    dropbox_backup.py [--config config.json] [--film NAME] [--dry-run] [--force]
                      [--report REPORT.json] [--json SUMMARY.json]

For every cue in a film the newest project file is copied into the film's
Dropbox folder together with the MULTITRACK render (and the IMPROVE / ORCH
renders when the film asks for them).  The master project is copied as well.

Nothing is deleted or overwritten before its replacement has been copied and
verified: every copy goes into a `.incoming-<random>` staging folder first and
is only swapped into place afterwards.  If anything goes wrong the previous
backup is left exactly as it was and the tool exits non-zero.

Exit status is 0 when every cue was backed up or skipped, 1 on any failure.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import shutil
import string
import sys
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Iterable, Sequence

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cueconfig import Config, ConfigError, Film, load_config  # noqa: E402

TOOL_VERSION = 1

OK = "OK"
SKIP = "SKIP"
FAIL = "FAIL"

# The verdicts of the checker, which the backup tool reads.
PASS = "PASS"
WARN = "WARN"

# --- naming (SPEC.md section 3) --------------------------------------------
# A cue number is the leading token of a project name: `1M01`, `2M03B`.
CUE_NUMBER_RE = re.compile(r"^(?P<number>\d+M\d+[A-Za-z]?)(?![0-9A-Za-z])")
# The version token that ends the cue name: `v01.01.08`.
VERSION_RE = re.compile(r"v\d+\.\d+\.\d+")

# --- what never gets copied -------------------------------------------------
VIDEO_EXTENSIONS = {
    ".mp4", ".mov", ".avi", ".mkv", ".m4v", ".webm", ".wmv", ".flv",
    ".mpg", ".mpeg", ".m2v", ".mts", ".m2ts", ".vob", ".ogv", ".3gp",
}
SKIP_NAMES = {".DS_Store", "Thumbs.db", "desktop.ini"}
SKIP_SUFFIXES = (".reapeaks",)
SKIP_DIR_NAMES = {"peaks"}
# Folders inside a cue project that hold no project file.
IGNORED_DIR_NAMES = {"backups", "exports", "peaks", "media"}

# The kinds of render folder the Lua writes inside an export folder.
RENDER_KINDS = ("MULTITRACK", "IMPROVE", "ORCH")


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------
def human_size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024.0
    return f"{n:.1f} GB"


def rand_suffix(length: int = 10) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return "".join(random.choice(alphabet) for _ in range(length))


def status_rank(status: str | None) -> int:
    return {PASS: 0, WARN: 1, FAIL: 2}.get(status or "", 0)


# ---------------------------------------------------------------------------
# naming
# ---------------------------------------------------------------------------
def cue_number_of(name: str) -> str | None:
    """The leading cue number of a project or folder name (`1M01`, `2M03B`)."""
    # Require the cue number to be followed by whitespace, separator, dot or end.
    match = re.match(r"^(?P<number>\d+M\d{1,2}[A-Za-z]?)(?![A-Za-z0-9])", name)
    if not match:
        return None
    return match.group("number")


def split_cue_label(name: str) -> tuple[str | None, str]:
    """Split a name into its cue number and the cue name that follows it.

    The cue name is the text between the cue number and the version token, so
    `1M01 - Grey Ghost - v01.01.08 TEST_002` gives (`1M01`, `Grey Ghost`).
    """
    match = CUE_NUMBER_RE.match(name)
    if not match:
        return None, ""
    number = match.group("number")
    rest = name[match.end():]
    version = VERSION_RE.search(rest)
    if version:
        rest = rest[:version.start()]
    rest = rest.strip().strip("-").strip()
    return number, rest


def is_project_file(path: Path) -> bool:
    """True for a real REAPER project file (not a `-bak`, `.rpp-bak` or `-PROX`)."""
    low = path.name.lower()
    if not low.endswith(".rpp"):
        return False
    if low.endswith(".rpp-bak") or low.endswith(".rpp-prox"):
        return False
    if low[:-4].endswith("-bak"):
        return False
    return not path.name.startswith(".")


# ---------------------------------------------------------------------------
# the source side: cue folders, projects, exports
# ---------------------------------------------------------------------------
@dataclass
class CueFolder:
    """One cue folder in the film's cue-projects directory."""

    path: Path
    number: str
    name: str

    @property
    def label(self) -> str:
        return f"{self.number} - {self.name}" if self.name else self.number


def find_project_files(root: Path) -> list[Path]:
    """Every project file under `root`, newest first.

    Ties on the modification time are broken by name, so the newest of two
    files saved in the same second is the one with the later name.
    """
    found: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames
                             if d.lower() not in IGNORED_DIR_NAMES
                             and not d.startswith("."))
        for name in sorted(filenames):
            path = Path(dirpath) / name
            if is_project_file(path):
                found.append(path)
    found.sort(key=lambda p: (p.stat().st_mtime, p.name), reverse=True)
    return found


def find_cue_folders(cue_projects_dir: Path) -> list[CueFolder]:
    """The cue folders of a film, one per sub-folder of `cue_projects_dir`."""
    cues: list[CueFolder] = []
    if not cue_projects_dir.is_dir():
        return cues
    for entry in sorted(cue_projects_dir.iterdir()):
        if not entry.is_dir() or entry.name.startswith("."):
            continue
        number, name = split_cue_label(entry.name)
        if number is None:
            projects = find_project_files(entry)
            if not projects:
                continue
            number, name = split_cue_label(projects[0].name)
            if number is None:
                continue
        cues.append(CueFolder(path=entry, number=number, name=name))
    return cues


def latest_project(cue: CueFolder) -> Path | None:
    """The newest project file of this cue."""
    for project in find_project_files(cue.path):
        if cue_number_of(project.name) == cue.number:
            return project
    return None


def find_export_dir(cue_dir: Path, project: Path) -> Path | None:
    """The export folder that belongs to `project`.

    The export folder is `<cue folder>/exports/<project>/`.  Its name is the
    project name without the extension, but the Lua has been seen to drop a
    suffix (`TEST_002`), so a folder whose name is a prefix of the project
    name is accepted as well.
    """
    exports = cue_dir / "exports"
    if not exports.is_dir():
        return None
    candidates = [d for d in sorted(exports.iterdir())
                  if d.is_dir() and not d.name.startswith(".")]
    stem = project.stem
    for candidate in candidates:
        if candidate.name == stem:
            return candidate
    prefixes = [d for d in candidates
                if stem.startswith(d.name + " ") or stem == d.name]
    if prefixes:
        return max(prefixes, key=lambda d: len(d.name))
    return None


def find_render_folders(export_dir: Path) -> dict[str, Path]:
    """The MULTITRACK / IMPROVE / ORCH folders inside an export folder."""
    kinds: dict[str, Path] = {}
    if not export_dir.is_dir():
        return kinds
    for entry in sorted(export_dir.iterdir()):
        if not entry.is_dir():
            continue
        upper = entry.name.upper()
        for kind in RENDER_KINDS:
            if upper == kind or upper.endswith(" " + kind):
                kinds[kind] = entry
                break
    return kinds


# ---------------------------------------------------------------------------
# copying
# ---------------------------------------------------------------------------
@dataclass
class PlannedFile:
    src: Path
    rel: str
    size: int


@dataclass
class CopyPlan:
    """What a copy will contain, before anything is written."""

    base: str                       # where the plan lands inside the target
    root: Path                      # the source directory the files come from
    files: list[PlannedFile] = field(default_factory=list)
    dirs: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)

    @property
    def total_size(self) -> int:
        return sum(f.size for f in self.files)

    @property
    def count(self) -> int:
        return len(self.files)

    def target(self, dest_root: Path) -> Path:
        return dest_root / self.base if self.base else dest_root


def plan_file(src: Path, base: str, max_bytes: int) -> CopyPlan:
    """A plan for a single file."""
    plan = CopyPlan(base=base, root=src.parent)
    size = src.stat().st_size
    if max_bytes and size > max_bytes:
        plan.skipped.append(f"{src.name}: {human_size(size)} is over the size limit")
    else:
        plan.files.append(PlannedFile(src, src.name, size))
    return plan


def plan_tree(src: Path, base: str, max_bytes: int) -> CopyPlan:
    """A plan for a whole folder, minus video files, peaks and oversized files."""
    plan = CopyPlan(base=base, root=src)
    for dirpath, dirnames, filenames in os.walk(src):
        dirnames[:] = sorted(d for d in dirnames
                             if d.lower() not in SKIP_DIR_NAMES
                             and not d.startswith("."))
        rel_dir = os.path.relpath(dirpath, src)
        if rel_dir != ".":
            plan.dirs.append(rel_dir)
        for name in sorted(filenames):
            if name in SKIP_NAMES or name.lower().endswith(SKIP_SUFFIXES):
                continue
            path = Path(dirpath) / name
            if path.suffix.lower() in VIDEO_EXTENSIONS:
                plan.skipped.append(f"{name}: video file")
                continue
            size = path.stat().st_size
            if max_bytes and size > max_bytes:
                plan.skipped.append(f"{name}: {human_size(size)} is over the size limit")
                continue
            plan.files.append(PlannedFile(path, os.path.relpath(path, src), size))
    return plan


def execute_plan(plan: CopyPlan, dest_root: Path) -> None:
    """Copy the planned files into `dest_root`."""
    target = plan.target(dest_root)
    target.mkdir(parents=True, exist_ok=True)
    for rel in plan.dirs:
        (target / rel).mkdir(parents=True, exist_ok=True)
    for planned in plan.files:
        dest = target / planned.rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(planned.src, dest)


def verify_plan(plan: CopyPlan, dest_root: Path) -> list[str]:
    """Check the copy against the plan: every file present, right size, no extras."""
    target = plan.target(dest_root)
    problems: list[str] = []
    for planned in plan.files:
        path = target / planned.rel
        if not path.is_file():
            problems.append(f"{planned.rel}: missing after the copy")
        else:
            size = path.stat().st_size
            if size != planned.size:
                problems.append(f"{planned.rel}: {size} bytes, expected {planned.size}")
    actual = sum(1 for p in target.rglob("*") if p.is_file()) if target.is_dir() else 0
    if actual != plan.count:
        problems.append(f"{target.name or dest_root.name}: {actual} file(s) copied, "
                        f"expected {plan.count}")
    return problems


def staged_path(plan: CopyPlan, incoming: Path) -> Path:
    """The path inside the staging folder that holds the new copy."""
    if plan.base:
        return incoming / plan.base
    if plan.files:
        return incoming / plan.files[0].rel
    return incoming


def remove_path(path: Path) -> None:
    """Delete a file or a folder, ignoring what is already gone."""
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path, ignore_errors=True)
    elif path.exists() or path.is_symlink():
        try:
            path.unlink()
        except OSError:
            pass


def safe_replace(plan: CopyPlan, dest: Path, dry_run: bool) -> list[str]:
    """Put the plan in place at `dest` without ever losing the old copy.

    The copy goes into `<parent>/.incoming-<random>/`, is verified there, and
    only then replaces `dest`; the old copy is moved to `.old-<random>` and
    deleted after the swap.  A failure leaves `dest` untouched.
    """
    if dry_run:
        return []
    parent = dest.parent
    incoming = parent / f".incoming-{rand_suffix()}"
    old = parent / f".old-{rand_suffix()}"
    parent.mkdir(parents=True, exist_ok=True)
    try:
        execute_plan(plan, incoming)
        problems = verify_plan(plan, incoming)
        if problems:
            return problems
        if dest.exists():
            dest.rename(old)
        try:
            staged_path(plan, incoming).rename(dest)
        except OSError:
            if old.exists() and not dest.exists():
                old.rename(dest)
            raise
        remove_path(old)
    finally:
        remove_path(incoming)
    return []


def clean_staging(parent: Path) -> None:
    """Remove leftover staging folders from an interrupted earlier run."""
    if not parent.is_dir():
        return
    for entry in parent.iterdir():
        if entry.name.startswith(".incoming-") or entry.name.startswith(".old-"):
            remove_path(entry)


# ---------------------------------------------------------------------------
# checker reports
# ---------------------------------------------------------------------------
class ReportIndex:
    """The checker reports, so a cue that failed is not backed up."""

    def __init__(self, paths: Iterable[Path] = ()) -> None:
        self.reports: list[dict] = []
        self.errors: list[str] = []
        for path in paths:
            try:
                data = json.loads(Path(path).read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                self.errors.append(f"{path}: {exc}")
                continue
            if isinstance(data, dict):
                self.reports.append(data)

    def status_for(self, export_dir: Path) -> str | None:
        """The checker's verdict for this export, or None when there is none."""
        verdict: str | None = None
        try:
            target = export_dir.resolve()
        except OSError:
            target = export_dir
        for report in self.reports:
            folders = report.get("folders")
            if not isinstance(folders, list):
                overall = report.get("status")
                if isinstance(overall, str):
                    verdict = overall if verdict is None else _worse(verdict, overall)
                continue
            for folder in folders:
                if not isinstance(folder, dict):
                    continue
                raw = folder.get("path")
                if not isinstance(raw, str):
                    continue
                try:
                    path = Path(raw).resolve()
                except OSError:
                    continue
                if path == target or path in target.parents or target in path.parents:
                    status = folder.get("status")
                    if isinstance(status, str):
                        verdict = status if verdict is None else _worse(verdict, status)
        return verdict

    @property
    def failed(self) -> bool:
        """True when any report in the set contains a FAIL."""
        for report in self.reports:
            if report.get("status") == FAIL:
                return True
            for folder in report.get("folders", []) or []:
                if isinstance(folder, dict) and folder.get("status") == FAIL:
                    return True
        return False


def _worse(a: str, b: str) -> str:
    return a if status_rank(a) >= status_rank(b) else b


# ---------------------------------------------------------------------------
# backing up
# ---------------------------------------------------------------------------
@dataclass
class Result:
    """What happened to one item (a cue or the master project)."""

    label: str
    status: str = OK
    reason: str = ""
    actions: list[str] = field(default_factory=list)
    size: int = 0

    def to_dict(self) -> dict:
        return {
            "label": self.label,
            "status": self.status,
            "reason": self.reason,
            "actions": self.actions,
            "bytes": self.size,
        }


def dropbox_cue_folder(root: Path, film_name: str, cue: CueFolder) -> Path:
    """The Dropbox folder for this cue, reusing an existing one if there is one."""
    cues = root / film_name / "CUES"
    if cues.is_dir():
        for entry in sorted(cues.iterdir()):
            if entry.is_dir() and cue_number_of(entry.name) == cue.number:
                return entry
    return cues / cue.label


def backup_cue(film: Film, cue: CueFolder, config: Config, dry_run: bool,
               force: bool, reports: ReportIndex) -> Result:
    """Copy one cue's project and renders into Dropbox."""
    result = Result(label=cue.label)

    project = latest_project(cue)
    if project is None:
        result.status = SKIP
        result.reason = "no project file"
        return result

    export_dir = find_export_dir(cue.path, project)
    if export_dir is None:
        result.status = SKIP
        result.reason = f"no export folder for {project.name}"
        return result

    renders = find_render_folders(export_dir)
    if not renders:
        result.status = SKIP
        result.reason = f"{export_dir.name} holds no render folders"
        return result

    verdict = reports.status_for(export_dir)
    if verdict == FAIL and not force:
        result.status = SKIP
        result.reason = "the checker reported a FAIL"
        return result

    max_bytes = config.max_file_mb * 1024 * 1024
    items: list[tuple[str, CopyPlan]] = []
    rpp_plan = plan_file(project, "", max_bytes)
    if not rpp_plan.files:
        result.status = SKIP
        result.reason = f"{project.name}: {rpp_plan.skipped[0] if rpp_plan.skipped else 'too big'}"
        return result
    items.append((project.name, rpp_plan))

    for kind in RENDER_KINDS:
        source = renders.get(kind)
        if source is None:
            continue
        if kind != "MULTITRACK" and not film.backup_improve_orch:
            continue
        items.append((kind, plan_tree(source, kind, max_bytes)))

    dest_folder = dropbox_cue_folder(config.dropbox_root, film.name, cue)
    if not dry_run:
        dest_folder.mkdir(parents=True, exist_ok=True)
        clean_staging(dest_folder)

    total = 0
    for name, plan in items:
        dest = dest_folder / name
        try:
            problems = safe_replace(plan, dest, dry_run)
        except OSError as exc:
            result.status = FAIL
            result.reason = f"{name}: {exc}"
            return result
        if problems:
            result.status = FAIL
            result.reason = f"{name}: {problems[0]}"
            for extra in problems[1:]:
                result.reason += f"; {extra}"
            return result
        total += plan.total_size
        skipped = len(plan.skipped)
        note = f"{name} ({plan.count} file(s), {human_size(plan.total_size)})"
        if skipped:
            note += f", {skipped} skipped"
        result.actions.append(note)

    # Only the newest project file stays in the cue folder; the older ones go
    # once the new one is in place.
    removed = remove_other_projects(dest_folder, project.name)
    if removed:
        result.actions.append(f"removed {removed} older project file(s)")
    result.size = total
    if verdict == "WARN":
        result.reason = "the checker warned"
    return result


def remove_other_projects(folder: Path, keep: str) -> int:
    """Delete the other project files in a Dropbox cue folder."""
    if not folder.is_dir():
        return 0
    removed = 0
    for entry in sorted(folder.iterdir()):
        if entry.is_file() and entry.name != keep and is_project_file(entry):
            remove_path(entry)
            removed += 1
    return removed


def backup_master(film: Film, config: Config, dry_run: bool) -> Result:
    """Copy the master project into Dropbox and rotate the previous one."""
    result = Result(label=f"{film.name} - MASTER")
    if film.master_project is None:
        result.status = SKIP
        result.reason = "no master project configured"
        return result
    source = film.master_project
    if not source.is_file():
        result.status = SKIP
        result.reason = f"{source} does not exist"
        return result

    master_dir = config.dropbox_root / film.name / "MASTER PROJECT"
    dest = master_dir / f"{film.name} - MASTER.rpp"
    max_bytes = config.max_file_mb * 1024 * 1024
    plan = plan_file(source, "", max_bytes)
    if not plan.files:
        result.status = SKIP
        result.reason = plan.skipped[0] if plan.skipped else "too big"
        return result

    if dry_run:
        result.actions.append(f"{dest.name} ({plan.count} file(s), "
                               f"{human_size(plan.total_size)})")
        result.size = plan.total_size
        return result

    master_dir.mkdir(parents=True, exist_ok=True)
    clean_staging(master_dir)
    incoming = master_dir / f".incoming-{rand_suffix()}"
    old = master_dir / f".old-{rand_suffix()}"
    try:
        execute_plan(plan, incoming)
        problems = verify_plan(plan, incoming)
        if problems:
            result.status = FAIL
            result.reason = problems[0]
            return result
        if dest.exists():
            dest.rename(old)
        try:
            staged_path(plan, incoming).rename(dest)
        except OSError:
            if old.exists() and not dest.exists():
                old.rename(dest)
            raise
        if old.exists():
            rotate_master(master_dir, old, film.name)
        remove_path(old)
    except OSError as exc:
        result.status = FAIL
        result.reason = str(exc)
        return result
    finally:
        remove_path(incoming)

    result.actions.append(f"{dest.name} ({human_size(plan.total_size)})")
    result.size = plan.total_size
    return result


def rotate_master(master_dir: Path, old: Path, film_name: str) -> Path | None:
    """Move the old master into `_previous` and keep only the newest three."""
    previous = master_dir / "_previous"
    previous.mkdir(parents=True, exist_ok=True)
    stamp = date.today().isoformat()
    target = previous / f"{film_name} - MASTER {stamp}.rpp"
    if target.exists():
        target.unlink()
    shutil.move(str(old), str(target))
    prune_previous(previous)
    return target


def prune_previous(previous: Path, keep: int = 3) -> list[Path]:
    """Keep only the newest `keep` files in `_previous`."""
    if not previous.is_dir():
        return []
    files = [f for f in previous.iterdir() if f.is_file()]
    files.sort(key=lambda f: (f.stat().st_mtime, f.name), reverse=True)
    removed = []
    for stale in files[keep:]:
        remove_path(stale)
        removed.append(stale)
    return removed


# ---------------------------------------------------------------------------
# running
# ---------------------------------------------------------------------------
def default_report_paths(cue: CueFolder) -> list[Path]:
    """Where a checker report for this cue is expected to be."""
    reports_dir = Path(__file__).resolve().parent / "reports"
    return [reports_dir / f"{cue.number}.json"]


def run(config: Config, film_filter: str | None = None, dry_run: bool = False,
        force: bool = False, report_path: Path | None = None) -> tuple[list[tuple[str, list[Result]]], int]:
    """Back every film up.  Returns the per-film results and the failure count."""
    films = config.films
    if film_filter:
        films = [f for f in films if f.name == film_filter]
        if not films:
            raise ConfigError(f"no film named {film_filter!r} in the config")

    all_results: list[tuple[str, list[Result]]] = []
    failures = 0
    for film in films:
        results: list[Result] = []
        for cue in find_cue_folders(film.cue_projects_dir):
            if report_path is not None:
                cue_reports = ReportIndex([report_path])
            else:
                paths = [p for p in default_report_paths(cue) if p.is_file()]
                cue_reports = ReportIndex(paths)
            result = backup_cue(film, cue, config, dry_run, force, cue_reports)
            if result.status == FAIL:
                failures += 1
            results.append(result)
        master = backup_master(film, config, dry_run)
        if master.status == FAIL:
            failures += 1
        results.append(master)
        all_results.append((film.name, results))
    return all_results, failures


def print_summary(all_results: Sequence[tuple[str, list[Result]]], dry_run: bool,
                  failures: int) -> None:
    prefix = "Dropbox backup (dry run)" if dry_run else "Dropbox backup"
    print(f"{prefix}: {len(all_results)} film(s)")
    total = 0
    for film_name, results in all_results:
        print(f"  {film_name}")
        for result in results:
            total += 1
            detail = result.reason
            if result.actions:
                actions = ", ".join(result.actions)
                detail = f"{detail}; {actions}" if detail else actions
            print(f"    {result.status:4s} {result.label:34s} {detail}")
    backed = sum(1 for _, results in all_results for r in results if r.status == OK)
    skipped = sum(1 for _, results in all_results for r in results if r.status == SKIP)
    print(f"  {total} item(s): {backed} backed up, {skipped} skipped, "
          f"{failures} failed")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Back the cue projects and renders up to Dropbox.")
    parser.add_argument("--config", help="path to config.json")
    parser.add_argument("--film", help="only back up this film")
    parser.add_argument("--dry-run", action="store_true",
                        help="print what would happen, change nothing")
    parser.add_argument("--force", action="store_true",
                        help="back a cue up even when the checker reported a FAIL")
    parser.add_argument("--report", help="checker JSON report to consult")
    parser.add_argument("--json", dest="json_path", help="write a JSON summary here")
    parser.add_argument("--quiet", action="store_true",
                        help="only print the summary lines")
    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
    except ConfigError as exc:
        print(f"dropbox_backup: {exc}", file=sys.stderr)
        return 1

    try:
        all_results, failures = run(
            config,
            film_filter=args.film,
            dry_run=args.dry_run,
            force=args.force,
            report_path=Path(args.report).expanduser() if args.report else None,
        )
    except ConfigError as exc:
        print(f"dropbox_backup: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"dropbox_backup: {exc}", file=sys.stderr)
        return 1

    if not args.quiet:
        print_summary(all_results, args.dry_run, failures)
    if args.json_path:
        payload = {
            "tool": "dropbox_backup",
            "version": TOOL_VERSION,
            "generated": datetime.now().isoformat(timespec="seconds"),
            "dry_run": args.dry_run,
            "status": FAIL if failures else OK,
            "films": [
                {
                    "name": name,
                    "items": [r.to_dict() for r in results],
                }
                for name, results in all_results
            ],
        }
        path = Path(args.json_path).expanduser()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
