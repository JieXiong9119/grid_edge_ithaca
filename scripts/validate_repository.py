"""Read-only notebook/path/data checks; never launches a simulation or writes results.

Default checks need only the standard library. --data checks local pipeline
artifacts with pandas/pyarrow. --inventory verifies the local migration journal.
"""

import argparse
import ast
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from grid_edge.paths import PATHS

NOTEBOOKS = [
    "0_ami_data_prep_and_aggregation.ipynb",
    "1_resstock_models_download_and_run.ipynb",
    "1.1_resstock_metadata_plots.ipynb",
    "1.2_resstock_timeseries_download.ipynb",
    "2_resstock_models_df_run.ipynb",
    "3_resstock_load_table_build.ipynb",
    "4_resstock_aggregation.ipynb",
    "5_postprocess_visualize.ipynb",
]


def check_notebooks() -> None:
    assert sorted(p.name for p in (ROOT / "notebooks").glob("*.ipynb")) == sorted(NOTEBOOKS)
    count = 0
    for name in NOTEBOOKS:
        document = json.loads((ROOT / "notebooks" / name).read_text(encoding="utf-8"))
        ids = [c.get("id") or c.get("metadata", {}).get("id") for c in document["cells"]]
        assert all(ids) and len(ids) == len(set(ids)), f"Missing/duplicate cell IDs: {name}"
        sources = []
        for number, cell in enumerate(document["cells"], 1):
            if cell["cell_type"] != "code":
                continue
            source = "".join(cell["source"])
            tree = ast.parse(source, filename=f"{name}:cell {number}")
            sources.append(source)
            for node in ast.walk(tree):
                if isinstance(node, ast.Constant) and isinstance(node.value, str):
                    value = node.value.replace("\\", "/")
                    assert not value.startswith(("../results", "../data", "C:/Users/")), (name, number, value)
            count += 1
        assert "from grid_edge.paths import" in "\n".join(sources), f"Missing path bootstrap: {name}"
        print(f"PASS notebook syntax and path bootstrap: {name}")
    print(f"PASS {len(NOTEBOOKS)} notebooks, {count} code cells; no notebook execution")


def check_inventory() -> None:
    folder = ROOT / "archive/reorganization_2026-10-29"
    assert (folder / "COMPLETE").exists(), "Migration incomplete; inspect the journal."
    total = size = hashes = 0
    for line in (folder / "moves.jsonl").read_text(encoding="utf-8").splitlines():
        item = json.loads(line)
        destination = ROOT / item["destination"]
        # These files received deliberate path-only edits after their verified move.
        if item["destination"].startswith(("notebooks/", "src/grid_edge/")):
            destination = folder / "before" / item["source"]
        for record in item["files"]:
            file = destination if record["relative"] == "." else destination / record["relative"]
            assert file.is_file(), f"Missing preserved file: {file}"
            assert file.stat().st_size == record["bytes"], f"Size changed: {file}"
            if "sha256" in record:
                with file.open("rb") as stream:
                    assert hashlib.file_digest(stream, "sha256").hexdigest() == record["sha256"], f"Hash changed: {file}"
                hashes += 1
            total += 1
            size += record["bytes"]
    for link in json.loads((folder / "compatibility-links.json").read_text(encoding="utf-8")):
        old, target = ROOT / link["path"], ROOT / link["target"]
        assert old.is_dir() and old.samefile(target), f"Broken compatibility link: {old}"
    print(f"PASS preservation: {total:,} files / {size:,} bytes; {hashes:,} SHA-256 checks; compatibility links valid")


def check_data() -> None:
    import numpy as np
    import pandas as pd
    import pyarrow.parquet as pq

    required = [PATHS.raw_ami / "ch1_4301002_individual.csv",
                PATHS.raw_network / "location_reference.csv",
                PATHS.matching / "match_report.csv",
                PATHS.ami / "ami_meter_xfr_map.csv",
                PATHS.ami / "ami_meter_wide_15_zero.parquet",
                PATHS.resources / "weather/Ithaca_2024.epw",
                PATHS.resources / "workflow_resstock.osw"]
    for suffix in ("", "_up04"):
        required.append(PATHS.selection / f"building_ids_metadata_2024{suffix}.csv")
        required.append(PATHS.resstock / f"resstock_timeseries_all_15{suffix}.parquet")
    for path in required:
        assert path.is_file(), f"Missing pipeline input: {path}"
    reference_index = reference_columns = None
    for scenario in ("baseline_rebuilt", "up04_rebuilt", "up04_df_2F"):
        building_table = PATHS.resstock / f"resstock_timeseries_all_15_{scenario}.parquet"
        assert "meter_ids" in pq.ParquetFile(building_table).schema.names, building_table
        file = PATHS.node_loads / f"aggregated_load_nodes_wide_resstock_plus_ami_fallback_RES_{scenario}_ami-zero.parquet"
        table = pd.read_parquet(file)
        # Writers may preserve time as the index or as an explicit column.
        if "time" in table.columns:
            table = table.set_index("time")
        table.index = pd.to_datetime(table.index)
        assert len(table) == 35040 and table.index.is_unique, file
        assert not ((table.index.month == 2) & (table.index.day == 29)).any(), file
        columns = [c for c in table.columns if c.endswith("_RES")]
        assert columns and np.isfinite(table[columns].to_numpy()).all(), file
        if reference_index is None:
            reference_index, reference_columns = table.index, columns
        else:
            assert table.index.equals(reference_index) and columns == reference_columns, file
        print(f"PASS {scenario}: {len(table):,} intervals, {len(columns)} RES nodes, {table[columns].to_numpy().sum():,.3f} kWh")
    print("PASS current data-flow inputs and scenario alignment (read-only)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", action="store_true")
    parser.add_argument("--data", action="store_true")
    args = parser.parse_args()
    check_notebooks()
    if args.data:
        check_data()
    if args.inventory:
        check_inventory()


if __name__ == "__main__":
    main()