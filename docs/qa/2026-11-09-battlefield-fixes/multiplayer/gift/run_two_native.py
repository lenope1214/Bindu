"""Preserve prior two-player evidence; reuse the original runner with a new output folder."""
from pathlib import Path
import importlib.util

here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("bindu_two_native", here.parent / "run_native.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
runner.OUT = here / "two-participant-final"
runner.OUT.mkdir(parents=True, exist_ok=True)
raise SystemExit(runner.main())
