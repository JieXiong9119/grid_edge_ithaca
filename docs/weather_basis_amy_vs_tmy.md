# Why we use AMY (not TMY) ResStock data

**Decision:** use the **AMY** ResStock release for everything: the metadata CSV *and* the building models.

| Piece | What we use |
|---|---|
| Metadata | `grid_edge_fy25/data/input_files/NY_baseline_metadata_and_annual_results_2024_amy.csv` |
| Models (S3) | `.../2024/resstock_amy2018_release_2/model_and_schedule_files/` |
| Simulation weather | `grid_edge_fy25/data/base_files/weather/Ithaca_2024.epw` (same as before) |

## Background

NREL publishes two versions of the same ResStock NY buildings:

- **TMY** (`resstock_tmy3_release_2`): built with a *typical* year of weather.
- **AMY** (`resstock_amy2018_release_2`): built with *actual* weather from one real year (2018).

The buildings are the same in both: same `bldg_id`s, same characteristics (size, vintage, heating type, etc.). Only the weather used to build them differs.

## Why AMY

1. **We compare against a real year of meter data.** Our AMI data is actual 2024 usage. A model built on actual weather is the better starting point than one built on a "typical" year.
2. **The metadata and the models must come from the same release.** The metadata file contains simulated results (`out.*` columns: annual kWh, equipment sizes). Those numbers only describe a model if both are from the same release. Mixing them (e.g. AMY metadata with TMY models) would make those numbers misleading.
3. **TMY understates cooling.** For our 766 buildings in the 7 counties, TMY shows about 32% less cooling electricity than AMY (AMY is +46.5% over TMY). Total electricity differs by about 4%, with individual buildings anywhere from -9% to +74%. Using the typical year would hide real summer peaks.
4. **The AMY metadata is complete.** It covers all 33,791 NY buildings. The TMY file is missing one (`bldg_id` 512459, which is not in our counties, so this does not affect us).

## What the weather difference actually changes

We simulate with `Ithaca_2024.epw` in both cases, so the hourly weather during the run is the same. The release still matters because each model has the original weather baked in. Checked on `bldg0000510`, the AMY and TMY models differ in:

- **Equipment sizing:** heating/cooling capacities and airflows were sized against each release's design weather (AMY about 1.7-1.8% smaller overall).
- **Ground temperatures** and **daylight-saving dates** inside the model.
- **Weather station** referenced by the model.
- **Metadata `out.*` values** (see point 3).

Not different: building characteristics (`in.*`), the calendar year (2018 in both), and the occupancy schedules (only tiny rounding differences in lighting).

## Honest limits

- "AMY" here is **2018** weather, not 2024. It is closer in spirit to real weather than TMY, but it is not 2024. The 2024 weather only enters through `Ithaca_2024.epw`.
- We did **not** run both versions end-to-end and compare simulated load profiles. The model differences above are small, so profiles are expected to be close but not identical. If this matters, run a few buildings both ways.
- If you only use `bldg_id` and `in.*` from the metadata and never use `out.*`, TMY would work too. We chose AMY so everything is consistent and the `out.*` columns are safe to use.

## Consequences for the repo

- `1_resstock_models_download_and_run.ipynb` and `1.1_resstock_metadata_plots.ipynb` use AMY.
- Old TMY model folders in `data/resstock_models/` must be deleted before re-downloading (the downloader skips folders that already have a `models` directory).
- `3_resstock_timeseries_download.ipynb` (released timeseries) and the older `download_resstock_models*.ipynb` notebooks still use the **TMY3** release. Do not mix their output with AMY results.
