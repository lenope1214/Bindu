#!/usr/bin/env python3
"""Bounded LLDB-DAP launch of an owned isolated Godot fuzz process."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,queue,shutil,subprocess,tempfile,threading,time,uuid
ROOT=Path(__file__).resolve().parents[4]
ADAPTER='/Applications/Xcode.app/Contents/Developer/usr/bin/lldb-dap'

class DAP:
    def __init__(self,log):
        self.log=log;self.q=queue.Queue(maxsize=128);self.seq=0;self.messages=[];self.log_bytes=0;self.log_limited=False;self.events={};self.queue_failure=False
        self.p=subprocess.Popen([ADAPTER],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=(log.parent/'adapter-stderr.log').open('wb'))
        threading.Thread(target=self.reader,daemon=True).start()
    def reader(self):
        while True:
            header={}
            while True:
                line=self.p.stdout.readline()
                if not line:return
                if line in [b'\r\n',b'\n']:break
                k,v=line.decode().split(':',1);header[k.lower()]=v.strip()
            raw=self.p.stdout.read(int(header['content-length']))
            message=json.loads(raw);self.q.put(message)
    def send(self,command,arguments):
        self.seq+=1;message={'seq':self.seq,'type':'request','command':command,'arguments':arguments};raw=json.dumps(message).encode();self.p.stdin.write(('Content-Length: %d\r\n\r\n'%len(raw)).encode()+raw);self.p.stdin.flush();return self.seq
    def next(self,timeout=10):
        message=self.q.get(timeout=timeout)
        if len(self.messages)<1000:self.messages.append(message)
        if message.get('type')=='event':self.events[message.get('event')]=message.get('body',{})
        if message.get('event')=='output' and 'Message queue out of memory' in message.get('body',{}).get('output',''):self.queue_failure=True
        raw=json.dumps(message)+'\n'
        if self.log_bytes+len(raw.encode())<=1048576:
            with self.log.open('a') as f:f.write(raw)
            self.log_bytes+=len(raw.encode())
        elif not self.log_limited:
            with self.log.open('a') as f:f.write('{"diagnostic":"DAP output retention limit 1MiB"}\n')
            self.log_limited=True
        return message
    def response(self,seq):
        while True:
            message=self.next()
            if message.get('type')=='response' and message.get('request_seq')==seq:return message

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('dap_copy',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    name='BinduToolsMessageQueueDAP'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'adapter':ADAPTER,'scope':'Owned headless single nominal seed2,3000. No original exact replay. Stripped stock binary; signal/stack/register evidence only if observed. Native fault capture path not validated when launch is denied.','stops':[]};dap=None;temp=None;project=None
    try:
        temp=tempfile.TemporaryDirectory(prefix='bindu-message-dap-')
        directory=temp.name
        project=Path(directory);h.copy_project(project,name);h.checked([h.GODOT,'--headless','--import','--path',directory],out/'import.log')
        record['source_sha256']={str(x.relative_to(project)):hashlib.sha256(x.read_bytes()).hexdigest() for x in (project/'scripts').rglob('*.gd')}
        dap=DAP(out/'dap.jsonl')
        init=dap.response(dap.send('initialize',{'clientID':'bindu-i15','adapterID':'lldb','pathFormat':'path','linesStartAt1':True,'columnsStartAt1':True,'supportsRunInTerminalRequest':False}));record['initialize']=init
        launch=dap.send('launch',{'program':h.GODOT,'cwd':directory,'args':['--headless','--fixed-fps','60','--path',directory,'-s','tools/fuzz.gd','--','2','3000'],'stopOnEntry':False,'disableASLR':False})
        while True:
            message=dap.next()
            if message.get('type')=='event' and message.get('event')=='initialized':break
            if message.get('request_seq')==launch and not message.get('success'):
                record['launch_failure']=message;raise RuntimeError('DAP launch blocked; no protection bypass')
        bp=dap.response(dap.send('setFunctionBreakpoints',{'breakpoints':[{'name':'Control::_update_minimum_size'},{'name':'CallQueue::push_callablep','condition':'this->pages_used >= this->max_pages'}]}));record['function_breakpoints']=bp
        dap.response(dap.send('configurationDone',{}))
        deadline=time.monotonic()+120;stdout=[];stdout_bytes=0;pause_requested=False
        while time.monotonic()<deadline:
            try:message=dap.next(timeout=2)
            except queue.Empty:
                if dap.p.poll() is not None:break
                continue
            if message.get('event')=='output':
                output=message.get('body',{}).get('output','');keep=output[:max(0,1048576-stdout_bytes)];stdout.append(keep);stdout_bytes+=len(keep)
            if dap.queue_failure and not pause_requested:
                record['queue_failure_observed']=True;pause_requested=True;dap.send('pause',{'threadId':0})
            if message.get('event')=='process':record['debuggee_pid']=message.get('body',{}).get('systemProcessId')
            if message.get('event')=='stopped':
                body=message.get('body',{});thread_id=body.get('threadId');stop={'event':body,'threads':dap.response(dap.send('threads',{}))}
                if thread_id:
                    stack=dap.response(dap.send('stackTrace',{'threadId':thread_id,'startFrame':0,'levels':20}));stop['stack']=stack
                    frames=stack.get('body',{}).get('stackFrames',[])
                    if frames:
                        scopes=dap.response(dap.send('scopes',{'frameId':frames[0]['id']}));stop['scopes']=scopes
                        for scope in scopes.get('body',{}).get('scopes',[]):
                            if scope.get('presentationHint')=='registers':stop['registers']=dap.response(dap.send('variables',{'variablesReference':scope['variablesReference']}))
                record['stops'].append(stop)
                if body.get('reason') in ['exception','signal']:record['fault_stop_observed']=True;break
                if pause_requested:record['queue_failure_pause_observed']=True;break
                dap.response(dap.send('setFunctionBreakpoints',{'breakpoints':[]}));dap.response(dap.send('continue',{'threadId':thread_id}))
            if message.get('event')=='exited':record['debuggee_exit']=message.get('body',{}).get('exitCode')
            if message.get('event')=='terminated':record['terminated_event']=True;break
        record['stdout']=''.join(stdout);record['done3000']='FUZZ DONE frames=3000' in record['stdout'];record['queue_failure']='Message queue out of memory' in record['stdout']
    except BaseException as error:record['error']=repr(error)
    finally:
        if dap:
            if dap.p.poll() is None:
                try:dap.send('disconnect',{'terminateDebuggee':True});dap.p.wait(timeout=5)
                except BaseException:
                    dap.p.terminate()
                    try:dap.p.wait(timeout=5)
                    except subprocess.TimeoutExpired:dap.p.kill();dap.p.wait()
            record['adapter_terminal']=dap.p.poll() is not None
            record['debuggee_pid']=dap.events.get('process',{}).get('systemProcessId',record.get('debuggee_pid'))
            record['debuggee_exit']=dap.events.get('exited',{}).get('exitCode',record.get('debuggee_exit'))
            record['queue_failure_observed']=dap.queue_failure
            record['dap_log_limited']=dap.log_limited
        def owned_pids():
            if project is None:return []
            rows=subprocess.check_output(['ps','-axo','pid,command'],text=True).splitlines()
            return [int(row.strip().split(None,1)[0]) for row in rows if h.GODOT in row and str(project) in row]
        for pid in owned_pids():subprocess.run(['kill','-TERM',str(pid)],check=False)
        deadline=time.monotonic()+5
        while owned_pids() and time.monotonic()<deadline:time.sleep(.05)
        for pid in owned_pids():subprocess.run(['kill','-KILL',str(pid)],check=False)
        deadline=time.monotonic()+5
        while owned_pids() and time.monotonic()<deadline:time.sleep(.05)
        record['owned_debuggee_processes_remaining']=owned_pids()
        record['debuggee_terminal']=not record['owned_debuggee_processes_remaining']
        if temp:temp.cleanup()
        shutil.rmtree(data,ignore_errors=True);record['temporary_project_removed']=project is None or not project.exists();record['isolated_save_removed']=not data.exists();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({k:v for k,v in record.items() if k in ['error','launch_failure','done3000','queue_failure','debuggee_exit','adapter_terminal','debuggee_terminal','terminated_event']},indent=2))
if __name__=='__main__':main()
