#!/usr/bin/env python3
"""One isolated functional/mutant gate and bounded headless function benchmark."""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import time
import uuid


def godot_processes():
    output = subprocess.run(["ps", "-axo", "pid=,comm="], capture_output=True, text=True, check=True).stdout
    found = []
    for line in output.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and (parts[1].endswith("/Godot") or parts[1] == "Godot"):
            found.append({"pid": int(parts[0]), "executable": parts[1]})
    return found


def run(args):
    root = Path(__file__).resolve().parents[5]
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sources = ["scripts/zone.gd", "scripts/orb.gd", "scripts/share.gd", "scripts/tower.gd", "scripts/features/combat.gd", "tools/battlefield_zone_check.gd"]
    hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sources}
    records = []
    with tempfile.TemporaryDirectory(prefix="bindu-zone-finite-") as temp:
        project = Path(temp)
        for name in ["scripts", "tools"]:
            shutil.copytree(root / name, project / name)
        for name in ["project.godot", "main.tscn", "icon.svg"]:
            shutil.copy(root / name, project / name)
        (project / "docs").mkdir()
        shutil.copy(root / "docs/features.md", project / "docs/features.md")
        config = project / "project.godot"
        config.write_text(re.sub(r'^config/name=.*', 'config/name="BinduToolsZoneFinite' + uuid.uuid4().hex + '"', config.read_text(), flags=re.M))
        online = project / "scripts/online_config.gd"
        online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', online.read_text()))
        imported = subprocess.run([str(args.godot), "--headless", "--path", str(project), "--editor", "--import", "--quit"], capture_output=True, text=True, timeout=30)
        (out / "import.log").write_text(imported.stdout + imported.stderr)
        if imported.returncode or re.search(r"SCRIPT ERROR|Parse Error|^ERROR:", imported.stdout + imported.stderr, re.M):
            raise RuntimeError("isolated parser failed")
        for mode in ["functional", "mutant-moved", "mutant-radius", "benchmark"]:
            folder = out / mode
            folder.mkdir(exist_ok=True)
            if mode == "benchmark" and godot_processes():
                raise RuntimeError("another Godot is running; no benchmark started")
            command = [str(args.godot), "--headless", "--audio-driver", "Dummy", "--path", str(project), "-s", "tools/battlefield_zone_check.gd", "--", str(folder)]
            if mode != "functional":
                command.append("bench" if mode == "benchmark" else mode)
            started_at = dt.datetime.now(dt.timezone.utc).isoformat()
            start = time.monotonic()
            samples = []
            with (folder / "run.log").open("w") as log:
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
                while process.poll() is None:
                    if mode == "benchmark":
                        samples.append({"elapsed_seconds": time.monotonic() - start, "processes": godot_processes()})
                    if time.monotonic() - start > 30:
                        process.kill()
                        process.wait()
                        raise RuntimeError("bounded run exceeded 30 seconds")
                    time.sleep(0.1)
            record = {"mode": mode, "command": command, "started_at_utc": started_at, "elapsed_seconds": time.monotonic() - start, "exit_code": process.returncode, "concurrency_samples": samples, "other_godot_seen": any(any(item["pid"] != process.pid for item in sample["processes"]) for sample in samples)}
            (folder / "run.json").write_text(json.dumps(record, indent=2) + "\n")
            records.append(record)
            log = (folder / "run.log").read_text()
            expected_exit = 1 if mode.startswith("mutant-") else 0
            marker = r"ZONE CHECK .* failures=" + ("1" if expected_exit else "0") + r"$"
            if process.returncode != expected_exit or not re.search(marker, log, re.M) or re.search(r"SCRIPT ERROR|Parse Error|^ERROR:", log, re.M) or record["other_godot_seen"]:
                raise RuntimeError("run failed verification: " + mode)
        (out / "manifest.json").write_text(json.dumps({"source_hashes": hashes, "runs": records, "platform": platform.platform(), "headless_only": True, "product_zone_changed": False}, indent=2) + "\n")
    print("ZONE FINITE PASS: functional + two expected RED mutants + bounded benchmark")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, default=Path("/Applications/Godot.app/Contents/MacOS/Godot"))
    parser.add_argument("--output", type=Path, required=True)
    run(parser.parse_args())
