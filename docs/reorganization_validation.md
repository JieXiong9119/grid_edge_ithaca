# Reorganization validation — 2026-10-29

## Preserved scope

- The eight working notebooks are in [../notebooks/](../notebooks/). Their scientific calculations, scenario selections and filenames were retained; setup and file destinations changed.
- **121,101 moved files, 96,048,241,985 bytes** were checked against the local move journal. **10,128 SHA-256 checks** passed for recorded hashes. The large model trees were moved intact and verified by file inventory/size, not fully content-hashed.
- Original notebook source, saved outputs, documentation (including pre-existing edits), figures and helper code are retained in the local pre-edit snapshot. Setup/configuration cell outputs and execution metadata may now reflect smoke tests; downstream analysis outputs were not regenerated.
- All tracked pre-migration file paths were accounted for at their original or mapped destinations. All 14 published figure references remain unchanged. Documentation file links resolve in this local checkout.
- Six Windows compatibility junctions resolve to the five canonical model trees and shared OpenStudio resources. Empty locked parent directories were left in place rather than terminating processes or deleting content.

The local move plan, journal, originals, link manifest and COMPLETE marker are under the reorganization snapshot directory described in [repository_structure.md](repository_structure.md#lossless-migration-and-evidence). Private/generated artifacts and backups remain git-ignored; no data was uploaded.

## Checks run

| Check | Result |
|---|---|
| [../tests/test_paths.py](../tests/test_paths.py) | 7 unit tests passed: root discovery, overrides, stage separation, output directories, CLI defaults |
| [../scripts/validate_repository.py](../scripts/validate_repository.py) | All 8 notebooks / 61 Python code cells parsed; path bootstrap and selected stale-path checks passed |
| Setup smoke tests | Setup cell ran successfully in all 8 notebooks, using the existing avangrid Python 3.13.15 kernel |
| Configuration smoke tests | Notebook 1, 1.1, 1.2, 2, 3 and 4 configuration cells passed; model/metadata/selection/matching/AMI inputs were found |
| External tool preflight | Notebook 2's OpenStudio version check and external ResStock measure-path checks passed; no simulations launched |
| Optional CLI | Help command completed successfully |
| Current scenario artifacts | All three combined tables have 35,040 unique intervals, no Feb 29, 146 aligned residential columns and finite values; scenario building tables retain `meter_ids` |
| Migration preservation | File sizes, recorded hashes and compatibility-link targets passed the full local inventory audit |
| Editor diagnostics | No errors reported for shared source, scripts, tests and project metadata |

Read-only energy totals from the existing combined residential node tables:

| Scenario | Annual kWh |
|---|---:|
| baseline_rebuilt | 4,013,436.460 |
| up04_rebuilt | 5,678,656.529 |
| up04_df_2F | 5,629,380.821 |

These checks do **not** rerun simulations, downloads, matching, aggregation, plotting or table generation. They do not establish equivalence for every possible parameter combination, validate every saved absolute workflow reference, or replace a future full pipeline run. Current settings remain `UPGRADE = 4` in notebook 1, `SCENARIO = "baseline"` in notebook 2 and the existing zero-gap/no-midnight-fix aggregation selection.

## Git review before committing

No staging, index cleanup or commit was performed. Most moves therefore appear as deleted old paths plus untracked new paths until staged.

Some historical resource files were already tracked below the old data directory. Windows junctions keep those paths physically readable, and adding an ignore rule does not remove existing index entries. During commit review, untrack those **old alias paths from the index only**, retaining the junctions and local files; track their canonical shared-resource paths instead. The eight tracked per-building `add_outputs` files are byte-identical to the canonical shared resources, and their model-tree copies remain intact. The historical tracked building-ID list remains eligible for tracking at its archive location. Never perform a recursive disk deletion of the compatibility directory.

Restart pre-migration kernels before normal work and open the notebooks from their new location. Only setup/configuration cells were exercised here; remaining cells still require normal top-to-bottom execution when regeneration is intended.