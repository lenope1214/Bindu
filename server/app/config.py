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
# 오류 로그: 기기 하나·IP 하나가 한 시간에 보낼 수 있는 줄 수, 보관 일수
LOG_PER_DEVICE_HOUR = int(_env("LOG_PER_DEVICE_HOUR", "100"))
LOG_PER_IP_HOUR = int(_env("LOG_PER_IP_HOUR", "300"))
LOG_KEEP_DAYS = int(_env("LOG_KEEP_DAYS", "30"))
# 통계: 이 웨이브에 못 미친 판은 밸런스 통계(선택률·구성·피해 몫 등)에서 빼고 이탈 통계로만 센다 (기록은 그대로 둠)
STATS_MIN_WAVE = int(_env("STATS_MIN_WAVE", "5"))
# 계정 토큰 서명 키. 비우면 ADMIN_TOKEN에서 만든다 (예전 .env 그대로 써도 되게)
AUTH_SECRET = _env("AUTH_SECRET")
AUTH_TOKEN_DAYS = int(_env("AUTH_TOKEN_DAYS", "30"))
# IP 하나가 한 시간에 새로 만들 수 있는 계정 수
AUTH_NEW_PER_IP_HOUR = int(_env("AUTH_NEW_PER_IP_HOUR", "20"))
# 소셜 로그인: 받을 클라이언트 id (쉼표로 여러 개). 비면 그 수단은 아직 안 받음
GOOGLE_CLIENT_IDS = [x for x in _env("GOOGLE_CLIENT_IDS").split(",") if x.strip()]
APPLE_CLIENT_IDS = [x for x in _env("APPLE_CLIENT_IDS").split(",") if x.strip()]
# 시험용 가짜 로그인 수단 (credential을 그대로 subject로). 운영에서는 끈다
AUTH_TEST_PROVIDER = _env("AUTH_TEST_PROVIDER") == "1"
