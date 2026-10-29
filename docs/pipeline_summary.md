# Residential load profiles for transformer nodes from AMI and ResStock: methodology

Technical report for the GRIDs project pipeline (Dryden, NY distribution circuit). It describes **what** each step does and **why**; the scenario results of notebook 5 are summarised in §12. Notebooks are in `grid_edge_fy25/notebooks/`; all paths are under `grid_edge_fy25/` unless noted. Weather-release choice: see [weather_basis_amy_vs_tmy.md](weather_basis_amy_vs_tmy.md).

## Contents

1. [Purpose and scope](#1-purpose-and-scope)
2. [Pipeline overview](#2-pipeline-overview) (run order, scenarios, inputs/outputs, final outcomes)
3. [Study area and data sources](#3-study-area-and-data-sources)
4. [AMI preparation](#4-ami-preparation-notebook-0-sections-12)
5. [AMI aggregation to transformer nodes](#5-ami-aggregation-to-transformer-nodes-notebook-0-section-3)
6. [ResStock selection, download and simulation](#6-resstock-selection-download-and-simulation-notebook-1)
7. [Building–meter matching](#7-buildingmeter-matching-external-step)
8. [Rebuilt and demand-flexibility simulations](#8-rebuilt-and-demand-flexibility-simulations-notebook-2)
9. [Scenario load tables](#9-scenario-load-tables-notebook-3)
10. [ResStock aggregation to transformer nodes](#10-resstock-aggregation-to-transformer-nodes-notebook-4)
11. [Time alignment and calendar conventions](#11-time-alignment-and-calendar-conventions)
12. [Scenario results](#12-scenario-results-notebook-5)
13. [Assumptions and limitations](#13-assumptions-and-limitations)
14. [Reproducibility and configuration](#14-reproducibility-and-configuration)
15. [Glossary](#15-glossary)

---

## 1. Purpose and scope

**Goal.** Produce 15-minute residential load profiles for every distribution transformer (node) of the Dryden circuit, for a measured 2024 reference and for a set of what-if scenarios: the current building stock, electrification with heat pumps, and heat pumps with HVAC demand flexibility. These profiles are the load input for the downstream grid-edge optimization.

**Approach.** Measured AMI data describes today's load but cannot answer what-if questions; building energy models can, but are not tied to specific customers. The pipeline links the two:

1. Each residential AMI meter is represented by one or more ResStock buildings whose simulated 2024 load best matches the meter's measured 2024 load (matching).
2. The matched buildings are then re-simulated under each scenario, keeping the match fixed, so differences between scenarios come only from the change to the building model.
3. Building loads are aggregated to transformer nodes through the meter→transformer map of the utility; meters without a usable match keep their measured load.

**Scope.**
- Residential load only. Non-residential meters are carried as measured AMI (`_NRS` columns) and are not changed by the scenarios.
- One year, 2024, on a 365-day 15-minute grid (35,040 intervals, Feb 29 removed).
- Not covered here: the matching algorithm itself (external repository), power-flow modelling and optimization. System- and node-level scenario results (energy and peak demand) are summarised in §12.

## 2. Pipeline overview

Run the notebooks top to bottom, in this order:

**0 → 1 → (external mapping) → 1.1 → 2 → 3 → 4 → 5**

Notebooks 0 and 1 do not depend on each other and can run in either order. Notebook 1.2 is optional.

### 2.1 Run order and dependencies

```mermaid
flowchart TD
    N0["0 AMI prep + aggregation"]
    N1["1 ResStock models: download + run<br/>(baseline, up04)"]
    M["buildstock-ami-mapping<br/>(external repo)"]
    N11["1.1 metadata plots"]
    N12["1.2 released timeseries<br/>(optional, TMY3)"]
    N2["2 re-simulate: rebuilt + demand flex"]
    N3["3 load tables (+ meter_ids)"]
    N4["4 ResStock aggregation to transformer nodes"]
    NC["Aggregate ResStock and AMI to Feeder Node<br/>(comparison)"]
    N5["5 post-process + visualize<br/>(scenario results)"]

    N0 -->|ami_ind_data_15| M
    N1 -->|resstock_timeseries_all_15| M
    M -->|match_report.csv| N11
    M -->|match_report.csv| N3
    M -->|match_report.csv| N4
    N1 -->|models + building-ID lists| N2
    N1 -.-> N12
    N2 -->|rebuilt model folders| N3
    N3 -->|resstock_timeseries_all_15_scenario| N4
    N0 -->|ami_meter_xfr_map + ami_meter_wide_15| N4
    N0 --> NC
    N4 --> NC
    N4 -->|resstock_plus_ami_fallback node tables| N5
```

| Step | Notebook / tool | Needs | What you get |
|---|---|---|---|
| 0 | `0_ami_data_prep_and_aggregation.ipynb` | raw AMI file, `location_reference.csv` | Cleaned 2024 AMI tables; AMI aggregated per transformer node; meter-to-transformer map and meter-wide AMI table |
| 1 | `1_resstock_models_download_and_run.ipynb` | NY metadata CSV, OpenStudio | Downloaded and simulated ResStock buildings (baseline and upgrade 4), original load tables |
| ext | `buildstock-ami-mapping` (external) | outputs of 0 and 1 | `results/match_report.csv` (AMI meter to ResStock building) |
| 1.1 | `1.1_resstock_metadata_plots.ipynb` | `match_report.csv`, metadata CSV | Distribution plots of matched buildings |
| 1.2 | `1.2_resstock_timeseries_download.ipynb` (optional) | building-ID list from 1 | NREL-released TMY3 timeseries (not used downstream) |
| 2 | `2_resstock_models_df_run.ipynb` | models and building-ID lists from 1 | Rebuilt models (2025_Release_1 measures) and demand-flex models, simulated |
| 3 | `3_resstock_load_table_build.ipynb` | rebuilt models from 2, `match_report.csv` | Load tables per scenario with a `meter_ids` column; `building_to_meter_map.csv` |
| 4 | `4_resstock_aggregation.ipynb` | load tables from 3, `match_report.csv`, AMI map and meter-wide table from 0 | ResStock residential load per transformer node for each scenario, with AMI fallback for unmatched meters |
| 5 | `5_postprocess_visualize.ipynb` | `resstock_plus_ami_fallback` node tables from 4 (three rebuilt scenarios) | Scenario comparison of energy and peak demand at system and node level, including peaks within the demand-flex window (§12) |
| - | `Aggregate ResStock and AMI to Feeder Node_02022026-Copy1.ipynb` | aggregated node files from 0 and 4 | Branch-level ResStock vs AMI comparison plots |

### 2.2 Scenarios analysed

All scenarios use the same 766 buildings (7 counties), the `Ithaca_2024.epw` weather file and 35,040 15-minute timestamps. Upgrade 4 only applies to part of the buildings (`applicability == True`); the rest are filled according to `MISSING_BLDG_POLICY` in notebook 4.

| Scenario | Made by | Description | Used for |
|---|---|---|---|
| AMI (measured) | notebook 0 | Smart meter data of ~792 service points, gaps handled by `GAP_METHOD` (`zero`, `nan`, `interpolate`) | Reference; matching; fallback for unmatched meters |
| Original baseline (`UPGRADE = 0`) | notebook 1 | Released baseline models, simulated with 2024 weather | Matching against AMI and validation |
| Original upgrade 4 (`UPGRADE = 4`) | notebook 1 | ENERGY STAR heat pump with the existing system as backup | Matching/validation of the upgrade set |
| `baseline_rebuilt` | notebooks 2 and 3 | Baseline rebuilt with the 2025_Release_1 measures, no flexibility | Baseline for the scenario comparison |
| `up04_rebuilt` | notebooks 2 and 3 | Heat pump (upgrade 4) rebuilt, no flexibility | Control for the demand-flex run |
| `up04_df_2F` | notebooks 2 and 3 | Heat pump plus upgrade 24: HVAC demand flexibility, 2 F load shed during on-peak hours | Demand-flex scenario |

Compare scenarios only among the three rebuilt runs. The original runs are kept for validation against AMI, because the rebuild shifts annual electricity by a few percent.

### 2.3 Inputs and outputs per step

`<s>` is a scenario name, `<g>` the AMI gap tag.

| Step | Inputs | Outputs |
|---|---|---|
| 0 | `data/input_files/consumption/ch1_4301002_individual.csv`, `data/input_files/location_reference.csv` | `data/parquet/ami_ind_data_15.*`, `ami_ind_data_hour.*`, `ami_duplicates_2024.csv`, `ami_meter_wide_15_<g>.parquet`; `results/aggregated_load_nodes_wide_ami_<g>.*`, `aggregated_load_nodes_ami_<g>_report.csv`, `ami_meter_xfr_map.csv`, `ami_meter_gap_summary.csv` |
| 1 | `data/input_files/NY_baseline_metadata_and_annual_results_2024_amy.csv` (and `NY_upgradeNN_...` for an upgrade), `data/base_files/` (workflow, measures, weather) | `data/base_files/building_ids_metadata_2024[_upNN].csv`, `data/resstock_models[_upNN]/`, `data/parquet/resstock_timeseries_all_15[_upNN].*`, `..._all_hour...`, `..._annual...` |
| ext | `ami_ind_data_15` (0), `resstock_timeseries_all_15` (1) | `results/match_report.csv` |
| 1.1 | `results/match_report.csv`, metadata CSV | `results/plots[_upNN]/`, `results/plots_spot_ids[_upNN]/` |
| 1.2 | `data/base_files/building_ids_metadata_2024[_upNN].csv`, public S3 bucket | `data/parquet/resstock_timeseries_*_released[_upNN].*` |
| 2 | `data/resstock_models[_up04]/`, building-ID lists (1), 2025_Release_1 measures, `Ithaca_2024.epw` | `data/resstock_models_rebuilt/`, `data/resstock_models_up04_rebuilt/`, `data/resstock_models_up04_df/` (each building with `run/eplusout.csv`) |
| 3 | rebuilt model folders (2), building-ID lists (1), `results/match_report.csv` | `data/parquet/resstock_timeseries_all_15_<s>.*`, `..._all_hour_<s>.*`, `..._annual_<s>.*` (each with `meter_ids`); `results/building_to_meter_map.csv` |
| 4 | `data/parquet/resstock_timeseries_all_15_<s>.parquet` (3), `results/match_report.csv`, `results/ami_meter_xfr_map.csv` and `data/parquet/ami_meter_wide_15_<g>.parquet` (0) | per scenario in `results/`: `aggregated_load_nodes_wide_resstock_RES_<s>.*`, `..._ami_fallback_RES_<s>_ami-<g>.*`, `..._resstock_plus_ami_fallback_RES_<s>_ami-<g>.*`, `resstock_aggregation_report_<s>.csv`, `resstock_meter_sources_<s>.csv`; plus `resstock_meter_status.csv` |
| 5 | `results/aggregated_load_nodes_wide_resstock_plus_ami_fallback_RES_<s>_ami-<g>.*` (4), `resstock_aggregation_report_baseline_rebuilt.csv` (check), `data/resstock_models_up04_df/*/run/in.schedules.csv` (window check) | `results/figures_postprocess/*.csv`, `*.png` (§12.10) |

### 2.4 Final outcomes

- **Transformer-node residential load per scenario** (`aggregated_load_nodes_wide_resstock_plus_ami_fallback_RES_<s>_ami-<g>.*`): the main input for the optimization work. For each of the three rebuilt scenarios it holds one 15-minute column per transformer (`<gisid>_RES`), ResStock for matched meters and AMI for the unmatched ones.
- **Measured AMI load per transformer node** (`aggregated_load_nodes_wide_ami_<g>.*`): residential and non-residential columns (`_RES`, `_NRS`), the reference and the source of the non-residential load.
- **Building load tables with `meter_ids`** (`resstock_timeseries_all_15_<s>.*`): 15-minute, hourly and annual ResStock loads per building, linked to the matched AMI meters.
- **Traceability reports:** `resstock_meter_sources_<s>.csv` and `resstock_meter_status.csv` show which meters use ResStock and which fall back to AMI.
- **Comparison and plots:** metadata distribution plots (1.1) and the ResStock vs AMI branch comparison.
- **Scenario results** (`results/figures_postprocess/`): summary tables and figures of energy and peak demand per scenario and per pairwise comparison (notebook 5, §12).

---

## 3. Study area and data sources

| Source | Content | Used for |
|---|---|---|
| AMI interval data (`ch1_4301002_individual.csv`) | `SERVICEPOINTID`, `CHANNELNUMBER`, `ENDTIME_EST` (interval end), `INTERVAL_READ` (kWh per 15 min); about 792 service points (SPIDs) on the Dryden circuit, 154 of them non-residential | Measured reference, matching target, fallback load |
| Location reference (`location_reference.csv`) | SPID → transformer (`xfr_gisid`) and sector (`Residential`) | Meter-to-node map |
| ResStock metadata, AMY release (`resstock_amy2018_release_2`, OEDI bucket `oedi-data-lake`) | Building characteristics, upgrade applicability, annual results for NY | Building selection |
| ResStock building models (same release) | Per-building `home.xml`, `in.schedules.csv`, `in.osm` for the baseline and upgrade 4 | Simulation |
| Weather file `Ithaca_2024.epw` | Actual 2024 weather for Ithaca | All simulations |
| OpenDSS feeder model | Transformer-level topology | Node definitions downstream (not used for the load build) |

**Building sample.** All 766 NY ResStock buildings in the seven counties around Ithaca (Cayuga, Chemung, Cortland, Schuyler, Seneca, Tioga, Tompkins) are simulated, not only the ones that end up matched. Justification: the matching step needs a candidate pool, and the pool should reflect the regional stock (climate zone, vintages, heating fuels) rather than the state as a whole. The county filter keeps the pool small enough to simulate locally while remaining representative of the circuit.

**Release choice (AMY vs TMY).** The AMY 2018 release is used for both metadata and models so that the building sample and its characteristics come from one consistent release. The release's own weather is not used: every model is re-simulated with the actual 2024 weather so that simulated and measured loads share the same weather year. Annual `out.*` columns of the metadata (simulated with 2018 weather) are therefore not comparable with the 2024 simulations. Details and the expected TMY/AMY differences are in [weather_basis_amy_vs_tmy.md](weather_basis_amy_vs_tmy.md).

## 4. AMI preparation (notebook 0, sections 1–2)

| Step | Method | Justification |
|---|---|---|
| Year filter | Keep `ENDTIME_EST` in 2024 | Same year as the weather file |
| Duplicates | Average rows with the same (SPID, timestamp) | All duplicates are the daylight-saving fall-back hour (Nov 3, 01:00–01:45), recorded twice in local clock time. Averaging keeps one value per interval on a regular grid; summing would double the hour, dropping one copy would be arbitrary |
| Leap day | Drop Feb 29 | The ResStock schedules have 365 days (35,040 rows); keeping Feb 29 would shift every later day by one against the simulations |
| Hourly table | Sum the four 15-min values by `floor(hour)` of the interval-end timestamp | Same convention as the ResStock hourly tables, so the two are directly comparable (see §11) |
| Diagnostic | Report multi-channel meters and duplicate rows (`ami_duplicates_2024.csv`) | Makes the duplicate handling auditable |

Values stay in kWh per 15 min (energy, not power) throughout, so aggregation is a plain sum and energy is conserved by construction.

## 5. AMI aggregation to transformer nodes (notebook 0, section 3)

**Regular grid.** Meters are pivoted to a time × SPID table on the full 35,040-step grid. Missing readings (including the spring-forward hour, missing for every meter) become explicit NaN so that they can be counted and handled consistently.

**Gap handling (`GAP_METHOD`).** A per-meter gap summary (coverage, number and length of gaps, first/last reading) is written before any filling. Three options are offered because no single choice suits every downstream use:

| Method | Behaviour | When to use | Trade-off |
|---|---|---|---|
| `zero` | NaN → 0 | Energy totals; reproduces the original notebook | Biases load low during gaps; creates artificial dips |
| `nan` | NaN kept and propagated | Strict analyses that must not use invented data | A node column is NaN wherever any of its meters is missing |
| `interpolate` | Linear interpolation of interior gaps of at most `INTERP_MAX_GAP` intervals (default 4 = 1 h); longer and edge gaps stay NaN | Time-series use (optimization) where short telemetry drops should not create dips | Smooths short peaks; long outages remain unresolved |

The gap tag (`zero`, `nan`, `interp<N>`) is written into every output name so that results built with different choices cannot be mixed by accident.

**Meter → transformer map.** Each SPID–transformer pair of the location reference becomes one row. Sector is `RES` when the `Residential` field starts with "res", otherwise `NRS`. A meter listed on *n* transformers (62 meters) is split equally, `weight = 1/n_xfr`. Justification: the location file gives no allocation share, and an equal split conserves the meter's energy while avoiding double counting. Meters without a transformer, and location-file meters without AMI, are reported rather than silently dropped.

**Aggregation.** Each node column `<xfr_gisid>_<RES|NRS>` is $\sum_m w_m \, E_m(t)$ over the meters with AMI on that transformer and sector, with `skipna=False` so that unresolved gaps stay visible. For `zero`, an assertion checks that total meter energy equals total node energy (relative tolerance $10^{-9}$).

**Outputs for later steps.** The map (`ami_meter_xfr_map.csv`) and the gap-handled meter-wide table (`ami_meter_wide_15_<g>.parquet`) are saved so that notebook 4 reuses exactly the same map, weights and gap treatment for its AMI fallback.

## 6. ResStock selection, download and simulation (notebook 1)

**Selection.** For the baseline, all 766 county buildings. For an upgrade (`UPGRADE = 4`), only buildings with `applicability == True` in the upgrade metadata (483 of 766 for upgrade 4), because model zips exist only for those. Every output of an upgrade run carries an `_upNN` tag so that runs never overwrite each other.

**Download.** Models are fetched from the public OEDI bucket in parallel (boto3 multipart, AWS CLI fallback); finished downloads are skipped on re-runs.

**Simulation.** Each model runs with OpenStudio 3.8.0 / EnergyPlus 24.1 through `workflow_resstock.osw`, seeded with the released `in.osm` and pointed at `Ithaca_2024.epw`. Justification: the released `in.osm` reproduces the released model exactly, so the only change from the release is the weather. The run period is set to 2023-01-01 to 2023-12-31 at 4 timesteps per hour (`set_run_period`), giving 35,040 intervals that match the 365-day schedules.

**Outputs measure.** `add_outputs` registers an EMS sensor on `Electricity:Facility` and reports it in kWh per timestep. Only this meter is registered by default: EnergyPlus creates some meters (e.g. `Cooling:Electricity`, `WaterSystems:NaturalGas`) only when a matching component exists, and a sensor on a missing meter aborts the run. Additional meters are opt-in (`include_extra_meters`).

**Failure handling.** A building fails if OpenStudio returns non-zero or `run/failed.job` exists; the first Severe error of each failure is summarised by cause. Re-runs skip finished buildings, so a batch can be resumed after fixing the cause.

**Load tables.** `eplusout.csv` of every finished building is condensed into 15-min, hourly and annual tables (`resstock_timeseries_all_15[_upNN]`, …), with the time conventions of §11. These "original" tables feed the matching step.

## 7. Building–meter matching (external step)

Matching is done in the separate `buildstock-ami-mapping` repository (`grid-edge` branch) from the 15-min AMI table (notebook 0) and the original ResStock baseline table (notebook 1). It ranks candidate buildings for each residential meter by load-shape agreement (CVRMSE, peak timing similarity and related shape metrics) and writes `results/match_report.csv` (`meter id` → `ResStock_ids`).

Properties that the later steps rely on:

- A meter can be matched to several buildings (*k* ≥ 1) or to none (empty list).
- A building can be matched to several meters (up to 14). This is expected: the candidate pool is small relative to the number of meters, and similar homes legitimately share an archetype.
- Matching is done once, against the original baseline runs, and is then held fixed for all scenarios. This isolates the scenario effect from any change in which buildings represent which meters.

## 8. Rebuilt and demand-flexibility simulations (notebook 2)

**Why rebuild.** The demand-flexibility measure (ResStock upgrade 24, "HVAC Demand Flexibility with On-Peak Load Shedding") exists only in ResStock `2025_Release_1` and acts on the HPXML schedules before the model is built. The released `in.osm` cannot be modified this way, so the models must be rebuilt from `home.xml` + `in.schedules.csv` with the 2025 measures. To keep scenario differences attributable to the flexibility alone, the no-flex controls (baseline and upgrade 4) are rebuilt through the identical path with a 0 °F offset.

**Common build path (per building).**

1. Copy `home.xml`, `in.schedules.csv` (if present) and the weather file from the source model; the source folders are never modified.
2. Apply compatibility patches (below).
3. Run `ResStockArgumentsPostHPXML` (setpoint shift; skipped at 0 °F) → `HPXMLtoOpenStudio` → `set_run_period` → `add_outputs` → EnergyPlus.

**Compatibility patches and their reasons.**

| Patch | Reason |
|---|---|
| ResStock `2025_Release_1` export with `OS_Version` set to 3.8.0 and `setKeepSiteLocationInformation` guarded | Run on the same OpenStudio 3.8.0 / EnergyPlus 24.1 as the original runs, so the engine is not a confounder |
| Derived weather file `Ithaca_2024_noleap2023.epw` (Feb 29 removed, year 2023) | The 365-day schedules do not fit the 8,784-hour leap-year EPW and the newer `HPXMLtoOpenStudio` rejects the mismatch; the 2023 calendar matches the run period of the original runs |
| Drop the all-zero `Vacancy` / `Power Outage` schedule columns | The newer reader treats them as unknown columns and fails; being all zero, they carry no information |
| Remove `DesignLoads`, `EmissionsScenarios` and the default `TemperatureCapacitanceMultiplier` from `home.xml` | Old element layout rejected by the newer schema, or references to files only present in a full ResStock checkout; design loads are recomputed during the build |
| Copy of `add_outputs` with EMS update frequency `ZoneTimestep` | EnergyPlus 24.1 rejects `Timestep` for that EMS output variable |

**Upgrade 24 settings.** `hvac_flex_peak_offset = 2` °F, pre-peak duration and offset 0, random shift 0. This is a pure on-peak load shed: heating setpoint −2 °F and cooling setpoint +2 °F during the NY on-peak window (18–22 h in summer, 17–21 h in winter and intermediate months, in standard time; one hour later on the local clock during DST). The window and its verification are described in §12.4. Pre-conditioning and randomisation are disabled so the scenario represents a single, transparent control action; other variants can be added as new entries of `SCENARIOS`.

**Vacant homes.** Buildings with no residents (69 in upgrade 4, 111 in the baseline) have no `in.schedules.csv` in the release. They are built with the default HPXML schedules, and the flexibility measure creates a schedule file with only the setpoint columns. They are kept so that every scenario contains the same buildings.

**Comparability.** The rebuild changes annual electricity by a few percent and not in a consistent direction (tested on one building: baseline −2.5 %, upgrade 4 +1.7 %), owing to measure-version differences. Scenarios are therefore compared only among the rebuilt runs; the original runs remain the basis for matching and validation against AMI.

## 9. Scenario load tables (notebook 3)

**Inclusion rule.** A building is used only if `run/eplusout.csv` and `run/finished.job` exist and `run/failed.job` does not. Unfinished and unreadable buildings are listed per scenario, so incomplete batches are visible instead of silently shrinking the sample.

**Conventions.** Identical to notebook 1 (column `EMS:EMS_ElectricityFacility_kWh [](TimeStep)`, `2024-` label prefix, midnight relabel, `floor(hour)` sums; §11), so original and rebuilt tables can be read with the same code.

**`meter_ids`.** Every row carries the list of AMI meters the building is matched to (from `match_report.csv`; `[]` when unmatched), and `building_to_meter_map.csv` lists the pairs. Justification: the building–meter relation is many-to-many; carrying it with the load data lets downstream users filter or join without re-reading the match report.

**Streaming.** Buildings are read in parallel and written incrementally to Parquet/CSV, so the full 15-min table (tens of millions of rows) never has to fit in memory. CSV output is optional (`WRITE_CSV`).

## 10. ResStock aggregation to transformer nodes (notebook 4)

**Meter load from matched buildings.** A residential meter matched to *k* buildings receives the average of their series:

$$
E_m^{\text{ResStock}}(t) = \frac{1}{k_m} \sum_{b \in B_m} E_b(t)
$$

Averaging (rather than summing) keeps one dwelling per meter, which is what a residential meter measures; the *k* matches are alternative representations of the same home. A building matched to several meters is counted once **per meter**: each meter is a separate dwelling, so reuse of an archetype is legitimate. (The superseded notebook de-duplicated buildings per transformer and under-counted load.)

**Node load.** Meter loads are distributed with the same `1/n_xfr` weights as notebook 0, so ResStock and AMI node columns share one map:

$$
E_x^{\text{RES}}(t) = \sum_{m \in M_x^{\text{matched}}} w_{m,x} \, E_m^{\text{ResStock}}(t) + \sum_{m \in M_x^{\text{fallback}}} w_{m,x} \, E_m^{\text{AMI}}(t)
$$

**AMI fallback.** Residential meters with an empty match list or absent from the match report keep their measured AMI load (from `ami_meter_wide_15_<g>`, i.e. with the chosen gap treatment). Justification: dropping them would under-state node load, while assigning an arbitrary building would invent a load shape. The fallback part is unchanged across scenarios, which is a stated limitation (§13). Meters with neither a match nor AMI contribute nothing and are flagged `no_data`. The ResStock part, the fallback part and their sum are written as separate files so that each can be used or checked on its own.

**Buildings missing from a scenario.** Upgrade 4 applies to only part of the stock, so some matched buildings have no upgrade series. `MISSING_BLDG_POLICY`:

- `"baseline"` (default): use the building's `baseline_rebuilt` series, i.e. a non-applicable building keeps its existing equipment. This mirrors how ResStock itself treats non-applicable buildings.
- `"ami"`: send the whole meter to the AMI fallback.

**Checks and traceability.** Per scenario, the total energy of the ResStock node table is asserted equal to the weighted sum of the meter loads (relative tolerance $10^{-9}$). `resstock_meter_status.csv` (`match_status` = `matched`, `empty_match` or `not_in_report`, plus `has_ami`) and `resstock_meter_sources_<s>.csv` (source per meter: `resstock`, `ami_fallback` or `no_data`, with the reason) make every node value traceable to its meters and buildings; `resstock_aggregation_report_<s>.csv` summarises each transformer.

**Non-residential load** is not modelled; the `_NRS` columns of notebook 0 are used unchanged.

## 11. Time alignment and calendar conventions

| Item | Convention | Consequence |
|---|---|---|
| Grid | 2024-01-01 00:00 to 2024-12-31 23:45, interval-end, Feb 29 removed: 35,040 steps | Same index for AMI and every ResStock scenario |
| Units | kWh per 15 min | Sums are energy; divide by 0.25 h for average kW |
| Simulation calendar | Run period 2023 (Jan 1 = Sunday); 2024 weather mapped by month/day; labels re-prefixed `2024-` | Weather and labels are aligned by date. The EnergyPlus weekday is 1 day behind the 2024 weekday before Feb 29 and 2 days behind after it, so weekday/weekend patterns align only approximately |
| EnergyPlus midnight | `24:00:00` relabelled to `00:00:00` of the **same** day when building the tables | 1 of 96 intervals per day is labelled 24 h early; `FIX_EPLUS_MIDNIGHT = True` in notebook 4 moves it to the next day (`_midfix` in output names). The first interval of the year is 0 in ResStock |
| Clock | ResStock in local standard time; AMI in local clock time with DST | From Mar 10 to Nov 3, ResStock and AMI differ by one hour. The AMI fall-back hour is averaged and the spring-forward hour is missing |
| Hourly tables | Sum by `floor(hour)` of the interval-end stamp | Hour *h* holds intervals ending at *h*:00–*h*:45, identical for AMI and ResStock |

These conventions are documented rather than corrected in the data because the original tables feed the external matching step, and changing them would change the match. The optional midnight fix is applied at aggregation time only.

## 12. Scenario results (notebook 5)

`5_postprocess_visualize.ipynb` compares the three rebuilt scenarios using `aggregated_load_nodes_wide_resstock_plus_ami_fallback_RES_<s>_ami-zero` (AMI gap tag `zero`, `MISSING_BLDG_POLICY = "baseline"`, no midnight fix).

- **Load.** The tables hold kWh per 15 min; the notebook divides by 0.25 h to get average kW. The **system load** is the sum of the 146 residential node columns (`_RES`). It includes the static AMI-fallback meters and excludes non-residential load.
- **Seasons.** Meteorological seasons are used (Winter = Dec–Feb, Spring = Mar–May, Summer = Jun–Aug, Fall = Sep–Nov). The exception is the demand-flex (DF) measure's own seasons, which are labelled as such (§12.4).
- **Timestamps.** Interval-end, local standard time, 2024 labels (§11).
- **Check.** Baseline annual energy (4,013,436 kWh) equals the total of `resstock_aggregation_report_baseline_rebuilt.csv`.
- **Figures.** The figures below are copies of the notebook outputs, kept in `docs/figures/postprocess/` because `results/` is not tracked by git. Re-copy them after re-running notebook 5.

Scenario names: **Baseline** = `baseline_rebuilt`, **Up4** = `up04_rebuilt`, **Up4+DF** = `up04_df_2F`.

### 12.1 System summary

| Metric | Baseline | Up4 | Up4+DF |
|---|---:|---:|---:|
| Annual energy (MWh) | 4,013.4 | 5,678.7 | 5,629.4 |
| Annual peak (kW) | 1,116.0 | 1,743.4 | 1,743.8 |
| Annual peak time | Dec 21 18:45 | Jan 14 12:30 | Jan 14 12:30 |
| Average load (kW) | 458.2 | 648.3 | 642.6 |
| Minimum load (kW) | 64.2 | 64.2 | 64.2 |
| Load factor (%) | 41.1 | 37.2 | 36.9 |
| P95 / P99 load (kW) | 737 / 893 | 1,131 / 1,369 | 1,124 / 1,363 |
| Hours above 90 % of peak | 15.3 | 10.8 | 8.5 |

| Comparison | Δ energy (MWh) | Δ energy (%) | Δ peak (kW) | Δ peak (%) | Δ load factor (pp) | Δ P99 (kW) |
|---|---:|---:|---:|---:|---:|---:|
| Up4 vs Baseline | +1,665.2 | +41.5 | +627.5 | +56.2 | −3.9 | +475.7 |
| Up4+DF vs Baseline | +1,615.9 | +40.3 | +627.8 | +56.3 | −4.2 | +470.2 |
| Up4+DF vs Up4 | −49.3 | −0.87 | +0.4 | +0.02 | −0.3 | −5.5 |

### 12.2 Energy: annual and monthly

| Month | Baseline (MWh) | Up4 (MWh) | Up4+DF (MWh) | Up4 vs Baseline (%) | Up4+DF vs Baseline (%) | Up4+DF vs Up4 (%) |
|---|---:|---:|---:|---:|---:|---:|
| Jan | 456.0 | 733.9 | 729.8 | +60.9 | +60.0 | −0.56 |
| Feb | 379.3 | 608.1 | 603.6 | +60.3 | +59.1 | −0.75 |
| Mar | 375.8 | 585.5 | 580.6 | +55.8 | +54.5 | −0.83 |
| Apr | 306.0 | 447.6 | 443.4 | +46.3 | +44.9 | −0.94 |
| May | 269.3 | 319.4 | 315.8 | +18.6 | +17.2 | −1.16 |
| Jun | 282.3 | 336.9 | 333.5 | +19.3 | +18.1 | −1.01 |
| Jul | 310.7 | 384.6 | 381.1 | +23.8 | +22.6 | −0.92 |
| Aug | 290.3 | 341.4 | 337.9 | +17.6 | +16.4 | −1.01 |
| Sep | 260.3 | 295.7 | 292.8 | +13.6 | +12.5 | −0.99 |
| Oct | 287.9 | 392.8 | 388.3 | +36.4 | +34.9 | −1.14 |
| Nov | 335.4 | 511.3 | 505.7 | +52.5 | +50.8 | −1.10 |
| Dec | 460.1 | 721.4 | 716.9 | +56.8 | +55.8 | −0.62 |
| **Annual** | **4,013.4** | **5,678.7** | **5,629.4** | **+41.5** | **+40.3** | **−0.87** |

- **Electrification (Up4 vs Baseline).** The increase is driven by heating: +55 to +61 % in Dec–Mar and +46 to +52 % in Apr and Nov, against +14 to +24 % in May–Sep.
- **Demand flexibility (Up4+DF vs Up4).** DF saves 3–6 MWh every month. The relative saving is smallest in Jan and Dec (−0.6 %), where the total load is largest, and around −1 % in the other months. The saving is net: the energy shed inside the window is partly recovered after it (§12.6).

![Annual and monthly energy per scenario, and monthly pairwise change](figures/postprocess/energy_annual_monthly.png)
*Figure 12.1. Annual energy (left), monthly energy (middle) and monthly pairwise energy change (right).*

![Monthly energy change, Up4+DF vs Up4](figures/postprocess/energy_monthly_df_vs_up04.png)
*Figure 12.2. Monthly energy change of Up4+DF vs Up4 (net of shed and rebound).*

### 12.3 Peak demand over all hours

| Season | Baseline (kW) | Up4 (kW) | Up4+DF (kW) | Up4 vs Baseline (%) | Up4+DF vs Baseline (%) | Up4+DF vs Up4 (%) | Peak time (Baseline / Up4 / Up4+DF) |
|---|---:|---:|---:|---:|---:|---:|---|
| Winter | 1,116.0 | 1,743.4 | 1,743.8 | +56.2 | +56.3 | +0.02 | Dec 21 18:45 / Jan 14 12:30 / Jan 14 12:30 |
| Spring | 974.3 | 1,514.1 | 1,529.6 | +55.4 | +57.0 | +1.03 | Mar 10 22:15 (all) |
| Summer | 732.1 | 1,034.0 | 1,032.3 | +41.2 | +41.0 | −0.16 | Jul 15 17:15 (all) |
| Fall | 934.2 | 1,430.9 | 1,430.1 | +53.2 | +53.1 | −0.05 | Nov 30 13:15 (all) |

Monthly peaks over all hours change by +26 to +59 % for Up4 vs Baseline. Up4+DF vs Up4 changes them by between −2.9 % (Dec) and +1.0 % (Mar); every other month is within ±1 %. The full monthly table is in `monthly_peaks_kw.csv`.

- **Electrification moves the annual peak.** It goes from a winter evening (Dec 21 18:45) to the middle of the coldest day (Jan 14 12:30), and it rises by 56 %.
- **DF barely changes the all-hours peaks.** DF only acts inside its window (§12.4), and most all-hours peaks fall outside it: Jan 14 12:30, Mar 10 22:15, Jul 15 17:15 and Nov 30 13:15.
- **December** is the only month whose all-hours peak lies inside the window (Dec 21 18:45), and its peak drops by 2.9 %.
- **March** rises by 1.0 % because Up4+DF's peak (Mar 10 22:15) falls about an hour after the window ends. There the Up4+DF load is still above Up4 during recovery from the shed. The first interval after the window shows a rebound spike of +156 kW.

![Annual, seasonal and monthly peaks over all hours](figures/postprocess/demand_peaks.png)
*Figure 12.3. All-hours peaks: annual (left), seasonal (middle) and monthly (right).*

![Monthly peak change over all hours, pairwise](figures/postprocess/monthly_peak_pairwise.png)
*Figure 12.4. Monthly all-hours peak change for each pairwise comparison.*

![Load duration curves](figures/postprocess/load_duration.png)
*Figure 12.5. System load duration curve over the full year (left) and over the top 100 hours (right).*

### 12.4 Demand-flexibility peak window

**Definition.** The DF run uses `ResStockArgumentsPostHPXML` (ResStock `2025_Release_1`) with no pre-peak period. In this mode the measure (`resources/common/schedule_modifier.rb`, `_get_peak_hour`) reads its peak window from `seasonal_shedding_peak_hours.json`. That file holds the Cambium 2050 MidCase net-load peak hour per state and season (Gagnon et al., 2024), and the window is applied every day. The NY entry is:

| Measure season | Months | Window (local standard time) |
|---|---|---|
| Winter | Dec, Jan, Feb, Mar | 17:00–21:00 |
| Intermediate | Apr, May, Oct, Nov | 17:00–21:00 |
| Summer | Jun–Sep | 18:00–22:00 |

**Verification.**

- **Schedule.** The `peak_period` column of the DF `in.schedules.csv` is identical across the buildings checked and matches these hours. During DST (Mar 11 – Nov 4) the file shifts them by +1 h, which EnergyPlus offsets. In the standard-time output the shed therefore stays at the same hours all year; no DST step is visible in the results.
- **Load response.** The system Up4+DF − Up4 difference is negative over exactly 16 intervals (4 h) per day and is followed by a rebound spike. On the 15-min interval-end labels the response appears one interval later than the nominal window:
  - labels 17:30–21:15 in winter and intermediate months;
  - labels 18:30–22:15 in summer.

  The notebook's window mask (`in_window`, with `WINDOW_LAG` = 15 min) reproduces this exactly: 5,840 intervals, i.e. 1,460 h per year (Figure 12.6).

![DF window verification](figures/postprocess/df_window_verification.png)
*Figure 12.6. Mean Up4+DF − Up4 system load by time of day for each measure season. Bars span the 15-min interval ending at the label; red bars are intervals inside the window mask.*

**Why separate the window.** DF is designed to cut load in the window only. A peak taken over all hours mixes that effect with peaks that DF does not target (§12.3). Each peak metric is therefore reported twice:

- **All hours** — the maximum over the full period;
- **DF window** — the maximum over the window intervals only.

### 12.5 Peak demand within the DF window vs all hours

| Period | Baseline (kW) | Up4 (kW) | Up4+DF (kW) | Up4 vs Baseline (%) | Up4+DF vs Baseline (%) | **Up4+DF vs Up4, window (%)** | Up4+DF vs Up4, all hours (%) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Annual | 1,116.0 | 1,700.1 | 1,650.5 | +52.4 | +47.9 | **−2.92** | +0.02 |
| Winter | 1,116.0 | 1,700.1 | 1,650.5 | +52.4 | +47.9 | **−2.92** | +0.02 |
| Spring | 951.3 | 1,392.5 | 1,356.2 | +46.4 | +42.6 | **−2.60** | +1.03 |
| Summer | 717.9 | 941.9 | 905.5 | +31.2 | +26.1 | **−3.86** | −0.16 |
| Fall | 918.0 | 1,330.7 | 1,296.6 | +45.0 | +41.2 | **−2.57** | −0.05 |
| Jan | 1,098.2 | 1,633.0 | 1,578.8 | +48.7 | +43.8 | **−3.32** | +0.02 |
| Feb | 1,003.2 | 1,570.6 | 1,520.3 | +56.6 | +51.5 | **−3.20** | −0.93 |
| Mar | 951.3 | 1,392.5 | 1,356.2 | +46.4 | +42.6 | **−2.60** | +1.03 |
| Apr | 758.9 | 1,103.7 | 1,060.6 | +45.4 | +39.8 | **−3.91** | −0.28 |
| May | 672.0 | 864.9 | 783.1 | +28.7 | +16.5 | **−9.47** | −0.30 |
| Jun | 717.9 | 941.9 | 905.5 | +31.2 | +26.1 | **−3.86** | −0.45 |
| Jul | 689.3 | 870.9 | 806.8 | +26.3 | +17.1 | **−7.35** | −0.16 |
| Aug | 641.5 | 814.6 | 708.9 | +27.0 | +10.5 | **−12.98** | +0.17 |
| Sep | 649.8 | 800.8 | 670.1 | +23.2 | +3.1 | **−16.32** | +0.11 |
| Oct | 600.6 | 851.9 | 801.4 | +41.8 | +33.4 | **−5.93** | +0.05 |
| Nov | 918.0 | 1,330.7 | 1,296.6 | +45.0 | +41.2 | **−2.57** | −0.05 |
| Dec | 1,116.0 | 1,700.1 | 1,650.5 | +52.4 | +47.9 | **−2.92** | −2.92 |

Window peak times (interval-end):

| Season | Baseline | Up4 | Up4+DF |
|---|---|---|---|
| Winter / annual | Dec 21 18:45 | Dec 21 18:45 | Dec 21 18:45 |
| Spring | Mar 20 19:45 | Mar 20 19:45 | Mar 20 19:45 |
| Summer | Jun 18 18:45 | Jun 19 18:45 | Jun 19 19:00 |
| Fall | Nov 30 20:00 | Nov 30 20:00 | Nov 30 20:00 |

- **DF reduces every in-window peak.** The reduction is 2.6–3.9 % per season and 2.6–16.3 % per month (34–131 kW). Over all hours, the same comparison changes by only −2.9 % to +1.0 %.
- **Relative reduction is largest in late summer and the shoulder months** (Sep −16 %, Aug −13 %, May −9 %, Jul −7 %). There the window peak is smaller and HVAC makes up a larger share of it. In absolute terms the largest cuts are Sep (−131 kW) and Aug (−106 kW). In the heating months the cuts are around 50 kW (Dec −50 kW, Jan −54 kW).
- **Electrification adds less to the window peak than to the all-hours peak** (+52.4 % vs +56.2 % annually), because the new heating peak occurs mid-day. With DF, the window peak rises only +47.9 % over Baseline.

![Peak change, DF window vs all hours](figures/postprocess/peak_change_window_vs_all.png)
*Figure 12.7. Pairwise peak change (annual, seasonal, monthly): all hours (grey) vs DF window (red).*

![Monthly peaks, DF window vs all hours](figures/postprocess/monthly_peaks_window_vs_all.png)
*Figure 12.8. Monthly peaks per scenario: all hours (solid) vs DF window (dashed).*

### 12.6 Shed and rebound (DF measure seasons)

The table compares Up4+DF with Up4.

- **In-window** values cover the window intervals.
- **Post-window** values cover the 1 h right after the window, where the setpoints return to normal.

| Measure season (days) | In-window Δ energy (MWh) | In-window Δ energy (%) | Mean in-window Δ (kW) | In-window Δ peak (%) | Post-window 1 h Δ energy (MWh) | Post-window 1 h Δ peak (%) |
|---|---:|---:|---:|---:|---:|---:|
| Winter (121) | −28.6 | −5.8 | −59.0 | −2.9 | +5.3 | +2.9 |
| Intermediate (122) | −28.0 | −8.8 | −57.5 | −2.6 | +5.7 | +13.6 |
| Summer (122) | −29.5 | −10.6 | −60.5 | −3.9 | +8.4 | +23.6 |
| **Year** | **−86.1** | | | | **+19.4** | |

- **Steady shed.** The shed is about 57–61 kW on average (1,460 h per year), almost the same in every season, so the relative energy cut is larger when the window load is smaller.
- **Recovery.** About 22 % of the shed energy (19.4 of 86.1 MWh) comes back in the first hour after the window. Another 17.4 MWh is recovered at other hours, so the annual net saving is 49.3 MWh (57 % of the shed).
- **Rebound peak.** All homes return to normal setpoints in the same interval (no pre-conditioning or randomisation), so the peak of the hour after the window is higher than without DF: +2.9 % in winter, +13.6 % in intermediate months and +23.6 % in summer. In March this recovery sets the all-hours spring peak (§12.3).

![Pairwise delta heatmaps](figures/postprocess/delta_heatmaps.png)
*Figure 12.9. Hourly mean pairwise load change by hour of day (y) and day of year (x). In the right panel (Up4+DF − Up4) the daily shed band and the rebound just after it are visible, as is the one-hour later window in summer.*

### 12.7 Winter and summer peak days

The peak days are the Up4 seasonal peak days: Jan 14 (winter) and Jul 15 (summer). Times are interval-end labels.

| Day | Scenario | Daily peak (kW) @ time | DF-window peak (kW) @ time | Daily energy (MWh) | DF-window energy (MWh) |
|---|---|---:|---:|---:|---:|
| Jan 14 | Baseline | 1,098.2 @ 18:45 | 1,098.2 @ 18:45 | 20.70 | 4.16 |
| Jan 14 | Up4 | 1,743.4 @ 12:30 | 1,633.0 @ 18:15 | 32.91 | 6.25 |
| Jan 14 | Up4+DF | 1,743.8 @ 12:30 | 1,578.8 @ 18:15 | 32.77 | 6.04 |
| Jul 15 | Baseline | 732.1 @ 17:15 | 611.3 @ 19:00 | 11.63 | 2.26 |
| Jul 15 | Up4 | 1,034.0 @ 17:15 | 766.5 @ 19:00 | 15.09 | 2.79 |
| Jul 15 | Up4+DF | 1,032.3 @ 17:15 | 711.5 @ 19:00 | 15.01 | 2.53 |

- **DF cuts the window peak** by 54 kW (−3.3 %) on Jan 14 and by 55 kW (−7.2 %) on Jul 15.
- **The daily peaks fall outside the window and are unchanged.** On Jan 14 the peak is at 12:30, a mid-day heating peak. On Jul 15 it is at 17:15, i.e. the interval ending 17:15, before the 18:00 summer window starts.

![Winter and summer peak-day profiles](figures/postprocess/peak_day_profiles_winter_summer.png)
*Figure 12.10. Load profiles (top) and pairwise change (bottom) on the winter (Jan 14) and summer (Jul 15) peak days; the DF window is shaded.*

![Seasonal average daily profiles](figures/postprocess/seasonal_avg_profiles.png)
*Figure 12.11. Average daily load profile per meteorological season.*

### 12.8 Node-level results (146 transformer nodes)

| Scenario | Node peak mean / median / max (kW) | Node energy mean / median / max (MWh) |
|---|---|---|
| Baseline | 14.8 / 11.8 / 53.2 | 27.5 / 17.2 / 117.6 |
| Up4 | 18.3 / 13.6 / 69.4 | 38.9 / 24.8 / 164.0 |
| Up4+DF | 18.3 / 13.5 / 69.4 | 38.6 / 24.6 / 162.3 |

Some nodes have no residential load (minimum 0).

| Comparison | Period | Mean node Δ peak (kW) | Median node Δ peak (%) | Median node Δ energy (%) | Nodes with peak ↑ (> 0.1 kW) | Nodes with peak ↓ (< −0.1 kW) |
|---|---|---:|---:|---:|---:|---:|
| Up4 vs Baseline | All hours | +3.48 | +13.9 | +43.2 | 106 | 2 |
| Up4 vs Baseline | DF window | +3.10 | +13.0 | +43.2 | 106 | 1 |
| Up4+DF vs Baseline | All hours | +3.46 | +13.1 | +42.0 | 106 | 2 |
| Up4+DF vs Baseline | DF window | +2.79 | +10.8 | +42.0 | 106 | 5 |
| Up4+DF vs Up4 | All hours | −0.02 | 0.0 | −0.87 | 15 | 24 |
| Up4+DF vs Up4 | DF window | −0.31 | −0.5 | −0.87 | 5 | 71 |

| Coincidence factor (system peak ÷ sum of node peaks) | Baseline | Up4 | Up4+DF |
|---|---:|---:|---:|
| All hours | 0.52 | 0.65 | 0.65 |
| DF window | 0.55 | 0.68 | 0.68 |

- **Electrification is concentrated on a few nodes.** The median node peak rises 14 %, but the largest increases are much bigger: `220270653_RES` +43.5 kW (+168 %), `220270497_RES` +27.3 kW (+125 %) and `220270566_RES` +21.0 kW (+79 %). 38 of 146 nodes show no peak change (|Δ| ≤ 0.1 kW):
  - 34 of them do not respond to the upgrade at all; their energy is also unchanged. Their load comes only from the static AMI fallback and/or buildings not applicable to upgrade 4.
  - 1 node has no residential load.
  - 4 nodes gain energy, but their peak does not change.
- **Coincidence rises from 0.52 to 0.65.** Heat-pump load makes node peaks more coincident: they happen on the same cold hours.
- **DF at node level.** Within the window, DF lowers the peak of 71 nodes. The largest cuts are −2.8 kW (`220270497_RES`, −6.7 %), −2.6 kW (`220270653_RES`) and −2.3 kW (`220270566_RES`). Over all hours, DF raises the peak of 15 nodes by up to +1.4 kW (`220269819_RES`, +9.3 %), because of the rebound.

![Node distributions](figures/postprocess/node_distributions.png)
*Figure 12.12. Node annual peak and energy distributions (top), node peak change per comparison (bottom left) and node peak, scenario vs reference (bottom right).*

![Node seasonal peaks](figures/postprocess/node_seasonal_peaks.png)
*Figure 12.13. Node seasonal peak distributions per scenario.*

![Node peak change, DF window vs all hours](figures/postprocess/node_peak_change_window_vs_all.png)
*Figure 12.14. Distribution of node peak change per comparison: all hours (grey) vs DF window (red).*

### 12.9 Key findings

1. **Partial electrification (Up4) is the dominant effect.** Annual energy rises 41.5 % and the system peak 56.2 %. The increase is winter-driven, and the annual peak moves to a cold-day mid-day hour (Jan 14 12:30). The load factor drops from 41.1 % to 37.2 % and node peaks become more coincident (CF 0.52 → 0.65).
2. **The 2 °F DF shed saves 0.87 % of annual energy (49 MWh) and lowers peaks inside its window by 2.6–3.9 % per season (up to 16 % in a month).** It does not lower the all-hours annual peak (+0.02 %), which falls outside the 17–21 h / 18–22 h window.
3. **Rebound partly offsets the shed.** About 22 % of the shed energy returns within the hour after the window. The peak in that hour rises by up to 24 % (summer), and in March the recovery sets a new seasonal peak (+1.0 %).
4. **Report DF peak impacts for both periods.** All-hours peaks understate what DF does inside its window; window peaks overstate what it does for the system peak. With electrified heating, the winter system peak at this circuit falls outside the Cambium-based window.

### 12.10 Output files (`results/figures_postprocess/`)

The PNG files are also copied to `docs/figures/postprocess/` for this document.

| File | Content |
|---|---|
| `system_summary.csv`, `system_pairwise_changes.csv` | §12.1 |
| `monthly_energy_mwh.csv`, `energy_annual_monthly.png`, `energy_monthly_df_vs_up04.png` | §12.2 |
| `seasonal_peaks_kw.csv`, `monthly_peaks_kw.csv`, `demand_peaks.png`, `monthly_peak_pairwise.png` | §12.3 |
| `df_window_verification.png` | §12.4 |
| `peaks_window_vs_all_kw.csv`, `peaks_window_vs_all_time.csv`, `peak_change_window_vs_all.png`, `monthly_peaks_window_vs_all.png` | §12.5 |
| `df_window_shed_rebound.csv` | §12.6 |
| `load_duration.png`, `peak_day_summary.csv`, `peak_day_profiles_winter_summer.png`, `seasonal_avg_profiles.png`, `delta_heatmaps.png` | §12.7 and load shape |
| `node_summary.csv`, `node_pairwise_stats.csv`, `node_distributions.png`, `node_seasonal_peaks.png`, `node_peak_change_window_vs_all.png` | §12.8 |

## 13. Assumptions and limitations

- **Representation.** Each matched meter is represented by archetypal ResStock buildings, not by a model of the actual home. Node loads are plausible, statistically grounded profiles, not reconstructions of individual customers.
- **Fixed match.** Matching uses the original baseline runs and is held fixed across scenarios; how well a match represents a meter under electrification is not tested.
- **Fallback meters are static.** AMI-fallback meters and the non-residential load do not respond to scenarios, so scenario differences at a node are diluted in proportion to its unmatched share.
- **Applicability.** With `MISSING_BLDG_POLICY = "baseline"`, non-applicable buildings keep their existing system in the upgrade scenarios; the upgrade scenarios are therefore partial electrification.
- **Rebuild offset.** Rebuilt and original runs differ by a few percent annually; only rebuilt runs are compared with each other.
- **Equal split.** Meters on several transformers are split equally in the absence of better information.
- **Gap handling.** `zero` biases load low during gaps; `nan` leaves holes; `interpolate` fills only short interior gaps.
- **Calendar and clock.** Weekday offset (1–2 days), DST hour offset and the midnight relabel (§11) limit the precision of sub-daily comparisons between ResStock and AMI.
- **Weather.** One year (2024) of actual weather; no inter-annual variability. AMY metadata annual results are not comparable with the 2024 simulations.
- **Demand flexibility.** A single fixed control (2 °F shed, no pre-conditioning, no randomisation, full participation of the matched homes). Simultaneous response of all homes is an upper-bound assumption for the rebound and peak effects.
- **Sector flag.** Residential/non-residential classification relies on the utility location file.

## 14. Reproducibility and configuration

**Software.** Python environment from `requirements.txt` (pandas, numpy, pyarrow); OpenStudio 3.8.0 with EnergyPlus 24.1 on Windows; ResStock `2025_Release_1` export (notebook 2 only); the `buildstock-ami-mapping` repository for matching. Run notebooks from `grid_edge_fy25/notebooks/`.

**Configuration knobs.**

| Notebook | Parameter | Meaning | Default |
|---|---|---|---|
| 0 | `AMI_FILE` | Raw AMI file | `data/input_files/consumption/ch1_4301002_individual.csv` |
| 0 | `GAP_METHOD`, `INTERP_MAX_GAP` | AMI gap treatment (§5) | `"zero"`, 4 |
| 1 | `UPGRADE` | 0 = baseline, otherwise upgrade id (`_upNN` outputs) | 0 |
| 1 | `MAX_WORKERS`, `MAX_PARALLEL`, `SKIP_FINISHED`, `SYNC_MEASURES` | Download/simulation parallelism and resume behaviour | see notebook |
| 2 | `SCENARIO` / `SCENARIOS` | Build path and flex settings per scenario | `baseline`, `up04`, `up04_df_2F` |
| 3 | `SCENARIOS_TO_BUILD`, `WRITE_CSV`, `N_WORKERS` | Which tables to build; CSV output; parallel reads | all, `True`, 8 |
| 4 | `SCENARIOS`, `BASELINE_SCENARIO` | Scenarios to aggregate; substitute for missing buildings | the three rebuilt runs, `baseline_rebuilt` |
| 4 | `MISSING_BLDG_POLICY` | `"baseline"` or `"ami"` (§10) | `"baseline"` |
| 4 | `AMI_GAP_TAG` | Which notebook 0 gap output to use for the fallback | `"zero"` |
| 4 | `FIX_EPLUS_MIDNIGHT` | Move the ResStock 00:00 rows to the next day (§11) | `False` |
| 5 | `SCENARIOS`, `COMPARISONS` | Scenario file tags to compare (selects gap tag/midfix variant); pairwise comparisons | three rebuilt runs, `ami-zero`; Up4 vs Baseline, Up4+DF vs Baseline, Up4+DF vs Up4 |
| 5 | `PEAK_DAY_SCEN` | Scenario whose winter/summer peak days are plotted | `Upgrade 04` |
| 5 | `DF_SEASON`, `DF_WINDOW`, `WINDOW_LAG` | DF window definition (§12.4) and label lag | NY windows, 15 min |

**Output naming.** `<s>` = scenario, `<g>` = AMI gap tag, `_upNN` = upgrade of an original run, `_midfix` = midnight fix applied. Each combination writes its own files, so variants can coexist and every result file states how it was made.

**Idempotence.** Downloads, simulations and the building-ID lists are skipped when already present (delete them to regenerate); load tables and aggregation outputs of the same scenario are overwritten.

## 15. Glossary

| Term | Meaning |
|---|---|
| AMI | Advanced metering infrastructure; 15-min smart-meter readings |
| SPID | Service point ID, one AMI meter |
| GISID / `xfr_gisid` | Transformer ID in the utility GIS; one transformer node |
| `_RES` / `_NRS` | Residential / non-residential column of a node |
| ResStock | NREL/NLR building-stock model of US homes; each building is a sample with an EnergyPlus model |
| AMY / TMY | Actual / typical meteorological year weather |
| Upgrade 4 | ResStock ENERGY STAR heat pump, existing system as backup |
| Upgrade 24 | ResStock HVAC demand flexibility with on-peak load shedding |
| Original run | Released `in.osm` simulated with 2024 weather (notebook 1) |
| Rebuilt run | Model rebuilt from `home.xml` with `2025_Release_1` measures (notebook 2) |
| Match | Assignment of ResStock buildings to an AMI meter (`match_report.csv`) |
| AMI fallback | Use of a meter's measured AMI load when it has no usable match |
| Gap tag | `zero`, `nan` or `interp<N>`: the AMI gap treatment used |
| Interval-end | A timestamp labels the 15 minutes ending at that time |
| DF window | Daily on-peak hours in which the demand-flex measure sheds HVAC load (§12.4) |
| Coincidence factor | System peak divided by the sum of individual node peaks |
| Rebound | Load increase right after the DF window, when setpoints return to normal |
| CVRMSE | Coefficient of variation of the root-mean-square error |
