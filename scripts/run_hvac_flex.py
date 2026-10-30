"""Run the optional HVAC-flex CLI without requiring an editable installation."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from grid_edge.run_hvac_flex import main


if __name__ == "__main__":
    main()