"""Fast path-contract checks; no private data or simulation engine required."""

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from grid_edge.paths import PATHS, ProjectPaths, find_project_root, openstudio_executable, resstock_checkout
from grid_edge.run_hvac_flex import parse_args


class PathTests(unittest.TestCase):
    def test_root_and_notebook_working_directories(self):
        with patch.dict(os.environ, {}, clear=True):
            for start in (PATHS.root, PATHS.root / "notebooks", Path(__file__)):
                self.assertEqual(find_project_root(start), PATHS.root)

    def test_explicit_root(self):
        with patch.dict(os.environ, {"GRID_EDGE_ROOT": str(PATHS.root)}):
            self.assertEqual(find_project_root(Path(tempfile.gettempdir())), PATHS.root)

    def test_invalid_override_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {"GRID_EDGE_ROOT": directory}):
                with self.assertRaises(FileNotFoundError):
                    find_project_root()

    def test_stage_separation(self):
        paths = [PATHS.raw_ami, PATHS.raw_network, PATHS.raw_resstock, PATHS.matching,
                 PATHS.released, PATHS.ami, PATHS.resstock, PATHS.selection,
                 PATHS.node_loads, PATHS.models, PATHS.resources,
                 PATHS.diagnostics, PATHS.metadata, PATHS.postprocess, PATHS.logs]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertTrue(all(p.is_relative_to(PATHS.root) for p in paths))

    def test_creates_outputs_not_raw_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = ProjectPaths(Path(directory))
            paths.ensure_output_dirs()
            self.assertTrue(paths.node_loads.is_dir())
            self.assertTrue(paths.postprocess.is_dir())
            self.assertFalse(paths.raw_ami.exists())
            self.assertFalse(paths.matching.exists())

    def test_external_tool_overrides(self):
        with patch.dict(os.environ, {"OPENSTUDIO_PATH": "custom/openstudio", "RESSTOCK_DIR": "custom/resstock"}):
            self.assertEqual(openstudio_executable(), Path("custom/openstudio"))
            self.assertEqual(resstock_checkout(), Path("custom/resstock"))

    def test_cli_uses_canonical_paths(self):
        with patch.object(sys, "argv", ["run_hvac_flex"]):
            args = parse_args()
        self.assertEqual(args.src, PATHS.models / "resstock_models_up04")
        self.assertEqual(args.dst, PATHS.models / "resstock_models_up04_df")
        self.assertEqual(args.epw, PATHS.resources / "weather/Ithaca_2024.epw")


if __name__ == "__main__":
    unittest.main()