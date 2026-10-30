# GrRIDS: ResStock + AMI Load Analysis

The GRIDs project combines NLR/NREL ResStock simulations with AMI smart-meter data to produce 15-minute transformer-node loads for the Dryden, NY circuit. The current scientific implementation is the **eight notebooks numbered 0, 1, 1.1, 1.2, 2, 3, 4 and 5** in [notebooks/](notebooks/). Historical notebooks and optimization prototypes are retained, not part of the working pipeline.

## Documentation

- [docs/repository_structure.md](docs/repository_structure.md): canonical folders, shared paths, migration evidence, Windows compatibility and archive retention.
- [docs/data_flow.md](docs/data_flow.md): producer/consumer table, schemas, units, scenario/gap filenames and the external matching contract.
- [docs/pipeline_summary.md](docs/pipeline_summary.md): complete methodology, scientific limitations and retained notebook 5 results/figures.
- [docs/weather_basis_amy_vs_tmy.md](docs/weather_basis_amy_vs_tmy.md): why metadata and models use AMY, with Ithaca 2024 simulation weather.
- [docs/reorganization_validation.md](docs/reorganization_validation.md): completed migration checks, preservation evidence and Git review caveat.

## Environment setup

Use Python 3.13 and the pinned dependencies in [requirements.txt](requirements.txt), which remains the authoritative dependency list. Select that environment as the VS Code notebook kernel. Reuse an existing configured environment; do not recreate or relocate it during a migration or simulation.

For a **new** Windows environment, from the repository root:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

On macOS/Linux, use a Python 3.13 virtual environment and the same dependency installation; the existing OpenStudio/rebuild workflow and compatibility junctions are Windows-oriented, not cross-platform certified.

The notebook bootstrap imports local source directly. **No extra project install is required for notebooks or the CLI wrapper.** Optional `python -m pip install -e .` makes the shared package importable elsewhere; [pyproject.toml](pyproject.toml) does not replace the dependency installation above. The requirements include notebook 5's `seaborn` dependency.

### External tools and launch paths

| Configuration | Default / requirement |
|---|---|
| `OPENSTUDIO_PATH` | C:/openstudio-3.8.0/bin/openstudio.exe; OpenStudio 3.8.0 with bundled EnergyPlus 24.1 |
| `RESSTOCK_DIR` | Sibling resstock_2025R1 checkout/export of `2025_Release_1`, with the documented compatibility patches; required for notebook 2 |
| `GRID_EDGE_ROOT` | Optional absolute checkout root when launching notebooks from outside the repository |
| Model downloads | Anonymous access to public S3 bucket `oedi-data-lake`; no AWS account required |

Set overrides **before starting the kernel**. Open notebooks from [notebooks/](notebooks/), run setup first, then run top to bottom. Repository-root and notebook-directory working directories are both supported through `PATHS` in [src/grid_edge/paths.py](src/grid_edge/paths.py). **Restart kernels after moving the repository/notebooks**: old working directories, imports and globals persist. Saved output cells may still show historical paths.

## Quick start: run order

**0 and 1 independently → external matching → 2 → 3 → 4 → 5.** Notebook 2 only needs notebook 1's models/selections, so its simulation can proceed independently of matching. Notebook 1.1 is optional post-match analysis; notebook 1.2 is optional TMY3 exploration, not a shortcut for the AMY pipeline.

| Step | Current notebook / handoff | Inputs → outputs |
|---|---|---|
| 0 | [notebooks/0_ami_data_prep_and_aggregation.ipynb](notebooks/0_ami_data_prep_and_aggregation.ipynb) | Raw AMI + network reference → cleaned AMI, meter map, gap-handled meter-wide AMI, measured node loads and diagnostics |
| 1 | [notebooks/1_resstock_models_download_and_run.ipynb](notebooks/1_resstock_models_download_and_run.ipynb) | AMY metadata + weather/workflow + OpenStudio → selected IDs, downloaded/simulated original models, building load tables |
| ext | External **buildstock-ami-mapping**, `grid-edge` branch | Cleaned 15-min AMI + **original baseline** ResStock table → [data/external/matching/match_report.csv](data/external/matching/match_report.csv); follow [docs/data_flow.md](docs/data_flow.md#external-matching-handoff) |
| 1.1 | [notebooks/1.1_resstock_metadata_plots.ipynb](notebooks/1.1_resstock_metadata_plots.ipynb) | Match report + AMY metadata → optional metadata/selected-spot plots |
| 1.2 | [notebooks/1.2_resstock_timeseries_download.ipynb](notebooks/1.2_resstock_timeseries_download.ipynb) | Selected IDs → optional released TMY3 tables in the isolated `PATHS.released` destination, data/external/resstock_released/ |
| 2 | [notebooks/2_resstock_models_df_run.ipynb](notebooks/2_resstock_models_df_run.ipynb) | Original models + IDs + external 2025 measures → rebuilt baseline, rebuilt upgrade 4 and demand-flex runs |
| 3 | [notebooks/3_resstock_load_table_build.ipynb](notebooks/3_resstock_load_table_build.ipynb) | Finished rebuilt runs + match report → scenario load tables with serialized `meter_ids`, reverse building–meter map |
| 4 | [notebooks/4_resstock_aggregation.ipynb](notebooks/4_resstock_aggregation.ipynb) | Scenario tables + match report + AMI map/meter-wide table → residential node loads, separate AMI fallback and traceability reports |
| 5 | [notebooks/5_postprocess_visualize.ipynb](notebooks/5_postprocess_visualize.ipynb) | Combined residential node loads → system/node energy and peak-demand CSV summaries and PNG figures |

### Selections to review before regeneration

- Notebook 1 is currently saved with **`UPGRADE = 4`**, not baseline. Run it separately with `UPGRADE = 0` and `4` when both original sets need regenerating. Match using the original baseline, and keep that match fixed across scenarios. Keep the optional notebooks' upgrade selections consistent with the intended analysis.
- Notebook 2 is saved with **`SCENARIO = "baseline"`**. Repeat for `up04` and `up04_df_2F` to regenerate all three runs. Notebook 3 maps these to `baseline_rebuilt`, `up04_rebuilt`, `up04_df_2F`.
- Notebook 4 defaults to `AMI_GAP_TAG = "zero"`, `MISSING_BLDG_POLICY = "baseline"`, `FIX_EPLUS_MIDNIGHT = False`. Notebook 5's file tags must match. These scientific selections were intentionally not changed by the reorganization.
- Compare scenarios among the **three rebuilt runs**; retain originals for matching/validation. Rebuilding shifts annual electricity by a few percent.
- Downloads/simulations may skip existing completed work, while load-table, aggregation and postprocessing cells can **overwrite outputs**. Archive existing outputs with provenance before deliberate regeneration. Never delete old models merely to force a download.

## Where files live

| Stage | Canonical locations |
|---|---|
| Raw inputs | [data/raw/ami/](data/raw/ami/) (consumption files directly here), [data/raw/network/](data/raw/network/), [data/raw/resstock/](data/raw/resstock/) |
| External mapping | [data/external/matching/match_report.csv](data/external/matching/match_report.csv) |
| Intermediate tables and selections | [data/interim/ami/](data/interim/ami/), [data/interim/resstock/](data/interim/resstock/), [data/interim/selection/](data/interim/selection/) |
| Final wide node loads | [data/processed/node_loads/](data/processed/node_loads/) — measured AMI, ResStock-only, fallback-only and combined scenarios |
| Models / simulation resources | [models/](models/), [resources/openstudio/](resources/openstudio/) |
| Diagnostics / plots / logs | [reports/diagnostics/](reports/diagnostics/), [reports/metadata/](reports/metadata/), [reports/postprocess/](reports/postprocess/), [reports/logs/](reports/logs/) |
| Published figure copies | [docs/figures/postprocess/](docs/figures/postprocess/) — retained, not regenerated by relocation |

Private inputs and generated data/model/report payloads are locally gitignored; a source checkout alone is not sufficient to rerun the pipeline. Schemas and exact filename families are in [docs/data_flow.md](docs/data_flow.md).

## Validation without rerunning the pipeline

The checks below are repeatable without regenerating pipeline results. The completed migration's results are recorded in [docs/reorganization_validation.md](docs/reorganization_validation.md). Run them only when no pipeline jobs are writing files. From the repository root, with the intended environment active:

```powershell
python scripts/validate_repository.py
python -m unittest discover -s tests -p test_paths.py
```

The default validator uses only the standard library: exact eight-notebook inventory, cell-ID uniqueness, Python syntax parsing without execution, shared-path bootstrap presence and selected stale path-literal checks. It is not a comprehensive path audit. The unit tests exercise root discovery, stage separation, environment overrides and CLI defaults without private data or OpenStudio; they create temporary test directories, not pipeline outputs.

Optional local checks:

```powershell
python scripts/validate_repository.py --data
python scripts/validate_repository.py --inventory
```

- **`--data`:** uses pandas/NumPy/pyarrow to read selected required artifacts and the three current `ami-zero`, no-midnight-fix combined scenarios; checks `meter_ids` schema presence, 35,040 unique timestamps without Feb 29, finite residential values and scenario index/column alignment. It does not validate every artifact, gap choice, model run or scientific result.
- **`--inventory`:** requires the completed local migration snapshot/journal and Windows compatibility manifest. Checks preserved files' sizes, recorded SHA-256 hashes and junction targets; not every large payload is hashed. This cannot pass from source alone or while migration is incomplete.
- Neither validator runs notebooks, downloads models, reruns simulations or matching, or overwrites pipeline outputs. These checks do **not** certify scientific equivalence, every embedded workflow path or the published report's results. Separate setup/configuration smoke tests and their limits are recorded in the migration validation report.

The optional existing HVAC-flex CLI is exposed by [scripts/run_hvac_flex.py](scripts/run_hvac_flex.py), backed by [src/grid_edge/run_hvac_flex.py](src/grid_edge/run_hvac_flex.py). `python scripts/run_hvac_flex.py --help` lists its options without installation; an actual run launches simulations and is not validation. Notebook 2 remains the scientific authority.

## Scientific conventions and retained history

- Scope: **766 candidate buildings** in Tompkins, Cortland, Tioga, Chemung, Schuyler, Seneca and Cayuga; upgrade 4 only applies to part of that pool. The documented AMI sample has 792 service points, 154 non-residential and 33 unmatched residential meters using AMI fallback.
- **35,040 quarter-hours**, 2024 labels with Feb 29 removed. AMI duplicate fall-back readings are averaged. DST, simulation-calendar and EnergyPlus-midnight caveats are retained in [docs/pipeline_summary.md](docs/pipeline_summary.md#11-time-alignment-and-calendar-conventions).
- Load tables/node files hold **kWh per interval**, not kW. Notebook 5 divides by 0.25 h for average kW. Non-residential AMI stays unchanged; rebuilt scenarios model residential load only.
- Metadata/models use `resstock_amy2018_release_2`; simulation weather is [resources/openstudio/weather/Ithaca_2024.epw](resources/openstudio/weather/Ithaca_2024.epw). Metadata `out.*` values describe release-weather runs, not the 2024 simulations. Released TMY3 outputs stay outside this flow.
- Legacy notebooks, branch comparisons/figures, optimization prototypes, UrbanOpt, alternate inputs and feature-importance outputs are retained under the archive, not deleted or required by current notebooks. The migration snapshot preserves original docs/notebooks/output cells and pre-existing uncommitted changes.
- Local environments and editor settings stay in place. Old model/resource paths retain Windows junctions for absolute paths embedded in saved simulations. **Do not move/delete those compatibility directories until old simulations are regenerated.** External ResStock paths still require the referenced checkout.

See [docs/repository_structure.md](docs/repository_structure.md#lossless-migration-and-evidence) for the one-time dry-run/`--apply`/`--resume` migration utility, journal and no-deletion policy. Do not start another migration while one is running. Tracked source, docs and moved historical code/resources should remain tracked; this documentation update does not stage or commit files.
