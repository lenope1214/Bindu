#!/usr/bin/env python3
"""Paired original/candidate drawing in one immutable native combat snapshot."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess,tempfile,uuid
from run_profile import ROOT,helper,runner
BASELINE='fcfb68bfc25e7ce6e29f2ef03cc4bdda371dfa93'


def candidate(source):
    marker='func _draw_fx(preview := false) -> void:\n\tvar session: BinduSession = self.session\n'
    assert source.count(marker)==1;source=source.replace(marker,marker+'\tvar low_fx := Meta.fx_low\n',1)
    for fragment in ['q[1] * (0.2 + 0.5 * k)','Color(q[2], 0.35 * bk), 9.0','Color(ec, 0.35 * al), 9.0','Color(1, 1, 1, al), 1.2']:
        lines=source.splitlines(keepends=True);matches=[i for i,line in enumerate(lines)if fragment in line];assert len(matches)==1,fragment
        i=matches[0];line=lines[i];indent=line[:len(line)-len(line.lstrip())];lines[i]=indent+'if not low_fx:\n\t'+line;source=''.join(lines)
    old='\t\tfor q in src.slice(1):\n\t\t\tsession.fx_layer.draw_circle(q, 6.0, Color(ec, 0.5 * al))'
    assert source.count(old)==1;source=source.replace(old,'\t\tif not low_fx:\n\t'+old.replace('\n','\n\t'))
    old='\tfor p in session.particles:\n\t\tsession.fx_layer.draw_circle(p[0], p[4] * clampf(p[2] / 0.4, 0.2, 1.0), Color(p[3], p[3].a * fx_k))'
    assert source.count(old)==1
    draw=old.splitlines()[1].lstrip()
    source=source.replace(old,'\tif low_fx:\n\t\t# 큰 장식 입자만 그린다. 원본과 난수는 보존한다.\n\t\tfor p in session.particles:\n\t\t\tif p[4] >= 3.5:\n\t\t\t\t'+draw+'\n\telse:\n\t\tfor p in session.particles:\n\t\t\t'+draw,1)
    return source


def span(source,name):
    start=source.index('func '+name+'(');match=re.search(r'^func ',source[start+5:],re.M);assert match
    return start,start+5+match.start()


def trace_draws(source):
    pattern=re.compile(r'^(\s*)session\.fx_layer\.(draw_[a-z_]+)\(',re.M)
    inserts=[];decorative=set()
    for match in pattern.finditer(source):
        start=match.end();depth=1;quote=None;escaped=False;end=start
        while depth:
            char=source[end]
            if quote:
                if escaped:escaped=False
                elif char=='\\':escaped=True
                elif char==quote:quote=None
            elif char in ['"',"'"]:quote=char
            elif char=='(':depth+=1
            elif char==')':depth-=1
            end+=1
        arguments=source[start:end-1];assert 'randf'not in arguments and 'randi'not in arguments
        key=match[2]+'/'+hashlib.sha256(re.sub(r'\s+','',arguments).encode()).hexdigest()[:16]
        compact=re.sub(r'\s+','',arguments)
        if any(fragment in compact for fragment in ['q[1]*(0.2+0.5*k)','Color(q[2],0.35*bk),9.0','Color(ec,0.35*al),9.0','Color(1,1,1,al),1.2','q,6.0,Color(ec,0.5*al)','p[4]*clampf(p[2]/0.4']):decorative.add(key)
        inserts.append((match.start(),match[1]+'qa_fx_commands.append(["'+key+'",['+arguments+']])\n'))
    for index,text in reversed(inserts):source=source[:index]+text+source[index:]
    assert len(decorative)==6,decorative
    return source+'\nvar qa_decorative_keys := '+json.dumps(sorted(decorative))+'\n'


def paired_source(original,after,trace):
    result=after
    for name in ['_draw_fx']:
        a,b=span(original,name);old=original[a:b].replace('func '+name+'(','func _qa_before'+name+'(',1)
        a,b=span(result,name);new=result[a:b].replace('func '+name+'(','func _qa_after'+name+'(',1)
        signature=re.match(r'func [^\n]+:',result[a:b])[0];arguments='preview'if name=='_draw_fx'else''
        wrapper=signature+'\n'
        if name=='_draw_fx':wrapper+='\tvar qa_started := Time.get_ticks_usec()\n\tqa_fx_count+=1\n'
        wrapper+='\tif qa_before:\n\t\t_qa_before'+name+'('+arguments+')\n\telse:\n\t\t_qa_after'+name+'('+arguments+')\n'
        if name=='_draw_fx':wrapper+='\tqa_fx_us=Time.get_ticks_usec()-qa_started\n'
        result=result[:a]+wrapper+'\n'+result[b:]+'\n'+old+'\n'+new+'\n'
    if trace:result=trace_draws(result)
    return result+'\nvar qa_before := false\nvar qa_fx_count := 0\nvar qa_fx_us := 0\nvar qa_fx_commands := []\n'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--mode',choices=['contract','benchmark'],default='contract');parser.add_argument('--profiles',nargs='+',choices=['pc100','phone130'],default=['pc100','phone130']);parser.add_argument('--product',action='store_true');args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    name='BinduToolsFXCompare'+uuid.uuid4().hex;userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'mode':args.mode,'baseline_ref':BASELINE,'product':args.product,'scope':'One frozen16tower/400orb native scene. Actual callback confirmed. Contract traces native FieldView FX commands; benchmark has only one timer/counter per FX callback. No physical FPS/input claim.','profiles':{}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-fx-compare-')as directory:
            project=Path(directory);helper.copy_project(project,name);(project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            field=project/'scripts/features/field_view.gd';original=subprocess.check_output(['git','show',BASELINE+':scripts/features/field_view.gd'],cwd=ROOT,text=True);after=field.read_text()if args.product else candidate(original)
            a,b=span(original,'_draw_fx');c,d=span(after,'_draw_fx');assert original[:a]+original[b:]==after[:c]+after[d:],'Outside FX callback changed; establish a new reviewed baseline.'
            record['original_field_sha256']=hashlib.sha256(original.encode()).hexdigest();record['candidate_field_sha256']=hashlib.sha256(after.encode()).hexdigest();(out/'candidate-field.txt').write_text(after)
            source=paired_source(original,after,args.mode=='contract');field.write_text(source);record['paired_source_sha256']=hashlib.sha256(source.encode()).hexdigest()
            runner.run([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            for profile in args.profiles:
                folder=out/profile;folder.mkdir();phone=profile.startswith('phone')
                command=[helper.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution','852x393'if phone else'1280x720','-s','tools/battlefield_fx_compare_check.gd','--',str(folder),'1.3'if phone else'1.0','phone'if phone else'pc','after',args.mode];record['profiles'][profile]={'command':command}
                text=runner.run(command,folder/'native.log');assert 'failures=0 ui=0'in text
                record['profiles'][profile].update(json.loads((folder/'fx-compare.json').read_text()))
                shutil.rmtree(userdata,ignore_errors=True);print('FX COMPARE',args.mode,profile,'exit0',flush=True)
    finally:
        shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
        if 'project'in locals():record['temporary_project_removed']=not project.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__':main()
