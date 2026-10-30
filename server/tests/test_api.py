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
           "src": {"elem:fire": 0.4, "pat:spray": 0.3, "rx:burning": 0.2, "mod:rapid": 0.1, "Bad Key": 0.5, "elem:ice": 2.0},
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
        # 피해 출처: 이상한 키·1을 넘는 몫은 버린다
        src = {x["key"]: x for x in s["srcs"]}
        assert s["src_runs"] == 5 and set(src) == {"elem:fire", "pat:spray", "rx:burning", "mod:rapid"}
        assert src["elem:fire"]["avg_share_all"] == 0.4 and src["rx:burning"]["runs"] == 5
        assert "rx:burning" in c.get("/admin/api/stats.csv", params={"kind": "srcs"}, headers=A).text
        # 관리: 숨기기·차단
        bad = c.get("/admin/runs", params={"invalid": True}, headers=A).json()
        assert len(bad) == 1 and "cap" in bad[0]["reason"]
        c.post("/admin/bans", json={"device_id": "dev-bbbbbbbb"}, headers=A)
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "season": 1}).json()
        assert [e["score"] for e in lb["entries"]] == [3000]
        assert c.get("/admin").status_code == 200

        # 모드: 쉽게 모드 판은 받지만 리더보드에는 없음, 반대 쌍·모르는 모드는 거부
        r = post_run(c, device="dev-eeeeeeee", score=9000, patch=2, modes=["stroll"]).json()
        assert r["accepted"] and r["rank"] is None
        r = post_run(c, device="dev-ffffffff", score=9000, patch=2, modes=["rush", "steel"]).json()
        assert r["accepted"] and r["rank"]["rank"] == 1
        assert not post_run(c, device="dev-gggggggg", patch=2, modes=["rush", "stroll"]).json()["accepted"]
        assert not post_run(c, device="dev-gggggggg", patch=2, modes=["bogus"]).json()["accepted"]
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1}).json()
        assert [e["score"] for e in lb["entries"]] == [9000, 3000]
        md = {x["key"]: x for x in c.get("/admin/api/stats", headers=A).json()["picks"] if x["kind"] == "mode"}
        assert md["mode:stroll"]["runs_picked"] == 1 and md["mode:rush"]["runs_picked"] == 1 and md["mode:none"]["runs_picked"] >= 5


def test_validate_bounds():
    # 실제 봇 기록 수준(웨이브 30, 점수 수십만)은 통과, 터무니없는 값은 걸림
    run = {"map": "plain", "rules": 1, "wave": 30, "score": 400_000, "kills": 1500, "game_secs": 3000, "real_secs": 600}
    assert validate.check(run) == ""
    assert "too fast" in validate.check(dict(run, game_secs=10))
    assert "cap" in validate.check(dict(run, score=10**10))
    # 어렵게 모드는 배율만큼 상한이 올라가고, 쉽게 모드는 상한을 낮추지 않는다
    cap = validate.max_score(30, "plain", 1)
    assert "cap" in validate.check(dict(run, score=int(cap * 1.2)))
    assert validate.check(dict(run, score=int(cap * 1.2), modes=["rush"])) == ""
    assert validate.check(dict(run, modes=["three", "soft"])) == ""
    assert validate.modes_mul(["rush", "steel"]) == 1.3 * 1.3
    assert validate.modes_mul(["rush"], {"modes": {"rush": 1.5}}) == 1.5


def post_logs(c, entries, device="dev-logs-aaaa"):
    body = json.dumps({"device": device, "platform": "windows", "os": "Windows 11", "game": "0.4.51", "patch": 0, "entries": entries}).encode()
    mac = hmac.new(b"hk", body, hashlib.sha256).hexdigest()
    return c.post("/v1/logs", content=body, headers={"X-Bindu-Mac": mac, "Content-Type": "application/json"})


def test_logs():
    with TestClient(app) as c:
        e = {"kind": "error", "msg": "Invalid polygon data, triangulation failed.", "file": "servers/rendering/renderer_canvas_cull.cpp", "line": 1500,
             "fn": "canvas_item_add_polygon", "bt": "[0] _draw_body (res://scripts/tower.gd:848)", "n": 3, "map": "plain", "rules": 1, "skin": "star", "wave": 3}
        assert post_logs(c, [e, dict(e, msg="other text same place", n=2)]).status_code == 200
        assert post_logs(c, [dict(e, file="", line=0, msg="printerr thing", kind="printerr")], device="dev-logs-bbbb").status_code == 200
        # 서명이 틀리면 거절
        assert c.post("/v1/logs", content=b'{"device":"dev-logs-aaaa","game":"0","entries":[]}', headers={"X-Bindu-Mac": "x"}).status_code == 403
        assert c.get("/admin/api/logs").status_code == 401
        ls = c.get("/admin/api/logs", headers=A).json()
        assert len(ls) == 2
        top = ls[0]
        assert top["times"] == 5 and top["devices"] == 1 and top["versions"] == ["0.4.51"] and top["file"].endswith("canvas_cull.cpp")
        d = c.get(f"/admin/api/logs/{top['fp']}", headers=A).json()
        assert len(d) == 2 and d[0]["skin"] == "star" and "tower.gd" in d[0]["backtrace"]
        assert c.get("/admin/api/logs", headers=A, params={"platform": "macos"}).json() == []
        # 한 시간 한도
        many = [dict(e, line=i) for i in range(20)]
        codes = [post_logs(c, many, device="dev-logs-cccc").status_code for _ in range(6)]
        assert codes[:5] == [200] * 5 and codes[5] == 429


def test_snapshots():
    # 진행 중 판: 같은 run_key는 한 줄을 고치고, 선택·피해 출처는 두 번 세지 않는다
    with TestClient(app) as c:
        assert c.get("/v1/boot", params={"game": "0.5.1"}).json()["snap"] is True
        dev, key = "dev-snap-aaaa", "k1-abc"
        kw = dict(device=dev, map="spiral", run=key, game="0.5.1", patch=2)
        r1 = post_run(c, ended=False, wave=5, score=1000, **kw).json()
        assert r1["accepted"]
        lb = c.get("/v1/leaderboard", params={"map": "spiral", "rules": 1, "device": dev}).json()
        assert lb["entries"][0]["ended"] is False and lb["entries"][0]["score"] == 1000
        # 같은 웨이브·낮은 웨이브 진행 기록은 무시
        assert post_run(c, ended=False, wave=5, score=99, **kw).json()["ignored"]
        r2 = post_run(c, ended=False, wave=10, score=2000, game_secs=800.0, **kw).json()
        assert r2["id"] == r1["id"]
        r3 = post_run(c, ended=True, wave=12, score=2500, game_secs=900.0, **kw).json()
        assert r3["id"] == r1["id"] and r3["rank"]["score"] == 2500
        # 끝난 판에 늦게 온 기록은 버림
        assert post_run(c, ended=False, wave=15, score=9999, game_secs=999.0, **kw).json()["ignored"]
        runs = [x for x in c.get("/admin/runs", headers=A).json() if x["device"] == dev]
        assert len(runs) == 1 and runs[0]["ended"] and runs[0]["wave"] == 12
        st = c.get("/admin/api/stats", params={"map": "spiral"}, headers=A).json()
        fire = next(x for x in st["picks"] if x["key"] == "elem:fire")
        assert st["runs"] == 1 and fire["offered"] == 1 and st["src_runs"] == 1
        # 끝난 판만 필터
        post_run(c, device="dev-snap-bbbb", map="spiral", run="k2", ended=False, wave=5, score=500)
        assert c.get("/admin/api/stats", params={"map": "spiral"}, headers=A).json()["runs"] == 2
        assert c.get("/admin/api/stats", params={"map": "spiral", "ended_only": True}, headers=A).json()["runs"] == 1
        # 한 번 검증에 걸린 판은 이후 정상 기록이 와도 무효
        kb = dict(device="dev-snap-cccc", map="spiral", run="k3")
        assert not post_run(c, ended=False, wave=5, score=10**12, **kb).json()["accepted"]
        assert not post_run(c, ended=True, wave=8, score=100, **kb).json()["accepted"]


def test_privacy_page():
    with TestClient(app) as c:
        r = c.get("/privacy")
        assert r.status_code == 200
        assert "개인정보처리방침" in r.text and "<li>" in r.text
        assert '<a href="https://github.com/lenope1214/bindu/issues">' in r.text


def test_stats_min_wave():
    # 최소 웨이브 전에 끝난 판은 밸런스 통계에서 빠지고 이탈 통계로만, 기록은 남는다
    with TestClient(app) as c:
        kw = dict(map="storm", game="0.5.9")
        post_run(c, device="dev-mw-aaaa", wave=8, **kw)
        post_run(c, device="dev-mw-bbbb", wave=2, score=200, **kw)
        post_run(c, device="dev-mw-cccc", wave=0, score=0, **kw)
        post_run(c, device="dev-mw-cccc", wave=2, score=210, **kw)
        q = {"map": "storm", "game": "0.5.9"}
        st = c.get("/admin/api/stats", params=q, headers=A).json()
        assert st["runs"] == 1 and st["avg_wave"] == 8 and st["src_runs"] == 1
        assert next(x for x in st["picks"] if x["key"] == "elem:fire")["offered"] == 1
        assert sum(w["runs"] for w in st["waves"]) == 4
        dr = st["dropout"]
        assert dr["min_wave"] == 5 and dr["runs_all"] == 4 and dr["runs"] == 3 and dr["rate"] == 0.75 and dr["players"] == 2
        assert [(w["wave"], w["runs"]) for w in dr["waves"]] == [(0, 1), (2, 2)]
        assert c.get("/admin/api/stats", params={**q, "min_wave": 0}, headers=A).json()["runs"] == 4
        assert "wave" in c.get("/admin/api/stats.csv", params={**q, "kind": "dropout"}, headers=A).text
        assert len([x for x in c.get("/admin/runs", params={"limit": 500}, headers=A).json() if x["device"].startswith("dev-mw")]) == 4
