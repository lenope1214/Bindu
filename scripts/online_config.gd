class_name OnlineConfig
## server/tools/setup.py가 만든 접속 설정. 서버 주소를 비우면 온라인 기능이 꺼진다.
## 공개키·HMAC 키는 게임 안에 들어가는 값이라 비밀이 아니다 (서버 개인키·관리자 토큰은 server/.env·keys/).

const SERVER_URL := "https://bindu.anon-chat.kr"
const RUN_HMAC_KEY := "SZvKlp_IZXYoOcJH9TualCpV3KPr6CFO"
const PATCH_PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2okrtPWid5XRfIJpoCYQ
8RP4TFPBWC2MP+wTEYBMlpoYRrVLjJVQ3voMs7W0ixbN6A7KoV1TKogkDpCv96c5
hkik30OkIVMufoBs21Xg7v1vpaIlNuEGHTStkd6LNf3+CsJFHYVS9Z15ZrOTFOpW
n6kwO7jZEkOAmJRGk+tt86f9fL0rkkJu3vlD90mGiok0thavb7IlqmUm1Y94p5vX
tWrd+JX8zpajY+Q/HvgGpAekKgFFiyUBk22IBcmvCEdFW4bDIETzN3FgY23sDLGg
ipHcnnR3c40WqbOH2Evy06/gqmFlj2o7Iy52T2WrUWOlt3lGUhS0Gbazjvu2oT+j
qQIDAQAB
-----END PUBLIC KEY-----"""
