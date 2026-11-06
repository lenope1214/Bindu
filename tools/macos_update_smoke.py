#!/usr/bin/env python3
"""Export two isolated real Bindu apps; update over local signed HTTPS and check relaunch/save/cleanup."""
import hashlib
import http.server
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import ssl
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
OUT = Path(os.environ.get('MACOS_SMOKE_OUT', '/tmp/bindu-macos-update-smoke')).resolve()
OUT.mkdir(parents=True, exist_ok=True)


def run(*args, **kwargs):
    r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, **kwargs)
    if r.returncode or 'SCRIPT ERROR:' in r.stdout:
        raise RuntimeError(r.stdout[-6000:])
    return r.stdout


def main():
    work = Path(tempfile.mkdtemp(prefix='bindu-macos-smoke-')).resolve()
    project = work / 'project'
    shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns('.git', '.godot', 'build', '__pycache__', 'keystore', 'keys', '.env*', '*.jks', '*.keystore', '*.exe', '*.zip'))
    name = 'BinduToolsMacUpdate' + work.name.rsplit('-', 1)[-1]
    cert, key = work / 'ca.pem', work / 'tls-key.pem'
    conf = work / 'tls.cnf'
    conf.write_text('[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=127.0.0.1\n[ext]\nsubjectAltName=IP:127.0.0.1\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\n')
    run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(key), '-out', str(cert), '-days', '1', '-config', str(conf))
    signing_key = work / 'release-key.pem'
    run('openssl', 'genrsa', '-out', str(signing_key), '2048')
    public = run('openssl', 'rsa', '-in', str(signing_key), '-pubout')
    # OpenSSL prints a status line on stderr; take only PEM from merged output.
    public = public[public.index('-----BEGIN PUBLIC KEY-----'):]
    shutil.copy2(cert, project / 'smoke-ca.crt')
    releases = {}
    zip_path = work / 'Bindu-macos.zip'

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith('/v1/boot?'):
                from urllib.parse import parse_qs, urlsplit
                current = parse_qs(urlsplit(self.path).query).get('game', [''])[0]
                body = json.dumps(dict(latest=releases if current == '0.0.1' else None, patch={'id': 0}, acct=False, snap=False)).encode()
            elif self.path == '/Bindu-macos.zip':
                body = zip_path.read_bytes()
            else:
                body = b'{}'
            self.send_response(200)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt, *args):
            with (OUT / 'https.log').open('a') as f:
                f.write(fmt % args + '\n')

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(cert, key)
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f'https://127.0.0.1:{server.server_port}'
    config = project / 'scripts/online_config.gd'
    s = config.read_text()
    s = re.sub(r'const SERVER_URL := "[^"]*"', f'const SERVER_URL := "{url}"', s)
    s = re.sub(r'const MP_URL := "[^"]*"', 'const MP_URL := ""', s)
    s = re.sub(r'const PATCH_PUBLIC_KEY := """.*?"""', 'const PATCH_PUBLIC_KEY := """' + public + '"""', s, flags=re.S)
    config.write_text(s)
    fixture = '''extends Node
var main
func _ready():
 get_window().unfocusable = true
 get_window().mode = Window.MODE_MINIMIZED
 Tutorial.load_file()
 Tutorial.done = true
 Tutorial.play_done = true
 Tutorial.save_file()
 main = load("res://main.tscn").instantiate()
 add_child(main)
 await get_tree().process_frame
 main.onboarding_system.tut_first = false
 main.tut.close()
 Meta.online_on = false
 if Net.game_version() == "0.0.1":
  if FileAccess.file_exists("user://smoke-attempted"):
   push_error("SMOKE rolled back to old app")
   get_tree().quit(1)
   return
  var attempted = FileAccess.open("user://smoke-attempted", FileAccess.WRITE)
  attempted.store_string("attempted")
  attempted.close()
  var saved = FileAccess.open("user://smoke-save.txt", FileAccess.WRITE)
  saved.store_string("preserve this save")
  saved.close()
  main.best_wave = 7
  main.best_score = 350
  main.progression_system._save_best()
  var previous_phase = main.phase
  main.title_label.hide()
  main.phase = BinduSession.Phase.READY
  main.wave = 4
  main.score = 123
  main.persistence_system._save_run()
  main.title_label.show()
  main.phase = previous_phase
  var run_hash = FileAccess.open("user://smoke-run.sha", FileAccess.WRITE)
  run_hash.store_string(FileAccess.get_sha256(BinduSession.RUN_PATH))
  run_hash.close()
  var limit = Time.get_ticks_msec() + 45000
  while not main.update_btn.visible and Time.get_ticks_msec() < limit:
   await get_tree().create_timer(0.1).timeout
  if not main.update_btn.visible or not Updater.available(Net.info.get("latest", {})):
   push_error("SMOKE release unavailable: " + JSON.stringify(Net.info))
   get_tree().quit(1)
   return
  main.update_btn.pressed.emit()
 else:
  await get_tree().create_timer(2.0).timeout
  var result = {"version":Net.game_version(), "save":FileAccess.get_file_as_string("user://smoke-save.txt"), "pid":OS.get_process_id(), "app":MacUpdater.app_path(), "best_wave":main.best_wave, "best_score":main.best_score, "run_hash_match":FileAccess.get_sha256(BinduSession.RUN_PATH) == FileAccess.get_file_as_string("user://smoke-run.sha"), "continue_visible":main.continue_btn.visible, "saved_wave":main.persistence_system._run_info().get("wave", -1)}
  var f = FileAccess.open("RESULT_PATH", FileAccess.WRITE)
  f.store_string(JSON.stringify(result))
  f.close()
  await get_tree().create_timer(4.0).timeout
  get_tree().quit()
'''.replace('RESULT_PATH', str(OUT / 'result.json'))
    (project / 'scripts/update_fixture.gd').write_text(fixture)
    (project / 'update_fixture.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/update_fixture.gd" id="1"]\n[node name="UpdateFixture" type="Node"]\nscript = ExtResource("1")\n')
    settings = project / 'project.godot'
    base = settings.read_text()
    base = re.sub(r'^config/name=.*', f'config/name="{name}"', base, flags=re.M)
    base = re.sub(r'^run/main_scene=.*', 'run/main_scene="res://update_fixture.tscn"', base, flags=re.M)
    base += '\n[network]\ntls/certificate_bundle_override="res://smoke-ca.crt"\n'
    settings.write_text(base)
    run(GODOT, '--headless', '--path', str(project), '--import')

    def export(version, target):
        settings.write_text(re.sub(r'^config/version=.*', f'config/version="{version}"', base, flags=re.M))
        target.parent.mkdir(parents=True, exist_ok=True)
        output = run(GODOT, '--headless', '--path', str(project), '--export-release', 'macOS', str(target))
        (OUT / ('export-' + version + '.log')).write_text(output)
        helpers = target / 'Contents/Helpers'
        helpers.mkdir()
        shutil.copy2(ROOT / 'build/macos/BinduUpdater', helpers / 'BinduUpdater')
        p = plistlib.loads((target / 'Contents/Info.plist').read_bytes())
        assert p['CFBundleShortVersionString'] == version, p
        run('/usr/bin/codesign', '--force', '--options', 'runtime', '--entitlements', str(ROOT / 'native/macos/entitlements.plist'), '--sign', '-', str(target))
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(target))
        return target

    old = export('0.0.1', work / 'Installed/Bindu.app')
    new = export('0.0.2', work / 'New/Bindu.app')
    run('/usr/bin/ditto', '-c', '-k', '--norsrc', '--keepParent', str(new), str(zip_path))
    sha = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    size = zip_path.stat().st_size
    payload = f'bindu-release|macos|0.0.2|{url}/Bindu-macos.zip|{sha}|{size}'
    body = work / 'payload'
    body.write_text(payload)
    sig_path = work / 'sig'
    run('openssl', 'dgst', '-sha256', '-sign', str(signing_key), '-out', str(sig_path), str(body))
    import base64
    releases.update(version='0.0.2', url=url + '/Bindu-macos.zip', sha256=sha, size=size, sig=base64.b64encode(sig_path.read_bytes()).decode())
    (OUT / 'result.json').unlink(missing_ok=True)
    with (OUT / 'old-app.log').open('w') as log:
        executable = plistlib.loads((old / 'Contents/Info.plist').read_bytes())['CFBundleExecutable']
        process = subprocess.Popen([str(old / 'Contents/MacOS' / executable)], stdout=log, stderr=subprocess.STDOUT)
        try:
            process.wait(timeout=100)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait()
            raise AssertionError((OUT / 'old-app.log').read_text()[-5000:])
    end = time.monotonic() + 55
    while not (OUT / 'result.json').exists() and time.monotonic() < end:
        time.sleep(.2)
    assert (OUT / 'result.json').exists(), (OUT / 'old-app.log').read_text()[-5000:]
    result = json.loads((OUT / 'result.json').read_text())
    assert result['version'] == '0.0.2' and result['save'] == 'preserve this save' and result['best_wave'] == 7 and result['best_score'] == 350 and result['run_hash_match'] and result['continue_visible'] and result['saved_wave'] == 4, result
    assert not list(old.parent.glob('.bindu-update-*')), 'helper stage not cleaned'
    assert plistlib.loads((old / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString'] == '0.0.2'
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(old))
    result.update(old_pid=process.pid, work=str(work), user_data_name=name, zip_sha256=sha, zip_size=size, stage_cleaned=True)
    (OUT / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    server.shutdown()
    print('MACOS UPDATE SMOKE ok', json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
