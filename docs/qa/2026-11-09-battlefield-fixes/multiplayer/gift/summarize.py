"""Verify preserved protocol evidence and the latest focused visual/teardown followups."""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
CASES = ["race", "race_reverse", "ack_loss", "complete_loss", "donor_rejoin_before_commit", "donor_rejoin", "owner_rejoin_before_commit", "owner_rejoin", "old_round", "host_donor", "force_fence", "retire_owner", "retire_donor", "donor_edit_rejoin"]
ACTORS = ["host", "peer_a", "peer_b"]
PROTOCOL = ["scripts/app/gift_transactions.gd", "scripts/features/multiplayer.gd", "scripts/mp.gd", "scripts/card_dock.gd"]


def actors_at(directory, case):
    checks = json.loads((directory / case / "checks.json").read_text())
    out = {}
    for actor in ACTORS:
        item = checks[actor]
        report = item["report"]
        log = (directory / case / (actor + ".log")).read_text()
        connection = [row["data"] for row in report["results"] if row["event"] == "connected"]
        out[actor] = {"exit":item["exit"], "assertions_passed":len(re.findall(r"^ok   ",log,re.M)), "assertions_failed":report["failures"], "ui_messages":report["ui_messages"], "runtime_errors":item["runtime_errors"], "warnings":item["warnings"], "actual_connection":connection[0] if connection else None}
    return out


def clean(row):
    return row["exit"] == 0 and row["assertions_failed"] == 0 and row["ui_messages"] == 0 and not row["runtime_errors"]


def main():
    primary = HERE / "final"
    old_manifest = json.loads((primary / "source-manifest.json").read_text())["source_hashes"]
    summary = {"protocol_cases":{}, "two_participant":{}, "focused":{}, "runtime_observations":[], "source_boundaries":{}, "failures":[]}
    for case in CASES:
        rows = actors_at(primary,case)
        summary["protocol_cases"][case] = rows
        for actor,row in rows.items():
            if row["exit"] or row["assertions_failed"] or row["ui_messages"] or not row["actual_connection"]:
                summary["failures"].append("protocol:" + case + "/" + actor)
            if row["runtime_errors"]:
                log = (primary / case / (actor + ".log")).read_text()
                expected = case == "owner_rejoin_before_commit" and actor == "host" and len(row["runtime_errors"]) == 3 and "SCTP sending failed" in row["runtime_errors"][0] and log.index("UI ok owner-recovery-coordinator") < log.index("ERROR:")
                summary["runtime_observations"].append({"case":case + "/" + actor,"errors":row["runtime_errors"],"after_final_capture":expected,"followup":"pending-pc-before-toast-fix/owner_rejoin_before_commit"})
                if not expected: summary["failures"].append("unclassified-runtime:" + case + "/" + actor)
    two = HERE / "two-participant-final"
    two_manifest = json.loads((two / "native-source-manifest.json").read_text())["files"]
    for name,value in two_manifest.items():
        if name != "scripts/online_config.gd" and old_manifest.get(name) != value:
            summary["failures"].append("primary-two-source:" + name)
    for mode in ("coop","vs"):
        exits = json.loads((two / (mode + "-process-results.json")).read_text())
        for actor in ("host","join"):
            log = (two / (mode + "-" + actor + ".log")).read_text()
            report = json.loads((two / (mode + "-" + actor) / "result.json").read_text())
            row = {"exit":exits[actor],"assertions_passed":len(re.findall(r"^ok   ",log,re.M)),"assertions_failed":report["failures"],"ui_messages":report["ui_messages"],"runtime_errors":[x for x in log.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|Compile Error|^ERROR:",x)],"warnings":[x for x in log.splitlines() if x.startswith("WARNING:")]}
            summary["two_participant"][mode + "/" + actor] = row
            if not clean(row): summary["failures"].append("two:" + mode + "/" + actor)
    stages = {"pending-pc":["race","race_reverse","ack_loss"],"pending-phone":["race","race_reverse","ack_loss"],"pending-pc-before-toast-fix":["owner_rejoin_before_commit"]}
    for stage,cases in stages.items():
        directory = HERE / stage
        stage_manifest = json.loads((directory / "source-manifest.json").read_text())["source_hashes"]
        for name in PROTOCOL:
            if stage_manifest[name] != old_manifest[name]: summary["failures"].append("protocol-source:" + stage + "/" + name)
        if stage in ("pending-pc","pending-phone"):
            for name,value in stage_manifest.items():
                if name.startswith("scripts/") and hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != value:
                    summary["failures"].append("latest-ui-source:" + stage + "/" + name)
        summary["focused"][stage] = {}
        for case in cases:
            rows = actors_at(directory,case)
            summary["focused"][stage][case] = rows
            for actor,row in rows.items():
                if not clean(row): summary["failures"].append("focused:" + stage + "/" + case + "/" + actor)
    changes = [name for name,value in old_manifest.items() if name.startswith("scripts/") and hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != value]
    summary["source_boundaries"] = {"primary_and_two_share_original_product_snapshot":True,"protocol_sha256":{name:old_manifest[name] for name in PROTOCOL},"later_product_changes":changes,"latest_pc_phone_manifest_matches_current_scripts":True,"test_revision":"Original 14-case tool preserved in manifest; focused tool adds neutral-preview assertions, phone touch profile, and synchronized QA shutdown."}
    if set(changes) - {"scripts/features/field_view.gd","scripts/features/frame.gd","scripts/features/ui_layout.gd"}:
        summary["failures"].append("unexpected-product-drift")
    all_rows = [row for case in summary["protocol_cases"].values() for row in case.values()] + list(summary["two_participant"].values()) + [row for stage in summary["focused"].values() for case in stage.values() for row in case.values()]
    summary["actor_results"] = len(all_rows)
    summary["assertions_passed"] = sum(row["assertions_passed"] for row in all_rows)
    summary["behavior_failures"] = sum(row["assertions_failed"] for row in all_rows)
    summary["ui_messages"] = sum(row["ui_messages"] for row in all_rows)
    summary["verdict"] = "pass with preserved post-check QA teardown observation" if not summary["failures"] else "fail"
    (HERE / "verification-summary.json").write_text(json.dumps(summary,indent=2) + "\n")
    print(json.dumps({key:summary[key] for key in ("actor_results","assertions_passed","behavior_failures","ui_messages","failures","verdict")},indent=2))
    return int(bool(summary["failures"]))


if __name__ == "__main__":
    raise SystemExit(main())
