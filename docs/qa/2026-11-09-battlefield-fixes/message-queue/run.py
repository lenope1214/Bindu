#!/usr/bin/env python3
"""Measure nominal fuzz outcomes with shared vs per-worker QA save identity."""
from pathlib import Path
import argparse,concurrent.futures,hashlib,importlib.util,json,os,re,shutil,subprocess,tempfile,time,uuid
ROOT=Path(__file__).resolve().parents[4]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('mq_copy',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    record={'scope':'Nominal seeds1..4/3000; same product, original fuzz/VirtualInput code. Minimal QA copy and URLs blank. Shared vs per-worker userdata; randomize/wall-clock behavior unchanged, not original exact replay.','cohorts':[]}
    record['product_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'scripts').rglob('*.gd')}
    def run_worker(project,case,seed):
        case.mkdir();log=case/'raw.log'
        command=[h.GODOT,'--headless','--fixed-fps','60','--path',str(project),'-s','tools/fuzz.gd','--',str(seed),'3000']
        start=time.monotonic();stop_reason=None;seen=0;queue_failure=False
        with log.open('w') as stream:
            proc=subprocess.Popen(command,stdout=stream,stderr=subprocess.STDOUT)
            try:
                while proc.poll() is None:
                    with log.open('rb') as reader:
                        reader.seek(seen);chunk=reader.read(262144);seen+=len(chunk)
                    if b'Message queue out of memory' in chunk:
                        queue_failure=True;stop_reason='observed_queue_failure_stop_before_statistics_flood';proc.terminate();break
                    if time.monotonic()-start>180:
                        stop_reason='deadline180s';proc.terminate();break
                    time.sleep(.05)
                try:code=proc.wait(timeout=5)
                except subprocess.TimeoutExpired:proc.kill();code=proc.wait()
            finally:
                if proc.poll() is None:proc.kill();proc.wait()
        raw=log.read_text(errors='replace');done='FUZZ DONE frames=3000' in raw;errors=re.findall(r'^(?:SCRIPT ERROR|ERROR:|.*Message queue out of memory).*$',raw,re.M)
        result={'seed':seed,'pid':proc.pid,'command':command,'exit':code,'stop_reason':stop_reason,'queue_failure':queue_failure or 'Message queue out of memory' in raw,'frames_done':done,'runtime_errors':errors[:6],'raw_bytes':log.stat().st_size,'raw_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'elapsed_seconds':time.monotonic()-start,'source_fuzz_sha256':hashlib.sha256((project/'tools/fuzz.gd').read_bytes()).hexdigest(),'virtual_input_sha256':hashlib.sha256((project/'tools/virtual_input.gd').read_bytes()).hexdigest(),'config':re.findall(r'^FUZZR.*$',raw,re.M),'owned_process_terminal':proc.poll() is not None}
        result['success']=code==0 and done and not errors and not result['queue_failure'];(case/'result.json').write_text(json.dumps(result,indent=2)+'\n');print('FUZZ',case.parent.name,seed,'exit',code,'done',done,'queue',result['queue_failure'],flush=True);return result
    try:
        for isolation in ['shared','per-worker']:
            cohort=out/isolation;cohort.mkdir();names=[];projects=[];row={'isolation':isolation,'runs':[]};record['cohorts'].append(row)
            with tempfile.TemporaryDirectory(prefix='bindu-message-queue-') as directory:
                temp=Path(directory)
                for i in range(1 if isolation=='shared' else 4):
                    project=temp/str(i);project.mkdir();name='BinduToolsMessageQueue'+uuid.uuid4().hex;names.append(name);h.copy_project(project,name);projects.append(project)
                    h.checked([h.GODOT,'--headless','--import','--path',str(project)],cohort/('import-'+str(i)+'.log'))
                try:
                    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
                        tasks=[pool.submit(run_worker,projects[0 if isolation=='shared' else seed-1],cohort/str(seed),seed) for seed in range(1,5)]
                        row['runs']=[task.result() for task in tasks]
                finally:
                    for name in names:shutil.rmtree(Path.home()/'Library/Application Support/Godot/app_userdata'/name,ignore_errors=True)
            row['temporary_projects_removed']=not temp.exists();row['isolated_saves_removed']=all(not (Path.home()/'Library/Application Support/Godot/app_userdata'/n).exists() for n in names)
        record['counts']={r['isolation']:{'runs':len(r['runs']),'queue_failures':sum(x['queue_failure'] for x in r['runs']),'other_failures':sum(not x['success'] and not x['queue_failure'] for x in r['runs'])} for r in record['cohorts']}
    finally:(out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record.get('counts',{}),indent=2))
if __name__=='__main__':main()
