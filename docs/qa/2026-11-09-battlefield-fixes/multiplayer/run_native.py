"""Snapshot current source; run two isolated native participants against local signaling."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")


def main():
    all_results = {}
    with tempfile.TemporaryDirectory(prefix="bindu-multiplayer-native-") as temporary:
        base = Path(temporary)
        source = base / "source"
        source.mkdir()
        for folder in ("scripts", "tools", "addons", "icons"):
            if (ROOT / folder).exists():
                shutil.copytree(ROOT / folder, source / folder)
        (source / "docs").mkdir()
        shutil.copy2(ROOT / "docs/features.md", source / "docs/features.md")
        for name in ("main.tscn", "project.godot", "icon.svg"):
            shutil.copy2(ROOT / name, source / name)
        for role in ("signal", "host", "join"):
            target = base / role
            target.mkdir()
            for folder in ("scripts", "tools", "addons", "icons"):
                if (source / folder).exists():
                    shutil.copytree(source / folder, target / folder)
            (target / "docs").mkdir()
            shutil.copy2(source / "docs/features.md", target / "docs/features.md")
            for name in ("main.tscn", "project.godot", "icon.svg"):
                shutil.copy2(source / name, target / name)
            project = target / "project.godot"
            project.write_text(re.sub(
                r"^config/name=.*$",
                'config/name="BinduToolsMPNative' + role + base.name[-6:] + '"',
                project.read_text(), flags=re.M))
            (target / "override.cfg").write_text(
                "[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n")
            config = target / "scripts/online_config.gd"
            config.write_text(re.sub(
                r'const (SERVER_URL|MP_URL) := "[^\"]*"',
                r'const \1 := ""', config.read_text()))
            import_log = OUT / ("native-import-" + role + ".log")
            with import_log.open("w") as log:
                subprocess.run([GODOT, "--headless", "--path", str(target), "--import"],
                               stdout=log, stderr=subprocess.STDOUT, timeout=90, check=True)
            text = import_log.read_text()
            if "Parse Error" in text or "Compile Error" in text:
                raise RuntimeError("Current source import failed: " + role)
        manifest = {
            "base": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            "scope": "Current working-tree snapshot; all usability owners; actual local WebRTC participants",
            "files": {str(p.relative_to(base / "host")): hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in sorted((base / "host/scripts").rglob("*.gd"))},
            "test_sha256": hashlib.sha256((base / "host/tools/battlefield_multiplayer_check.gd").read_bytes()).hexdigest(),
        }
        (OUT / "native-source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        for mode in os.environ.get("MP_QA_MODES", "coop,vs").split(","):
            (OUT / (mode + "-source-manifest.json")).write_text(json.dumps(manifest, indent=2) + "\n")
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
            env = {**os.environ, "BINDU_MP_URL": "http://127.0.0.1:" + str(port), "MP_MODE": mode}
            logs = {r: (OUT / (mode + "-" + r + ".log")).open("w")
                    for r in ("signal", "host", "join")}
            processes = {}
            try:
                processes["signal"] = subprocess.Popen(
                    [GODOT, "--headless", "--path", str(base / "signal"), "-s", "tools/mp_signal.gd", "--", str(port)],
                    stdout=logs["signal"], stderr=subprocess.STDOUT, env=env)
                # Await the actual local listener, not an assumed startup delay.
                deadline = time.monotonic() + 10
                while True:
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=.2):
                            break
                    except OSError:
                        if processes["signal"].poll() is not None or time.monotonic() > deadline:
                            raise RuntimeError("Local signaling did not start")
                        time.sleep(.05)
                code = base / (mode + "-code.txt")
                for role in ("host", "join"):
                    dest = OUT / (mode + "-" + role)
                    dest.mkdir(exist_ok=True)
                    processes[role] = subprocess.Popen(
                        [GODOT, "--audio-driver", "Dummy", "--path", str(base / role),
                         "--resolution", "1280x720", "-s", "tools/battlefield_multiplayer_check.gd",
                         "--", role, str(code), str(dest)],
                        stdout=logs[role], stderr=subprocess.STDOUT, env=env)
                with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                    results = dict(pool.map(
                        lambda role: (role, processes[role].wait(timeout=145)), ("host", "join")))
                (OUT / (mode + "-process-results.json")).write_text(json.dumps(results, indent=2) + "\n")
                all_results[mode] = results
                print(mode, results, flush=True)
            finally:
                for process in processes.values():
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                for log in logs.values():
                    log.close()
        print("All signaling/client processes stopped; temporary snapshots cleaned on exit")
    return 1 if any(code for result in all_results.values() for code in result.values()) else 0


if __name__ == "__main__":
    raise SystemExit(main())
