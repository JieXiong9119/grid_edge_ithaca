"""Repository paths, independent of the notebook's working directory.

Only path/configuration infrastructure lives here; notebooks remain authoritative
for scientific calculations. Importing this module never creates directories.
"""

import os
from dataclasses import dataclass
from pathlib import Path


def find_project_root(start: Path | str | None = None) -> Path:
    """Find this checkout, or use an explicitly configured GRID_EDGE_ROOT."""
    override = os.environ.get("GRID_EDGE_ROOT")
    candidate = Path(override) if override else Path(start or __file__)
    candidate = candidate.expanduser().resolve()
    if candidate.is_file():
        candidate = candidate.parent
    for root in (candidate, *candidate.parents):
        if (root / "src" / "grid_edge" / "paths.py").is_file() and (root / "README.md").is_file():
            return root
        if override:
            break
    raise FileNotFoundError(f"Cannot find grid-edge checkout from {candidate}; set GRID_EDGE_ROOT.")


@dataclass(frozen=True)
class ProjectPaths:
    """Stage boundaries shared by notebooks, scripts, and validation."""

    root: Path

    @property
    def raw_ami(self) -> Path:
        return self.root / "data/raw/ami"

    @property
    def raw_network(self) -> Path:
        return self.root / "data/raw/network"

    @property
    def raw_resstock(self) -> Path:
        return self.root / "data/raw/resstock"

    @property
    def matching(self) -> Path:
        return self.root / "data/external/matching"

    @property
    def released(self) -> Path:
        return self.root / "data/external/resstock_released"

    @property
    def ami(self) -> Path:
        return self.root / "data/interim/ami"

    @property
    def resstock(self) -> Path:
        return self.root / "data/interim/resstock"

    @property
    def selection(self) -> Path:
        return self.root / "data/interim/selection"

    @property
    def node_loads(self) -> Path:
        return self.root / "data/processed/node_loads"

    @property
    def models(self) -> Path:
        return self.root / "models"

    @property
    def resources(self) -> Path:
        return self.root / "resources/openstudio"

    @property
    def diagnostics(self) -> Path:
        return self.root / "reports/diagnostics"

    @property
    def metadata(self) -> Path:
        return self.root / "reports/metadata"

    @property
    def postprocess(self) -> Path:
        return self.root / "reports/postprocess"

    @property
    def logs(self) -> Path:
        return self.root / "reports/logs"

    def ensure_output_dirs(self) -> None:
        """Create generated destinations, never fabricate missing raw inputs."""
        for path in (self.ami, self.resstock, self.selection, self.node_loads,
                     self.models, self.diagnostics, self.metadata,
                     self.postprocess, self.logs, self.released):
            path.mkdir(parents=True, exist_ok=True)


PATHS = ProjectPaths(find_project_root())


def openstudio_executable() -> Path:
    """Preserve the pinned engine default; allow a local installation override."""
    return Path(os.environ.get("OPENSTUDIO_PATH", "C:/openstudio-3.8.0/bin/openstudio.exe")).expanduser()


def resstock_checkout() -> Path:
    """Default to a sibling 2025R1 export rather than a particular user's home."""
    return Path(os.environ.get("RESSTOCK_DIR", str(PATHS.root.parent / "resstock_2025R1"))).expanduser()