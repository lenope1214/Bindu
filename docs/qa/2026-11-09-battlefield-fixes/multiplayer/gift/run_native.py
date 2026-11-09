"""Actual local signaling + three native WebRTC participants, isolated saves and source hashes."""
from pathlib import Path
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent / os.environ.get("GIFT_OUTPUT_SUBDIR", "native")
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
SCENARIOS = os.environ.get("GIFT_SCENARIOS", "race,race_reverse,ack_loss,complete_loss,donor_rejoin_before_commit,donor_rejoin,owner_rejoin_before_commit,owner_rejoin,old_round,host_donor,force_fence,retire_owner,retire_donor,donor_edit_rejoin").split(",")
ACTORS = ("host", "peer_a", "peer_b")
RESOLUTION = os.environ.get("GIFT_RESOLUTION", "1280x720")


def main():
    completed = {}
    with tempfile.TemporaryDirectory(prefix="bindu-native-gift-") as temporary:
        base = Path(temporary)
        source = base / "source"
        source.mkdir()
        for folder in ("scripts", "tools", "addons", "icons"):
            if (ROOT / folder).exists():
                shutil.copytree(ROOT / folder, source / folder)
        (source / "docs").mkdir()
        shutil.copy2(ROOT / "docs/features.md", source / "docs/features.md")
        for filename in ("project.godot", "main.tscn", "icon.svg"):
            shutil.copy2(ROOT / filename, source / filename)
        original_hashes = {
            str(path.relative_to(source)):hashlib.sha256(path.read_bytes()).hexdigest()
            for folder in ("scripts", "tools") for path in sorted((source / folder).rglob("*.gd"))
        }
        packet_source = source / "scripts/features/multiplayer.gd"
        product_text = packet_source.read_text()
        marker = "func _mp_packet(from: int, msg: Dictionary) -> void:\n\tvar session: BinduSession = self.session\n"
        assert product_text.count(marker) == 1, "packet handler integration changed; inspect hook placement"
        packet_source.write_text(product_text.replace(marker, marker +
            '\t# Local QA hook: delay actual received packets before product dispatch.\n'
            '\tif session.has_meta("gift_qa_receive"):\n'
            '\t\tvar gate: Callable = session.get_meta("gift_qa_receive")\n'
            '\t\tif gate.call(from, msg): return\n'))
        manifest = {
            "captured_at_utc":datetime.now(timezone.utc).isoformat(),
            "godot_version":subprocess.check_output([GODOT,"--version"],text=True).strip(),
            "profile":{"resolution":RESOLUTION,"scale":os.environ.get("GIFT_SCALE","1.0"),"device":os.environ.get("GIFT_DEVICE","pc")},
            "base_revision":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
            "source_hashes":original_hashes,
            "instrumented_packet_sha256":hashlib.sha256(packet_source.read_bytes()).hexdigest(),
            "instrumentation":"only incoming packet delay callback before unchanged product handler; original repository files untouched",
            "fixture_boundary":"valid initial offers/placement may be deterministic; transactions and outcomes require actual local WebRTC",
        }
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        for role in ("signal",) + ACTORS:
            project = base / role
            shutil.copytree(source, project)
            config = project / "project.godot"
            config.write_text(re.sub(r'^config/name=.*$', 'config/name="BinduToolsGift%s%s"' % (role, base.name), config.read_text(), flags=re.M))
            online = project / "scripts/online_config.gd"
            online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"', r'const \1 := ""', online.read_text()))
            (project / "override.cfg").write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            with (OUT / ("import-" + role + ".log")).open("w") as log:
                result = subprocess.run([GODOT,"--headless","--path",str(project),"--import"],stdout=log,stderr=subprocess.STDOUT,timeout=100)
            text = (OUT / ("import-" + role + ".log")).read_text()
            if result.returncode or "Parse Error" in text or "Compile Error" in text:
                raise RuntimeError("Source import failed: " + role)
            if role == "host":
                with (OUT / "parser-host.log").open("w") as log:
                    check = subprocess.run([GODOT,"--headless","--path",str(project),"--check-only","-s","tools/battlefield_gift_check.gd"],stdout=log,stderr=subprocess.STDOUT,timeout=30)
                parser_text = (OUT / "parser-host.log").read_text()
                if check.returncode or "SCRIPT ERROR" in parser_text or "Parse Error" in parser_text or "Compile Error" in parser_text:
                    raise RuntimeError("Gift test parser failed; see parser-host.log")
        for scenario in SCENARIOS:
            scenario_out = OUT / scenario
            scenario_out.mkdir(exist_ok=True)
            shared = base / (scenario + "-coordination")
            shared.mkdir()
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
            environment = {**os.environ,"BINDU_MP_URL":"http://127.0.0.1:" + str(port)}
            logs = {role:(scenario_out / (role + ".log")).open("w") for role in ("signal",) + ACTORS}
            processes = {}
            try:
                processes["signal"] = subprocess.Popen([GODOT,"--headless","--path",str(base / "signal"),"-s","tools/mp_signal.gd","--",str(port)],stdout=logs["signal"],stderr=subprocess.STDOUT,env=environment)
                deadline = time.monotonic() + 10
                while "MPSIG listening " not in (scenario_out / "signal.log").read_text():
                    if processes["signal"].poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("Local signaling listener unavailable")
                    time.sleep(.05)
                for role in ACTORS:
                    evidence = scenario_out / role
                    evidence.mkdir(exist_ok=True)
                    processes[role] = subprocess.Popen([GODOT,"--audio-driver","Dummy","--path",str(base / role),"--resolution",RESOLUTION,"-s","tools/battlefield_gift_check.gd","--",role,str(shared),str(evidence),scenario],stdout=logs[role],stderr=subprocess.STDOUT,env=environment)
                with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
                    results = dict(pool.map(lambda role:(role,processes[role].wait(timeout=205)),ACTORS))
                for log in logs.values():
                    log.flush()
                checks = {}
                for role in ACTORS:
                    role_log = (scenario_out / (role + ".log")).read_text()
                    errors = [line for line in role_log.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|Compile Error|^ERROR:", line)]
                    warnings = [line for line in role_log.splitlines() if line.startswith("WARNING:")]
                    result_path = scenario_out / role / "result.json"
                    report = json.loads(result_path.read_text()) if result_path.exists() else None
                    checks[role] = {"exit":results[role],"runtime_errors":errors,"warnings":warnings,"report":report}
                    if errors or report is None or report.get("failures",1) or report.get("ui_messages",1):
                        results[role] = results[role] or 1
                completed[scenario] = results
                (scenario_out / "process-results.json").write_text(json.dumps(results,indent=2)+'\n')
                (scenario_out / "checks.json").write_text(json.dumps(checks,indent=2)+'\n')
                (scenario_out / "source-manifest.json").write_text(json.dumps(manifest,indent=2)+'\n')
                print(scenario,results,flush=True)
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
        (OUT / "summary.json").write_text(json.dumps(completed,indent=2)+'\n')
    return int(any(code for result in completed.values() for code in result.values()))


if __name__ == "__main__":
    raise SystemExit(main())
