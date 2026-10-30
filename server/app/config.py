"""환경 변수 설정. docker-compose의 .env에서 채운다 (tools/setup.py가 만들어 줌)."""
import os


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


DATABASE_URL = _env("DATABASE_URL", "sqlite:///./bindu.db")
# 관리자 API·통계 페이지 토큰
ADMIN_TOKEN = _env("ADMIN_TOKEN")
# 게임이 판 기록에 붙이는 HMAC 키 (게임 scripts/online_config.gd와 같은 값)
RUN_HMAC_KEY = _env("RUN_HMAC_KEY")
# 패치 서명용 RSA 개인키 (공개키는 게임에 들어감)
PATCH_KEY_PATH = _env("PATCH_KEY_PATH", "./keys/patch_private.pem")
# IP는 그대로 저장하지 않고 소금 친 해시만 (제출 빈도 제한용)
IP_SALT = _env("IP_SALT", "bindu")
# 같은 기기가 판 기록을 다시 보낼 수 있을 때까지 초
RUN_MIN_INTERVAL = float(_env("RUN_MIN_INTERVAL", "20"))
# IP 하나가 한 시간에 보낼 수 있는 판 기록 수
RUN_PER_IP_HOUR = int(_env("RUN_PER_IP_HOUR", "60"))
