#!/usr/bin/env python3
"""Build the matching source's arm64 iOS Simulator debug slice; preserve other ZIP entries."""
from pathlib import Path
import argparse,hashlib,json,plistlib,subprocess,zipfile

REF='ed1daf0bf001b61586d9930840f2f1394092c079'


def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--scons',type=Path,required=True);p.add_argument('--official-template',type=Path,required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    source=args.source.resolve();out=args.output.resolve();assert not out.exists()
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()==REF
    subprocess.run(['git','diff','--exit-code'],cwd=source,check=True,stdout=subprocess.DEVNULL)
    command=[str(args.scons.resolve()),'platform=ios','target=template_debug','arch=arm64','simulator=yes','debug_symbols=no','optimize=size','vulkan=no','metal=no','-j8']
    with out.with_suffix('.build.log').open('w') as log:r=subprocess.run(command,cwd=source,stdout=log,stderr=subprocess.STDOUT)
    assert r.returncode==0,r.returncode
    replacements={'libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a':source/'bin/libgodot.ios.template_debug.arm64.simulator.a','libgodot_camera.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot_camera.a':source/'bin/libgodot_camera.ios.template_debug.arm64.simulator.a'}
    for file in replacements.values():assert 'architecture: arm64' in subprocess.check_output(['xcrun','lipo','-info',str(file)],text=True)
    with zipfile.ZipFile(args.official_template) as original,zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=3) as result:
        for item in original.infolist():
            data=replacements[item.filename].read_bytes() if item.filename in replacements else original.read(item.filename)
            if item.filename in ['libgodot.ios.debug.xcframework/Info.plist','libgodot_camera.ios.debug.xcframework/Info.plist']:
                info=plistlib.loads(data)
                for lib in info['AvailableLibraries']:
                    if lib.get('SupportedPlatformVariant')=='simulator':lib['SupportedArchitectures']=['arm64']
                data=plistlib.dumps(info)
            result.writestr(item,data)
    out.with_suffix('.json').write_text(json.dumps({'engine_ref':REF,'command':command,'template_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'debug_libraries':{name:hashlib.sha256(path.read_bytes()).hexdigest() for name,path in replacements.items()},'release_libraries_unchanged':True},indent=2)+'\n')


if __name__=='__main__':main()
