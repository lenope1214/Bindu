#!/usr/bin/env python3
"""Frozen full-hit replay with trait activation, delayed state and RNG checks."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[5]
BASELINE_REF = 'ef82a0963614c15d4a03a3e770a7a3641dbe028b'
path = Path(__file__).resolve().parent.parent / 'guard-range/run_replay.py'
spec = importlib.util.spec_from_file_location('guard_helpers', path)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def hit_span(source):
    start = source.index('func hit(o: Orb,')
    end = source.index('\n\n\n# ----------', start)
    return start, end


def variant_tower(source, variant):
    original = subprocess.check_output(['git', 'show', BASELINE_REF + ':scripts/tower.gd'], cwd=ROOT, text=True)
    a, b = hit_span(original)
    body = original[a:b]
    if variant != 'baseline':
        for before, after in [
            ('\tif o.hp > 0.0:\n\t\tShare.condense(', '\tif els.has(Elem.METAL) and o.hp > 0.0:\n\t\tShare.condense('),
            ('\tShare.on_hit(self, o, false)', '\tif els.has(Elem.EARTH) or els.has(Elem.TIME):\n\t\tShare.on_hit(self, o, false)'),
            ('\tShare.mark(self, o)', '\tif els.has(Elem.BLOOD) or els.has(Elem.ILLUSION):\n\t\tShare.mark(self, o)'),
        ]:
            assert body.count(before) == 1
            body = body.replace(before, after)
        if variant == 'mutant':
            body = body.replace('if els.has(Elem.EARTH) or els.has(Elem.TIME):', 'if els.has(Elem.EARTH) and els.has(Elem.TIME):')
    a, b = hit_span(source)
    return source[:a] + body + source[b:]


def instrument(source, triples_only=False):
    source = source.replace('var preview: AttackPreview', 'var preview: AttackPreview\nvar qa_traces := []', 1)
    marker = '\t\tif suite == "context":'
    assert source.count(marker) == 1
    matrix = '''		if suite == "hit_traits":
			for element in Elem.ALL:
				run_case(pat, {element:2}, {}, {}, "single:" + str(element), 2, true)
			for pair in [[Elem.EARTH,Elem.WOOD],[Elem.EARTH,Elem.TIME],[Elem.METAL,Elem.WOOD],[Elem.BLOOD,Elem.WATER],[Elem.ILLUSION,Elem.FIRE],[Elem.BLOOD,Elem.ILLUSION],[Elem.TIME,Elem.METAL],[Elem.FIRE,Elem.ICE],[Elem.SOUL,Elem.POISON],[Elem.LIGHT,Elem.DARK],[Elem.TIME,Elem.ICE],[Elem.BLOOD,Elem.METAL],[Elem.ILLUSION,Elem.METAL]]:
				run_case(pat, {pair[0]:2,pair[1]:2}, {"multi":1}, {"echo":1}, "trait-pair:" + str(pair), 2, true)
		elif suite == "context":'''
    if triples_only:
        matrix = '''		if suite == "hit_traits":
			for triple in [[Elem.METAL,Elem.EARTH,Elem.BLOOD],[Elem.METAL,Elem.TIME,Elem.ILLUSION],[Elem.EARTH,Elem.TIME,Elem.BLOOD],[Elem.FIRE,Elem.EARTH,Elem.TIME],[Elem.METAL,Elem.LIGHT,Elem.ILLUSION],[Elem.FIRE,Elem.ICE,Elem.BLOOD]]:
				run_case(pat, {triple[0]:2,triple[1]:2,triple[2]:2}, {"multi":1}, {"echo":1}, "trait-triple:" + str(triple), 2, true)
		elif suite == "context":'''
    source = source.replace(marker, matrix)
    source = source.replace('"pairs": Elem.REACTIONS.size(),', '"hit_traits": ' + ('6' if triples_only else 'Elem.ALL.size() + 13') + ', "pairs": Elem.REACTIONS.size(),', 1)
    source = source.replace('\tvar expected := []', '\tvar expected := []\n\tvar qa_extra := []', 1)
    marker = '\t\tif frame % 20 == 0: expected.append(state(main))'
    assert source.count(marker) == 1
    source = source.replace(marker, '\t\tif frame % 20 == 0:\n\t\t\texpected.append(state(main))\n\t\t\tqa_extra.append(qa_extended_state(main))')
    marker = '\tseed(419)\n\tvar index := 0'
    assert source.count(marker) == 1
    source = source.replace(marker, '\tqa_traces.append({"pattern":pat,"label":label,"states":expected,"extended":qa_extra,"next_rng":randi()})\n' + marker)
    marker = '\tquit(1 if fails > 0 else 0)'
    source = source.replace(marker, '\tFileAccess.open(OS.get_environment("BINDU_HIT_TRACE"), FileAccess.WRITE).store_string(JSON.stringify(qa_traces))\n' + marker, 1)
    source += '''
func qa_extended_state(world: BinduSession) -> Array:
	var towers := []
	for tower in world.towers.get_children():
		var pending := []
		for row in tower.later: pending.append(normalize(row[0]))
		towers.append([pending,normalize(tower.mirror_t),normalize(tower.mirror_f),normalize(tower.mirror_cd),is_instance_valid(tower.mirror_src)])
	var orbs := []
	for orb in world.orbs.get_children():
		if not orb.is_queued_for_deletion(): orbs.append([normalize(orb.rep_cd),normalize(orb.gore_t),is_instance_valid(orb.gore_src)])
	return [towers,orbs]
'''
    return source


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mutant', action='store_true')
    parser.add_argument('--triples-only', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not (out / 'run.json').exists(), 'Use a fresh output directory'
    record = {'baseline_ref': BASELINE_REF, 'precision': 'Existing parity fields plus delayed timers, repeat cooldown, gore source validity and mirror state; floats/positions normalized1e-5. Not every runtime field.', 'variants': {}}
    suites = ['hit_traits'] if args.triples_only else ['basic', 'hit_traits', 'deaths']
    expected_cases = {'basic':300, 'hit_traits':90 if args.triples_only else 450, 'deaths':45}
    for variant in ['baseline', 'candidate'] + (['mutant'] if args.mutant else []):
        case_out = out / variant
        case_out.mkdir(exist_ok=True)
        name = 'BinduToolsHitReplay' + uuid.uuid4().hex
        userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
        with tempfile.TemporaryDirectory(prefix='bindu-hit-replay-') as tmp:
            project = Path(tmp)
            helper.copy_project(project, name)
            tower = project / 'scripts/tower.gd'
            tower.write_text(variant_tower(tower.read_text(), variant))
            harness = project / 'tools/preview_parity_check.gd'
            harness.write_text(instrument(harness.read_text(), args.triples_only))
            helper.checked([helper.GODOT, '--headless', '--import', '--path', tmp], case_out / 'import.log')
            variant_record = {'tower_sha256': hashlib.sha256(tower.read_bytes()).hexdigest(), 'suites': {}}
            try:
                for suite in (['hit_traits'] if variant == 'mutant' else suites):
                    trace = case_out / (suite + '-traces.json')
                    command = [helper.GODOT, '--headless', '--audio-driver', 'Dummy', '--path', tmp, '-s', 'tools/preview_parity_check.gd', '--', 'unused', '1.0', 'pc', suite]
                    helper.checked(command, case_out / (suite + '.log'), env={**os.environ, 'BINDU_HIT_TRACE': str(trace)})
                    data = json.loads(trace.read_text())
                    expected = expected_cases[suite]
                    assert len(data) == expected
                    variant_record['suites'][suite] = {'cases':len(data),'samples':sum(len(row['states']) for row in data),'trace_sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'command':command}
                    print(variant, suite, len(data), flush=True)
            finally:
                shutil.rmtree(userdata, ignore_errors=True)
                variant_record['isolated_save_removed'] = not userdata.exists()
        variant_record['temporary_project_removed'] = not project.exists()
        record['variants'][variant] = variant_record
    for suite in suites:
        before = json.loads((out / 'baseline' / (suite + '-traces.json')).read_text())
        after = json.loads((out / 'candidate' / (suite + '-traces.json')).read_text())
        assert before == after, suite + ': state/RNG differs'
    record['equal_suites'] = suites
    record['cases'] = sum(expected_cases[suite] for suite in suites)
    record['samples'] = record['cases'] * 12
    if args.mutant:
        baseline = json.loads((out / 'baseline/hit_traits-traces.json').read_text())
        mutant = json.loads((out / 'mutant/hit_traits-traces.json').read_text())
        differences = [a['pattern'] + '/' + a['label'] for a, b in zip(baseline, mutant) if a != b]
        assert differences, 'Mutant not detected'
        record['mutant_detected_cases'] = differences
    (out / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print('REPLAY',record['cases'],'cases',record['samples'],'samples equal; mutant cases',len(record.get('mutant_detected_cases',[])))


if __name__ == '__main__':
    main()
