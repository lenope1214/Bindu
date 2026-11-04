#!/usr/bin/env python3
"""TestFlight 외부 그룹 배포 (App Store Connect API). build_ios.command upload가 업로드 뒤에 부른다.

사용: python3 tools/testflight.py <빌드 번호> [테스트 내용]
처리가 끝날 때까지(최대 40분) 기다린 뒤: 테스트 내용(한국어) → 자동 공지 켬 → 외부 그룹에 넣기 → 베타 심사 제출.
키: ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 (저장소 밖). 필요: pip install 'pyjwt[crypto]' requests
"""
import os
import sys
import time

import jwt
import requests

KEY_ID = os.environ.get("ASC_KEY_ID", "L3SBLC93C6")
ISSUER = os.environ.get("ASC_ISSUER", "ca10c558-a72c-459d-9f5f-3be72f8694dc")
APP_ID = "6828785423"
GROUP = "Bindu tester - ext"
API = "https://api.appstoreconnect.apple.com/v1"


def headers() -> dict:
    key = open(os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")).read()
    now = int(time.time())
    tok = jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}, key,
                     algorithm="ES256", headers={"kid": KEY_ID})
    return {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}


def call(method: str, path: str, **kw) -> dict:
    r = requests.request(method, API + path, headers=headers(), timeout=60, **kw)
    if r.status_code >= 400:
        sys.exit(f"{method} {path} 실패 {r.status_code}: {r.text[:300]}")
    return r.json() if r.text else {}


def main() -> None:
    num, notes = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
    build = None
    for _ in range(80):  # 30초마다, 최대 40분
        got = call("GET", "/builds", params={"filter[app]": APP_ID, "filter[version]": num, "include": "buildBetaDetail"})
        if got["data"] and got["data"][0]["attributes"]["processingState"] == "VALID":
            build = got
            break
        print(f"빌드 {num} 처리 기다리는 중…", flush=True)
        time.sleep(30)
    if build is None:
        sys.exit(f"빌드 {num}이 40분 안에 처리되지 않았어요")
    bid = build["data"][0]["id"]
    if notes:
        locs = call("GET", f"/builds/{bid}/betaBuildLocalizations")["data"]
        ko = next((l for l in locs if l["attributes"]["locale"].startswith("ko")), None)
        if ko:
            call("PATCH", f"/betaBuildLocalizations/{ko['id']}", json={"data": {"type": "betaBuildLocalizations", "id": ko["id"], "attributes": {"whatsNew": notes}}})
        else:
            call("POST", "/betaBuildLocalizations", json={"data": {"type": "betaBuildLocalizations", "attributes": {"locale": "ko", "whatsNew": notes},
                                                                    "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
    detail = build["included"][0]["id"]
    call("PATCH", f"/buildBetaDetails/{detail}", json={"data": {"type": "buildBetaDetails", "id": detail, "attributes": {"autoNotifyEnabled": True}}})
    groups = call("GET", f"/apps/{APP_ID}/betaGroups")["data"]
    gid = next(g["id"] for g in groups if g["attributes"]["name"] == GROUP)
    call("POST", f"/betaGroups/{gid}/relationships/builds", json={"data": [{"type": "builds", "id": bid}]})
    r = requests.post(API + "/betaAppReviewSubmissions", headers=headers(), timeout=60,
                      json={"data": {"type": "betaAppReviewSubmissions", "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
    if r.status_code >= 400 and "ALREADY" not in r.text.upper():
        sys.exit(f"베타 심사 제출 실패 {r.status_code}: {r.text[:300]}")
    print(f"빌드 {num}: 외부 그룹 '{GROUP}'에 넣고 베타 심사 제출 (자동 공지 켬)")


if __name__ == "__main__":
    main()
