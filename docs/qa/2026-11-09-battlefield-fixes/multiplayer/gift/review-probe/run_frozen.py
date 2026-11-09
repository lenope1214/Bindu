#!/usr/bin/env python3
"""Run read-only service counterexamples on the recorded isolated snapshot."""
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import uuid

base = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--freeze-current", action="store_true")
parser.add_argument("--output", type=Path, default=base)
parser.add_argument("--cases", default="terminal-rejoin,settled-retry,ordinary-choice,context-only,old-ack,loser-result,disconnect-retire,settled-replay,caps-fence,fence-pending,fence-auto,moving-context,legacy-tw")
args = parser.parse_args()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
if args.freeze_current:
    repo = base.parents[5]
    project = Path(tempfile.mkdtemp(prefix="bindu-gift-review-"))
    name = "BinduToolsGiftReview" + uuid.uuid4().hex
    for part in ["scripts", "tools", "docs"]:
        shutil.copytree(repo / part, project / part)
    for part in ["main.tscn", "project.godot", "icon.svg"]:
        shutil.copy2(repo / part, project / part)
    config = project / "project.godot"
    config.write_text(re.sub(r'^config/name=.*$', f'config/name="{name}"', config.read_text(), flags=re.M))
    online = project / "scripts/online_config.gd"
    online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', online.read_text()))
    record = {"project":str(project), "isolated_name":name, "frozen_at_utc":dt.datetime.now(dt.timezone.utc).isoformat(), "source_hashes":{str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project / "scripts").rglob("*.gd")}}
    (out / "frozen.json").write_text(json.dumps(record, indent=2) + "\n")
else:
    record = json.loads((out / "frozen.json").read_text())
    project = Path(record["project"])
    assert project.is_dir(), "Recorded snapshot was cleaned; use --freeze-current --output NEW_DIRECTORY"
godot = "/Applications/Godot.app/Contents/MacOS/Godot"
shutil.copy2(base / "probe.gd", project / "tools/gift_review_probe.gd")
shutil.copy2(project / "scripts/app/gift_transactions.gd", out / "service-under-review.txt")
record["probe_sha256"] = hashlib.sha256((base / "probe.gd").read_bytes()).hexdigest()
record["started_at_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
results = []
try:
    with (out / "import.log").open("w") as log:
        imported = subprocess.run([godot, "--headless", "--import", "--path", str(project)], stdout=log, stderr=subprocess.STDOUT, timeout=180)
    record["import_exit"] = imported.returncode
    for case in args.cases.split(","):
        command = [godot, "--headless", "--audio-driver", "Dummy", "--path", str(project), "-s", "tools/gift_review_probe.gd", "--", case]
        with (out / (case + ".log")).open("w") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        text = (out / (case + ".log")).read_text()
        results.append({"case":case, "command":command, "exit":result.returncode, "script_errors":text.count("SCRIPT ERROR"), "observations":[line for line in text.splitlines() if line.startswith("PROBE ")]})
        print(case, result.returncode, results[-1]["observations"], "script_errors", results[-1]["script_errors"], flush=True)
finally:
    shutil.rmtree(project, ignore_errors=True)
    userdata = Path.home() / "Library/Application Support/Godot/app_userdata" / record["isolated_name"]
    shutil.rmtree(userdata, ignore_errors=True)
    record["results"] = results
    record["temporary_project_removed"] = not project.exists()
    record["isolated_userdata_removed"] = not userdata.exists()
    record["finished_at_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    (out / "run.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
