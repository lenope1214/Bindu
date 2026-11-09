#!/usr/bin/env python3
"""Build an unsigned isolated single-player iOS Simulator QA app. Export outside project."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess

ROOT=Path(__file__).resolve().parents[4]
GODOT=os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')


def run(command,log):
    with log.open('w') as stream:r=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT)
    text=log.read_text();assert r.returncode==0 and not re.search(r'^(?:SCRIPT ERROR|ERROR:)',text,re.M),(command,r.returncode,text[-3000:])


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--workdir',type=Path,required=True);parser.add_argument('--ios-template',type=Path,required=True);args=parser.parse_args()
    work=args.workdir.resolve();work.mkdir(parents=True,exist_ok=True);assert not any(work.iterdir())
    project=work/'project';project.mkdir();export=work/'export';export.mkdir()
    for name in ['scripts','icons']:shutil.copytree(ROOT/name,project/name)
    for name in ['project.godot','main.tscn','icon.svg']:shutil.copy2(ROOT/name,project/name)
    (project/'docs').mkdir();shutil.copy2(ROOT/'docs/features.md',project/'docs/features.md')
    (project/'qa_ios').mkdir();shutil.copy2(ROOT/'tools/battlefield_ios_runtime_probe.gd',project/'qa_ios/monitor.gd')
    original={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
    cfg=project/'project.godot';cfg.write_text(cfg.read_text().replace('config/name="Bindu"','config/name="BinduToolsIOSLifecycle"')+'\n[autoload]\nBattlefieldIOSQA="*res://qa_ios/monitor.gd"\n')
    online=project/'scripts/online_config.gd';online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',online.read_text()))
    template=str(args.ios_template.resolve());assert Path(template).is_file()
    (project/'export_presets.cfg').write_text('''[preset.0]
name="iOS QA"
platform="iOS"
runnable=false
export_filter="all_resources"
include_filter=""
exclude_filter="tools/*,build/*,docs/*,*.command,*.md"
export_path=""
[preset.0.options]
custom_template/debug="'''+template+'''"
custom_template/release="'''+template+'''"
application/app_store_team_id="XXXXXXXXXX"
application/bundle_identifier="dev.bindu.usabilityqa.lifecycle"
application/export_project_only=true
application/short_version="1.0.0"
application/version="1"
application/min_ios_version="15.0"
application/targeted_device_family=2
icons/icon_1024x1024="res://icons/icon_1024.png"
''')
    run([GODOT,'--headless','--path',str(project),'--import'],work/'import.log')
    run([GODOT,'--headless','--path',str(project),'--export-debug','iOS QA',str(export/'BinduIOSQA.xcodeproj')],work/'export.log')
    run(['xcodebuild','-project',str(export/'BinduIOSQA.xcodeproj'),'-scheme','BinduIOSQA','-configuration','Debug','-destination','generic/platform=iOS Simulator','-derivedDataPath',str(work/'derived'),'CODE_SIGNING_ALLOWED=NO','CODE_SIGN_IDENTITY=','DEVELOPMENT_TEAM=','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','build'],work/'xcode.log')
    app=work/'derived/Build/Products/Debug-iphonesimulator/BinduIOSQA.app'
    record={'source_ref':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'original_scripts':original,'qa_sha256':hashlib.sha256((project/'qa_ios/monitor.gd').read_bytes()).hexdigest(),'template_sha256':hashlib.sha256(Path(template).read_bytes()).hexdigest(),'pck_sha256':hashlib.sha256((export/'BinduIOSQA.pck').read_bytes()).hexdigest(),'app_binary_sha256':hashlib.sha256((app/'BinduIOSQA').read_bytes()).hexdigest(),'bundle':'dev.bindu.usabilityqa.lifecycle','app':str(app),'scope':'Custom debug ARM64 Simulator; no WebRTC extension copied, operational URLs blank, product scripts otherwise unchanged'}
    (work/'build.json').write_text(json.dumps(record,indent=2)+'\n');print(app,flush=True)


if __name__=='__main__':main()
