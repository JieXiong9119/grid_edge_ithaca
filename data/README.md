# Data stages

Payloads in this directory are local and git-ignored. Do not commit private AMI or utility mapping data.

| Stage | Contents | Producer |
|---|---|---|
| raw/ami, raw/network, raw/resstock | Original utility inputs and AMY metadata | External sources |
| external/matching | Fixed match report imported from the mapping project | External matching |
| external/resstock_released | Optional released TMY timeseries; never mix with AMY runs | Notebook 1.2 |
| interim/ami | Cleaned AMI, meter-wide series and meter-to-transformer map | Notebook 0 |
| interim/selection | Building-ID lists and building-to-meter map | Notebooks 1 and 3 |
| interim/resstock | Original and rebuilt per-building load tables | Notebooks 1 and 3 |
| processed/node_loads | AMI reference and scenario node-load products | Notebooks 0 and 4 |

Use `PATHS` in [../src/grid_edge/paths.py](../src/grid_edge/paths.py), not working-directory-relative paths. See [../docs/data_flow.md](../docs/data_flow.md) for filenames, schemas, producers and consumers. Archive old inputs/results with their settings before deliberately overwriting a stage.