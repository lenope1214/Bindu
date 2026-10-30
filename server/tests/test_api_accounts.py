import base64
import json
import random
import time

import test_api as base  # 환경 변수·앱·post_run을 같이 쓴다 (같은 DB)
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from fastapi.testclient import TestClient

from app import accounts, config, progress
from app.main import app

config.AUTH_TEST_PROVIDER = True


def auth(c, dev, secret="a" * 64, nick=""):
    return c.post("/v1/auth/device", json={"device": dev, "secret": secret, "nick": nick})


def H(tok):
    return {"Authorization": "Bearer " + tok}


def prog(**kw):
    d = progress.empty()
    d.update(kw)
    return d


def test_device_auth_and_backfill():
    with TestClient(app) as c:
        # 계정 없을 때(예전 게임) 남긴 판 기록
        assert base.post_run(c, device="acc-old-1", rules=3, patch=2, score=500).status_code == 200
        r = auth(c, "acc-old-1", nick="옛날")
        assert r.status_code == 200, r.text
        a = r.json()
        assert a["new"] and a["linked"] == [] and a["nick"] == "옛날"
        # 같은 기기·같은 비밀값: 같은 계정
        b = auth(c, "acc-old-1").json()
        assert b["account"] == a["account"] and not b["new"]
        # 기기 id만 알고 비밀값이 다르면 거부
        assert auth(c, "acc-old-1", secret="b" * 64).status_code == 403
        assert c.get("/v1/me", headers=H(a["token"])).json()["account"] == a["account"]
        assert c.get("/v1/me", headers=H(a["token"] + "x")).status_code == 401
        assert c.get("/v1/me").status_code == 401
        # 예전 기록이 계정으로 묶였고, 토큰으로 리더보드에서 내 순위가 보인다
        lb = c.get("/v1/leaderboard", params={"map": "plain", "rules": 3}, headers=H(a["token"])).json()
        assert lb["me"]["score"] == 500


def test_save_merge_and_link():
    with TestClient(app) as c:
        pa = auth(c, "acc-pc-0001").json()
        pb = auth(c, "acc-phone-01").json()
        assert pa["account"] != pb["account"]
        # 두 기기에서 따로 한 진행
        r = c.put("/v1/save", json={"data": prog(best={"plain@v1": [10, 3000]}, ach=["first", "wave10"], counts={"acc-pc-0001": [100, 3]},
                                                 lww={"tower_skin": [100, "hex"], "nick": [100, "피시"]})}, headers=H(pa["token"]))
        assert r.status_code == 200 and r.json()["rev"] == 1
        c.put("/v1/save", json={"data": prog(best={"plain@v1": [12, 2500], "spiral@v1": [5, 900]}, ach=["first", "boss"],
                                             counts={"acc-phone-01": [40, 2]}, lww={"tower_skin": [200, "gem"], "fav:elem:fire": [150, True]})},
              headers=H(pb["token"]))
        # 같은 것을 다시 올려도 rev는 그대로
        again = c.put("/v1/save", json={"data": prog(ach=["first"])}, headers=H(pa["token"])).json()
        assert again["rev"] == 1
        # 형식이 틀리면 거부
        assert c.put("/v1/save", json={"data": {"format": 99}}, headers=H(pa["token"])).status_code == 422
        # 소셜 연결: PC가 먼저 g-1을 붙이고, 폰이 같은 g-1로 로그인 → 폰 계정이 PC 계정에 합쳐짐
        la = c.post("/v1/auth/link", json={"provider": "test", "credential": "g-1"}, headers=H(pa["token"])).json()
        assert la["account"] == pa["account"] and la["linked"] == ["test"] and not la["merged"]
        lb = c.post("/v1/auth/link", json={"provider": "test", "credential": "g-1"}, headers=H(pb["token"])).json()
        assert lb["merged"] and lb["account"] == pa["account"]
        # 폰의 예전 토큰도 남은 계정으로 따라간다
        assert c.get("/v1/me", headers=H(pb["token"])).json()["account"] == pa["account"]
        # 폰 기기 인증도 이제 PC 계정
        assert auth(c, "acc-phone-01").json()["account"] == pa["account"]
        d = c.get("/v1/save", headers=H(lb["token"])).json()["data"]
        assert d["best"] == {"plain@v1": [12, 3000], "spiral@v1": [5, 900]}
        assert d["ach"] == ["boss", "first", "wave10"]
        assert d["counts"] == {"acc-pc-0001": [100, 3], "acc-phone-01": [40, 2]}
        assert d["lww"]["tower_skin"] == [200, "gem"] and d["lww"]["fav:elem:fire"] == [150, True]
        # 해제
        assert c.delete("/v1/auth/link/test", headers=H(lb["token"])).json()["linked"] == []


def test_runs_with_token_one_line_per_account():
    with TestClient(app) as c:
        a = auth(c, "acc-tok-0001").json()
        b = auth(c, "acc-tok-0002").json()
        c.post("/v1/auth/link", json={"provider": "test", "credential": "g-tok"}, headers=H(a["token"]))
        b = c.post("/v1/auth/link", json={"provider": "test", "credential": "g-tok"}, headers=H(b["token"])).json()
        for dev, tok, score in (("acc-tok-0001", a["token"], 4000), ("acc-tok-0002", b["token"], 6000)):
            r = base.post_run(c, headers=H(tok), device=dev, map="line", rules=3, patch=2, score=score, wave=9)
            assert r.status_code == 200, r.text
        board = c.get("/v1/leaderboard", params={"map": "line", "rules": 3}, headers=H(a["token"])).json()
        mine = [e for e in board["entries"] if e["me"]]
        assert len(mine) == 1 and mine[0]["score"] == 6000 and board["me"]["score"] == 6000
        # 다른 기기의 토큰을 붙인 기록은 계정에 넣지 않는다
        base.post_run(c, headers=H(a["token"]), device="acc-tok-other", map="line", rules=3, patch=2, score=99999)
        board = c.get("/v1/leaderboard", params={"map": "line", "rules": 3}, headers=H(a["token"])).json()
        assert board["me"]["score"] == 6000


def test_run_saves_move_between_devices():
    with TestClient(app) as c:
        a = auth(c, "acc-run-pc01").json()
        b = auth(c, "acc-run-ph01").json()
        c.post("/v1/auth/link", json={"provider": "test", "credential": "g-run"}, headers=H(a["token"]))
        b = c.post("/v1/auth/link", json={"provider": "test", "credential": "g-run"}, headers=H(b["token"])).json()
        rs = {"game": "0.5.3", "platform": "windows", "map": "line", "rules": 1, "wave": 12, "score": 4000, "data": "[run]\nwave=12\n"}
        assert c.put("/v1/save/runs/run-1", json=rs, headers=H(a["token"])).status_code == 200
        lst = c.get("/v1/save/runs", headers=H(b["token"])).json()
        assert [(x["run"], x["mine"], x["wave"]) for x in lst] == [("run-1", False, 12)]
        got = c.post("/v1/save/runs/run-1/claim", headers=H(b["token"])).json()
        assert got["data"] == rs["data"] and got["mine"]
        # 원래 기기는 더 못 올리고 못 지운다 (이어하기를 지우라는 뜻)
        assert c.put("/v1/save/runs/run-1", json=rs, headers=H(a["token"])).status_code == 409
        assert c.delete("/v1/save/runs/run-1", headers=H(a["token"])).status_code == 409
        assert c.put("/v1/save/runs/run-1", json={**rs, "wave": 13}, headers=H(b["token"])).status_code == 200
        assert c.delete("/v1/save/runs/run-1", headers=H(b["token"])).status_code == 200
        assert c.get("/v1/save/runs", headers=H(a["token"])).json() == []
        # 계정당 최대 수
        for i in range(accounts.RUN_SAVE_MAX + 2):
            c.put(f"/v1/save/runs/r{i}", json=rs, headers=H(a["token"]))
        assert len(c.get("/v1/save/runs", headers=H(a["token"])).json()) == accounts.RUN_SAVE_MAX


def test_delete_account():
    with TestClient(app) as c:
        a = auth(c, "acc-del-0001").json()
        c.put("/v1/save", json={"data": prog(ach=["first"])}, headers=H(a["token"]))
        assert c.delete("/v1/account", headers=H(a["token"])).json() == {"deleted": True}
        assert c.get("/v1/me", headers=H(a["token"])).status_code == 401
        n = auth(c, "acc-del-0001").json()
        assert n["new"] and n["account"] != a["account"]
        assert c.get("/v1/save", headers=H(n["token"])).json()["data"]["ach"] == []


def test_merge_is_order_free():
    rnd = random.Random(7)

    def rand():
        return progress.clean(prog(
            best={f"m{i}": [rnd.randint(0, 30), rnd.randint(0, 9999)] for i in range(rnd.randint(0, 4))},
            ach=[f"a{rnd.randint(0, 5)}" for _ in range(3)],
            counts={f"device-{rnd.randint(0, 3)}x": [rnd.randint(0, 99), rnd.randint(0, 9)]},
            lww={k: [rnd.randint(0, 3), rnd.choice(["x", "y", True, 3])] for k in ("map", "tower_skin", "fav:elem:fire") if rnd.random() < 0.7}))
    for _ in range(300):
        a, b, d = rand(), rand(), rand()
        assert progress.merge(a, b) == progress.merge(b, a)
        assert progress.merge(progress.merge(a, b), d) == progress.merge(a, progress.merge(b, d))
        assert progress.merge(a, a) == a
    # 모르는 키·기기 설정은 버린다
    c = progress.clean(prog(lww={"volume": [1, 0.5], "map": [1, "plain"]}, extra=1))
    assert c["lww"] == {"map": [1, "plain"]} and "extra" not in c


def _b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def test_google_id_token_verify():
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pn = key.public_key().public_numbers()
    url = accounts.PROVIDERS["google"]["jwks"]
    accounts._jwks[url] = (time.time(), {"k1": {"kty": "RSA", "kid": "k1", "n": _b64(pn.n.to_bytes(256, "big")), "e": _b64(pn.e.to_bytes(3, "big"))}})

    def tok(**claims):
        h = _b64(json.dumps({"alg": "RS256", "kid": "k1"}).encode())
        p = _b64(json.dumps({"iss": "https://accounts.google.com", "aud": "cid", "sub": "123", "exp": time.time() + 60, **claims}).encode())
        s = _b64(key.sign(f"{h}.{p}".encode(), padding.PKCS1v15(), hashes.SHA256()))
        return f"{h}.{p}.{s}"
    old = config.GOOGLE_CLIENT_IDS
    config.GOOGLE_CLIENT_IDS = ["cid"]
    try:
        assert accounts.verify_id_token("google", tok()) == "123"
        for bad in (tok(aud="other"), tok(exp=time.time() - 1), tok(iss="https://evil"), tok()[:-4] + "AAAA"):
            try:
                accounts.verify_id_token("google", bad)
                raise AssertionError("받으면 안 됨")
            except ValueError:
                pass
        with TestClient(app) as c:
            a = auth(c, "acc-goog-001").json()
            r = c.post("/v1/auth/link", json={"provider": "google", "credential": tok(sub="g-real")}, headers=H(a["token"])).json()
            assert r["linked"] == ["google"]
    finally:
        config.GOOGLE_CLIENT_IDS = old
    # 설정 안 한 수단은 501
    with TestClient(app) as c:
        a = auth(c, "acc-appl-001").json()
        assert c.post("/v1/auth/link", json={"provider": "apple", "credential": "x"}, headers=H(a["token"])).status_code == 501
