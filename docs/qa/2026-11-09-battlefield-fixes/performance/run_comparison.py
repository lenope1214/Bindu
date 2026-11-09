#!/usr/bin/env python3
"""Run the same native benchmark on an isolated baseline/current snapshot."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
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
    parser.add_argument("--source", choices=("baseline", "current"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[4])
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    baseline = "e25b6eab5b4e64cca7ee5e0089d50e149588e9b9"
    godot = "/Applications/Godot.app/Contents/MacOS/Godot"
    tool = repo / "tools/battlefield_load_check.gd"
    record = {
        "source": args.source,
        "base_revision": baseline,
        "started_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "tool_sha256": hashlib.sha256(tool.read_bytes()).hexdigest(),
        "samples": 180,
        "warmup": 30,
        "orbs": 300,
        "towers": 16,
        "resolution": "1280x720",
        "profiler_enabled": True,
        "cleanup": "pending",
    }
    with tempfile.TemporaryDirectory(prefix="bindu-native-compare-") as tmp:
        project = Path(tmp)
        if args.source == "baseline":
            archive = subprocess.Popen(
                ["git", "archive", baseline], cwd=repo, stdout=subprocess.PIPE
            )
            subprocess.run(["tar", "-x", "-C", tmp], stdin=archive.stdout, check=True)
            assert archive.stdout is not None
            archive.stdout.close()
            assert archive.wait() == 0
            shutil.copy2(tool, project / "tools/battlefield_load_check.gd")
            # The new benchmark reads this otherwise-unused setting. The baseline
            # has no skill-aim slowdown; no game logic consults the adapter value.
            meta = project / "scripts/meta.gd"
            meta.write_text(meta.read_text() + "\nstatic var skill_aim_slow := false  # native benchmark adapter only\n")
            record["adapter"] = "scripts/meta.gd: append unused static skill_aim_slow=false for harness compatibility"
        else:
            for name in ("scripts", "tools", "docs"):
                shutil.copytree(repo / name, project / name)
            for name in ("main.tscn", "project.godot", "icon.svg"):
                shutil.copy2(repo / name, project / name)
            record["adapter"] = "none; current uncommitted product source snapshot"
        config = project / "project.godot"
        isolated_name = "BinduToolsLoad" + uuid.uuid4().hex
        config.write_text(re.sub(r'^config/name=.*$', 'config/name="' + isolated_name + '"', config.read_text(), flags=re.M))
        isolated_userdata = Path.home() / "Library/Application Support/Godot/app_userdata" / isolated_name
        record["isolated_userdata"] = str(isolated_userdata)
        (project / "override.cfg").write_text("[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n")
        online = project / "scripts/online_config.gd"
        online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', online.read_text()))
        with (output / "import.log").open("w") as log:
            imported = subprocess.run([godot, "--headless", "--import", "--path", tmp], stdout=log, stderr=subprocess.STDOUT, timeout=300)
        record["import_exit"] = imported.returncode
        if imported.returncode:
            result_code = imported.returncode
        else:
            command = [godot, "--audio-driver", "Dummy", "--path", tmp, "--resolution", "1280x720", "-s", "tools/battlefield_load_check.gd", "--", str(output), "1.0", "pc", "load", "180"]
            record["native_command"] = command
            with (output / "native.log").open("w") as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=900, env={**os.environ, "BINDU_AUDIT_REVISION": baseline, "BINDU_PROFILE_CPU": "1", "BINDU_LOAD_SOURCE_STATE": args.source + "; see source_hashes and adapter record"})
            result_code = result.returncode
            record["native_exit"] = result_code
        shutil.rmtree(isolated_userdata, ignore_errors=True)
        record["isolated_userdata_removed"] = not isolated_userdata.exists()
    record["cleanup"] = "TemporaryDirectory removed after native process reached terminal state"
    record["finished_at_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    (output / "run.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(args.source, "exit", result_code, "temporary snapshot cleaned", flush=True)
    return result_code


if __name__ == "__main__":
    raise SystemExit(main())
