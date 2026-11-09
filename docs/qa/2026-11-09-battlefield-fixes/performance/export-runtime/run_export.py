#!/usr/bin/env python3
"""Build an isolated macOS QA app and compare editor/release + queued input.

Product scripts are copied unchanged except empty operational URLs. The QA
MainLoop lives outside the production tools export exclusion. No path override,
store upload, version bump or original project import is required.
"""
from pathlib import Path
import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[5]
GODOT = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
MARKER = 'BinduQA controlled trace probe'

EXTRA_GD = '''
var qa_queue_rows := []
var qa_delivery := {}

func qa_queue_probes() -> void:
	for speed in [1.0,8.0]:
		await load_fixture()
		main.game_speed = speed
		Meta.fx_low = false
		for i in 30:
			await process_frame
			main.frame_system._process(1.0/60.0)
			fill_orbs()
			RenderingServer.force_draw()
		for trial in 3:
			await process_frame
			qa_delivery = {}
			var worker := Thread.new()
			var start := Time.get_ticks_usec()
			worker.start(qa_post.bind(trial))
			main.frame_system._process(1.0/60.0)
			var compute_end := Time.get_ticks_usec()
			fill_orbs()
			RenderingServer.force_draw()
			var draw_end := Time.get_ticks_usec()
			var deadline := Time.get_ticks_usec()+2000000
			while qa_delivery.is_empty() and Time.get_ticks_usec()<deadline:
				await create_timer(0.001).timeout
			worker.wait_to_finish()
			ok("BF-49",not qa_delivery.is_empty(),"queued synthetic pause request delivered")
			if qa_delivery.is_empty(): continue
			var row: Dictionary = qa_delivery.duplicate()
			row.merge({"speed":speed,"trial":trial,"main_frame_cpu_ms":(compute_end-start)/1000.0,"draw_return_ms":(draw_end-start)/1000.0,"posted_during_compute":row.posted_us>=start and row.posted_us<compute_end,"posted_before_draw_return":row.posted_us<draw_end})
			qa_queue_rows.append(row)
			ok("BF-49",row.paused_state_seen and row.pause_ui_seen,"queued pause reached state and menu")
			var resume := InputEventKey.new()
			resume.keycode = KEY_P
			resume.pressed = true
			VirtualInput.send(resume)
			resume.pressed = false
			VirtualInput.send(resume)
			ok("BF-49",not paused,"queued probe resumed")
			await process_frame

func qa_post(id: int) -> void:
	OS.delay_msec(5)
	call_deferred("qa_deliver",id,Time.get_ticks_usec())

func qa_deliver(id: int, posted_us: int) -> void:
	var received := Time.get_ticks_usec()
	var press := InputEventKey.new()
	press.keycode = KEY_P
	press.pressed = true
	VirtualInput.send(press)
	var done := Time.get_ticks_usec()
	qa_delivery = {"id":id,"posted_us":posted_us,"received_us":received,"queue_to_dispatch_ms":(received-posted_us)/1000.0,"dispatch_to_state_ms":(done-received)/1000.0,"paused_state_seen":paused,"pause_ui_seen":main.pause_box.is_visible_in_tree()}
	press.pressed = false
	VirtualInput.send(press)

func qa_diagnostic(output_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	ErrLog.install()
	qa_error_root()
	var rows := ErrLog.take()
	var selected := rows.filter(func(row):return "BinduQA controlled trace probe" in str(row.get("msg","")))
	var bt := str(selected[0].get("bt","")) if selected.size()==1 else ""
	var result := {"events":selected,"expected_events":selected.size()==1,"root_in_backtrace":"qa_error_root" in bt,"mid_in_backtrace":"qa_error_mid" in bt,"leaf_in_backtrace":"qa_error_leaf" in bt,"debug_build":OS.is_debug_build(),"template":OS.has_feature("template"),"tracking_setting":ProjectSettings.get_setting("debug/settings/gdscript/always_track_call_stacks")}
	FileAccess.open(output_dir.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\\t"))
	print("QA DIAGNOSTIC ",JSON.stringify(result))
	quit(0 if selected.size()==1 else 1)

func qa_error_root() -> void:
	qa_error_mid()

func qa_error_mid() -> void:
	qa_error_leaf()

func qa_error_leaf() -> void:
	push_error("BinduQA controlled trace probe")
'''


def run(command, log, diagnostic=False, **kwargs):
    with log.open('w') as stream:
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT, **kwargs)
        deadline = time.monotonic()+600
        while process.poll() is None:
            text = log.read_text()
            fatal = "Error: Can't run project:" in text or 'SCRIPT ERROR' in text or 'Parse Error' in text
            if fatal or time.monotonic()>deadline:
                process.terminate()
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:process.kill();process.wait()
                raise AssertionError(('fatal startup/runtime error' if fatal else 'timeout',command,text[-1000:]))
            time.sleep(0.25)
        returncode = process.returncode
    text = log.read_text()
    errors = re.findall(r'^(?:SCRIPT ERROR|ERROR:).*$', text, re.M)
    assert returncode == 0, (command, returncode, text[-2000:])
    if diagnostic:
        assert len(errors) == 1 and MARKER in errors[0], errors
    else:
        assert not errors, errors
    assert not re.search(r'Parse Error|Compile Error', text), text[-2000:]
    return text


def prepare(project, name, stack):
    for folder in ['scripts','icons']:
        shutil.copytree(ROOT/folder,project/folder)
    for file in ['project.godot','main.tscn','icon.svg','export_presets.cfg']:
        shutil.copy2(ROOT/file,project/file)
    qa = project/'qa'
    qa.mkdir()
    (qa/'empty.tscn').write_text('[gd_scene format=3]\n\n[node name="QAEmpty" type="Node"]\n')
    for file in ['spec_check.gd','carry_check.gd','ui_check.gd','virtual_input.gd','battlefield_load_check.gd']:
        text = (ROOT/'tools'/file).read_text().replace('res://tools/','res://qa/')
        (qa/file).write_text(text)
    harness = qa/'battlefield_load_check.gd'
    text = harness.read_text()
    begin = text.index('\t_hash_sources("res://scripts")')
    end = text.index('\tawait create_timer(0.2)',begin)
    text = text[:begin]+'\tsource_hashes = {"provided_by_export_driver":true}\n'+text[end:]
    text = 'class_name ExportLoadLoop\n'+text
    text = text.replace('for speed in [1.0, 4.0, 8.0]:','for speed in [1.0, 8.0]:').replace('for reduced in [false, true]:','for reduced in [false]:')
    text = text.replace('\tvar args := OS.get_cmdline_user_args()','\tvar args := OS.get_cmdline_user_args()\n\tif args.size()>3 and args[3]=="diagnostic":\n\t\tqa_diagnostic(args[0])\n\t\treturn',1)
    marker = '\tvar data := {'
    assert text.count(marker) == 1
    text = text.replace(marker,'\tawait qa_queue_probes()\n'+marker)
    text = text.replace('var data := {','var data := {"queue_probes":qa_queue_rows,"runtime_features":{"template":OS.has_feature("template"),"debug_build":OS.is_debug_build(),"editor":OS.has_feature("editor"),"tracking_setting":ProjectSettings.get_setting("debug/settings/gdscript/always_track_call_stacks")},',1)
    harness.write_text(text+EXTRA_GD)
    config = project/'project.godot'
    text = config.read_text()
    text = re.sub(r'^config/name=.*$',f'config/name="{name}"',text,flags=re.M)
    text = text.replace('run/main_scene="res://main.tscn"','run/main_scene="res://qa/empty.tscn"\nrun/main_loop_type="ExportLoadLoop"')
    text = text.replace('[display]','[display]\n\nwindow/size/no_focus=true\nwindow/size/mode=1')
    if stack != 'keep':
        text = text.replace('settings/gdscript/always_track_call_stacks=true','settings/gdscript/always_track_call_stacks='+('true' if stack=='on' else 'false'))
    config.write_text(text)
    online = project/'scripts/online_config.gd'
    online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',online.read_text()))
    preset = project/'export_presets.cfg'
    text = preset.read_text()
    marker='[preset.4.options]'
    before,after = text.split(marker,1)
    after=after.replace('application/bundle_identifier="kr.chat.anon.bindu"','application/bundle_identifier="kr.chat.anon.bindu.qa'+uuid.uuid4().hex+'"')
    preset.write_text(before+marker+after)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--stack',choices=['keep','on','off'],default='keep')
    parser.add_argument('--runtimes',nargs='+',choices=['editor','release'],default=['editor','release'])
    args=parser.parse_args()
    guard=(Path(tempfile.gettempdir())/'bindu-export-runtime.lock').open('w')
    fcntl.flock(guard,fcntl.LOCK_EX|fcntl.LOCK_NB)
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    assert not any(out.iterdir()),'Use a fresh output directory'
    name='BinduToolsExportRun'+uuid.uuid4().hex
    userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'stack_variant':args.stack,'scope':'Current product scripts, isolated custom QA MainLoop and macOS export. Fixed simulation delta, minimized no-focus SubViewport. Queue request is call_deferred from a5ms worker, not physical OS input. Diagnostic process intentionally emits one named error; timing processes require0errors.','runs':{}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-export-runtime-') as directory:
            project=Path(directory);prepare(project,name,args.stack)
            record['source_hashes']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(project.rglob('*')) if p.is_file()}
            (out/'qa-mainloop.txt').write_text((project/'qa/battlefield_load_check.gd').read_text())
            run([GODOT,'--headless','--import','--path',directory],out/'import.log')
            executables={'editor':[GODOT,'--path',directory]}
            if 'release' in args.runtimes:
                app=project/'build/BinduQA.app';app.parent.mkdir()
                command=[GODOT,'--headless','--path',directory,'--export-release','macOS',str(app)]
                run(command,out/'export.log');record['export_command']=command
                candidates=list((app/'Contents/MacOS').iterdir());assert len(candidates)==1
                binary=candidates[0];executables['release']=[str(binary)]
                record['release_binary_sha256']=hashlib.sha256(binary.read_bytes()).hexdigest()
                pcks=list((app/'Contents/Resources').glob('*.pck'));assert len(pcks)==1
                record['release_pack_sha256']=hashlib.sha256(pcks[0].read_bytes()).hexdigest()
            for runtime in args.runtimes:
                folder=out/runtime;folder.mkdir()
                shutil.rmtree(userdata,ignore_errors=True)
                command=executables[runtime]+['--audio-driver','Dummy','--resolution','1280x720','--',str(folder),'1.0','pc','load','30']
                text=run(command,folder/'native.log',env={**os.environ,'BINDU_PROFILE_CPU':'1'})
                assert 'conditions=2 failures=0 ui=0' in text
                data=json.loads((folder/'measurements.json').read_text());assert len(data['queue_probes'])==6
                diagnostic=executables[runtime]+['--audio-driver','Dummy','--',str(folder),'1.0','pc','diagnostic']
                run(diagnostic,folder/'diagnostic.log',diagnostic=True)
                diag=json.loads((folder/'diagnostic.json').read_text());assert diag['expected_events']
                record['runs'][runtime]={'command':command,'diagnostic_command':diagnostic,'runtime_features':data['runtime_features'],'queue_probes':data['queue_probes'],'diagnostic':diag,'exit':0,'timing_runtime_errors':0}
                print('EXPORT RUNTIME',runtime,'exit0',flush=True)
        record['temporary_project_removed']=not project.exists()
    except BaseException as error:
        record['failure']=str(error)[:2000]
        raise
    finally:
        if 'project' in locals():record['temporary_project_removed']=not project.exists()
        shutil.rmtree(userdata,ignore_errors=True)
        record['isolated_save_removed']=not userdata.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({key:value['runtime_features'] for key,value in record['runs'].items()},indent=2))


if __name__=='__main__':
    main()
