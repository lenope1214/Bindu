#!/usr/bin/env python3
"""Google Play 내부 테스트에 AAB 올리기 (Play Developer API, 서비스 계정).

사용: python3 tools/play_upload.py [Bindu.aab] [출시 노트] [draft|completed]
키: ~/.appstoreconnect/play-key.json (저장소 밖, PLAY_KEY로 바꿀 수 있음). 필요: pip install 'pyjwt[crypto]' requests
앱이 아직 한 번도 출시되지 않았으면 Play가 draft만 받는다 (그때는 Play Console에서 출시를 눌러야 함).
"""
import json
import os
import sys
import time

import jwt
import requests

PKG = "kr.chat.anon.bindu"
TRACK = os.environ.get("PLAY_TRACK", "internal")  # 비공개 테스트: alpha
KEY = os.path.expanduser(os.environ.get("PLAY_KEY", "~/.appstoreconnect/play-key.json"))
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
UP = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}"


def token() -> str:
    sa = json.load(open(KEY))
    now = int(time.time())
    a = jwt.encode({"iss": sa["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
                    "aud": sa["token_uri"], "iat": now, "exp": now + 3600}, sa["private_key"], algorithm="RS256")
    r = requests.post(sa["token_uri"], data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": a}, timeout=60)
    r.raise_for_status()
    return r.json()["access_token"]


def ok(r: requests.Response) -> dict:
    if r.status_code >= 400:
        sys.exit(f"{r.request.method} {r.url.split('?')[0]} 실패 {r.status_code}: {r.text[:400]}")
    return r.json() if r.text else {}


def main() -> None:
    aab = sys.argv[1] if len(sys.argv) > 1 else "Bindu.aab"
    notes = sys.argv[2] if len(sys.argv) > 2 else ""
    status = sys.argv[3] if len(sys.argv) > 3 else "completed"
    h = {"Authorization": f"Bearer {token()}"}
    edit = ok(requests.post(f"{API}/edits", headers=h, timeout=60))["id"]
    with open(aab, "rb") as f:
        code = ok(requests.post(f"{UP}/edits/{edit}/bundles?uploadType=media", headers={**h, "Content-Type": "application/octet-stream"},
                                data=f, timeout=1800))["versionCode"]
    rel = {"versionCodes": [str(code)], "status": status}
    if notes:
        rel["releaseNotes"] = [{"language": "ko-KR", "text": notes[:500]}]
    ok(requests.put(f"{API}/edits/{edit}/tracks/{TRACK}", headers=h, json={"track": TRACK, "releases": [rel]}, timeout=60))
    ok(requests.post(f"{API}/edits/{edit}:commit", headers=h, timeout=120))
    print(f"versionCode {code}: {TRACK} 트랙에 올림 ({status})")


if __name__ == "__main__":
    main()
