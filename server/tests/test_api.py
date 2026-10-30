import hashlib
import hmac
import json
import os
import sys
import tempfile

TMP = tempfile.mkdtemp()
os.environ.update(DATABASE_URL=f"sqlite:///{TMP}/t.db", ADMIN_TOKEN="adm", RUN_HMAC_KEY="hk", PATCH_KEY_PATH=f"{TMP}/k.pem", RUN_MIN_INTERVAL="0")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient  # noqa: E402

from app import signing, validate  # noqa: E402
from app.main import app  # noqa: E402

PUB = signing.generate_keypair(os.environ["PATCH_KEY_PATH"])
A = {"Authorization": "Bearer adm"}


def post_run(c, **kw):
    run = {"device": "dev-aaaaaaaa", "nick": "bok", "platform": "windows", "game": "0.4.25", "patch": 0, "map": "plain", "rules": 1,
           "wave": 8, "score": 3000, "kills": 80, "best_combo": 10, "game_secs": 400.0, "real_secs": 200.0,
           "perks": {"power": 1},
           "towers": [{"els": {"fire": 2, "wood": 1}, "pat": "spray", "plv": 1, "mods": {"rapid": 2}, "share": 0.7},
                      {"els": {"ice": 1}, "pat": "shot", "plv": 1, "mods": {}, "prism": 1, "share": 0.3}],
           "log": [{"w": 0, "k": "card", "o": ["elem:fire", "elem:ice", "elem:wood"], "p": "elem:fire"},
                   {"w": 2, "k": "card", "o": ["pat:spray", "mod:rapid", "elem:ice"], "p": ""},
                   {"w": 2, "k": "card", "o": ["pat:spray", "mod:rapid", "elem:ice"], "p": "pat:spray"},
                   {"w": 5, "k": "perk", "o": ["perk:power", "perk:luck", "perk:core"], "p": "perk:power"}]}
    run.update(kw)
    body = json.dumps(run).encode()
    mac = hmac.new(b"hk", body, hashlib.sha256).hexdigest()
    return c.post("/v1/runs", content=body, headers={"X-Bindu-Mac": mac, "Content-Type": "application/json"})


def test_flow():
    with TestClient(app) as c:
        # 패치 없음 → id 0
        b = c.get("/v1/boot", params={"game": "0.4.25", "platform": "windows"}).json()
        assert b["patch"] == {"id": 0} and b["season"]["id"] == 1 and b["latest"] is None
        # 관리자 토큰 없으면 거부
        assert c.post("/admin/patches", json={"data": {}}).status_code == 401
        assert c.post("/admin/patches", json={"data": {"bogus": 1}}, headers=A).status_code == 422
        r = c.post("/admin/patches", json={"data": {"rules": {"1": {"max_mod": 4}}, "perks": {"power": 0.2}}, "notes": "t", "min_game": "0.4.25"}, headers=A).json()
        assert r == {"id": 1, "season": 1}
        b = c.get("/v1/boot", params={"game": "0.4.25", "platform": "windows"}).json()
        p = b["patch"]
        assert p["id"] == 1 and signing.verify(p["payload"], p["sig"], PUB)
        assert json.loads(p["payload"])["data"]["perks"]["power"] == 0.2
        assert c.get("/v1/boot", params={"game": "0.4.24"}).json()["patch"] == {"id": 0}  # 버전 범위 밖
        assert c.get("/v1/boot", params={"game": "0.4.25", "patch": 1}).json()["patch"] == {"id": 1, "same": True}
        # 새 버전 알림
        c.put("/admin/releases/windows", json={"version": "0.5.0", "url": "https://x/y.zip", "sha256": "ab" * 32, "size": 9}, headers=A)
        lt = c.get("/v1/boot", params={"game": "0.4.25", "platform": "windows"}).json()["latest"]
        assert lt["version"] == "0.5.0" and lt["sha256"] == "ab" * 32
        assert signing.verify(f"bindu-release|windows|0.5.0|https://x/y.zip|{'ab' * 32}|9", lt["sig"], PUB)
        assert c.get("/v1/boot", params={"game": "0.5.0", "platform": "windows"}).json()["latest"] is None
        # 해시를 안 주면 서버가 파일을 받아 계산, 주소를 비우면 지난 주소 그대로
        zp = os.path.join(TMP, "Bindu-windows.zip")
        with open(zp, "wb") as f:
            f.write(b"zipdata")
        r = c.put("/admin/releases/windows", json={"version": "0.5.1", "url": "file://" + zp}, headers=A).json()
        assert r["sha256"] == hashlib.sha256(b"zipdata").hexdigest() and r["size"] == 7
        r = c.put("/admin/releases/windows", json={"version": "0.5.2", "url": ""}, headers=A).json()
        assert r["url"] == "file://" + zp and r["sha256"] == hashlib.sha256(b"zipdata").hexdigest()
        assert c.put("/admin/releases/windows", json={"version": "0.5.3", "url": "file:///nope.zip"}, headers=A).status_code == 422
        assert c.put("/admin/releases/windows", json={"version": "0.5.3", "sha256": "zz"}, headers=A).status_code == 422

        # 판 기록: 서명 틀리면 거부
        assert c.post("/v1/runs", content=b"{}", headers={"X-Bindu-Mac": "00"}).status_code == 403
        r = post_run(c, patch=1)
        assert r.status_code == 200, r.text
        assert r.json()["accepted"] and r.json()["rank"]["rank"] == 1
        r = post_run(c, device="dev-bbbbbbbb", nick="<b>x</b>", score=5000, patch=1)
        assert r.json()["rank"]["rank"] == 1
        # 말이 안 되는 점수
        r = post_run(c, device="dev-cccccccc", score=10**9, patch=1).json()
        assert not r["accepted"]
        # 같은 기기 낮은 점수는 순위에 영향 없음
        post_run(c, score=100, patch=1)
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "device": "dev-aaaaaaaa"}).json()
        assert [e["score"] for e in lb["entries"]] == [5000, 3000]
        assert lb["entries"][0]["nick"] == "bx/b" and lb["me"]["rank"] == 2 and lb["total"] == 2

        # 새 시즌: 예전 패치로 한 판은 시즌 0(리더보드 제외)
        r = c.post("/admin/patches", json={"data": {"perks": {"power": 0.1}}, "new_season": True, "season_name": "S2"}, headers=A).json()
        assert r == {"id": 2, "season": 2}
        assert post_run(c, device="dev-dddddddd", patch=1).json()["season"] == 0
        assert post_run(c, device="dev-dddddddd", patch=2).json()["season"] == 2
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1}).json()
        assert lb["season"]["name"] == "S2" and len(lb["entries"]) == 1
        assert len(c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "season": 1}).json()["entries"]) == 2

        # 통계
        s = c.get("/admin/api/stats", headers=A).json()
        pk = {x["key"]: x for x in s["picks"]}
        assert pk["perk:power"]["picked"] == s["runs"]
        assert pk["pat:spray"]["offered"] == 2 * s["runs"] and pk["pat:spray"]["rate"] == 0.5
        fin = {x["key"]: x for x in s["finals"]}
        assert fin["elem:fire"]["avg_amount"] == 2 and fin["link:prism"]["presence"] == 1.0
        assert s["runs"] == 5  # 검증 실패 1판 제외
        assert c.get("/admin/api/stats", params={"valid_only": False}, headers=A).json()["runs"] == 6
        csv = c.get("/admin/api/stats.csv", params={"kind": "finals"}, headers=A).text
        assert "elem:fire" in csv
        # 관리: 숨기기·차단
        bad = c.get("/admin/runs", params={"invalid": True}, headers=A).json()
        assert len(bad) == 1 and "cap" in bad[0]["reason"]
        c.post("/admin/bans", json={"device_id": "dev-bbbbbbbb"}, headers=A)
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "season": 1}).json()
        assert [e["score"] for e in lb["entries"]] == [3000]
        assert c.get("/admin").status_code == 200


def test_validate_bounds():
    # 실제 봇 기록 수준(웨이브 30, 점수 수십만)은 통과, 터무니없는 값은 걸림
    run = {"map": "plain", "rules": 1, "wave": 30, "score": 400_000, "kills": 1500, "game_secs": 3000, "real_secs": 600}
    assert validate.check(run) == ""
    assert "too fast" in validate.check(dict(run, game_secs=10))
    assert "cap" in validate.check(dict(run, score=10**10))
