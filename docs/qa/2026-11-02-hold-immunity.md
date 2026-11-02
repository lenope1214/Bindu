# 붙잡기 면역 실패 회귀 검사

2026-11-02. 기준 커밋 `adb0183fb013719cb5f30e5785fcd532c03065e2`, 게임 설정 0.7.4.
macOS arm64, Godot 4.7.2.stable.official.ed1daf0bf, Python 3.13.9.

## 재현과 수정

범위 안 모든 구체가 기절·속박 면역이면 정지 적용은 실패하지만 기술 사용이 성공으로 처리되어 30초 쿨다운이 소모됐다.
`Orb.root()`는 면역일 때 false를 반환한다. 붙잡기가 이 반환값을 무시한 것이 원인이다.

대상 탐색 실패, 정지 적용 실패, 사용 결과 처리 오류를 구분해 검사했다. 기존 정상 구체·보스 적용 검사와 혼합 범위 검사는 수정 전에도 통과했고, 면역 상태에서만 정지 타이머 0인데 사용 성공·쿨다운 30초로 기록됐다.

이제 하나 이상 정지 적용에 성공해야 기술을 사용한 것으로 처리한다. 수동으로 전부 면역인 범위를 누르면 면역 안내와 조준을 유지하고, 자동 사용은 알림 없이 다시 시도한다. 범위 후보 탐색은 실제 거리와 생존 여부를 함께 확인한다.

## 수정 전후 비교

새 회귀 검사를 먼저 추가하고 수정 전 코드로 실행했다. 같은 검사 명령을 수정 후 다시 실행했다.

```sh
GODOT=/tmp/bindu-hold-qa/Godot.app/Contents/MacOS/Godot tools/run.sh spec
```

- 수정 전: 종료 코드 1, `SPEC 실패 (실패 5, 확인한 기능 173개)`.
  - 일반·보스 각각 직접 면역 및 연속 제어로 생긴 면역: 사용 true, 쿨다운 30초, 면역 안내 없음.
  - 자동 사용: 면역 중 쿨다운을 써서 면역 해제 후 바로 재시도하지 못함.
- 수정 후: 종료 코드 0, `SPEC 통과 (실패 0, 확인한 기능 173개)`.

| 시나리오 | 확인한 결과 |
|---|---|
| 기존 일반 구체·보스 | 일반 2초·보스 1초 정지 타이머, 쿨다운 30초 유지 |
| 직접 설정한 면역: 일반·보스 | 사용 false, 쿨다운 0, 사용 횟수 0, 성공 효과 없음, 면역 안내·조준 유지 |
| 3회 연속 제어 후 121프레임 경과: 일반·보스 | 실제 면역이 남고 정지가 풀린 상태에서 같은 실패 처리 |
| 죽은 구체·실제 범위 밖 면역 구체 | 쿨다운 없이 대상 없음 안내, 면역 안내 없음 |
| 면역·비면역 혼합, 두 탐색 순서 | 비면역 구체 모두 정지, 면역 구체는 그대로, 쿨다운·사용 횟수 한 번 |
| 자동 사용 후 면역 해제 | 면역 중 비용·안내 없음, 면역 해제 후 보스에 정상 적용 |

로그: `/tmp/bindu-hold-pr-qa/spec-before.log`, `spec-after.log`.

## 종합 검사

서버 개발 의존성을 설치한 가상환경에서 실행했다.

```sh
source /tmp/bindu-hold-pr-venv313/bin/activate
GODOT=/tmp/bindu-hold-qa/Godot.app/Contents/MacOS/Godot tools/run.sh check
```

- 통과: 기능 173개, 그린 궤적, 무작위 입력 4개 시드(오류 각각 0), 13웨이브 이어하기, 온라인 서명, 패치 키 적용, 정원 검사.
- 서버: `25 passed, 1 warning`.
- 전체 종료 코드 1: `CHECK 실패: rulekeys`.

수정하지 않은 기준 main에서 다음 명령을 실행해 기존 실패임을 확인했다(종료 코드 1).

```sh
VERIFY=1 GODOT=/tmp/bindu-hold-qa/Godot.app/Contents/MacOS/Godot tools/run.sh rulekeys
```

두 실행 모두 `FAIL rule keys: server/app/rule_keys.json이 오래됨 (tools/run.sh rulekeys)`.
이번 변경은 규칙 수치와 해당 생성 파일을 수정하지 않는다.
로그: `/tmp/bindu-hold-pr-qa/check.log`, `rulekeys-baseline.log`.

추가 실행: `python3 tools/notes_check.py` → `NOTES ok`; `tools/gen_patch_notes.gd` → 패치노트 72개·최신 0.7.4, 생성 파일 변경 없음; `git diff --check` → 종료 코드 0.

## 검증 범위

헤드리스에서 수동 조준·기술 실행·자동 사용 함수 경로를 검사했다. 실제 마우스 클릭·터치·화면 렌더링·기기·배포본은 미검증이다. 원래 VOC의 모든 발생 조건을 확인한 것은 아니다.
