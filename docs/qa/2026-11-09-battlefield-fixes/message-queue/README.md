# I-15 메시지큐 고갈 진단

**재현·원인·제품 수정은 미확정이다.** [최초 고갈](../accessibility/fuzz-oom.json)의 입력 순서가 없어 동일 실행을 복원하지 못했다. 추가로 원래 fuzz 8회와 계측 fuzz 2회를 완료했고 같은 고갈은 관찰하지 못했다. 이후 성공을 해결 증거로 쓰지 않는다. 제품 변경·큐 한도 증가·검사 완화는 없다.

[가설·반증 조건](plan.json), [측정 요약·소스 검증·제한](summary.json). 네 가지 가설은 특정 입력의 레이아웃 순환, 엔진의 객체 수명/지연 콜백, 병렬 저장 공유, 난수/시간/실행 순서다. 아직 어느 것도 원인으로 확정하거나 배제하지 않았다.

## 원래 fuzz의 저장 공유 비교

`tools/run.sh fuzz`는 사본 하나에서 병렬 프로세스를 띄워 같은 `user://`를 사용한다. 다른 실행과는 격리되지만 같은 묶음 안에서는 저장을 공유한다. 재시작 시 상태 혼입 가능성이라는 가설이다. 제품 오류나 I-15의 원인이라는 증거는 아니다.

원래 `tools/fuzz.gd`와 `VirtualInput`을 바꾸지 않고 같은 제품 소스에서 두 묶음을 순서대로 측정했다. 명목 시드1–4, 각3,000프레임, headless/fixed-fps60, 묶음 안4개 병렬이다. 최소 프로젝트 사본·빈 온라인 URL을 사용했다. [전체 실행·PID·exit·해시](cohorts-01/run.json).

| 저장 격리 | 완료/exit0 | 큐 고갈 | 그 밖의 실행 실패 |
|---|---:|---:|---:|
| 묶음 안 공유 | 4/4 | 0 | 0 |
| 프로세스마다 개별 | 4/4 | 0 | 0 |

원본 로그: 공유 [1](cohorts-01/shared/1/raw.log)·[2](cohorts-01/shared/2/raw.log)·[3](cohorts-01/shared/3/raw.log)·[4](cohorts-01/shared/4/raw.log), 개별 [1](cohorts-01/per-worker/1/raw.log)·[2](cohorts-01/per-worker/2/raw.log)·[3](cohorts-01/per-worker/3/raw.log)·[4](cohorts-01/per-worker/4/raw.log). 0/4 대 0/4로 드문 경합을 배제할 수 없다. 일부 ObjectDB2 종료 경고는 원본 그대로다.

## 네이티브 디버거 제한

설치된 `lldb-dap`으로 소유한 격리 Godot 프로세스의 launch를 요청했지만 macOS가 `Not allowed to attach to process`로 거부했다. [응답 원문](dap-01/dap.jsonl), [정리·결과](dap-01/run.json). adapter는 종료됐고 breakpoint 설정·실행 중지·스택/레지스터/주소 관찰은 진행되지 않았다. 권한이나 보호 설정은 바꾸지 않았다.

DAP 로그 보존 한도와 소유 프로세스 정리를 보강한 뒤 [두 번째 실행](dap-02/run.json)도 같은 연결 거부였다. [응답](dap-02/dap.jsonl), 남은 소유 프로세스0·adapter 종료·임시 프로젝트/저장 제거를 확인했다. 네이티브 fault 수집 분기는 검증되지 않았다.

별도 [정적 image lookup](symbols.json)에서도 두 함수의 일치 심볼을 찾지 못했다. 이는 현재 배포 바이너리의 심볼 관찰 한계이며 함수 부재의 증거가 아니다. 원래 충돌 로그의 근처 심볼 이름을 정확한 원인 함수로 해석하지 않는다.

## 다음 발생을 위한 계측

[실행 도구](run_trace.py)가 임시 사본에만 [관찰자](trace.gd)와 [fuzz 파생 도구](fuzz_trace.gd)를 추가한다. 임시 `VirtualInput.send()`의 좌표 변환 직전 논리 입력과 fuzz의 직접 취소 신호 호출을 기록한다. 저장소의 기존 `send()`나 제품70개 스크립트는 수정하지 않았다.

- 입력 종류·좌표·수정키·버튼·키·touch 상태, 연속 입력 번호, 프레임·단조 시간.
- 프레임 전후의 일부 진행 상태·실제 UI 배율/모드와 큐 high-water monitor. 현재 점유량·RSS 측정은 아니다.
- `minimum_size_changed` 누계와 같은 관찰 프레임의64/128/256회 변화 지점. 관찰자는 최소 크기를 조회하거나 크기·난수를 변경하지 않는다.
- 매 기록 flush, trace32MiB 한도, stdout1MiB 보존 한도. 고갈 문자열 관찰 시 해당 자식만 종료하고 자연 충돌과 구분한다. 이 고갈 시 중지 분기는 이번 성공 실행에서 발동하지 않았다.

[합성 monitor 대조](monitor-controls.json)는 별도 Python 자식의2MiB 출력 중1MiB만 보존하고, 두 pipe read로 나뉜 고갈 문자열을 감지해 해당 자식을 종료함을 확인했다. 실제 Godot 충돌 재현과 구분한다. 합성 대량 출력 원본도 로컬 보존한다.

수정한 관찰자로 시드2·4를 각각3,000프레임 실행했다. [시드2 로그](trace-02/2/raw.log), [시드4 로그](trace-02/4/raw.log). 입력6,212개, 직접 취소4개, 각3,000개의 프레임 전/후 기록이 연속이었다. 큐 high-water32,768바이트,64회 이상 단일 관찰 프레임의 Control 변화는 없었다. 일반적인 누적 inspector 변경을 I-15 순환의 증거로 보지 않는다.

두 실행 모두 첫 process 프레임의 모드 목록이 비어 있었다. 시작 `FUZZR`에 출력한 모드와 실제 진행 중 상태가 다르므로 시작 로그만으로 특정 모드를 검증했다고 주장하지 않는다. 초기화/설정 재읽기와 headless 첫 판 처리는 관찰된 상태를 바꿀 수 있다. 도구의 기존 설정 순서는 이번 진단에서 바꾸지 않았다.

**정확한 replay는 아니다.** 전역 RNG 상태·전체 게임 필드·OS 입력·실제 지연 콜백 순서는 기록하지 않는다. 관찰자의 JSONL 쓰기와 flush는 실행 시간을 바꾼다. 원래 고갈을 재현하지 못한 이번 기록을 수정 검증으로 사용하지 않는다. 전체 trace와 첫 시도 원자료는 로컬 보존하고, 공개 요약에 경로·바이트·SHA와 표본을 남겼다.

첫 계측은 씬 준비 전 화면 크기를 조회해 관찰자 오류를 냈다. [오류 원문](trace-01/2/raw.log). 엔진은3,000프레임/exit0이었지만 통과에서 제외했다. 준비 상태 확인을 추가한 뒤 새 폴더 `trace-02`로 재검증했으며 기존 실패를 덮어쓰지 않았다.

## 재실행과 잔여 작업

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/message-queue/run.py --output /tmp/bindu-mq-cohorts-new
python3 docs/qa/2026-11-09-battlefield-fixes/message-queue/run_dap.py --output /tmp/bindu-mq-dap-new
python3 docs/qa/2026-11-09-battlefield-fixes/message-queue/run_trace.py --output /tmp/bindu-mq-trace-new
```

새 출력 경로를 사용한다. 디버거 연결 거부도 유효한 진단 결과로 기록하며 보호를 우회하지 않는다. 모든 도구는 소유 자식·고유 QA 저장·임시 프로젝트만 정리한다. [이번 실제 소스/로그](summary.json)의 정리 결과를 확인했다. 제품 변경이 없어 이전 제품 회귀를 반복하지 않았고 추가 측정 범위를 위에 한정했다.

다음은 기록한 입력/실제 설정으로 재현 범위를 좁히고, 권한·심볼이 갖춰진 디버거에서 고갈 직전 큐와 호출자를 관찰하는 일이다. I-15, 전체 접근성 탐색, 고배속 전체 지연, 실기기·사람 과제는 미완료다. 사용자 지시대로 작업별 로컬 커밋만 쌓고 최신 main pull → rebase → push·PR 갱신은 전체 작업 마지막에 한 번 수행한다.
