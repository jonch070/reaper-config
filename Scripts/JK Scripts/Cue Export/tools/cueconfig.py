"""Config loading and validation for the Cue Export tools.

`tools/config.json` holds the real settings and is git-ignored;
`tools/config.example.json` is the shipped template.  Both tools read the
same file, so the loading and the error messages live here.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

__all__ = [
    "ConfigError",
    "Film",
    "Config",
    "load_config",
    "default_config_path",
]


class ConfigError(Exception):
    """Raised when the config file is missing or does not make sense."""


@dataclass
class Film:
    """One film in the config."""

    name: str
    cue_projects_dir: Path
    master_project: Path | None = None
    backup_improve_orch: bool = False

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "cue_projects_dir": str(self.cue_projects_dir),
            "master_project": str(self.master_project) if self.master_project else None,
            "backup_improve_orch": self.backup_improve_orch,
        }


@dataclass
class Config:
    """The whole config."""

    dropbox_root: Path
    reaper_app: Path
    nightly_time: str = "02:00"
    project_load_wait_s: int = 60
    project_timeout_s: int = 1800
    retries: int = 1
    max_file_mb: int = 2000
    films: list[Film] = field(default_factory=list)
    path: Path | None = None

    def film(self, name: str) -> Film | None:
        for f in self.films:
            if f.name == name:
                return f
        return None

    def to_dict(self) -> dict:
        return {
            "dropbox_root": str(self.dropbox_root),
            "reaper_app": str(self.reaper_app),
            "nightly_time": self.nightly_time,
            "project_load_wait_s": self.project_load_wait_s,
            "project_timeout_s": self.project_timeout_s,
            "retries": self.retries,
            "max_file_mb": self.max_file_mb,
            "films": [f.to_dict() for f in self.films],
        }


def default_config_path() -> Path:
    """`tools/config.json`, next to this file."""
    return Path(__file__).resolve().parent / "config.json"


def _require(data: dict, key: str, kind: type, errors: list[str],
             default=None, where: str = "") -> object:
    label = f"{where}.{key}" if where else key
    if key not in data:
        if default is not None:
            return default
        errors.append(f"{label}: missing")
        return None
    value = data[key]
    if kind is float and isinstance(value, int) and not isinstance(value, bool):
        value = float(value)
    if not isinstance(value, kind) or (kind is int and isinstance(value, bool)):
        errors.append(f"{label}: expected {kind.__name__}, got {type(value).__name__}")
        return None
    return value


def _parse(data: dict, path: Path | None) -> Config:
    errors: list[str] = []
    if not isinstance(data, dict):
        raise ConfigError("config: the top level must be an object")

    root = _require(data, "dropbox_root", str, errors)
    reaper = _require(data, "reaper_app", str, errors)
    nightly = _require(data, "nightly_time", str, errors, default="02:00")
    load_wait = _require(data, "project_load_wait_s", int, errors, default=60)
    timeout = _require(data, "project_timeout_s", int, errors, default=1800)
    retries = _require(data, "retries", int, errors, default=1)
    max_mb = _require(data, "max_file_mb", int, errors, default=2000)

    if isinstance(nightly, str):
        parts = nightly.split(":")
        if len(parts) != 2 or not all(p.isdigit() for p in parts):
            errors.append(f"nightly_time: expected HH:MM, got {nightly!r}")
        else:
            hour, minute = int(parts[0]), int(parts[1])
            if not (0 <= hour <= 23 and 0 <= minute <= 59):
                errors.append(f"nightly_time: {nightly!r} is not a valid time of day")
    for label, value in (("project_load_wait_s", load_wait),
                         ("project_timeout_s", timeout),
                         ("retries", retries),
                         ("max_file_mb", max_mb)):
        if isinstance(value, int) and value < 0:
            errors.append(f"{label}: must not be negative")

    films: list[Film] = []
    raw_films = data.get("films")
    if raw_films is None:
        errors.append("films: missing")
    elif not isinstance(raw_films, list):
        errors.append(f"films: expected a list, got {type(raw_films).__name__}")
    else:
        seen: set[str] = set()
        for index, raw in enumerate(raw_films):
            where = f"films[{index}]"
            if not isinstance(raw, dict):
                errors.append(f"{where}: expected an object")
                continue
            name = _require(raw, "name", str, errors, where=where)
            cue_dir = _require(raw, "cue_projects_dir", str, errors, where=where)
            master = raw.get("master_project")
            if master is not None and not isinstance(master, str):
                errors.append(f"{where}.master_project: expected a string")
                master = None
            improve_orch = raw.get("backup_improve_orch", False)
            if not isinstance(improve_orch, bool):
                errors.append(f"{where}.backup_improve_orch: expected true or false")
                improve_orch = False
            if isinstance(name, str):
                if name in seen:
                    errors.append(f"{where}.name: duplicate film {name!r}")
                seen.add(name)
            if not isinstance(cue_dir, str):
                continue
            cue_path = Path(cue_dir).expanduser()
            if not cue_path.is_absolute():
                errors.append(f"{where}.cue_projects_dir: must be an absolute path, "
                              f"got {cue_dir!r}")
                continue
            if not cue_path.is_dir():
                errors.append(f"{where}.cue_projects_dir: {cue_path} does not exist")
                continue
            master_path = None
            if isinstance(master, str):
                master_path = Path(master).expanduser()
                if not master_path.is_absolute():
                    errors.append(f"{where}.master_project: must be an absolute path, "
                                  f"got {master!r}")
                    master_path = None
                elif not master_path.is_file():
                    errors.append(f"{where}.master_project: {master_path} does not exist")
                    master_path = None
            films.append(Film(
                name=name if isinstance(name, str) else f"<film {index}>",
                cue_projects_dir=cue_path,
                master_project=master_path,
                backup_improve_orch=improve_orch,
            ))

    if errors:
        raise ConfigError("config problems:\n  - " + "\n  - ".join(errors))

    return Config(
        dropbox_root=Path(str(root)).expanduser(),
        reaper_app=Path(str(reaper)).expanduser(),
        nightly_time=str(nightly),
        project_load_wait_s=int(load_wait),
        project_timeout_s=int(timeout),
        retries=int(retries),
        max_file_mb=int(max_mb),
        films=films,
        path=path,
    )


def load_config(path: str | Path | None = None) -> Config:
    """Read and validate the config file.

    Raises `ConfigError` with every problem listed, so a broken config does
    not have to be fixed one error at a time.
    """
    config_path = Path(path).expanduser() if path else default_config_path()
    if not config_path.is_file():
        raise ConfigError(
            f"config: {config_path} does not exist\n"
            f"  copy config.example.json to {config_path} and fill it in")
    try:
        text = config_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ConfigError(f"config: cannot read {config_path}: {exc}") from exc
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"config: {config_path} is not valid JSON: {exc}") from exc
    return _parse(data, config_path)
