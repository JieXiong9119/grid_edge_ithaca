"""One-time, lossless migration of the pre-2026-10-29 layout.

Dry run by default; --apply performs same-volume renames and writes an inventory.
Never rewrites notebooks, simulation artifacts, or input data. No deletion or
overwrite is allowed. A failed migration retains an append-only move journal.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OLD = Path("grid_edge_fy25")
SNAPSHOT = Path("archive/reorganization_2026-10-29")


def plan_moves() -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []

    def add(source: Path, destination: Path) -> None:
        if (ROOT / source).exists():
            moves.append((source, destination))

    for source in sorted((ROOT / OLD / "notebooks").glob("[0-5]*.ipynb")):
        add(source.relative_to(ROOT), Path("notebooks") / source.name)
    add(OLD / "demand_flex/run_hvac_flex.py", Path("src/grid_edge/run_hvac_flex.py"))
    add(OLD / "optimization", Path("archive/legacy/optimization"))
    add(Path("past_UO_files"), Path("archive/legacy/urbanopt"))
    for source in sorted((ROOT / OLD / "data").glob("resstock_models*")):
        add(source.relative_to(ROOT), Path("models") / source.name)
    for name in ("measures", "weather", "workflow_resstock.osw"):
        add(OLD / "data/base_files" / name, Path("resources/openstudio") / name)
    for name in ("building_ids_metadata_2024.csv", "building_ids_metadata_2024_up04.csv"):
        add(OLD / "data/base_files" / name, Path("data/interim/selection") / name)
    add(OLD / "data/input_files/consumption", Path("data/raw/ami"))
    add(OLD / "data/input_files/location_reference.csv", Path("data/raw/network/location_reference.csv"))
    for source in sorted((ROOT / OLD / "data/input_files").glob("*_amy.csv")):
        add(source.relative_to(ROOT), Path("data/raw/resstock") / source.name)
    for source in sorted((ROOT / OLD / "data/parquet").iterdir()):
        if source.name == "ami_duplicates_2024.csv":
            dest = Path("reports/diagnostics")
        elif source.name.startswith("ami_"):
            dest = Path("data/interim/ami")
        elif "released" in source.name:
            dest = Path("data/external/resstock_released")
        elif source.name.startswith("resstock_timeseries_"):
            dest = Path("data/interim/resstock")
        else:
            continue  # Unknown files are preserved in the legacy tree below.
        add(source.relative_to(ROOT), dest / source.name)
    for source in sorted((ROOT / OLD / "results").iterdir()):
        name = source.name
        if name.startswith("aggregated_load_nodes_wide_"):
            dest = Path("data/processed/node_loads") / name
        elif name == "match_report.csv":
            dest = Path("data/external/matching") / name
        elif name == "ami_meter_xfr_map.csv":
            dest = Path("data/interim/ami") / name
        elif name == "building_to_meter_map.csv":
            dest = Path("data/interim/selection") / name
        elif name.startswith(("resstock_aggregation_report_", "resstock_meter_", "aggregated_load_nodes_ami_", "ami_meter_gap_")):
            dest = Path("reports/diagnostics") / name
        elif name == "figures_postprocess":
            dest = Path("reports/postprocess")
        elif name.startswith("plots"):
            dest = Path("reports/metadata") / name
        else:
            continue
        add(source.relative_to(ROOT), dest)
    add(OLD / "data/up04_df_batch.log", Path("reports/logs/up04_df_batch.log"))
    # Preserve all unclassified content, including empty directories, as a tree.
    add(OLD, Path("archive/legacy/grid_edge_fy25"))
    return moves


def inventory(path: Path) -> list[dict]:
    """Record every file; hash small source/config files, not terabytes of runs."""
    files = [path] if path.is_file() else sorted(p for p in path.rglob("*") if p.is_file())
    records = []
    for file in files:
        stat = file.stat()
        record = {"relative": "." if file == path else file.relative_to(path).as_posix(),
                  "bytes": stat.st_size, "mtime_ns": stat.st_mtime_ns}
        if file == path or (file.suffix in {".py", ".ipynb", ".md", ".toml"} and stat.st_size < 20_000_000):
            with file.open("rb") as stream:
                record["sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
        records.append(record)
    return records


def move_tree(source: Path, destination: Path) -> None:
    """Archive children if Windows has an open handle on a parent directory.

    Empty locked source directories are left in place; no process is terminated
    and no file is deleted. The complete directory structure exists in the archive.
    """
    try:
        source.rename(destination)
    except PermissionError:
        if not source.is_dir():
            raise
        destination.mkdir(parents=True, exist_ok=False)
        for child in source.iterdir():
            move_tree(child, destination / child.name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--resume", action="store_true", help="Continue an interrupted journal without repeating completed moves")
    args = parser.parse_args()
    snapshot = ROOT / SNAPSHOT
    if (snapshot / "COMPLETE").exists():
        raise SystemExit("Migration already completed; use validate_repository.py --inventory instead.")
    if args.resume:
        plan = json.loads((snapshot / "plan.json").read_text(encoding="utf-8"))
        moves = [(Path(item["source"]), Path(item["destination"])) for item in plan]
        recorded = {item["source"]: item for item in (
            json.loads(line) for line in (snapshot / "moves.jsonl").read_text(encoding="utf-8").splitlines())}
    elif not (ROOT / OLD / "notebooks").is_dir():
        raise SystemExit("Legacy notebooks not found: migration is already applied or checkout is incomplete.")
    else:
        moves = plan_moves()
        recorded = {}
    for source, target in moves:
        if source.as_posix() in recorded and (ROOT / target).exists() and not (ROOT / source).exists():
            continue
        print(f"{source.as_posix()} -> {target.as_posix()}", flush=True)
        if (ROOT / target).exists():
            raise FileExistsError(f"Refusing to overwrite {target}")
    if not args.apply:
        print(f"Dry run: {len(moves)} moves. Use --apply after reviewing.")
        return
    if not args.resume:
        snapshot.mkdir(parents=True, exist_ok=False)
        # Preserve pre-existing edits and outputs before any source cleanup.
        for rel in [Path("README.md"), Path(".gitignore"), Path("docs"),
                    OLD / "notebooks", OLD / "demand_flex"]:
            dst = snapshot / "before" / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            if (ROOT / rel).is_dir():
                shutil.copytree(ROOT / rel, dst)
            else:
                shutil.copy2(ROOT / rel, dst)
        (snapshot / "git-status-before.txt").write_text(
            subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True), encoding="utf-8")
        (snapshot / "plan.json").write_text(json.dumps(
            [{"source": s.as_posix(), "destination": d.as_posix()} for s, d in moves], indent=2), encoding="utf-8")
    with (snapshot / "moves.jsonl").open("a" if args.resume else "x", encoding="utf-8") as journal:
        for source, target in moves:
            src, dst = ROOT / source, ROOT / target
            if source.as_posix() in recorded and dst.exists() and not src.exists():
                print(f"ALREADY MOVED {source}", flush=True)
                continue
            records = inventory(src)
            item = {"source": source.as_posix(), "destination": target.as_posix(), "files": records}
            # Journal the intended rename first, allowing manual recovery after interruption.
            if source.as_posix() not in recorded:
                journal.write(json.dumps(item) + "\n")
                journal.flush()
            elif records != recorded[source.as_posix()]["files"]:
                raise RuntimeError(f"Unmoved source changed after interruption: {source}")
            dst.parent.mkdir(parents=True, exist_ok=True)
            move_tree(src, dst)
            after = inventory(dst)
            # File watchers on this Windows checkout may refresh mtime on a rename.
            # Preserve the original timestamp; compare contents/size independently.
            for before_record, after_record in zip(records, after):
                if before_record["relative"] == after_record["relative"] and before_record["mtime_ns"] != after_record["mtime_ns"]:
                    file = dst if before_record["relative"] == "." else dst / before_record["relative"]
                    os.utime(file, ns=(file.stat().st_atime_ns, before_record["mtime_ns"]))
            without_times = lambda rows: [{k: v for k, v in row.items() if k != "mtime_ns"} for row in rows]
            if without_times(records) != without_times(after):
                raise RuntimeError(f"Inventory changed while moving {source}; stop and inspect journal.")
            print(f"VERIFIED {source}: {len(records)} files, {sum(r['bytes'] for r in records):,} bytes", flush=True)
    if os.name == "nt":
        # Saved OSW/OSM/XML files embed these old absolute paths. Do not rewrite them.
        links = [(ROOT / OLD / "data" / p.name, p) for p in (ROOT / "models").iterdir() if p.is_dir()]
        links.append((ROOT / OLD / "data/base_files", ROOT / "resources/openstudio"))
        for old, new in links:
            old.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["cmd", "/c", "mklink", "/J", str(old), str(new)], check=True)
        (snapshot / "compatibility-links.json").write_text(json.dumps(
            [{"path": str(old.relative_to(ROOT)), "target": str(new.relative_to(ROOT))} for old, new in links], indent=2), encoding="utf-8")
    (snapshot / "COMPLETE").write_text("All moves verified; no original files deleted.\n", encoding="utf-8")


if __name__ == "__main__":
    main()