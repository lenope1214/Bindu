"""Run original card-writing checks; add read-only actual-font summary metrics in copies."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import re
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[4]
QA = REPO / "docs/qa/2026-11-09-battlefield-fixes/usability"
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
METRICS = '''\t\tvar actual_fs := Meta.fs(14)
\t\tvar actual_summary: String = dock.summary_text(button)
\t\tvar actual_lines: PackedStringArray = main.onboarding_system._wrap_words(main.patchlog_system._kr_keep(actual_summary), button.size.x - 28, actual_fs).split("\\n")
\t\tvar summary_key := str(button.get_meta("offer_card", button.get_meta("card")[0]))
\t\tsummary_metrics[summary_key] = {"name":button.get_meta("card")[0].get("name", ""), "summary":actual_summary, "width":button.size.x, "height":button.size.y, "font_size":actual_fs, "lines":Array(actual_lines), "shown":Array(actual_lines.slice(0, mini(3, actual_lines.size()))), "truncated":actual_lines.size() > 3, "tail":Array(actual_lines.slice(3)), "last_body_baseline":51.0 + (Meta.fs(18) - 18) + (actual_fs + 4.0) * (mini(3, actual_lines.size()) - 1), "body_descent":main.ui_font.get_descent(actual_fs), "foot_baseline":button.size.y - 8.0, "foot_ascent":main.ui_font.get_ascent(Meta.fs(11)), "capture":tag + ".png"}
'''
SEMANTICS = '''
func verify_fronts() -> void:
\tvar total: int = Elem.ALL.size() + Pat.PATTERNS.size() + Pat.MODS.size() + Pat.LINKS.size() + Pat.TRIGS.size() + main.PERKS.size()
\tok("BF-24", summary_metrics.size() == total, "entire actual card/perk pool recorded")
\tvar by_name := {}
\tfor row: Dictionary in summary_metrics.values():
\t\tby_name[row.name] = row
\t\tok("BF-24", not row.truncated, str(row.name) + " actual-font summary fits three lines")
\t\tfor line: String in row.lines:
\t\t\tok("BF-24", main.ui_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(row.font_size)).x <= float(row.width) - 27.0, str(row.name) + " actual-font width fits")
\tvar required := {"유도":["불가", "벽", "혼불", "시계침", "연쇄 번개"], "실드":["이월 없음", "+%d" % int(main.perks_system._perk_val("shield")), "최대 %d" % int(main.perks_system._perk_val("shield_max"))], "성벽":["최대 %d조각" % int(main.perks_system._perk_val("rampart_max")), "벽 레벨합", "고른 횟수"], "운명의 동전":["앞면 2회", "뒷면 1회", "새로고침 +%d" % int(main.perks_system._perk_val("coin"))], "조화":["1회만", "최대 +%s%%" % String.num(main.perks_system._perk_val("harmony_cap") * 100.0).trim_suffix(".0")]}
\tfor name: String in required:
\t\tvar shown: String = "".join(by_name[name].shown).replace("\\u2060", "").replace(" ", "")
\t\tfor term: String in required[name]:
\t\t\tok("BF-24", shown.contains(term.replace(" ", "")), name + " visible critical term: " + term)
\tvar original_patch: Dictionary = Patch.data.duplicate(true)
\tPatch.data = {"perks":{"coin":3, "shield":2, "shield_max":5, "rampart":2, "rampart_max":6, "harmony":0.4, "harmony_cap":0.33}, "rules":{"all":{"homing_fade_min":0.42, "pierce_hit":0.6, "pierce_dmg":0.09, "pierce_shield":0.3, "pierce_armor":0.25, "pincer_frac":0.13, "pincer_t":4.0}}}
\tRules.apply(1)
\tvar proof := {}
\tfor pk: Dictionary in main.PERKS:
\t\tif pk.id in ["coin", "shield", "rampart", "harmony"]:
\t\t\tproof[pk.id] = main.perks_system._perk_summary(pk)
\tproof["homing"] = main.cards_system._card_simple({"type":"mod", "id":"homing"}, [{"t":Pat.mdesc("homing")}])[0].t
\tproof["pierce"] = main.cards_system._card_simple({"type":"mod", "id":"pierce"}, [{"t":Pat.mdesc("pierce")}])[0].t
\tproof["pincer"] = main.cards_system._card_simple({"type":"link", "id":"pincer"}, [])[0].t
\tvar patched_terms := {"coin":["+3"], "shield":["+2", "최대 5", "이월 없음"], "rampart":["최대 6", "×2"], "harmony":["×0.4", "+33%"], "homing":["42%", "불가"], "pierce":["×0.6", "+9%", "+30%", "25%"], "pincer":["13%", "4초"]}
\tfor key: String in patched_terms:
\t\tfor term: String in patched_terms[key]:
\t\t\tok("BF-24", str(proof[key]).contains(term), "patch value reflected: " + key + " " + term)
\tFileAccess.open(output.path_join("patched-front-proof.json"), FileAccess.WRITE).store_string(JSON.stringify(proof, "\\t"))
\tPatch.data = original_patch
\tRules.apply(1)
'''


def main():
    with tempfile.TemporaryDirectory(prefix="bindu-card-writing-sources-") as temporary:
        base = Path(temporary) / "source"
        base.mkdir()
        for folder in ("scripts", "tools"):
            shutil.copytree(REPO / folder, base / folder)
        (base / "docs").mkdir()
        shutil.copy2(REPO / "docs/features.md", base / "docs/features.md")
        for filename in ("main.tscn", "project.godot", "icon.svg"):
            shutil.copy2(REPO / filename, base / filename)
        hashes = {str(p.relative_to(base)):hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(base.rglob("*")) if p.is_file()}
        check = base / "tools/card_writing_check.gd"
        original = check.read_text()
        measured = original.replace('var expected_rows: Array = []', 'var expected_rows: Array = []\nvar summary_metrics := {}')
        measured = measured.replace('\tFileAccess.open(output.path_join("captures.json")', '\tFileAccess.open(output.path_join("summary-metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(summary_metrics, "\\t"))\n\tFileAccess.open(output.path_join("captures.json")')
        measured = measured.replace('\t\tvar lines: PackedStringArray =', METRICS + '\t\tvar lines: PackedStringArray =')
        measured = measured.replace('\tFileAccess.open(output.path_join("summary-metrics.json")', '\tverify_fronts()\n\tFileAccess.open(output.path_join("summary-metrics.json")')
        measured += SEMANTICS
        assert measured != original and measured.count('var actual_fs :=') == 1
        check.write_text(measured)

        def run(phone):
            profile = "phone130" if phone else "pc130"
            evidence = QA / ("card-writing-" + profile)
            evidence.mkdir(parents=True, exist_ok=True)
            output = Path(tempfile.mkdtemp(prefix="bindu-card-writing-" + profile + "-"))
            project = Path(temporary) / profile
            shutil.copytree(base, project)
            config = project / "project.godot"
            config.write_text(re.sub(r'^config/name=.*$', 'config/name="BinduToolsWriting%s%s"' % (profile, project.parent.name), config.read_text(), flags=re.M))
            online = project / "scripts/online_config.gd"
            online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"', r'const \1 := ""', online.read_text()))
            (project / "override.cfg").write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            manifest = {"base_revision":subprocess.check_output(["git","rev-parse","HEAD"],cwd=REPO,text=True).strip(),"source_hashes":hashes,"executed_test_sha256":hashlib.sha256(measured.encode()).hexdigest(),"instrumentation":"only records actual Meta.fs(14) summary lines and baseline geometry; original assertions preserved","output":str(output),"profile":profile,"resolution":"2556x1179" if phone else "1280x720","scale":1.3}
            (evidence / "source-manifest.json").write_text(json.dumps(manifest,indent=2)+'\n')
            (evidence / "executed-card-writing-check.gd").write_text(measured)
            with (evidence / "import.log").open("w") as log:
                imported = subprocess.run([GODOT,"--headless","--path",str(project),"--import"],stdout=log,stderr=subprocess.STDOUT,timeout=180)
            source_log=(evidence / "import.log").read_text()
            if imported.returncode or "Parse Error" in source_log or "Compile Error" in source_log:
                result={"import_exit":imported.returncode,"native_exit":None}
            else:
                command=[GODOT,"--audio-driver","Dummy","--path",str(project),"--resolution",manifest["resolution"],"-s","tools/card_writing_check.gd","--",str(output),"1.3"]
                if phone:command.append("phone")
                with (evidence / "native.log").open("w") as log:
                    executed=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=180)
                result={"import_exit":0,"native_exit":executed.returncode,"output":str(output),"command":[x.replace(str(project),"<isolated-project>") for x in command]}
                for filename in ("captures.json","summary-metrics.json","patched-front-proof.json","link_pincer_summary.png","link_pincer_detail.png","mod_homing_summary.png","perk_harmony.png","perk_rampart.png","perk_coin.png","perk_shield.png"):
                    if (output / filename).exists():shutil.copy2(output / filename,evidence / filename)
                first=next(iter(sorted(output.glob('elem_*_summary.png'))),None)
                if first:shutil.copy2(first,evidence / "card4.png")
            (evidence / "process-result.json").write_text(json.dumps(result,indent=2)+'\n')
            print(profile,result,flush=True)
            return result
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(run,(False,True)))
        return int(any(r.get("native_exit") != 0 for r in results))


if __name__ == "__main__":
    raise SystemExit(main())
