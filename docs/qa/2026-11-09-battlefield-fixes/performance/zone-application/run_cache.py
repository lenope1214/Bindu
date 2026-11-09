#!/usr/bin/env python3
"""Frozen affinity-cache candidate. Never patches the user's product checkout."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,subprocess,tempfile,uuid

ROOT=Path(__file__).resolve().parents[5]
BASELINE='9426f14aada006ca4f600a19680390579423cb4b'
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
helper=module('replay_helpers',Path(__file__).resolve().parent.parent/'guard-range/run_replay.py')
runner=module('export_helpers',Path(__file__).resolve().parent.parent/'export-runtime/run_export.py')


def frozen(path):return subprocess.check_output(['git','show',BASELINE+':'+path],cwd=ROOT,text=True)


def candidate_share(source,mutant=False,kind='last-input'):
    start=source.index('static func aff(');stop=source.index('\n\n## ',start)
    body=source[start:stop]
    if kind=='last-input':
        snapshot='els'if mutant else'els.duplicate()'
        body=body.replace('\tvar ck := 0','\tif _aff_last_elements == els:\n\t\tvar cached = _aff.get(_aff_last_mask)\n\t\tif cached != null:\n\t\t\treturn cached\n\tvar ck := 0',1)
        body=body.replace('\tif _aff.has(ck):','\t_aff_last_elements = '+snapshot+'\n\t_aff_last_mask = ck\n\tif _aff.has(ck):',1)
        fields='static var _aff_last_elements := {}  # 상성 키 조회의 마지막 값 사본: 직접 수정도 감지\nstatic var _aff_last_mask := 0\n\n'
        return source[:start]+fields+body+source[stop:]
    body=body.replace('\tvar ck := 0','\tvar cached_tower := tw as Tower\n\tif cached_tower != null and not cached_tower._share_affinity.is_empty() and cached_tower._share_affinity_elements == els:\n\t\treturn cached_tower._share_affinity\n\tvar ck := 0',1)
    snapshot='els' if mutant else 'els.duplicate()'
    body=body.replace('\t\treturn _aff[ck]','\t\tif cached_tower != null:\n\t\t\tcached_tower._share_affinity_elements = '+snapshot+'\n\t\t\tcached_tower._share_affinity = _aff[ck]\n\t\treturn _aff[ck]',1)
    body=body.replace('\treturn out','\tif cached_tower != null:\n\t\tcached_tower._share_affinity_elements = '+snapshot+'\n\t\tcached_tower._share_affinity = out\n\treturn out',1)
    return source[:start]+body+source[stop:]


def candidate_tower(source):
    marker='var eff := {}  # 지금 쓰는 속성 (매 프레임 갱신)\n';assert source.count(marker)==1
    return source.replace(marker,marker+'var _share_affinity_elements := {}  # 마지막 상성 조회의 속성 값 사본: 직접 수정도 감지\nvar _share_affinity := {}  # 읽기 전용 파생값. Tower 수명 안에서만 보관\n')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--mutant-alias',action='store_true');parser.add_argument('--cache-kind',choices=['last-input','tower-typed'],default='last-input');parser.add_argument('--product',action='store_true');args=parser.parse_args()
    assert not (args.product and args.mutant_alias)
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    name='BinduToolsAffinityCache'+uuid.uuid4().hex;userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'baseline':BASELINE,'scope':'Headless exact affinity result/alias/input/RNG contract and isolated microbenchmark. Not whole-frame or physical FPS.','mutant_alias':args.mutant_alias,'cache_kind':'product'if args.product else args.cache_kind}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-affinity-cache-')as directory:
            project=Path(directory);helper.copy_project(project,name)
            old=frozen('scripts/share.gd');start=old.index('static func aff(');stop=old.index('\n\n## ',start)
            reference=old[start:stop].replace('static func aff(','static func qa_reference_aff(',1)
            source=(ROOT/'scripts/share.gd').read_text()if args.product else candidate_share(old,args.mutant_alias,args.cache_kind);(out/'candidate-share.txt').write_text(source)
            record['candidate_share_sha256']=hashlib.sha256(source.encode()).hexdigest()
            (project/'scripts/share.gd').write_text(source+'\n'+reference+'\n')
            source=(ROOT/'scripts/tower.gd').read_text()if args.product else frozen('scripts/tower.gd')
            if not args.product and args.cache_kind=='tower-typed':source=candidate_tower(source)
            record['candidate_tower_sha256']=hashlib.sha256(source.encode()).hexdigest();(project/'scripts/tower.gd').write_text(source)
            record['qa_tool_sha256']=hashlib.sha256((project/'tools/battlefield_affinity_cache_check.gd').read_bytes()).hexdigest()
            runner.run([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            command=[helper.GODOT,'--headless','--audio-driver','Dummy','--path',directory,'-s','tools/battlefield_affinity_cache_check.gd','--',str(out),'mutant'if args.mutant_alias else 'normal'];record['command']=command
            text=runner.run(command,out/'check.log');data=json.loads((out/'results.json').read_text());assert data['failures']==0
            record['result']=data;record['exit']=0
    finally:
        shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
        if 'project'in locals():record['temporary_project_removed']=not project.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({'checks':data['checks'],'mutant_detections':data['mutant_detections'],'timings':data['timings']},indent=2))


if __name__=='__main__':main()
