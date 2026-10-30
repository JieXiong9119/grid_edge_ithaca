# Repository structure and retention

The eight notebooks numbered **0, 1, 1.1, 1.2, 2, 3, 4, 5** in [../notebooks/](../notebooks/) are the current scientific implementation. Shared code provides paths and an optional existing CLI; it does not replace notebook methodology. Start with [../README.md](../README.md), then [data_flow.md](data_flow.md) for artifact contracts and [pipeline_summary.md](pipeline_summary.md) for methods and published results.

## Working layout

Paths below are relative to the repository root; links resolve from this document. Private/generated directories may be absent in a source-only checkout.

| Location | Responsibility | Shared path |
|---|---|---|
| [../notebooks/](../notebooks/) | Exactly the eight current notebooks; no unnumbered historical notebooks | repository root + notebooks |
| [../src/grid_edge/paths.py](../src/grid_edge/paths.py) | Repository discovery, stage boundaries, external-tool defaults; importing does not create directories | `PATHS` |
| [../src/grid_edge/run_hvac_flex.py](../src/grid_edge/run_hvac_flex.py) | Optional existing HVAC-flex CLI implementation; notebook 2 remains authoritative | — |
| [../scripts/run_hvac_flex.py](../scripts/run_hvac_flex.py) | CLI wrapper that imports local source without installation | — |
| [../data/raw/ami/](../data/raw/ami/) | Original consumption-folder contents directly here, including [../data/raw/ami/ch1_4301002_individual.csv](../data/raw/ami/ch1_4301002_individual.csv); no extra consumption subfolder | `PATHS.raw_ami` |
| [../data/raw/network/](../data/raw/network/) | Utility meter-to-transformer location reference | `PATHS.raw_network` |
| [../data/raw/resstock/](../data/raw/resstock/) | Baseline and upgrade-04 AMY metadata, original names unchanged | `PATHS.raw_resstock` |
| [../data/external/matching/](../data/external/matching/) | External matching handoff, not an output of this repo | `PATHS.matching` |
| Optional released-TMY destination: data/external/resstock_released/ | Notebook 1.2 only; deliberately isolated from simulated AMY tables | `PATHS.released` |
| [../data/interim/ami/](../data/interim/ami/) | Cleaned long AMI, gap-handled meter-wide tables, meter-to-transformer map | `PATHS.ami` |
| [../data/interim/resstock/](../data/interim/resstock/) | Original and rebuilt ResStock load tables, CSV and Parquet; original basenames unchanged | `PATHS.resstock` |
| [../data/interim/selection/](../data/interim/selection/) | Building-ID lists and building-to-meter map | `PATHS.selection` |
| [../data/processed/node_loads/](../data/processed/node_loads/) | All aggregated wide node loads: AMI, ResStock-only, fallback-only and combined | `PATHS.node_loads` |
| [../models/](../models/) | Downloaded and simulated model trees; see scenario table below | `PATHS.models` |
| [../resources/openstudio/](../resources/openstudio/) | Shared weather, measures and workflow | `PATHS.resources` |
| [../reports/diagnostics/](../reports/diagnostics/) | AMI duplicates/gaps/aggregation, ResStock aggregation and meter status/source reports | `PATHS.diagnostics` |
| [../reports/metadata/](../reports/metadata/) | Notebook 1.1 plots and selected-spot tables, including upgrade-tagged variants | `PATHS.metadata` |
| [../reports/postprocess/](../reports/postprocess/) | All notebook 5 CSV and PNG outputs | `PATHS.postprocess` |
| [../reports/logs/](../reports/logs/) | Batch logs, including the preserved upgrade-04 DF batch log | `PATHS.logs` |
| [figures/postprocess/](figures/postprocess/) | Tracked, published figure copies used by the technical report; not notebook 5's write destination | — |

### Model folders and scenario tags

All five names are retained; migration renames directories, rather than recomputing simulations.

| Model location | Producer / selection | Load-table tag |
|---|---|---|
| [../models/resstock_models/](../models/resstock_models/) | Notebook 1, `UPGRADE = 0` | No suffix: original baseline, used for matching |
| [../models/resstock_models_up04/](../models/resstock_models_up04/) | Notebook 1, `UPGRADE = 4` | `_up04`: original applicable upgrade buildings |
| [../models/resstock_models_rebuilt/](../models/resstock_models_rebuilt/) | Notebook 2, `SCENARIO = "baseline"` | `_baseline_rebuilt` |
| [../models/resstock_models_up04_rebuilt/](../models/resstock_models_up04_rebuilt/) | Notebook 2, `SCENARIO = "up04"` | `_up04_rebuilt` |
| [../models/resstock_models_up04_df/](../models/resstock_models_up04_df/) | Notebook 2, `SCENARIO = "up04_df_2F"` | `_up04_df_2F` |

The resources are [../resources/openstudio/weather/Ithaca_2024.epw](../resources/openstudio/weather/Ithaca_2024.epw), [../resources/openstudio/measures/](../resources/openstudio/measures/) and [../resources/openstudio/workflow_resstock.osw](../resources/openstudio/workflow_resstock.osw). Notebook 2 additionally needs the external ResStock checkout; the local measures are not a replacement for it.

## Launching and local compatibility

- Bootstrap cells support both repository-root and notebook-directory working directories. They add local source to `sys.path` and import `PATHS`; no editable install is required. For launching outside the checkout, set `GRID_EDGE_ROOT` to its absolute root before starting the kernel.
- **Restart kernels after the move**, then run setup first. An old kernel retains its working directory, imports and path globals. Saved output cells can still display historical paths; they are not evidence of the current setup.
- `OPENSTUDIO_PATH` defaults to C:/openstudio-3.8.0/bin/openstudio.exe. `RESSTOCK_DIR` defaults to the sibling resstock_2025R1 checkout/export of `2025_Release_1`. Set overrides before launching the notebook; preserve the documented engine and measure compatibility patches.
- Existing local virtual environments (.venv, .venv-1 and .venv-2) and VS Code settings (.vscode) intentionally stay at the repository root. Relocating them would break interpreter references.
- The old grid_edge_fy25/data/resstock_models* locations and grid_edge_fy25/data/base_files are retained as **local Windows junctions** to the canonical model and resource directories. Saved OSW/OSM/XML artifacts embed those old absolute paths. New code must use `PATHS`, not the junctions.
- These junctions are not portable symlinks committed to git, and they do not make a checkout portable. **Do not move or delete the compatibility directories until the old simulations have been regenerated and their references reviewed.** Even with junctions, saved workflows that reference an external ResStock checkout still require that checkout at the referenced location; environment overrides only affect newly configured runs.

## Historical work, not current dependencies

The migration retains all unclassified original content under [../archive/legacy/grid_edge_fy25/](../archive/legacy/grid_edge_fy25/), preserving its internal tree: unnumbered legacy notebooks and their Archive subfolder; the branch-comparison notebook and figures; alternate input metadata; older building-ID lists; feature-importance outputs; and duplicate weather files. The old top-level project folder is only a compatibility location, not a second working pipeline. Windows denied renaming the parent directory, so its children were archived instead; any locked empty directories were left in place without terminating sessions.

[../archive/legacy/optimization/](../archive/legacy/optimization/) preserves the two original optimization prototypes; they are **not** the working load pipeline. [../archive/legacy/urbanopt/](../archive/legacy/urbanopt/) preserves the original past_UO_files tree, including relative internal references. No archived code or data is used by the current notebooks. Historical code intentionally retains old paths and may need manual path changes and an appropriate environment to rerun. Do not treat archive-wide search hits as current dependencies.

## Lossless migration and evidence

[../scripts/reorganize_repository.py](../scripts/reorganize_repository.py) is a **one-time** migration utility, not a pipeline step. With no flags it previews moves; `--apply` performs them, and `--apply --resume` continues an interrupted journal. Do not start a second migration while one is running, or rerun it against an already migrated checkout. Review the existing plan and journal first.

Local evidence is retained in [../archive/reorganization_2026-10-29/](../archive/reorganization_2026-10-29/):

- [../archive/reorganization_2026-10-29/before/](../archive/reorganization_2026-10-29/before/) preserves all original notebooks and saved output cells, docs, helper code, README and ignore rules, including pre-existing uncommitted changes.
- [../archive/reorganization_2026-10-29/plan.json](../archive/reorganization_2026-10-29/plan.json) records source/destination pairs; [../archive/reorganization_2026-10-29/moves.jsonl](../archive/reorganization_2026-10-29/moves.jsonl) journals every moved file's relative name, byte size and timestamp, plus SHA-256 for direct-file moves and selected small source/config files. **Not every large payload is hashed.** An entry is written before its rename, so a journal entry alone does not prove completion.
- Successful completion writes a COMPLETE marker and, on Windows, a compatibility-links.json manifest. Inventory validation requires these local records; documentation changes do not establish that migration completed.

### Retention and version control

1. **Never delete old models to trigger a fresh download.** Preserve the original model tree, building selection, release, weather, engine/measure versions, settings and outputs in a provenance-labelled archive before deliberate regeneration. Downloads skip existing model folders; a skipped folder is not a release-consistency check. Do not relocate models that an active job or saved workflow still needs.
2. Keep the migration snapshot and journal. Archive superseded inputs, match reports and outputs with their settings before rerunning a producer that overwrites a filename. Do not silently replace the inputs underlying published results.
3. [../.gitignore](../.gitignore) keeps private data, model/report payloads, migration snapshots and local compatibility junctions out of git. Source, docs, published figures and moved historical code/resources should remain tracked; the reorganization is not a request to untrack them. Neither staging nor committing is part of this documentation update.
4. The scientific results and published figures in [pipeline_summary.md](pipeline_summary.md) remain intact. Updating their paths does not recalculate or revalidate them.
5. **Git review:** ignored junctions can still expose paths already in the Git index. Before committing this reorganization, remove only the old compatibility-path entries from the index, not from disk, and stage the canonical resource/archive paths. The index was deliberately not changed by this migration. The old per-building tracked `add_outputs` measure files are byte-identical to their canonical shared resource copies; both local copies remain. The previously tracked historical building-ID list is explicitly allowed in the archive ignore rules. See [reorganization_validation.md](reorganization_validation.md).

## Validation boundaries

See [../README.md](../README.md#validation-without-rerunning-the-pipeline) for commands to run **after migration finishes**. [../scripts/validate_repository.py](../scripts/validate_repository.py) checks notebook structure/path literals by default, reads selected current artifacts with `--data`, and checks local preservation records with `--inventory`. [../tests/test_paths.py](../tests/test_paths.py) tests path contracts using `unittest`.

These validator checks do not run notebooks, download models, launch simulations, redo matching, overwrite pipeline outputs, prove every embedded workflow path portable, or certify scientific equivalence. A source-only checkout cannot satisfy the private-data or local-inventory checks. Results of the completed migration audit and separate safe notebook smoke tests are in [reorganization_validation.md](reorganization_validation.md).