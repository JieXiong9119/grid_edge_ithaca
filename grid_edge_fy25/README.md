# Compatibility only

The working pipeline moved to [../notebooks/](../notebooks/); see [../README.md](../README.md).

The data subdirectory here contains local Windows junctions for the old ResStock model roots and base resources. Existing OSW/OSM/XML files embed those absolute paths. These links refer to the canonical model/resource trees, not duplicate copies. Do not delete or move them while historical workflows still depend on them. New code must use [../src/grid_edge/paths.py](../src/grid_edge/paths.py).

Unclassified historical content is preserved under [../archive/legacy/grid_edge_fy25/](../archive/legacy/grid_edge_fy25/). Empty directories held open by Windows sessions may remain here; they are not another active pipeline.