#!/usr/bin/env python3
"""Validate native geometry/source lineage; keep physical usability outside this verdict."""
from pathlib import Path
import argparse,collections,json,hashlib,subprocess,re

def intersects(a,b):
    return a[0]<b[0]+b[2] and b[0]<a[0]+a[2] and a[1]<b[1]+b[3] and b[1]<a[1]+a[3]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--baseline',type=Path,required=True);parser.add_argument('--product',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    before=json.loads((args.baseline/'run.json').read_text());after=json.loads((args.product/'run.json').read_text());assert len(before['cases'])==122 and len(after['cases'])==302
    old=json.loads((args.baseline/'source-build.json').read_text());new=json.loads((args.product/'source-build.json').read_text());root=Path(__file__).resolve().parents[4]
    for name,sha in new['original_scripts'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==sha,name
    for name,sha in old['original_scripts'].items():assert hashlib.sha256(subprocess.check_output(['git','show','0f9fe31:'+name],cwd=root)).hexdigest()==sha,name
    changed=sorted(k for k in new['original_scripts'] if new['original_scripts'][k]!=old['original_scripts'][k]);assert changed==['scripts/card_dock.gd','scripts/features/abilities.gd','scripts/features/hud.gd','scripts/features/ui_layout.gd'],changed
    assert new['template_sha256']==old['template_sha256']
    baseline_violations=collections.Counter(v['type'] for case in before['cases'].values() for v in case['violations']);assert baseline_violations=={'inspector_control_overlap':12},baseline_violations
    comparisons={};final_cases={};old_hint_overlaps=[]
    for name,case in after['cases'].items():
        assert not case['violations'],(name,case['violations'])
        snapshot=args.product/name/'state.json';assert hashlib.sha256(snapshot.read_bytes()).hexdigest()==case['state_sha256']
        d=json.loads(snapshot.read_text());assert d['layout']['field']=='(1280.0, 720.0)'
        assert d['layout']['inspector']['visible']==('inspected' in name),name
        for button in d['layout']['buttons']:
            text=[float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',button['text_size'])]
            padding=[float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',button['style_minimum'])]
            assert text[0]+padding[0]<=button['local_rect'][2],(name,'width',button)
            assert text[1]+padding[1]<=button['local_rect'][3],(name,'height',button)
        assert all(r['type']==1 and r['code']=='BinduIOSQA logger probe' for r in d['runtime_log'])
        final_cases[name]={'buttons':[b['rect'] for b in d['layout']['buttons']],'inspector':d['layout']['inspector'],'hint':{'visible':d['layout']['hint_visible'],'rect':d['layout']['hint_rect']},'borders':[b['normal_border'] for b in d['layout']['buttons'][:2]],'field':d['layout']['field']}
        if name in before['cases']:
            prior=before['cases'][name];assert case['camera']==prior['camera'],name
            assert case['safe_ui_rect']==prior['safe_ui_rect'],name
            b=json.loads((args.baseline/name/'state.json').read_text());assert b['towers']==d['towers'] and b['picks']==d['picks']
            if b['layout']['hint_visible'] and any(intersects(b['layout']['hint_rect'],control['rect']) for control in b['layout']['buttons']):old_hint_overlaps.append(name)
            comparisons[name]={'same_camera':True,'same_safe_ui':True,'before_violations':prior['violations'],'after_violations':case['violations']}
    assert len(comparisons)==122
    assert len(old_hint_overlaps)==12,old_hint_overlaps
    assert after['native_control_checks']=={'phone':6,'tablet':6}
    result={'scope':after['scope'],'baseline_cases':122,'baseline_violations':dict(baseline_violations),'baseline_derived_hint_overlap_cases':old_hint_overlaps,'product_cases':302,'product_violations':0,'matched_camera_safe_ui_object_cases':122,'native_control_checks':12,'runtime_errors':0,'unexpected_warnings':0,'known_warning':'Positive BinduIOSQA logger probe per process retained','changed_product_scripts':changed,'source_lineage':{'before_build_sha256':hashlib.sha256((args.baseline/'source-build.json').read_bytes()).hexdigest(),'product_build_sha256':hashlib.sha256((args.product/'source-build.json').read_bytes()).hexdigest(),'product_source_matches_checkout':True},'comparisons':comparisons,'product_geometry':final_cases}
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('302 native scenes: no geometry/style violation;122 matched camera/state cases;12 actual-touch checks')

if __name__=='__main__':main()
