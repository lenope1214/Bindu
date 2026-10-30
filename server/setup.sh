#!/bin/sh
# 처음 한 번: 비밀값·서명 키·게임 접속 설정을 만든다. 예) ./setup.sh https://bindu.example.com
set -e
cd "$(dirname "$0")"
[ -n "$1" ] || { echo "사용법: ./setup.sh <서버 주소>  (예: https://bindu.example.com, 로컬 시험: http://localhost:8000)"; exit 1; }
docker build -q -t bindu-server . >/dev/null
docker run --rm -v "$(pwd)/..:/repo" -w /repo/server -u "$(id -u):$(id -g)" bindu-server python tools/setup.py "$@"
