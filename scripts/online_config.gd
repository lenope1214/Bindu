class_name OnlineConfig
## server/tools/setup.py가 만든 접속 설정. 서버 주소를 비우면 온라인 기능이 꺼진다.
## 공개키·HMAC 키는 게임 안에 들어가는 값이라 비밀이 아니다 (서버 개인키·관리자 토큰은 server/.env·keys/).

const SERVER_URL := ""
const RUN_HMAC_KEY := ""
const PATCH_PUBLIC_KEY := """"""
