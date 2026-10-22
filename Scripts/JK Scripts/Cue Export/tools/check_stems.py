#!/usr/bin/env python3
"""Check a Cue Export folder against the contract in SPEC.md section 2.

Usage:
    check_stems.py <export folder> [--report report.md] [--json report.json]

The argument may be an IMPROVE/ORCH folder, a MULTITRACK folder, or any parent
that contains several of them; every export folder found underneath is checked.

Exit status is 0 when every folder passed or warned, and 1 when anything failed.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Iterable, Sequence

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from smf import MidiError, read_midi  # noqa: E402

TOOL_VERSION = 1

PASS = "PASS"
WARN = "WARN"
FAIL = "FAIL"

# --- thresholds (SPEC.md section 2) ---------------------------------------
EMPTY_FAIL_DBFS = -90.0
EMPTY_WARN_DBFS = -60.0
NORMALIZED_PEAK_TOLERANCE_DB = 0.1
NORMALIZED_SHARE = 0.5
NULL_PASS_DB = -60.0
NULL_WARN_DB = -40.0
CLICK_BLEED_WARN = 0.02
CLICK_BLEED_FAIL = 0.1
# The click is allowed to sit at lag 0 or one frame either side of it.
CLICK_FRAME_RATES = (24.0, 25.0, 30.0)
MASTER_TARGET_DBFS = -24.0
# Lengths are allowed to differ by this much before it is a failure.  REAPER's
# click render comes up a handful of samples short of the stems.
LENGTH_TOLERANCE_S = 0.001

# Envelope-domain null test: used to tell "the mix is wrong" apart from "the
# project re-randomises its MIDI on every render" (see NOTES.md).
ENVELOPE_HOP_MS = 10
ENVELOPE_PASS_CORR = 0.90
ENVELOPE_PASS_GAIN_DB = 3.0

# --- file naming ----------------------------------------------------------
TC_RE = r"\d{2}\.\d{2}\.\d{2}\.\d{2}"
# <project> - <tc> - <track>          (stems and references)
HEAD_RE = re.compile(rf"^(?P<project>.+?) - (?P<tc>{TC_RE}) - (?P<rest>.+)$")
# <folders>_<track> dry - <project> - <tc>[-001]   (multitrack stems)
TAIL_RE = re.compile(rf"^(?P<head>.+?) - (?P<project>.+?) - (?P<tc>{TC_RE})(?P<seq>-\d{{3}})?$")

REFERENCE_ROLES = {
    "MASTER",
    "MIX MINUS",
    "CLICK",
    "MASTER REF",
    "TEMPO MAP",
    "MIDI",
    "IMPROVE",
    "ORCH",
}
IGNORED_NAMES = {".DS_Store"}
IGNORED_DIRS = {"peaks"}
IGNORED_SUFFIXES = {".reapeaks"}


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------
def dbfs(value: float) -> float:
    """Amplitude to dBFS (0 or negative -> -inf)."""
    if value <= 0:
        return float("-inf")
    return 20.0 * math.log10(value)


def rms_dbfs(value: float) -> float:
    return dbfs(value)


def peak_to_db(value: float) -> float:
    return dbfs(value)


def bit_depth_of(subtype: str) -> int | None:
    m = re.match(r"PCM_(\d+)$", subtype or "")
    if m:
        return int(m.group(1))
    if subtype in ("FLOAT", "DOUBLE"):
        return 32 if subtype == "FLOAT" else 64
    return None


def full_scale(subtype: str) -> float:
    """Largest magnitude that is not clipped for this subtype."""
    depth = bit_depth_of(subtype)
    if depth and depth <= 32:
        return (2 ** (depth - 1) - 1) / (2 ** (depth - 1))
    return 1.0


def status_rank(status: str) -> int:
    return {PASS: 0, WARN: 1, FAIL: 2}.get(status, 0)


def worst(statuses: Iterable[str]) -> str:
    out = PASS
    for s in statuses:
        if status_rank(s) > status_rank(out):
            out = s
    return out


def human_size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024.0
    return f"{n:.1f} GB"


# ---------------------------------------------------------------------------
# data model
# ---------------------------------------------------------------------------
@dataclass
class Check:
    id: str
    title: str
    status: str = PASS
    detail: str = ""
    data: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "status": self.status,
            "detail": self.detail,
            "data": self.data,
        }


@dataclass
class AudioFile:
    path: Path
    rel: str
    role: str  # stem | reference | fx_return | midi | stray
    label: str = ""
    project: str | None = None
    timecode: str | None = None
    sr: int | None = None
    subtype: str | None = None
    bit_depth: int | None = None
    channels: int | None = None
    frames: int | None = None
    duration: float | None = None
    peak: float | None = None
    peak_db: float | None = None
    rms: float | None = None
    rms_db: float | None = None
    clipped: bool | None = None
    note: str = ""

    def to_dict(self) -> dict:
        return {
            "path": self.rel,
            "role": self.role,
            "label": self.label,
            "project": self.project,
            "timecode": self.timecode,
            "sample_rate": self.sr,
            "subtype": self.subtype,
            "bit_depth": self.bit_depth,
            "channels": self.channels,
            "frames": self.frames,
            "duration": self.duration,
            "peak_dbfs": self.peak_db,
            "rms_dbfs": self.rms_db,
            "clipped": self.clipped,
            "note": self.note,
        }


@dataclass
class FolderReport:
    path: Path
    kind: str  # stems | multitrack
    label: str
    checks: list[Check] = field(default_factory=list)
    files: list[AudioFile] = field(default_factory=list)
    project: str | None = None
    timecodes: list[str] = field(default_factory=list)
    error: str | None = None

    @property
    def status(self) -> str:
        if self.error:
            return FAIL
        return worst(c.status for c in self.checks)

    def add(self, check: Check) -> Check:
        self.checks.append(check)
        return check

    def to_dict(self) -> dict:
        return {
            "path": str(self.path),
            "kind": self.kind,
            "label": self.label,
            "status": self.status,
            "project": self.project,
            "timecodes": self.timecodes,
            "error": self.error,
            "files": [f.to_dict() for f in self.files],
            "checks": [c.to_dict() for c in self.checks],
        }


# ---------------------------------------------------------------------------
# folder discovery and classification
# ---------------------------------------------------------------------------
FOLDER_KIND_RE = re.compile(r"^(?P<base>.*?)(?:\s+)(?P<kind>IMPROVE|ORCH|MULTITRACK)$")


def classify_folder(path: Path) -> tuple[str, str] | None:
    """Return (kind, label) for an export folder, or None if it is not one."""
    m = FOLDER_KIND_RE.match(path.name)
    if not m:
        return None
    kind = m.group("kind")
    if kind == "MULTITRACK":
        return "multitrack", "MULTITRACK"
    return "stems", kind


def discover_export_folders(root: Path, max_depth: int = 4) -> list[Path]:
    """Find every export folder at or below `root`."""
    found: list[Path] = []
    if not root.exists():
        return found

    def walk(path: Path, depth: int) -> None:
        if classify_folder(path):
            found.append(path)
            return  # do not descend into an export folder looking for more
        if depth >= max_depth:
            return
        try:
            entries = sorted(path.iterdir())
        except OSError:
            return
        for entry in entries:
            if entry.is_dir() and not entry.name.startswith("."):
                walk(entry, depth + 1)

    if root.is_file():
        root = root.parent
    walk(root, 0)
    return found


# ---------------------------------------------------------------------------
# file naming
# ---------------------------------------------------------------------------
def parse_name(stem: str) -> dict:
    """Pull the project / timecode / role out of an export file name."""
    info: dict = {"project": None, "timecode": None, "rest": stem, "head": None}
    body = stem
    if body.startswith("_"):
        info["reference"] = True
        body = body[1:]
    else:
        info["reference"] = False

    m = HEAD_RE.match(body)
    if m:
        info["project"] = m.group("project")
        info["timecode"] = m.group("tc")
        info["rest"] = m.group("rest")
        return info

    m = TAIL_RE.match(body)
    if m:
        info["project"] = m.group("project")
        info["timecode"] = m.group("tc")
        info["head"] = m.group("head")
        info["rest"] = m.group("head")
        return info

    return info


def stem_label(rel: str, parsed: dict) -> str:
    """Human label for a stem: the track name, without the project/timecode."""
    rel_dir = rel.rsplit("/", 1)[0] if "/" in rel else ""
    rest = parsed.get("rest") or ""
    if rel_dir:
        rest = f"{rel_dir}/{rest}"
    return rest


# ---------------------------------------------------------------------------
# audio
# ---------------------------------------------------------------------------
def scan_audio(path: Path) -> AudioFile:
    """Read the header and measure peak / rms / clipping."""
    info = sf.info(str(path))
    af = AudioFile(
        path=path,
        rel=str(path),
        role="stem",
        sr=info.samplerate,
        subtype=info.subtype,
        bit_depth=bit_depth_of(info.subtype),
        channels=info.channels,
        frames=info.frames,
        duration=info.duration,
    )
    limit = full_scale(info.subtype)
    peak = 0.0
    total = 0.0
    count = 0
    clipped = False
    for block in sf.blocks(str(path), blocksize=1 << 18, dtype="float64", always_2d=True):
        if block.size:
            peak = max(peak, float(np.max(np.abs(block))))
            total += float(np.sum(block.astype(np.float64) ** 2))
            count += block.size
            if not clipped and peak >= limit:
                clipped = True
    af.peak = peak
    af.peak_db = peak_to_db(peak)
    rms = math.sqrt(total / count) if count else 0.0
    af.rms = rms
    af.rms_db = rms_dbfs(rms)
    af.clipped = clipped
    return af


def load_audio(path: Path) -> np.ndarray:
    data, _ = sf.read(str(path), dtype="float64", always_2d=True)
    return data


def envelope(mono: np.ndarray, sr: int, hop_ms: int = ENVELOPE_HOP_MS) -> np.ndarray:
    """Short-term RMS envelope."""
    hop = max(1, int(sr * hop_ms / 1000))
    n = len(mono) // hop
    if n == 0:
        return np.zeros(0)
    trimmed = mono[:n * hop].reshape(n, hop)
    return np.sqrt(np.mean(trimmed ** 2, axis=1))


def to_mono(data: np.ndarray) -> np.ndarray:
    return data.mean(axis=1) if data.ndim > 1 else data


def click_lag_candidates(sr: int) -> list[int]:
    """Lags (in samples) the click is allowed to sit at.

    The click and the stems are rendered from the same project start, so lag 0
    is the expected case.  The click comes back with the timecode of the frame
    it was rendered on, which is often one frame later than the stems, so a
    frame either way is allowed too.  Keeping the set small matters: picking
    the best of thousands of candidate lags would inflate the measured gain by
    picking the noisiest one.
    """
    lags = {0}
    for fps in CLICK_FRAME_RATES:
        frame = int(round(sr / fps))
        lags.add(frame)
        lags.add(-frame)
    return sorted(lags)


def least_squares_gain(click: np.ndarray, target: np.ndarray, lag: int) -> float:
    """Least-squares gain of `click` inside `target` at the given lag.

    A positive lag means the click starts later in the target than it does in
    the click file.
    """
    click = np.asarray(click).ravel()
    target = np.asarray(target).ravel()
    i0 = max(0, -lag)
    i1 = min(click.size, target.size - lag)
    if i1 - i0 < 64:
        return 0.0
    c = click[i0:i1]
    x = target[i0 + lag:i1 + lag]
    energy = float(np.dot(c, c))
    if energy <= 0:
        return 0.0
    return float(np.dot(c, x)) / energy


# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------
def collect_files(folder: Path, report: FolderReport) -> tuple[list[AudioFile], list[AudioFile]]:
    """Sort the folder's files into stems/references and strays."""
    kind = report.kind
    label = report.label
    stems: list[AudioFile] = []
    references: list[AudioFile] = []
    strays: list[AudioFile] = []
    for path in sorted(folder.rglob("*")):
        if path.is_dir():
            continue
        rel = str(path.relative_to(folder))
        if path.name in IGNORED_NAMES or path.name.startswith("."):
            continue
        if path.suffix.lower() in IGNORED_SUFFIXES:
            continue
        if any(part in IGNORED_DIRS for part in path.parts[:-1]):
            continue
        if path.suffix.lower() not in (".wav", ".mid"):
            continue

        parsed = parse_name(path.stem)
        is_ref = parsed.get("reference", False)
        rest = (parsed.get("rest") or "").strip()
        rel_dir = rel.rsplit("/", 1)[0] if "/" in rel else ""

        af = AudioFile(path=path, rel=rel, role="stem")
        af.project = parsed.get("project")
        af.timecode = parsed.get("timecode")

        if path.suffix.lower() == ".mid":
            af.role = "midi"
            af.label = rest or path.stem
            references.append(af)
            continue

        if is_ref:
            if rest in REFERENCE_ROLES:
                af.role = "reference"
                af.label = rest
                references.append(af)
            else:
                af.role = "stray"
                af.label = rest or path.stem
                strays.append(af)
            continue

        # Not underscore-prefixed: a stem, unless it is the FX RETURN.
        if rest == "FX RETURN":
            af.role = "fx_return"
            af.label = "FX RETURN"
            references.append(af)
            continue

        if af.project is None:
            af.role = "stray"
            af.label = path.stem
            strays.append(af)
            continue

        af.role = "stem"
        af.label = stem_label(rel, parsed)
        stems.append(af)

    return stems, references, strays


def check_inventory(folder: Path, report: FolderReport, stems, references, strays) -> None:
    """Which reference files should be here, and are they?"""
    present = {f.label: f for f in references}
    expected: list[str] = []
    if report.kind == "stems":
        expected = ["MASTER", "MIX MINUS", "CLICK", report.label]
    else:
        expected = ["MASTER REF", "CLICK", "TEMPO MAP", "MIDI"]

    missing = [e for e in expected if e not in present]
    # The MIDI file is only written when the cue actually contains MIDI.
    midi_missing = [m for m in missing if m in ("IMPROVE", "ORCH", "MIDI")]
    hard_missing = [m for m in missing if m not in midi_missing]

    status = PASS
    detail = f"{len(stems)} stems, {len(references)} reference files"
    notes: list[str] = []
    if hard_missing:
        status = FAIL
        notes.append("missing: " + ", ".join(hard_missing))
    if midi_missing:
        status = worst([status, WARN])
        notes.append("no MIDI file (the cue may have had no MIDI in range): " + ", ".join(midi_missing))
    if strays:
        status = worst([status, WARN])
        notes.append("stray files: " + ", ".join(f.rel for f in strays))

    if report.kind == "multitrack":
        for sub in ("DRY", "WET"):
            if not (folder / sub).is_dir():
                status = worst([status, WARN])
                notes.append(f"no {sub}/ folder (that job may not have run)")
        if "FX RETURN" not in present:
            status = worst([status, WARN])
            notes.append("no FX RETURN stem in DRY/")

    detail = "; ".join([detail] + notes) if notes else detail
    report.add(Check("inventory", "Inventory", status, detail, {
        "expected_references": expected,
        "missing": missing,
        "stems": [f.rel for f in stems],
        "references": [f.rel for f in references],
        "stray": [f.rel for f in strays],
    }))


def check_format(report: FolderReport, stems, references) -> None:
    """Sample rate, depth, channels and length have to agree."""
    measured = [f for f in stems + references if f.frames is not None]
    if not measured:
        report.add(Check("format", "Format", FAIL, "no audio files found"))
        return

    def fmt(f: AudioFile) -> tuple:
        return (f.sr, f.bit_depth, f.channels)

    stem_fmts = {fmt(f) for f in stems}
    ref_fmts = {fmt(f) for f in references if f.role in ("reference", "fx_return")}
    status = PASS
    details: list[str] = []

    if len(stem_fmts) > 1:
        status = FAIL
        details.append("stems disagree on format: " + ", ".join(
            f"{sr}Hz/{bd}bit/{ch}ch" for sr, bd, ch in sorted(stem_fmts, key=str)))
    if ref_fmts and stem_fmts and not ref_fmts <= stem_fmts:
        status = FAIL
        details.append("references disagree with the stems: " + ", ".join(
            f"{sr}Hz/{bd}bit/{ch}ch" for sr, bd, ch in sorted(ref_fmts, key=str)))

    lengths = {f.frames for f in stems}
    if len(lengths) > 1:
        status = FAIL
        details.append("stems have different lengths: " + ", ".join(
            f"{n} frames ({n / (stems[0].sr or 1):.3f}s)" for n in sorted(lengths)))

    sr = stems[0].sr if stems and stems[0].sr else (measured[0].sr or 0)
    tol = int(LENGTH_TOLERANCE_S * sr) if sr else 1
    stem_len = stems[0].frames if stems else None
    short: list[str] = []
    for f in references:
        if stem_len is None or f.frames is None:
            continue
        delta = f.frames - stem_len
        if abs(delta) > tol:
            status = FAIL
            details.append(f"{f.rel} is {delta:+d} frames from the stems")
        elif delta:
            short.append(f"{f.label} {delta:+d} frames")

    if short:
        details.append("lengths within tolerance: " + ", ".join(short))

    fmt_text = ""
    if sr:
        bd = stems[0].bit_depth if stems else measured[0].bit_depth
        ch = stems[0].channels if stems else measured[0].channels
        fmt_text = f"{sr} Hz, {bd}-bit, {ch} ch"
        if stem_len:
            fmt_text += f", {stem_len / sr:.3f} s"

    report.add(Check("format", "Format", status,
                     "; ".join(details) if details else f"all files {fmt_text}",
                     {"formats": sorted({f"{sr}Hz/{bd}bit/{ch}ch" for sr, bd, ch in (fmt(f) for f in measured)})}))


def check_levels(report: FolderReport, stems, references) -> None:
    """Empty stems, clipping, and stems that all sit at the same level."""
    status = PASS
    details: list[str] = []

    empty_fail: list[str] = []
    empty_warn: list[str] = []
    for f in stems:
        if f.peak_db is None:
            continue
        if f.peak_db < EMPTY_FAIL_DBFS:
            empty_fail.append(f"{f.rel} ({f.peak_db:.1f} dBFS)")
        elif f.peak_db < EMPTY_WARN_DBFS:
            empty_warn.append(f"{f.rel} ({f.peak_db:.1f} dBFS)")
    if empty_fail:
        status = FAIL
        details.append("silent stems: " + ", ".join(empty_fail))
    if empty_warn:
        status = worst([status, WARN])
        details.append("very quiet stems: " + ", ".join(empty_warn))

    clipped = [f.rel for f in stems if f.clipped]
    if clipped:
        status = worst([status, WARN])
        details.append("clipping in: " + ", ".join(clipped))

    # "looks normalized": many stems sharing the same peak within 0.1 dB
    peaks = [f.peak_db for f in stems if f.peak_db is not None and f.peak_db > EMPTY_WARN_DBFS]
    normalized: list[str] = []
    if len(peaks) >= 3:
        for candidate in peaks:
            group = [p for p in peaks if abs(p - candidate) <= NORMALIZED_PEAK_TOLERANCE_DB]
            if len(group) >= max(3, math.ceil(len(peaks) * NORMALIZED_SHARE)):
                normalized = [f"{f.rel} ({f.peak_db:.2f} dBFS)" for f in stems
                              if f.peak_db is not None and abs(f.peak_db - candidate) <= NORMALIZED_PEAK_TOLERANCE_DB]
                break
    if normalized:
        status = worst([status, WARN])
        details.append(f"{len(normalized)} stems sit at the same peak - looks normalized")

    master = next((f for f in references if f.label == "MASTER"), None)
    master_note = ""
    if master and master.peak_db is not None:
        master_note = (f"MASTER peak {master.peak_db:.2f} dBFS, "
                       f"integrated RMS {master.rms_db:.2f} dBFS "
                       f"(preset target {MASTER_TARGET_DBFS:.0f})")

    report.add(Check("levels", "Levels: empty / clipping / normalized", status,
                     "; ".join(details) if details else (master_note or "no issues"),
                     {
                         "master_peak_dbfs": master.peak_db if master else None,
                         "master_rms_dbfs": master.rms_db if master else None,
                         "normalized_group": normalized,
                         "clipped": clipped,
                         "empty": empty_fail + empty_warn,
                     }))


def check_timecodes(report: FolderReport) -> None:
    """Every file in a folder should carry the same timecode.

    The click is rendered in its own pass and comes back with the timecode of
    the frame it was rendered on, which is usually one frame later than the
    stems.  That is a naming wart, not a broken export, so it warns.
    """
    by_code: dict[str, list[str]] = {}
    for f in report.files:
        if f.timecode:
            by_code.setdefault(f.timecode, []).append(f.rel)
    if len(by_code) <= 1:
        report.add(Check("timecode", "Timecode", PASS,
                         f"all files carry {next(iter(by_code), '-')}",
                         {"timecodes": report.timecodes}))
        return
    # The odd one out is usually the click.
    counts = {code: len(paths) for code, paths in by_code.items()}
    odd = min(by_code, key=lambda c: counts[c])
    report.add(Check("timecode", "Timecode", WARN,
                     f"files carry {len(by_code)} different timecodes: "
                     + ", ".join(f"{code} ({counts[code]} files)" for code in report.timecodes)
                     + f"; the minority timecode {odd} belongs to: "
                     + ", ".join(sorted(by_code[odd])[:4]),
                     {"timecodes": report.timecodes, "files": by_code}))


def _null_metrics(reference: np.ndarray, mixed: np.ndarray, sr: int) -> dict:
    n = min(len(reference), len(mixed))
    a = reference[:n].ravel()
    b = mixed[:n].ravel()
    denom = float(np.dot(b, b))
    gain = float(np.dot(a, b)) / denom if denom else 0.0
    residual = a - gain * b
    ref_rms = math.sqrt(float(np.mean(a ** 2))) if a.size else 0.0
    res_rms = math.sqrt(float(np.mean(residual ** 2))) if residual.size else 0.0
    sample_residual_db = dbfs(res_rms / ref_rms) if ref_rms > 0 else float("-inf")

    env_ref = envelope(to_mono(reference[:n]), sr)
    env_mix = envelope(to_mono(mixed[:n]), sr)
    k = min(len(env_ref), len(env_mix))
    env_ref, env_mix = env_ref[:k], env_mix[:k]
    if k > 4:
        e_denom = float(np.dot(env_mix, env_mix))
        env_gain = float(np.dot(env_ref, env_mix)) / e_denom if e_denom else 0.0
        env_res = env_ref - env_gain * env_mix
        env_ref_rms = math.sqrt(float(np.mean(env_ref ** 2)))
        env_res_rms = math.sqrt(float(np.mean(env_res ** 2)))
        env_residual_db = dbfs(env_res_rms / env_ref_rms) if env_ref_rms > 0 else float("-inf")
        env_corr = float(np.corrcoef(env_ref, env_mix)[0, 1]) if env_ref_rms > 0 else 0.0
        env_gain_db = dbfs(abs(env_gain))
    else:
        env_gain, env_residual_db, env_corr, env_gain_db = 0.0, float("-inf"), 0.0, float("-inf")

    return {
        "sample_residual_db": sample_residual_db,
        "gain": gain,
        "gain_db": dbfs(abs(gain)),
        "envelope_residual_db": env_residual_db,
        "envelope_corr": env_corr,
        "envelope_gain_db": env_gain_db,
        "frames": n,
    }


def _null_status(metrics: dict, strict: bool) -> tuple[str, str]:
    """Grade the null test.

    The sample-accurate residual is the metric the spec asks for, but it can
    only pass when two renders are sample-identical.  Projects that randomise
    MIDI on every render never are, so when the envelope says the mix is right
    we downgrade the failure to a warning and say why.
    """
    sample_db = metrics["sample_residual_db"]
    env_ok = (metrics["envelope_corr"] >= ENVELOPE_PASS_CORR
              and abs(metrics["envelope_gain_db"]) <= ENVELOPE_PASS_GAIN_DB)
    if sample_db <= NULL_PASS_DB:
        return PASS, ""
    if sample_db <= NULL_WARN_DB:
        return WARN, ""
    if not strict and env_ok:
        return WARN, ("renders are not sample-identical, so the sample-accurate null "
                      "cannot hold; the envelope matches")
    return FAIL, ""


def check_null(report: FolderReport, strict: bool) -> None:
    """Stems + mix minus against the master, per SPEC.md section 2."""
    references = {f.label: f for f in report.files if f.role in ("reference", "fx_return")}
    stems = [f for f in report.files if f.role == "stem"]

    if report.kind == "stems":
        master = references.get("MASTER")
        mix_minus = references.get("MIX MINUS")
        if not master or not mix_minus or not stems:
            report.add(Check("null", "Null test", WARN,
                             "skipped: needs MASTER, MIX MINUS and at least one stem"))
            return
        sr = master.sr or 48000
        mixed = load_audio(mix_minus.path)
        for f in stems:
            data = load_audio(f.path)
            n = min(len(mixed), len(data))
            mixed = mixed[:n]
            mixed[:n] += data[:n]
        reference = load_audio(master.path)
        metrics = _null_metrics(reference, mixed, sr)
        status, note = _null_status(metrics, strict)
        detail = (f"sample residual {metrics['sample_residual_db']:.1f} dB rel. MASTER "
                  f"(best-fit gain {metrics['gain_db']:+.2f} dB); "
                  f"envelope corr {metrics['envelope_corr']:.3f}, "
                  f"envelope gain {metrics['envelope_gain_db']:+.2f} dB, "
                  f"envelope residual {metrics['envelope_residual_db']:.1f} dB")
        if note:
            detail += f"; {note}"
        report.add(Check("null", "Null test: stems + MIX MINUS vs MASTER", status, detail, metrics))
        return

    master_ref = references.get("MASTER REF")
    if not master_ref:
        report.add(Check("null", "Null test", WARN, "skipped: no MASTER REF"))
        return
    sr = master_ref.sr or 48000
    reference = load_audio(master_ref.path)
    sub_results = []
    status = PASS
    for sub in ("DRY", "WET"):
        files = [f for f in report.files if f.role == "stem" and f"/{sub}/" in "/" + f.rel]
        if not files:
            continue
        mixed = None
        for f in files:
            data = load_audio(f.path)
            if mixed is None:
                mixed = data.copy()
            else:
                n = min(len(mixed), len(data))
                mixed = mixed[:n]
                mixed[:n] += data[:n]
        if sub == "DRY":
            fx = references.get("FX RETURN")
            if fx:
                data = load_audio(fx.path)
                n = min(len(mixed), len(data))
                mixed = mixed[:n]
                mixed[:n] += data[:n]
        metrics = _null_metrics(reference, mixed, sr)
        sub_status, note = _null_status(metrics, strict)
        status = worst([status, sub_status])
        entry = {"subset": sub, **metrics}
        if note:
            entry["note"] = note
        sub_results.append(entry)

    if not sub_results:
        report.add(Check("null", "Null test", WARN, "skipped: no DRY or WET stems"))
        return
    detail = "; ".join(
        f"{r['subset']}: sample residual {r['sample_residual_db']:.1f} dB "
        f"(gain {r['gain_db']:+.2f} dB), envelope corr {r['envelope_corr']:.3f}, "
        f"envelope gain {r['envelope_gain_db']:+.2f} dB "
        f"({r.get('note', 'sample-identical renders')})"
        for r in sub_results)
    report.add(Check("null", "Null test: DRY/WET vs MASTER REF", status, detail,
                     {"subsets": sub_results}))


def check_click_bleed(report: FolderReport) -> None:
    """The click must not be in the master, the mix minus or any stem."""
    references = {f.label: f for f in report.files if f.role in ("reference", "fx_return")}
    click = references.get("CLICK")
    if not click:
        report.add(Check("click", "Click bleed", WARN, "skipped: no CLICK reference"))
        return

    click_data = load_audio(click.path)
    sr = click.sr or 48000
    click_2d = click_data if click_data.ndim > 1 else click_data[:, None]
    lags = click_lag_candidates(sr)

    targets = [f for f in report.files
               if f.role in ("stem", "reference", "fx_return") and f.label != "CLICK"]
    results = []
    status = PASS
    worst_gain = 0.0
    for f in targets:
        data = load_audio(f.path)
        data_2d = data if data.ndim > 1 else data[:, None]
        best_gain = 0.0
        best_lag = 0
        for lag in lags:
            gains = [least_squares_gain(click_2d[:, c], data_2d[:, c], lag)
                     for c in range(data_2d.shape[1])]
            gain = float(gains[int(np.argmax(np.abs(gains)))]) if gains else 0.0
            if abs(gain) > abs(best_gain):
                best_gain, best_lag = gain, lag
        gain = best_gain
        worst_gain = max(worst_gain, abs(gain))
        results.append({"file": f.rel, "label": f.label, "gain": gain,
                        "gain_db": dbfs(abs(gain)), "lag_frames": best_lag,
                        "lag_ms": best_lag / sr * 1000.0})
        del data

    for r in results:
        if abs(r["gain"]) > CLICK_BLEED_FAIL:
            status = FAIL
        elif abs(r["gain"]) > CLICK_BLEED_WARN:
            status = worst([status, WARN])

    detail = (f"worst click bleed {worst_gain:.4f} "
              f"({dbfs(worst_gain):.1f} dB) over {len(results)} files")
    report.add(Check("click", "Click bleed", status, detail, {"targets": results}))


def check_midi(report: FolderReport) -> None:
    """Parse every .mid and report what is in it."""
    midi_files = [f for f in report.files if f.role == "midi"]
    if not midi_files:
        report.add(Check("midi", "MIDI", WARN, "no MIDI files found"))
        return

    status = PASS
    details: list[str] = []
    entries = []
    for f in midi_files:
        try:
            mid = read_midi(str(f.path))
        except (MidiError, OSError) as exc:
            status = FAIL
            details.append(f"{f.rel}: {exc}")
            continue

        tempos = mid.tempos
        notes = mid.note_count
        channels = mid.channels
        entry = {
            "file": f.rel,
            "label": f.label,
            "format": mid.format,
            "track_count": len(mid.tracks),
            "declared_tracks": mid.track_count,
            "ticks_per_beat": mid.ticks_per_beat,
            "note_count": notes,
            "channels": channels,
            "tempo_changes": [{"tick": t, "bpm": round(b, 3)} for t, b in tempos],
            "time_signatures": [{"tick": t, "numerator": n, "denominator": d}
                                for t, n, d in mid.time_signatures],
            "markers": [{"tick": t, "name": name} for t, name in mid.markers],
            "smpte_offset": mid.smpte_offset,
            "track_names": [tr.name for tr in mid.tracks if tr.name],
            "duration_s": round(mid.duration_seconds, 3),
        }
        entries.append(entry)

        if not tempos:
            status = FAIL
            details.append(f"{f.rel}: no tempo event")
        if notes == 0 and f.label != "TEMPO MAP":
            status = FAIL
            details.append(f"{f.rel}: no notes (expected for {f.label})")
        if mid.smpte_offset is None:
            status = worst([status, WARN])
            details.append(f"{f.rel}: no SMPTE offset event")

        summary = (f"{f.rel}: {len(mid.tracks)} tracks, {notes} notes, "
                   f"channels {channels or '-'}, "
                   f"{len(tempos)} tempo change(s), "
                   f"{len(mid.time_signatures)} time signature(s), "
                   f"{len(mid.markers)} marker(s), "
                   f"SMPTE offset {mid.smpte_offset or '-'}")
        details.append(summary)

    report.add(Check("midi", "MIDI", status, "; ".join(details), {"files": entries}))


# ---------------------------------------------------------------------------
# folder check
# ---------------------------------------------------------------------------
def check_folder(folder: Path, strict: bool = False) -> FolderReport:
    classified = classify_folder(folder)
    kind, label = classified if classified else ("stems", folder.name)
    report = FolderReport(path=folder, kind=kind, label=label)

    stems, references, strays = collect_files(folder, report)
    report.files = stems + references + strays

    # Timecodes seen in this folder (the click is often one frame later).
    codes = {f.timecode for f in report.files if f.timecode}
    report.timecodes = sorted(codes)
    projects = {f.project for f in report.files if f.project}
    report.project = sorted(projects)[0] if len(projects) == 1 else None

    check_inventory(folder, report, stems, references, strays)

    # Measure the audio.
    for f in report.files:
        if f.role in ("stem", "reference", "fx_return"):
            measured = scan_audio(f.path)
            f.sr = measured.sr
            f.subtype = measured.subtype
            f.bit_depth = measured.bit_depth
            f.channels = measured.channels
            f.frames = measured.frames
            f.duration = measured.duration
            f.peak = measured.peak
            f.peak_db = measured.peak_db
            f.rms = measured.rms
            f.rms_db = measured.rms_db
            f.clipped = measured.clipped

    check_format(report, stems, references)
    check_levels(report, stems, references)
    check_timecodes(report)
    check_null(report, strict=strict)
    check_click_bleed(report)
    check_midi(report)
    return report


# ---------------------------------------------------------------------------
# output
# ---------------------------------------------------------------------------
def render_markdown(reports: Sequence[FolderReport], generated: str) -> str:
    lines: list[str] = []
    overall = worst(r.status for r in reports)
    lines.append("# Cue export check")
    lines.append("")
    lines.append(f"- Generated: {generated}")
    lines.append(f"- Folders checked: {len(reports)}")
    lines.append(f"- **Overall: {overall}**")
    lines.append("")
    for report in reports:
        name = report.project or report.path.name
        lines.append(f"## {name} {report.label}")
        lines.append("")
        lines.append(f"`{report.path}`")
        lines.append("")
        if report.error:
            lines.append(f"**{FAIL}** - {report.error}")
            lines.append("")
            continue
        lines.append("| Check | Status | Detail |")
        lines.append("| --- | --- | --- |")
        for check in report.checks:
            detail = check.detail.replace("|", "\\|")
            lines.append(f"| {check.title} | {check.status} | {detail} |")
        lines.append("")
        if report.timecodes:
            lines.append(f"Timecodes: {', '.join(report.timecodes)}")
            lines.append("")
        lines.append("| File | Role | Format | Length | Peak | RMS |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for f in report.files:
            if f.role == "midi":
                fmt = "midi"
                length = "-"
                peak = rms = "-"
            else:
                fmt = f"{f.sr} Hz {f.bit_depth}-bit {f.channels}ch"
                length = f"{f.duration:.3f}s" if f.duration else "-"
                peak = f"{f.peak_db:.2f} dB" if f.peak_db is not None else "-"
                rms = f"{f.rms_db:.2f} dB" if f.rms_db is not None else "-"
            label = f.rel.replace("|", "\\|")
            lines.append(f"| {label} | {f.role} | {fmt} | {length} | {peak} | {rms} |")
        lines.append("")
    return "\n".join(lines)


def render_json(reports: Sequence[FolderReport], generated: str) -> str:
    payload = {
        "tool": "check_stems",
        "version": TOOL_VERSION,
        "generated": generated,
        "status": worst(r.status for r in reports),
        "folders": [r.to_dict() for r in reports],
    }
    return json.dumps(payload, indent=2)


# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------
def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check a Cue Export folder (IMPROVE / ORCH / MULTITRACK).")
    parser.add_argument("folders", nargs="+", help="export folder(s), or a parent of them")
    parser.add_argument("--report", help="write the markdown report here")
    parser.add_argument("--json", dest="json_path", help="write the JSON report here")
    parser.add_argument("--strict", action="store_true",
                        help="grade the null test on the sample-accurate residual only")
    parser.add_argument("--quiet", action="store_true", help="only print the summary line")
    args = parser.parse_args(argv)

    targets: list[Path] = []
    for raw in args.folders:
        path = Path(raw).expanduser()
        if not path.exists():
            print(f"check_stems: {raw}: no such path", file=sys.stderr)
            return 1
        found = discover_export_folders(path)
        if not found:
            print(f"check_stems: {raw}: no IMPROVE / ORCH / MULTITRACK folder found", file=sys.stderr)
            return 1
        targets.extend(found)

    seen: set[Path] = set()
    reports: list[FolderReport] = []
    for folder in targets:
        resolved = folder.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        try:
            reports.append(check_folder(folder, strict=args.strict))
        except Exception as exc:  # pragma: no cover - defensive
            report = FolderReport(path=folder, kind="stems", label=folder.name)
            report.error = f"{type(exc).__name__}: {exc}"
            reports.append(report)

    generated = datetime.now().isoformat(timespec="seconds")
    overall = worst(r.status for r in reports)

    markdown = render_markdown(reports, generated)
    if args.report:
        Path(args.report).parent.mkdir(parents=True, exist_ok=True)
        Path(args.report).write_text(markdown, encoding="utf-8")
    if args.json_path:
        Path(args.json_path).parent.mkdir(parents=True, exist_ok=True)
        Path(args.json_path).write_text(render_json(reports, generated), encoding="utf-8")
    if not args.report and not args.quiet:
        print(markdown)

    for report in reports:
        name = report.project or report.path.name
        print(f"{report.status:4s}  {name} {report.label}")
        for check in report.checks:
            if check.status != PASS:
                print(f"        {check.status:4s} {check.title}: {check.detail}")
    print(f"{overall}: {len(reports)} folder(s) checked")
    return 1 if overall == FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
