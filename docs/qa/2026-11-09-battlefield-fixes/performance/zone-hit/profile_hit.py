#!/usr/bin/env python3
"""Localize current zone application costs. Product files stay unchanged."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,re,shutil,subprocess,tempfile,uuid

ROOT=Path(__file__).resolve().parents[5]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
helper=module('replay_helpers',Path(__file__).resolve().parent.parent/'guard-range/run_replay.py')
runner=module('export_helpers',Path(__file__).resolve().parent.parent/'export-runtime/run_export.py')


def wrap(source,name,arguments,result,key,static=False):
    match=re.search(r'^(?:static )?func '+re.escape(name)+r'\([^\n]*\) -> '+result+':',source,re.M);assert match,name
    signature=match[0];body_name='_qa_original_'+name
    source=source[:match.start()]+signature.replace('func '+name+'(','func '+body_name+'(',1)+source[match.end():]
    call=body_name+'('+arguments+')'
    if result=='void':
        body='\tif not Zone.qa_active:\n\t\t'+call+'\n\t\treturn\n\tvar start := Time.get_ticks_usec()\n\t'+call+'\n'
    else:
        body='\tif not Zone.qa_active:\n\t\treturn '+call+'\n\tvar start := Time.get_ticks_usec()\n\tvar value: '+result+' = '+call+'\n'
    body+='\tvar elapsed := Time.get_ticks_usec()-start\n\tZone.qa_record('+key+',elapsed)\n'
    if result!='void':body+='\treturn value\n'
    return source+'\n'+signature+'\n'+body


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    name='BinduToolsHitPhaseProfile'+uuid.uuid4().hex;userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'scope':'Current native x8/full,16towers/400in-arena moving orb goal, warm30/sample60, fixed1/60delta. Inclusive function CPU; nested timers include wrapper bookkeeping and must not be summed. Warmup/pause/captures excluded by qa_active. Not physical FPS/input latency or a before/after comparison.'}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-hit-phase-profile-')as directory:
            project=Path(directory);helper.copy_project(project,name)
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            record['original_source_hashes']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest()for p in (project/'scripts').rglob('*.gd')}
            zone=project/'scripts/zone.gd';source=zone.read_text()
            for method,arguments,result in [('affect','orbs, delta','void'),('_gore_affect','orbs','void'),('_hit','o, amount, k','void'),('_rapid','','float'),('_p','','float')]:
                source=wrap(source,method,arguments,result,'"Zone.'+method+'/"+kind')
            source+='\nstatic var qa_active := false\nstatic var qa_stats := {}\n\nstatic func qa_record(key: String, elapsed: int) -> void:\n\tif not qa_stats.has(key):qa_stats[key]={"calls":0,"us":0}\n\tqa_stats[key].calls+=1\n\tqa_stats[key].us+=elapsed\n'
            zone.write_text(source)
            for filename,methods in [('share.gd',[('gore_step','tw, o, amt, at, stage','void'),('carry','tw, o, f, key, at, stage, rep','void')]),('tower.gd',[('hit','o, dmg, k, extra, can_split, force_crit','void')])]:
                file=project/'scripts'/filename;source=file.read_text()
                for method,arguments,result in methods:
                    key='"'+filename+'.'+method+'"'
                    if filename=='tower.gd':key+='+("/zone" if in_zone else "/direct")'
                    source=wrap(source,method,arguments,result,key)
                if filename=='tower.gd':
                    begin=source.index('func _qa_original_hit(');end=source.index('\n\n\n# ----------',begin)
                    hit=source[begin:end]
                    before='\tvar els: Dictionary = eff if not eff.is_empty() else elements'
                    assert hit.count(before)==1
                    hit=hit.replace(before,'\tvar qa_hit_us := Time.get_ticks_usec() if Zone.qa_active else 0\n'+before)
                    for boundary,key in [
                        ('\t# 출처: 금속 고정 피해','damage'),
                        ('\tfor bk in [[fb, fire_key]', 'source-prelude'),
                        ('\tif lit:\n\t\trest *= 0.5','boost-attribution'),
                        ('\t_pincer(o)','source-finish'),
                        ('\tvar dm := Share.dur(self)','callbacks'),
                        ('\t# 특징 공유: 금속 응축','element-effects'),
                    ]:
                        assert hit.count(boundary)==1,boundary
                        marker_text='\tif Zone.qa_active:\n\t\tZone.qa_record("Hit.'+key+'",Time.get_ticks_usec()-qa_hit_us)\n\t\tqa_hit_us=Time.get_ticks_usec()\n'
                        hit=hit.replace(boundary,marker_text+boundary,1)
                    hit+='\n\tif Zone.qa_active:Zone.qa_record("Hit.trait-effects",Time.get_ticks_usec()-qa_hit_us)\n'
                    source=source[:begin]+hit+source[end:]
                file.write_text(source)
            harness=project/'tools/battlefield_load_check.gd';source=harness.read_text().replace('var orb_goal := 300','var orb_goal := 400')
            fixture=(ROOT/'tools/battlefield_feedback_check.gd').read_text();a=fixture.index('func fill_orbs()');b=fixture.index('\nfunc verify(',a)
            start=source.index('func fill_orbs()');stop=source.index('\nfunc measure_case(',start);source=source[:start]+fixture[a:b]+'\n'+source[stop:]
            source=source.replace('for speed in [1.0, 4.0, 8.0]:','for speed in [8.0]:').replace('for reduced in [false, true]:','for reduced in [false]:')
            source=source.replace('\tmain.combat_system.prof.clear()','\tmain.combat_system.prof.clear()\n\tZone.qa_stats.clear()\n\tZone.qa_active=true')
            source=source.replace('\t\t\tprobes.append(await pause_probe())','\t\t\tZone.qa_active=false\n\t\t\tprobes.append(await pause_probe())\n\t\t\tZone.qa_active=true')
            source=source.replace('\tvar label := "x%d-fx-%s"','\tZone.qa_active=false\n\tvar label := "x%d-fx-%s"')
            source=source.replace('\tvar data := {','\tFileAccess.open(output.path_join("application-times.json"),FileAccess.WRITE).store_string(JSON.stringify(Zone.qa_stats,"\\t"))\n\tvar data := {')
            harness.write_text(source)
            record['instrumented_source_hashes']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest()for p in (project/'scripts').rglob('*.gd')}
            runner.run([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            command=[helper.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution','1280x720','-s','tools/battlefield_load_check.gd','--',str(out),'1.0','pc','load','60'];record['command']=command
            text=runner.run(command,out/'native.log',env={**os.environ,'BINDU_PROFILE_CPU':'1'});assert 'conditions=1 failures=0 ui=0'in text
            rows=json.loads((out/'application-times.json').read_text());record['inclusive_totals']=dict(sorted(rows.items(),key=lambda pair:pair[1]['us'],reverse=True));record['exit']=0;record['runtime_errors']=0
    finally:
        shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
        if 'project'in locals():record['temporary_project_removed']=not project.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record['inclusive_totals'],indent=2))


if __name__=='__main__':main()
