# GrRIDS — ResStock + AMI Load Analysis 

This repository contains the full data pipeline for the GRIDs project. It downloads and runs NLR ResStock building energy models for upstate New York, processes AMI (smart meter) interval data, matches simulated loads to metered buildings, aggregates both datasets to distribution feeder nodes, and evaluates model accuracy against measured AMI loads.

---

# Environment Setup

Use Python 3.13 with pinned packages from [requirements.txt](requirements.txt).

## 1. Create and activate a virtual environment

### Windows (PowerShell)

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### macOS/Linux

```bash
python3.13 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

## 2. Validate the environment

```bash
python -c "import pandas, numpy, matplotlib, pyarrow, fastparquet, boto3, openpyxl; print('python deps OK')"
python -m awscli --version
```

## 3. Install external tools (not pip-managed)

- OpenStudio 3.9.0+
- EnergyPlus (required by OpenStudio runs)

The notebook references these paths for OpenStudio:

- Windows: `C:/openstudio-3.9.0/bin/openstudio.exe`
- macOS: `/Applications/OpenStudio-3.9.0/bin/openstudio`

---

# Project Context

The goal is to build feeder-level load profiles for the Dryden, NY distribution circuit by combining:

- **ResStock** — NLR's national residential building stock model used to simulate 15-minute electricity load profiles for representative buildings
- **AMI** — 15-minute interval smart meter data for ~792 service points on the circuit
- **OpenDSS feeder model** — transformer-level network topology used to map meters and buildings to feeder nodes

The matched, aggregated load profiles feed into downstream optimization work to study demand flexibility and grid edge resources.

---

# Repository Structure

```bash
grid_edge_fy25/
│
├── notebooks/
│   ├── download_resstock_models_latest-Resstock2025.ipynb
│   ├── Aggregate AMI and Resstock Load to Feeder Node.ipynb
│   ├── Aggregate ResStock and AMI to Feeder Node_02022026-Copy1.ipynb
│   ├── figures_resstock_vs_ami/
│   ├── weather_files/
│   └── Archive/
│
├── data/
│   ├── base_files/
│   │   └── weather/
│   ├── resstock_models/
│   └── parquet/
│
├── results/
│
└── results_2025/
```

---

# Workflow Run Order

Run notebooks in the following order.

## Step 1 — Download and Run ResStock Models

### `download_resstock_models_latest-Resstock2025.ipynb`

Downloads ResStock models from S3, runs OpenStudio simulations, and saves timeseries Parquet outputs.

### Outputs

- `data/parquet/resstock_timeseries_all_15.parquet`
- `data/parquet/ami_ind_data_15.parquet`
- `data/base_files/building_ids_metadata_2025.csv`

---

## Step 2 — AMI ↔ ResStock Matching

### External Repository

`buildstock-ami-mapping`

Run separately to match each AMI meter to its best-fit ResStock building.

### Output

- `results/match_report.csv`

---

## Step 3 — Aggregate to Feeder Nodes

### `Aggregate AMI and Resstock Load to Feeder Node.ipynb`

Reads AMI + match report and aggregates both datasets to transformer-level feeder nodes.

### Outputs

- `results/aggregated_load_nodes_wide_ami.csv`
- `results/aggregated_load_nodes_wide_resstock_RES_ONLY.csv`

---

## Step 4 — Compare ResStock vs AMI

### `Aggregate ResStock and AMI to Feeder Node_02022026-Copy1.ipynb`

Compares simulated ResStock loads against measured AMI loads by feeder branch.

### Outputs

- `notebooks/figures_resstock_vs_ami/`

---

# Notebook Descriptions

---

## 1. `download_resstock_models_latest-Resstock2025.ipynb`

Main pipeline — run first.

### Sections

- Read building IDs
- Aggregate matched metadata
- Distribution charts for matched buildings
- Distribution charts for selected spot IDs
- Download ResStock models from AWS S3
- Inject workflow + measures + weather file
- Run OpenStudio simulations
- Process `eplusout.csv`
- Save Parquet outputs
- Prepare AMI data
- Inspect output files

---

## 2. `Aggregate AMI and Resstock Load to Feeder Node.ipynb`

AMI + ResStock aggregation to transformer nodes.

### Sections

- Load AMI data
- Fill missing timestamps
- Identify missing SPIDs
- Aggregate AMI by transformer GISID
- Validate aggregated totals
- Cross-check against OpenDSS model
- Build SPID → GISID → ResStock mapping
- Aggregate ResStock by node

---

## 3. `Aggregate ResStock and AMI to Feeder Node_02022026-Copy1.ipynb`

Branch-level comparison notebook.

### Sections

- Load aggregated ResStock + AMI files
- Build branch-level ResStock profile
- Build branch-level AMI profile
- Compute model accuracy metrics
- Generate comparison plots

---

# Key Caveats

## Leap Year Handling

ResStock TMY3 release 2 models are **not leap-year aware**.

Use:

- simulation run period = **2023**
- weather file = **2024 EPW**

Remove **Feb 29** from AMI before comparison.

---

## S3 Source

```bash
s3://oedi-data-lake/nrel-pds-building-stock/end-use-load-profiles-for-us-building-stock/2025/
```

---

## County Scope

Counties included:

- Tompkins
- Cortland
- Tioga
- Chemung
- Schuyler
- Seneca
- Cayuga

Coverage:

- 607 buildings (2024 dataset)
- 1,516 buildings (2025 dataset)

---

## AMI Coverage

- 792 total SPIDs
- 154 commercial SPIDs
- 33 residential SPIDs unmatched in match report

Unmatched residential SPIDs fall back to AMI in aggregation.

---

## Timeseries Length

All timeseries are filtered to:

- **35,040 timestamps**
- `365 days × 96 intervals`
- Feb 29 excluded

---

# Key Input Files

| File | Description |
|---|---:|
| `NY_upgrade0.xlsx` | ResStock metadata for NY |
| `ch1_4301002_individual.csv` | Raw AMI 15-minute interval data |
| `location_reference.csv` | SPID → GISID mapping |
| `Ithaca_2024.epw` | EnergyPlus weather file |
| `workflow_resstock.osw` | OpenStudio workflow |
| `match_report.csv` | AMI ↔ ResStock matching results |
| `load_2.dss` | OpenDSS feeder model |

---

# Key Output Files

| File | Description |
|---|---:|
| `building_ids_metadata_2025.csv` | Building IDs used in simulation |
| `resstock_timeseries_all_15.parquet` | 15-min ResStock timeseries |
| `resstock_timeseries_all_hour.parquet` | Hourly ResStock timeseries |
| `resstock_timeseries_annual.parquet` | Annual building totals |
| `ami_ind_data_15.parquet` | Cleaned AMI interval data |
| `aggregated_load_nodes_wide_ami.csv` | AMI loads by transformer |
| `aggregated_load_nodes_wide_resstock_RES_ONLY.csv` | ResStock loads by transformer |
| `resstock_spid_gsid_mapping_RES_ONLY.csv` | SPID → GISID → ResStock mapping |
| `missing_res_service_ids_in_match_report.csv` | Missing residential SPIDs |
| `figures_resstock_vs_ami/` | Branch comparison plots |

---

# Related Repositories

## `buildstock-ami-mapping`

Use the `grid-edge` branch.

Generates:

```bash
match_report.csv
```

Matches AMI meter load profiles to ResStock building IDs using:

- CVRMSE
- peak timing similarity
- load shape metrics

---