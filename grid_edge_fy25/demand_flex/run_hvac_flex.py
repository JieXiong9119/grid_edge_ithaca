"""Apply ResStock HVAC demand flexibility to the downloaded upgrade models and simulate them.

Per building (copied from SRC to DST, SRC is never modified):
  1. copy models/home.xml + models/in.schedules.csv and the EPW
  2. repoint EPWFilePath / SchedulesFilePath in home.xml to local files
  3. run an OSW:  ResStockArgumentsPostHPXML (setpoint offsets)
                  -> HPXMLtoOpenStudio (rebuild OSM; measures from the 2025_Release_1 export, OpenStudio 3.8)
                  -> set_run_period -> add_outputs
The schedules have 35040 rows (2023, 365 days) but Ithaca_2024.epw is a leap year (8784 h), which HPXMLtoOpenStudio
rejects. A derived EPW is used for the rebuild/run: Feb 29 dropped, year 2023, data period starts Sunday.

Usage (from repo root, one building):
    python grid_edge_fy25/demand_flex/run_hvac_flex.py --buildings bldg0000510
Control run (same pipeline, no offset):
    python grid_edge_fy25/demand_flex/run_hvac_flex.py --peak-offset 0 --dst grid_edge_fy25/data/resstock_models_up04_rebuilt
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

FY25 = Path(__file__).resolve().parents[1]
DATA = FY25 / "data"
BASE_FILES = DATA / "base_files"


def make_noleap_epw(src: Path, out_dir: Path) -> Path:
    """8784-row AMY 2024 EPW -> 8760-row 2023-calendar EPW (no Feb 29, year 2023, Sunday start)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    dst = out_dir / (src.stem + "_noleap2023.epw")
    lines = src.read_text(encoding="latin-1").splitlines()
    head, data = lines[:8], lines[8:]
    head = [re.sub(r"^(DATA PERIODS,\d+,\d+,[^,]*,)\w+,", r"\1Sunday,", h) for h in head]
    out = []
    for row in data:
        f = row.split(",", 5)
        if f[1] == "2" and f[2] == "29":
            continue
        f[0] = "2023"
        out.append(",".join(f))
    if len(out) != 8760:
        raise RuntimeError(f"{src.name}: expected 8760 rows after dropping Feb 29, got {len(out)}")
    dst.write_text("\n".join(head + out) + "\n", encoding="latin-1")
    return dst


def make_measures_dir(out_dir: Path) -> Path:
    """Copy base_files/measures to out_dir, with the EMS update frequency in add_outputs set to ZoneTimestep.

    The shared measure sets 'Timestep'; in the original up04 runs that ended up as ZoneTimestep in the IDF, but here
    it is written as-is and EnergyPlus 24.1 rejects it.
    """
    dst = out_dir / "_measures"
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(BASE_FILES / "measures", dst, ignore=shutil.ignore_patterns("tests", "docs"))
    mrb = dst / "add_outputs" / "measure.rb"
    mrb.write_text(mrb.read_text(encoding="utf-8").replace("setUpdateFrequency('Timestep')",
                                                           "setUpdateFrequency('ZoneTimestep')"), encoding="utf-8")
    return dst


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--src", type=Path, default=DATA / "resstock_models_up04")
    p.add_argument("--dst", type=Path, default=DATA / "resstock_models_up04_df")
    p.add_argument("--epw", type=Path, default=BASE_FILES / "weather" / "Ithaca_2024.epw")
    # export of git tag 2025_Release_1 (measures/ResStockArgumentsPostHPXML + resources/hpxml-measures); HPXML 4.0
    p.add_argument("--resstock", type=Path, default=Path(r"C:\Users\jxiong\Documents\GitHub\resstock_2025R1"))
    p.add_argument("--openstudio", type=Path, default=Path(r"C:\openstudio-3.8.0\bin\openstudio.exe"))
    p.add_argument("--buildings", nargs="*", default=None, help="bldg folder names; default = all in --src")
    p.add_argument("--peak-offset", type=int, default=2, help="hvac_flex_peak_offset (deg F)")
    p.add_argument("--pre-peak-hours", type=float, default=0, help="hvac_flex_pre_peak_duration_hours (0 = shed)")
    p.add_argument("--pre-peak-offset", type=int, default=0, help="hvac_flex_pre_peak_offset (deg F)")
    p.add_argument("--random-shift-min", type=int, default=0, help="flex_random_shift_minutes")
    p.add_argument("--workers", type=int, default=1)
    p.add_argument("--force", action="store_true", help="re-run buildings that already finished")
    return p.parse_args()


def build_osw(a, bdir: Path, bldg: str) -> dict:
    hpxml = (bdir / "models" / "home.xml").as_posix()
    return {
        "measure_paths": [
            (a.resstock / "measures").as_posix(),
            (a.resstock / "resources" / "hpxml-measures").as_posix(),
            (a.measures_dir).as_posix(),
        ],
        "run_directory": "./run/",
        "steps": [
            {
                "measure_dir_name": "ResStockArgumentsPostHPXML",
                "arguments": {
                    "hpxml_path": hpxml,
                    "hvac_flex_peak_offset": a.peak_offset,
                    "hvac_flex_pre_peak_duration_hours": a.pre_peak_hours,
                    "hvac_flex_pre_peak_offset": a.pre_peak_offset,
                    "flex_random_shift_minutes": a.random_shift_min,
                    "ev_flex_enabled": False,
                    "building_id": str(int(bldg.replace("bldg", ""))),
                },
            },
            {
                "measure_dir_name": "HPXMLtoOpenStudio",
                "arguments": {"hpxml_path": hpxml, "output_dir": (bdir / "run").as_posix(), "debug": True},
            },
            {
                "measure_dir_name": "set_run_period",
                "arguments": {"timesteps_per_hour": 4, "begin_date": "2023-01-01", "end_date": "2023-12-31"},
            },
            {"measure_dir_name": "add_outputs", "arguments": {}},
        ],
    }


def copy_schedules(src: Path, dst: Path, bldg: str):
    """Copy in.schedules.csv, dropping the legacy all-zero 'Vacancy'/'Power Outage' columns.

    OS-HPXML 1.10 reads them as unknown (string) columns and then crashes in set_unavailable_periods.
    """
    drop_names = {"Vacancy", "Power Outage"}
    rows = [ln.rstrip("\r\n").split(",") for ln in src.read_text(encoding="utf-8").splitlines()]
    drop = [i for i, h in enumerate(rows[0]) if h in drop_names]
    for i in drop:
        if any(float(r[i]) != 0 for r in rows[1:]):
            raise RuntimeError(f"{bldg}: column '{rows[0][i]}' has non-zero values; cannot drop")
    keep = [i for i in range(len(rows[0])) if i not in drop]
    dst.write_text("\n".join(",".join(r[i] for i in keep) for r in rows) + "\n", encoding="utf-8")


def prepare(a, bldg: str) -> Path:
    src, bdir = a.src / bldg, a.dst / bldg
    (bdir / "models").mkdir(parents=True, exist_ok=True)
    (bdir / "weather").mkdir(exist_ok=True)
    # Vacant homes (NumberofResidents = 0) come without in.schedules.csv; they keep the file-less home.xml and the flex
    # measure creates a schedule file with only the setpoint columns.
    has_sched = (src / "models" / "in.schedules.csv").exists()
    if has_sched:
        copy_schedules(src / "models" / "in.schedules.csv", bdir / "models" / "in.schedules.csv", bldg)
    shutil.copy2(a.epw, bdir / "weather" / a.epw.name)

    xml = (src / "models" / "home.xml").read_text(encoding="utf-8")
    xml, n1 = re.subn(r"<EPWFilePath>[^<]*</EPWFilePath>", f"<EPWFilePath>{a.epw.name}</EPWFilePath>", xml)
    xml, n2 = re.subn(r"<SchedulesFilePath>[^<]*</SchedulesFilePath>",
                      "<SchedulesFilePath>in.schedules.csv</SchedulesFilePath>", xml)
    if n1 != 1 or n2 != (1 if has_sched else 0):
        raise RuntimeError(f"{bldg}: expected 1 EPWFilePath and {1 if has_sched else 0} SchedulesFilePath, got {n1} and {n2}")
    # The old (ResStock 3.2) files carry software-written HVACPlant design loads without the Infiltration/Ventilation/
    # Piping children; the 2025_R1 HPXML writer turns the missing ones into empty elements that its own reader then
    # rejects. Design loads are recomputed by HPXMLtoOpenStudio, so drop the block.
    xml = re.sub(r"[ \t]*<DesignLoads\b.*?</DesignLoads>\s*", "", xml, flags=re.S)
    # Emissions scenarios reference ResStock-only cambium CSVs that are not part of this setup; not needed for loads.
    xml = re.sub(r"[ \t]*<EmissionsScenarios>.*?</EmissionsScenarios>\s*", "", xml, flags=re.S)
    # Moved under AdvancedResearchFeatures in newer HPXML; value 1.0 is the default. (The flex measure's rewrite drops it
    # silently, but the offset-0 control run skips the rewrite, so do it here for both runs.)
    xml = re.sub(r"[ \t]*<TemperatureCapacitanceMultiplier[^>]*>1(\.0+)?</TemperatureCapacitanceMultiplier>\s*", "", xml)
    (bdir / "models" / "home.xml").write_text(xml, encoding="utf-8")

    osw = bdir / "workflow_df.osw"
    osw.write_text(json.dumps(build_osw(a, bdir, bldg), indent=2), encoding="utf-8")
    return osw


def run_one(a, bldg: str):
    bdir = a.dst / bldg
    if not a.force and (bdir / "run" / "finished.job").exists() and not (bdir / "run" / "failed.job").exists():
        return bldg, "skipped", ""
    if (bdir / "run").exists():
        shutil.rmtree(bdir / "run")
    osw = prepare(a, bldg)
    r = subprocess.run([str(a.openstudio), "run", "-w", str(osw)], capture_output=True, text=True, cwd=bdir)
    (bdir / "openstudio_stdout.log").write_text(r.stdout + "\n--- stderr ---\n" + r.stderr, encoding="utf-8")
    ok = r.returncode == 0 and not (bdir / "run" / "failed.job").exists() and (bdir / "run" / "eplusout.csv").exists()
    return bldg, "ok" if ok else "FAILED", "" if ok else (r.stderr or r.stdout)[-1500:]


def main():
    a = parse_args()
    a.epw = make_noleap_epw(a.epw, a.dst / "_weather")
    a.measures_dir = make_measures_dir(a.dst)
    blds = a.buildings or sorted(p.name for p in a.src.iterdir() if p.is_dir() and p.name.startswith("bldg"))
    print(f"{len(blds)} building(s): {a.src} -> {a.dst} | peak_offset={a.peak_offset} "
          f"pre_peak_h={a.pre_peak_hours} pre_peak_offset={a.pre_peak_offset}", flush=True)
    failed = 0
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        futs = [ex.submit(run_one, a, b) for b in blds]
        for i, f in enumerate(as_completed(futs), 1):
            bldg, status, msg = f.result()
            failed += status == "FAILED"
            print(f"[{i}/{len(blds)}] {bldg}: {status}", flush=True)
            if msg:
                print(msg, flush=True)
    print(f"done, {failed} failed", flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
