"""Replay current usability/information UI checks from one isolated source cache.

No personal save, production URL, native focus, or OS pointer interaction.
UI_CASE=inspector selects a usability case; UI_CASES=usability selects that suite.
"""
from pathlib import Path
import concurrent.futures
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[4]
QA = REPO / "docs/qa/2026-11-09-battlefield-fixes"
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
SELECTED = os.environ.get("UI_CASES", "usability,information").split(",")
CASE = os.environ.get("UI_CASE", "all")
SUFFIX = os.environ.get("UI_SUFFIX", "")
CASES = [
    ("usability", "pc", "1280x720", "1.0", "pc", "usability_check.gd"),
    ("usability", "phone", "2556x1179", "1.3", "phone", "usability_check.gd"),
    ("information", "integrated-pc", "1280x720", "1.0", "pc", "battlefield_information_check.gd"),
    ("information", "integrated-phone", "2556x1179", "1.3", "phone", "battlefield_information_check.gd"),
]


def main():
    with tempfile.TemporaryDirectory(prefix="bindu-info-usability-") as temporary:
        base = Path(temporary) / "source"
        base.mkdir()
        for folder in ("scripts", "tools"):
            shutil.copytree(REPO / folder, base / folder)
        (base / "docs").mkdir()
        shutil.copy2(REPO / "docs/features.md", base / "docs/features.md")
        for filename in ("main.tscn", "project.godot", "icon.svg"):
            shutil.copy2(REPO / filename, base / filename)
        hashes = {
            str(path.relative_to(base)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(base.rglob("*")) if path.is_file()
        }
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()

        def run(case):
            group, profile, resolution, scale, device, script = case
            evidence = QA / group / (profile + SUFFIX)
            evidence.mkdir(parents=True, exist_ok=True)
            project = Path(temporary) / (group + "-" + profile)
            shutil.copytree(base, project)
            config = project / "project.godot"
            config.write_text(re.sub(
                r"^config/name=.*$",
                'config/name="BinduToolsLatest%s%s%s"' % (group, profile, project.parent.name),
                config.read_text(), flags=re.M,
            ))
            online = project / "scripts/online_config.gd"
            online.write_text(re.sub(
                r'const (SERVER_URL|MP_URL) := "[^"]*"', r'const \1 := ""', online.read_text(),
            ))
            (project / "override.cfg").write_text(
                "[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n"
            )
            manifest = {
                "base_revision": revision,
                "captured_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "source_state": "single uncommitted source cache; isolated name/online URL overrides",
                "source_hashes": hashes, "script": script, "resolution": resolution,
                "ui_scale": scale, "device": device, "case": CASE if group == "usability" else None,
            }
            (evidence / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            with (evidence / "import.log").open("w") as log:
                imported = subprocess.run(
                    [GODOT, "--headless", "--path", str(project), "--import"],
                    stdout=log, stderr=subprocess.STDOUT, timeout=180,
                )
            import_text = (evidence / "import.log").read_text()
            if imported.returncode or "Parse Error" in import_text or "Compile Error" in import_text:
                result = {"import_exit": imported.returncode, "native_exit": None, "parser_error": True}
            else:
                command = [
                    GODOT, "--audio-driver", "Dummy", "--path", str(project),
                    "--resolution", resolution, "-s", "tools/" + script,
                    "--", str(evidence), scale, device,
                ]
                if group == "usability":
                    command.append(CASE)
                with (evidence / "native.log").open("w") as log:
                    executed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                result = {
                    "import_exit": imported.returncode, "native_exit": executed.returncode,
                    "command": [part.replace(str(project), "<isolated-project>") for part in command],
                }
            (evidence / "process-result.json").write_text(json.dumps(result, indent=2) + "\n")
            print(group, profile, result, flush=True)
            return result

        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(run, [case for case in CASES if case[0] in SELECTED]))
        print("Isolated source copies cleaned on exit", flush=True)
        return int(any(result.get("native_exit") != 0 for result in results))


if __name__ == "__main__":
    raise SystemExit(main())
