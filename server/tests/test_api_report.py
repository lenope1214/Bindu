import test_api as base  # 환경 변수·앱·post_run을 같이 쓴다 (같은 DB)
from fastapi.testclient import TestClient

from app import reports
from app.main import app, clean_nick
from test_api_accounts import H, auth

A = base.A


def test_bad_nick():
    assert reports.bad_nick("시 발") and reports.bad_nick("FuCk_you") and reports.bad_nick("개1새끼") and reports.bad_nick("운영자")
    assert not reports.bad_nick("별빛") and not reports.bad_nick("Tester") and not reports.bad_nick("grape") and not reports.bad_nick("")
    assert clean_nick("씨발놈", "abcd1234") == "익명-abcd" and clean_nick("빈두고수", "abcd1234") == "빈두고수"


def test_report_flow():
    with TestClient(app) as c:
        boot = c.get("/v1/boot", params={"game": "0.7.2"}).json()
        assert boot["report"] is True
        pt = boot["patch"]["id"]
        bad = auth(c, "rep-dev-0001", nick="좋은이름").json()
        me = auth(c, "rep-dev-0002").json()
        assert len(bad["pid"]) == 16 and bad["pid"] != me["pid"]
        assert base.post_run(c, device="rep-dev-0001", nick="좋은이름", map="plain", game="0.7.2", patch=pt, headers=H(bad["token"])).status_code == 200
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "limit": 100}, headers=H(me["token"])).json()
        row = next(e for e in lb["entries"] if e["nick"] == "좋은이름")
        assert row["pid"] == bad["pid"]
        # 나쁜 이름으로 바꾸려 하면 익명으로 저장
        base.post_run(c, device="rep-dev-0001", nick="병신", wave=3, map="plain", game="0.7.2", patch=pt, headers=H(bad["token"]))
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "limit": 100}).json()
        assert not any(e["nick"] == "병신" for e in lb["entries"])
        # 신고: 토큰 필요, 자기 자신 안 됨, 같은 신고는 하나로
        body = {"pid": bad["pid"], "nick": "좋은이름", "where": "board", "reason": "nick"}
        assert c.post("/v1/reports", json=body).status_code == 401
        assert c.post("/v1/reports", json=body, headers=H(bad["token"])).status_code == 422
        assert c.post("/v1/reports", json=body, headers=H(me["token"])).status_code == 200
        assert c.post("/v1/reports", json=body, headers=H(me["token"])).status_code == 200
        rs = c.get("/admin/api/reports", headers=A).json()
        mine = [r for r in rs if r["nick"] == "좋은이름"]
        assert len(mine) == 1 and mine[0]["target"] == bad["account"] and mine[0]["reporters"] == 1
        assert c.get("/admin/api/reports").status_code == 401
        # 이름 지우기 → 익명, 신고 닫힘
        assert c.post(f"/admin/reports/{mine[0]['id']}", json={"action": "rename"}, headers=A).json()["status"] == "renamed"
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "limit": 100}).json()
        assert any(e["nick"] == "익명-rep-" and e["pid"] == bad["pid"] for e in lb["entries"])
        assert not [r for r in c.get("/admin/api/reports", headers=A).json() if r["id"] == mine[0]["id"]]
        # 다시 신고 → 차단하면 리더보드에서 빠짐
        c.post("/v1/reports", json={**body, "where": "mp"}, headers=H(me["token"]))
        rid = c.get("/admin/api/reports", headers=A).json()[0]["id"]
        assert c.post(f"/admin/reports/{rid}", json={"action": "ban"}, headers=A).json()["status"] == "banned"
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 1, "limit": 100}).json()
        assert not any(e["pid"] == bad["pid"] for e in lb["entries"])
