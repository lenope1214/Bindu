#!/usr/bin/env python3
"""Existing information/flow regressions against an isolated current product snapshot."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re,shutil,tempfile,uuid

ROOT=Path(__file__).resolve().parents[4]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    source=ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py';spec=importlib.util.spec_from_file_location('copy_helper',source);helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    record={'scope':'Native macOS virtual GUI input. Phone is simulated, physical devices and actual iOS checks separate.','runs':{}}
    with tempfile.TemporaryDirectory(prefix='bindu-skill-layout-regression-') as directory:
        project=Path(directory);name='BinduToolsSkillLayout'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name;helper.copy_project(project,name);(project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
        record['source_sha256']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
        try:
            helper.checked([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            for profile,kind in [('pc130','pc'),('phone130','phone')]:
                for tool in ['battlefield_information_check','battlefield_core_check']:
                    case=out/(profile+'-'+tool);case.mkdir();text=helper.checked([helper.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution','852x393' if kind=='phone' else '1280x720','-s','tools/'+tool+'.gd','--',str(case),'1.3',kind],case/'run.log');summary=re.findall(r'^(?:BATTLEFIELD CORE|INFORMATION) failures=0 ui=\d+$',text,re.M);assert summary
                    record['runs'][case.name]={'passed':True,'summary':summary,'warnings':re.findall(r'^WARNING:[^\n]+',text,re.M)};print(case.name,summary,flush=True)
        finally:shutil.rmtree(data,ignore_errors=True)
    record['project_removed']=not project.exists();record['isolated_save_removed']=not data.exists();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n')

if __name__=='__main__':main()
