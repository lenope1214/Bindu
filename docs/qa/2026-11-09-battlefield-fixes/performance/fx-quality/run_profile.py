#!/usr/bin/env python3
"""Count actual native drawing primitives in a frozen400-orb scene."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re,shutil,tempfile,uuid

ROOT=Path(__file__).resolve().parents[5]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
helper=module('replay_helpers',Path(__file__).resolve().parent.parent/'guard-range/run_replay.py')
runner=module('export_helpers',Path(__file__).resolve().parent.parent/'export-runtime/run_export.py')


def instrument(project):
    original={};changes={}
    for path,methods in [('scripts/orb.gd',['_draw']),('scripts/projectile.gd',['_draw']),('scripts/zone.gd',['_draw']),('scripts/tower.gd',['_draw']),('scripts/features/field_view.gd',['_draw','_draw_fx'])]:
        file=project/path;source=file.read_text();original[path]=hashlib.sha256(source.encode()).hexdigest();label=file.stem
        lines=[];count=0
        for line in source.splitlines(keepends=True):
            if re.match(r'^\s*(?:(?:session(?:\.fx_layer)?)\.)?draw_(?!set_)[a-z_]+\(',line):
                indent=line[:len(line)-len(line.lstrip())];lines.append(indent+'Zone.qa_primitive("'+label+'")\n');count+=1
            lines.append(line)
        source=''.join(lines)
        for method in methods:
            match=re.search(r'^func '+method+r'\([^\n]*\) -> void:',source,re.M);assert match,method
            signature=match[0];replacement=signature.replace('func '+method+'(','func _qa_original'+method+'(',1)
            source=source[:match.start()]+replacement+source[match.end():]
            source+='\n'+signature+'\n\tvar started := Time.get_ticks_usec()\n\t_qa_original'+method+'('+('preview'if method=='_draw_fx'else'')+')\n\tZone.qa_draw("'+label+'/'+method+'",Time.get_ticks_usec()-started)\n'
        file.write_text(source);changes[path]={'primitive_call_sites':count,'instrumented_sha256':hashlib.sha256(source.encode()).hexdigest()}
    zone=project/'scripts/zone.gd'
    zone.write_text(zone.read_text()+'''
static var qa_primitives := {}
static var qa_draws := {}

static func qa_primitive(label: String) -> void:
	qa_primitives[label]=qa_primitives.get(label,0)+1

static func qa_draw(label: String, elapsed: int) -> void:
	if not qa_draws.has(label):qa_draws[label]={"calls":0,"us":0}
	qa_draws[label].calls+=1
	qa_draws[label].us+=elapsed
''')
    return original,changes


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--profiles',nargs='+',choices=['pc100','phone130'],default=['pc100','phone130']);args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    name='BinduToolsFXProfile'+uuid.uuid4().hex;userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'scope':'Frozen native16tower/400orb scene, full vs reduced effects. Actual draw callback/primitive counters add overhead; inclusive script timings are localization only. Not before/after uninstrumented FPS.','profiles':{}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-fx-profile-')as directory:
            project=Path(directory);helper.copy_project(project,name)
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            record['original_source_hashes'],record['instrumentation']=instrument(project)
            runner.run([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            for profile in args.profiles:
                folder=out/profile;folder.mkdir();phone=profile.startswith('phone')
                command=[helper.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution','852x393'if phone else'1280x720','-s','tools/battlefield_fx_quality_check.gd','--',str(folder),'1.3'if phone else'1.0','phone'if phone else'pc','after']
                text=runner.run(command,folder/'native.log');assert 'failures=0 ui=0'in text
                data=json.loads((folder/'feedback.json').read_text());record['profiles'][profile]={'command':command,'checks':data['checks'],'failures':data['failures'],'ui_errors':data['ui_errors']}
                shutil.rmtree(userdata,ignore_errors=True);print('FX PROFILE',profile,'exit0',flush=True)
    finally:
        shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
        if 'project'in locals():record['temporary_project_removed']=not project.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__':main()
