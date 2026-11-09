#!/usr/bin/env python3
"""Isolate the targeting differential from the player's project and saves."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--variant", choices=("current", "before", "mutant"), default="current")
    parser.add_argument("--benchmark", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[5]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    godot = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
    record = {"variant": args.variant, "benchmark": args.benchmark, "started_at_utc": dt.datetime.now(dt.timezone.utc).isoformat()}
    isolated_name = "BinduToolsTargeting" + uuid.uuid4().hex
    userdata = Path.home() / "Library/Application Support/Godot/app_userdata" / isolated_name
    with tempfile.TemporaryDirectory(prefix="bindu-targeting-") as tmp:
        project = Path(tmp)
        for name in ("scripts", "tools", "docs"):
            shutil.copytree(repo / name, project / name)
        for name in ("main.tscn", "project.godot", "icon.svg"):
            shutil.copy2(repo / name, project / name)
        config = project / "project.godot"
        config.write_text(re.sub(r'^config/name=.*$', f'config/name="{isolated_name}"', config.read_text(), flags=re.M))
        online = project / "scripts/online_config.gd"
        online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', online.read_text()))
        tower = project / "scripts/tower.gd"
        if args.variant == "before":
            baseline = subprocess.check_output(["git", "show", "e25b6ea:scripts/tower.gd"], cwd=repo, text=True)
            original = baseline[baseline.index("func _guard_pick("):baseline.index("\n\n\n## 날아가는 탄의 속도", baseline.index("func _guard_pick("))]
            source = tower.read_text()
            start = source.index("func _guard_pick(")
            end = source.index("\n\n\n## 날아가는 탄의 속도", start)
            tower.write_text(source[:start] + original + source[end:])
        elif args.variant == "mutant":
            source = tower.read_text()
            old = "if preferred != null and not (preferred_g > limit):"
            assert old in source
            tower.write_text(source.replace(old, "if preferred != null and preferred_g < limit:", 1))
            record["mutation"] = "preferred inclusive band boundary changed to exclusive, temporary copy only"
        with (output / "import.log").open("w") as log:
            imported = subprocess.run([godot, "--headless", "--import", "--path", tmp], stdout=log, stderr=subprocess.STDOUT, timeout=300)
        record["import_exit"] = imported.returncode
        assert imported.returncode == 0 and not re.search(r"SCRIPT ERROR|Parse Error|Compile Error", (output / "import.log").read_text()), "import failed"
        command = [godot, "--headless", "--audio-driver", "Dummy", "--path", tmp, "-s", "tools/battlefield_targeting_check.gd", "--", str(output), "both" if args.benchmark else "check"]
        record["command"] = command
        with (output / "check.log").open("w") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        record["exit"] = result.returncode
        assert not re.search(r"^(?:SCRIPT ERROR|ERROR:)", (output / "check.log").read_text(), re.M), "runtime errors"
        data = json.loads((output / "results.json").read_text())
        assert data["comparisons"] == 41564
        assert set(data["exercised_pattern_levels"]) == {pattern + ":" + str(level) for pattern in data["patterns"] for level in [1, 3, 8]}
        record["comparisons"] = data["comparisons"]
        record["mismatch_count"] = data["mismatch_count"]
        assert result.returncode == (1 if data["mismatch_count"] else 0)
    shutil.rmtree(userdata, ignore_errors=True)
    record["isolated_userdata_removed"] = not userdata.exists()
    record["temporary_project_removed"] = True
    record["finished_at_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    (output / "run.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(args.variant, "exit", result.returncode, "temporary project and isolated save cleaned")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
