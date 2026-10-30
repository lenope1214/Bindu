"""처음 한 번: 비밀값(.env), 패치 서명 키, 게임 쪽 설정(scripts/online_config.gd)을 만든다.
이미 있는 .env·키는 덮어쓰지 않는다 (키를 바꾸면 이미 배포한 게임이 패치를 거부함).

    ./setup.sh https://bindu.example.com                 (Mac·Linux)
    server\\setup.ps1 https://bindu.example.com -Tunnel   (Windows, Cloudflare Tunnel)
"""
import argparse
import os
import re
import secrets
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from cryptography.hazmat.primitives import serialization  # noqa: E402

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # server/
ENV = os.path.join(HERE, ".env")
KEY = os.path.join(HERE, "keys", "patch_private.pem")
GAME_CFG = os.path.join(HERE, "..", "scripts", "online_config.gd")


def read_env() -> dict:
    out = {}
    if os.path.exists(ENV):
        for line in open(ENV, encoding="utf-8"):
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.rstrip("\n").split("=", 1)
                out[k.strip()] = v.strip()
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("url", help="게임이 접속할 서버 주소, 예: https://bindu.example.com (로컬 시험: http://localhost:8000)")
    ap.add_argument("--tunnel", action="store_true", help="Cloudflare Tunnel 뒤에서 실행 (Caddy는 80 포트 HTTP만, 인증서는 Cloudflare가)")
    args = ap.parse_args()
    url = args.url.rstrip("/")
    env = read_env()
    m = re.match(r"https?://([^/:]+)", url)
    defaults = {
        "DOMAIN": m.group(1) if m else "localhost",
        "ADMIN_TOKEN": secrets.token_urlsafe(24),
        "RUN_HMAC_KEY": secrets.token_urlsafe(24),
        "IP_SALT": secrets.token_urlsafe(12),
        "POSTGRES_PASSWORD": secrets.token_urlsafe(18),
    }
    added = [k for k in defaults if k not in env]
    for k in added:
        env[k] = defaults[k]
    if args.tunnel:
        env["DOMAIN"] = ":80"
    elif env.get("DOMAIN") == ":80":
        env["DOMAIN"] = defaults["DOMAIN"]
    with open(ENV, "w", encoding="utf-8") as f:
        f.write("# tools/setup.py가 만든 비밀값. git에 올리지 않는다.\n")
        for k, v in env.items():
            f.write(f"{k}={v}\n")
    os.chmod(ENV, 0o600)

    from app.signing import generate_keypair, public_pem
    if os.path.exists(KEY):
        with open(KEY, "rb") as f:
            pub = public_pem(serialization.load_pem_private_key(f.read(), password=None))
        print("패치 서명 키: 기존 키 사용")
    else:
        pub = generate_keypair(KEY)
        print("패치 서명 키: 새로 만듦 →", KEY)

    with open(GAME_CFG, "w", encoding="utf-8") as f:
        f.write("class_name OnlineConfig\n")
        f.write("## server/tools/setup.py가 만든 접속 설정. 서버 주소를 비우면 온라인 기능이 꺼진다.\n")
        f.write("## 공개키·HMAC 키는 게임 안에 들어가는 값이라 비밀이 아니다 (서버 개인키·관리자 토큰은 server/.env·keys/).\n\n")
        f.write(f'const SERVER_URL := "{url}"\n')
        f.write(f'const RUN_HMAC_KEY := "{env["RUN_HMAC_KEY"]}"\n')
        f.write('const PATCH_PUBLIC_KEY := """' + pub.strip() + '"""\n')
    print("게임 설정: scripts/online_config.gd 저장 (커밋해서 빌드에 넣기)")
    if added:
        print(".env에 새로 넣은 값:", ", ".join(added))
    print("관리자 토큰:", env["ADMIN_TOKEN"])


if __name__ == "__main__":
    main()
