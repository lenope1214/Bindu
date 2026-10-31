"""0.5.5 업적·도감 수집: 진행 tally 합치기, 지난 판 카드로 수집 채우기, 칭호, 보유율."""
import test_api as base
import test_api_accounts as ta
from fastapi.testclient import TestClient

from app import progress
from app.main import app


def test_tally_merge_rules():
    a = ta.prog(tally={"dev-aaaaaaaa": {"pick:elem:fire": 3, "max:wave": 12}})
    b = ta.prog(tally={"dev-aaaaaaaa": {"pick:elem:fire": 1, "max:wave": 20, "rx_kills": 5}, "dev-bbbbbbbb": {"pick:pat:spray": 2}})
    m = progress.merge(progress.clean(a), progress.clean(b))
    assert m["tally"]["dev-aaaaaaaa"] == {"pick:elem:fire": 3, "max:wave": 20, "rx_kills": 5}
    assert m["tally"]["dev-bbbbbbbb"] == {"pick:pat:spray": 2}
    assert progress.merge(progress.clean(b), progress.clean(a)) == m
    # 예전 게임(tally 없음)도 그대로 읽는다
    old = progress.clean({k: v for k, v in ta.prog().items() if k != "tally"})
    assert old["tally"] == {}


def test_backfill_title_and_rates():
    with TestClient(app) as c:
        # 0.5.4로 한 판 (카드 기록 elem:fire·pat:spray 고름, 특성 power) → 0.5.5 첫 동기화 때 수집으로
        assert base.post_run(c, device="ach-dev-0001", game="0.5.4", wave=12).status_code == 200
        assert base.post_run(c, device="ach-dev-0001", game="0.5.5", wave=6).status_code == 200  # 0.5.5 판은 게임이 직접 셈
        tok = ta.auth(c, "ach-dev-0001").json()["token"]
        mine = ta.prog(best={"plain@v1": [12, 5000]}, ach=["first", "wave10", "boss25"],
                       tally={"ach-dev-0001": {"pick:elem:ice": 1}}, lww={"title": [100, "boss25"]})
        r = c.put("/v1/save", json={"data": mine}, headers=ta.H(tok)).json()
        past = r["data"]["tally"]["past-ach-dev-0001"]
        assert past.get("pick:elem:fire") == 1 and past.get("pick:pat:spray") == 1 and "pick:elem:ice" not in past
        # 다시 올려도 한 번만 채운다
        r2 = c.put("/v1/save", json={"data": mine}, headers=ta.H(tok)).json()
        assert r2["data"]["tally"]["past-ach-dev-0001"] == past
        # 칭호는 판 기록과 같이 리더보드에
        assert c.post("/admin/seasons", json={"name": "S-ach", "min_game": "0.5.5"}, headers=base.A).status_code == 200
        r = base.post_run(c, device="ach-dev-0001", nick="칭호맨", title="boss25", map="spiral", game="0.5.5", headers=ta.H(tok))
        assert r.status_code == 200 and r.json()["accepted"], r.text
        lb = c.get("/v1/leaderboard", params={"map": "spiral", "rules": 1, "season": r.json()["season"]}).json()
        top = [e for e in lb["entries"] if e["nick"] == "칭호맨"]
        assert top and top[0]["title"] == "boss25"
        assert base.post_run(c, device="ach-dev-0001", title="Bad Title").status_code == 422
        # 보유율: 5웨이브 이상 해 본 진행만 분모
        rt = c.get("/v1/ach_rates").json()
        assert rt["players"] >= 1 and 0 < rt["rates"]["boss25"] <= 1

