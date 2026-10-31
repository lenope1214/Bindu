import test_api as base  # 환경 변수·앱·post_run을 같이 쓴다 (같은 DB)
from fastapi.testclient import TestClient

from app import votes
from app.main import app
from test_api_accounts import H, auth

A = base.A


def test_vote_flow():
    with TestClient(app) as c:
        assert c.get("/v1/boot", params={"game": "0.6.0"}).json()["vote"] is True
        # 토큰 없이: 회차·지난 결과만
        g = c.get("/v1/vote").json()
        assert g["round"] and g["max"] == 5 and g["mine"] == [] and g["reason"] == "auth"
        rid = g["round"]["id"]
        a = auth(c, "vote-dev-0001").json()
        # 판을 안 했으면 못 넣는다
        g = c.get("/v1/vote", headers=H(a["token"])).json()
        assert not g["eligible"] and g["reason"] == "play"
        assert c.put("/v1/vote", json={"round": rid, "votes": [{"key": "elem:fire", "dir": "up"}]}, headers=H(a["token"])).status_code == 403
        # 4웨이브 판은 모자라고 5웨이브 판이면 된다
        assert base.post_run(c, device="vote-dev-0001", wave=4, score=900, headers=H(a["token"])).status_code == 200
        assert not c.get("/v1/vote", headers=H(a["token"])).json()["eligible"]
        assert base.post_run(c, device="vote-dev-0001", wave=8, headers=H(a["token"])).status_code == 200
        assert c.get("/v1/vote", headers=H(a["token"])).json()["eligible"]
        body = {"round": rid, "votes": [{"key": "elem:fire", "dir": "up"}, {"key": "pat:spray", "dir": "down"},
                                        {"key": "mod:homing", "dir": "fix", "note": "  너무ㅋㅋㅋㅋㅋㅋㅋㅋ 빙빙 돌아요 <b> "}]}
        r = c.put("/v1/vote", json=body, headers=H(a["token"]))
        assert r.status_code == 200 and r.json()["count"] == 3
        mine = {v["key"]: v for v in c.get("/v1/vote", headers=H(a["token"])).json()["mine"]}
        assert mine["mod:homing"]["note"] == "너무ㅋㅋㅋ 빙빙 돌아요 b" and mine["elem:fire"]["dir"] == "up"
        # 6장은 거부, 이상한 키 거부, 링크 의견은 지움
        six = {"round": rid, "votes": [{"key": f"perk:p{i}", "dir": "up"} for i in range(6)]}
        assert c.put("/v1/vote", json=six, headers=H(a["token"])).status_code == 422
        assert c.put("/v1/vote", json={"round": rid, "votes": [{"key": "Bad", "dir": "up"}]}, headers=H(a["token"])).status_code == 422
        # 다시 넣으면 통째로 바뀜 (같은 계정은 표 하나)
        body["votes"][2]["note"] = "www.spam.com 오세요"
        assert c.put("/v1/vote", json=body, headers=H(a["token"])).status_code == 200
        assert {v["key"]: v for v in c.get("/v1/vote", headers=H(a["token"])).json()["mine"]}["mod:homing"]["note"] == ""
        # 두 번째 사람
        b = auth(c, "vote-dev-0002").json()
        base.post_run(c, device="vote-dev-0002", wave=6, headers=H(b["token"]))
        c.put("/v1/vote", json={"round": rid, "votes": [{"key": "elem:fire", "dir": "up"}, {"key": "mod:homing", "dir": "fix", "note": "설명이 어려워요"}]},
              headers=H(b["token"]))
        s = c.get("/admin/api/votes", headers=A).json()
        rows = {r["key"]: r for r in s["rows"]}
        assert s["voters"] == 2 and rows["elem:fire"]["up"] == 2 and rows["pat:spray"]["down"] == 1 and rows["mod:homing"]["fix"] == 2
        assert rows["mod:homing"]["notes"] == 1 and rows["elem:fire"]["pick_rate"] is not None
        notes = c.get("/admin/api/votes/notes", params={"round": rid, "key": "mod:homing"}, headers=A).json()
        assert [n["note"] for n in notes] == ["설명이 어려워요"]
        assert "elem:fire" in c.get("/admin/api/votes.csv", headers=A).text
        assert c.get("/admin/api/votes").status_code == 401
        # 차단하면 집계에서 빠지고 못 넣는다
        c.post("/admin/bans", json={"device_id": "vote-dev-0002", "reason": "t"}, headers=A)
        s = c.get("/admin/api/votes", headers=A).json()
        assert s["voters"] == 1 and {r["key"]: r for r in s["rows"]}["elem:fire"]["up"] == 1
        assert c.get("/v1/vote", headers=H(b["token"])).json()["reason"] == "banned"
        # 새 회차: 지난 회차는 닫히고 결과가 보이며, 닫힌 회차에는 못 넣는다
        n = c.post("/admin/vote_rounds", json={"name": "0.6.0 다음"}, headers=A).json()
        assert n["name"] == "0.6.0 다음" and n["id"] == rid + 1
        g = c.get("/v1/vote", headers=H(a["token"])).json()
        assert g["round"]["id"] == n["id"] and g["mine"] == []
        assert g["last"]["id"] == rid and g["last"]["up"][0] == {"key": "elem:fire", "n": 1} and g["last"]["voters"] == 1
        assert c.put("/v1/vote", json=body, headers=H(a["token"])).status_code == 409


def test_vote_merge_and_delete():
    with TestClient(app) as c:
        rid = c.get("/v1/vote").json()["round"]["id"]
        a = auth(c, "vote-pc-00001").json()
        b = auth(c, "vote-ph-00001").json()
        for dev, t in (("vote-pc-00001", a), ("vote-ph-00001", b)):
            base.post_run(c, device=dev, wave=9, headers=H(t["token"]))
        c.put("/v1/vote", json={"round": rid, "votes": [{"key": "elem:ice", "dir": "up"}]}, headers=H(b["token"]))
        # b를 a에 합치면 a에 표가 없으니 b 표가 옮겨 간다
        from app.db import Account, SessionLocal
        from app import accounts
        db = SessionLocal()
        accounts.merge_accounts(db, db.get(Account, b["account"]), db.get(Account, a["account"]))
        db.commit()
        db.close()
        g = c.get("/v1/vote", headers=H(a["token"])).json()
        assert [v["key"] for v in g["mine"]] == ["elem:ice"]
        assert c.delete("/v1/account", headers=H(a["token"])).status_code == 200
        assert "elem:ice" not in {r["key"] for r in c.get("/admin/api/votes", headers=A).json()["rows"]}


def test_clean_note():
    assert votes.clean_note("a\x00b  c") == "ab c"
    assert votes.clean_note("http://x") == ""
    assert len(votes.clean_note("가" * 3 + "나" * 100)) <= votes.NOTE_MAX
