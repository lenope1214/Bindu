# 점검 도구

게임을 바꾼 뒤 결과가 어떻게 달라졌는지 같은 방법으로 다시 재기 위한 스크립트. 모두 헤드리스 Godot으로 돌고, 프로젝트를 임시 폴더에 복사해서 실제 게임의 기록·이어하기 파일은 건드리지 않는다.

```
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh bots 1 32
```

| 명령 | 하는 일 | 출력 |
|---|---|---|
| `bots [규칙] [판 수] [stack]` | 자동 플레이 봇(시드 1~N). `stack`은 한 오브젝트에 몰아 넣기 | 도달 웨이브 중간값·평균·최소·최대, 죽은 웨이브 분포 |
| `long [규칙] [맵] [웨이브]` | 죽지 않는 봇으로 그 웨이브까지 | 웨이브가 4분 넘게 안 끝나면 `STUCK`과 그때 구체·오브젝트 상태 |
| `cont [규칙] [맵] [웨이브]` | 4웨이브마다 게임을 끄고 이어하기 | 저장 전후 상태가 다르면 `DIFF` |
| `fuzz [판 수] [프레임]` | 무작위 클릭·끌기·키·터치 (`GARDEN=1`이면 정원 판, 홀수 시드는 물러남까지) | 시드별 스크립트 오류 수 |
| `tree [규칙] [판 수]` | 같은 시드로 씨앗 나무 없음·절반·전부 봇 (봇에 직접 켜려면 `TREE=half\|full`) | 셋의 중간값·평균·죽은 웨이브 분포 (목표: 전부도 중간값 +4 이내) |
| `garden [시드 수] [웨이브]` | 정원 봇(`garden_bot.gd`): 상점에서 싼 것부터 사서 놓고 자동 웨이브. `REBIRTHS=n` 환생 n번으로 시작, `MINS` 실제 시간 제한 | 웨이브마다 이슬·오브젝트·게임 시간, 물러남(`RETREAT`), 끝에 `RESULT`·숙련 |
| `elem` | 속성마다 직선탄 Lv2 하나가 30초간 준 피해/초 | 속성별 피해/초·통과 시간 |
| `rx` | 특수 반응마다 두 속성 Lv1 직선탄 하나 앞을 구체 무리(초당 3개, 폭 ±50)가 30초 지나갈 때. `RX=bell,styx`로 골라 보기, `SOLO=1`이면 반응 대신 속성 하나(Lv2)씩 | 반응 피해/초(rx)·전체 피해/초(all). 구체가 죽지 않아 처치로 터지는 효과(저주·혼불 일부)는 빠짐 |
| `compare` | 같은 시드로 기준 규칙과 새 규칙을 32판씩 (`stack`을 붙이면 몰빵 봇) | 두 규칙의 중간값·평균·상위 25% 판 평균(참고), 차이, 판정(어려움: 중간값 -2 이하 또는 평균 x0.85 미만 / 쉬움: +3 이상 또는 x1.25 초과 / 비슷함) |
| `modes` | `modes [규칙=1] [판 수=32] [모드...]`: 모드마다 같은 시드로 모드 없는 판과 비교 (모드를 쉼표로 이으면 함께 켬). 봇에 모드를 켜려면 환경 변수 `MODES=rush,steel` | 모드별 웨이브 중간값·평균 차이와 점수 손익분기 배율 (`docs/modes.md`) |
| `pat_dps.gd` | `godot --headless --fixed-fps 60 --path . -s tools/pat_dps.gd` (`PAT=lob,shot` `PLV=3` `ELEM=<번호>`): 공격방식마다 오브젝트 하나(속성 Lv1) 앞을 죽지 않는 무리가 30초 가로지를 때(cross)·정면으로 올 때(head) | 공격방식별 피해/초 |
| `pat_kill.gd` | 같은 방법(`HP=15` `RATE=1`): 체력 HP 구체가 정면으로 60초 올 때(lane). spiral은 비껴 도는 길이 오브젝트 앞을 지나지 않는 경우가 많아 참고만 | 공격방식별 처치율 |
| `path_test.gd` | `godot --headless --path . -s tools/path_test.gd`: 그린 궤적 넣기·그리기(꺾기·길이 제한)·길 따라 맞히기·레벨업 길이와 갈래·4개 상한·유도 차단·저장·대격변·등장 비율 | 항목별 ok/FAIL, 실패가 있으면 끝 코드 1 |
| `path_shot.gd` | `xvfb-run godot --rendering-driver opengl3 --path . -s tools/path_shot.gd -- <폴더> [글자 크기] [touch]`: 그린 궤적 카드·그리는 중·다 씀·쉬는 시간·마우스 올림·웨이브 중·새 갈래 스크린샷 | PNG |
| `vary_shot.gd` | `xvfb-run godot --path . -s tools/vary_shot.gd -- <폴더> [글자 크기] [touch]`: 판마다 다른 흐름 점수 줄 칩 말풍선(이벤트·예고·봉인·적응) 스크린샷 | PNG |
| `mp_signal.gd` | `godot --headless -s tools/mp_signal.gd -- [포트=8790]`: 멀티플레이 중개 Worker(server/mp-worker)와 같은 약속의 로컬 서버. 게임·도구는 `BINDU_MP_URL=http://127.0.0.1:8790` | 로그 |
| `mp_conn_test.gd` | 두 프로세스로 `-- host <코드 파일>` / `-- join <코드 파일>` (BINDU_MP_URL 필요): WebRTC로 이어져 메시지를 주고받는지 | `MPCONN ok` / `MPCONN FAIL` |
| `mp_play.gd` | 두(이상) 프로세스로 봇 판: `MP_ROLE=host\|join MP_MODE=vs\|coop MP_FILE=<코드 파일> MP_WAVES=8 MP_N=<참가 인원>` + BINDU_MP_URL. 대결은 웨이브마다 진입 방향이 같은지, 협동은 웨이브·점수·오브젝트가 같은지 | 웨이브마다 `MPW`·`MPDEALT`(주인별 피해), 끝에 `MPPLAY` |
| `mp_shot.gd` | `xvfb-run godot --rendering-driver opengl3 --path . -s tools/mp_shot.gd -- <폴더> [글자 크기] [touch] [vs\|coop]`: 연결 없이 상태만 채워 시작 버튼·방 화면·상태 줄·웨이브·끝 화면 스크린샷 | PNG |
| `vote_shot.gd` | `xvfb-run godot --rendering-driver opengl3 --path <사본> -s tools/vote_shot.gd -- <폴더> [글자 크기] [touch] [phone]`: 서버 없이 응답을 채워 시작 화면 [투표]·투표 창(표·개선 의견·표 다 씀·지난 회차 결과)·판 끝 화면 버튼·이번 판 탭 스크린샷. 사본의 online_config SERVER_URL은 http://127.0.0.1:9로 | PNG |
| `spec` | [docs/features.md](../docs/features.md)에서 검사가 spec인 기능마다 기대 동작을 확인(tools/spec_check.gd), 끝에 문서와 대조 | 기능별 ok/FAIL, 실패가 있으면 끝 코드 1 |
| `check` | 배포 전 한 번에: spec + 그린 궤적 + 무작위 입력 4판 + 이어하기 13웨이브 + 온라인 서명 + 패치 키 + 서버 pytest(패키지가 있을 때). 4~5분 | `CHECK 통과` / `CHECK 실패: <항목>`, 끝 코드 |
| `patch_keys_check.gd` | `godot --headless --path . -s tools/patch_keys_check.gd`: 온라인 패치 rules의 오브젝트 수치 키(공격방식별 피해·속도·사거리, 강화·속성 수치, 규칙별 덮어쓰기)가 실제 값·설명 글에 먹는지 | 항목별 ok/FAIL, 끝 줄 `PATCHCHECK ok` |
| `gcheck` | 정원 점검(`garden_check.gd`, 빈 기록으로): 상점 값 치르기·웨이브와 이슬·물러남(웨이브 0 아래로 안 감)·저장 뒤 이어하기·꺼 둔 동안 보상(50%, 8시간)·환생(두 번 누르기, 씨앗)·씨앗 나무 사기·숙련 단계·일반 판 보너스와 ~grow 기록 키 | 항목별 ok/FAIL |
| `garden_shot.gd` | `xvfb-run godot --rendering-driver opengl3 --path . -s tools/garden_shot.gd -- <폴더> [글자 크기]`: 시작 화면 정원 줄·씨앗 나무 창·상점 4장·놓기·웨이브 중·물러난 뒤·특성 4장·리더보드 스크린샷 | PNG |
| `perf` | 후반 부하(오브젝트 16개, 속성 3종·강화 10개씩, 구체 400개)를 1·4·8배속으로 600프레임씩 | 프레임 시간 평균·95%·최대, 화면 위 구체·탄·장판 수 |

환경 변수: `SPEED`(배속, bots 4·long 8), `SMART`(기본 1: 사람처럼 중앙 가까이에서 길목 바깥쪽을 겨눠 배치, `SMART=0`은 예전 봇). `SKIP=n`: `SKIP_FROM`(기본 8)웨이브부터 웨이브 넘기기를 n개씩 쓰고, 멈추면 쌓인 것을 다 고른 뒤 다시 넘긴다.

봇은 쉬는 시간마다 진입 방향이 옮겨 가 아무 길목도 겨누지 않게 된 오브젝트를 비어 있는 길목으로 옮긴다(사람이 하듯이). 2026-10-30 판 길이 목표(중간값 12~15웨이브)는 이 봇 기준이다.

봇은 같은 시드여도 판마다 1~2웨이브 흔들린다. 비교할 때는 같은 판 수(32판 이상)로, 바꾸기 전 코드와 나란히 돌린다.

`perf`는 헤드리스라 실제 화면 그리기 비용은 빠지고, 이 컨테이너처럼 한글 글꼴이 없는 환경에서는 글자 모양 계산이 실제보다 훨씬 비싸게 나온다. 같은 기계에서 고치기 전후를 번갈아 두 번 이상 돌려 비교할 것(한 번은 ±3ms 흔들림).

`compare`의 "비슷함"은 봇 기준일 뿐이다. 버전 5(강화 칸)는 봇으로 중간값 -1·평균 x0.91(비슷함)이었지만 사람에겐 너무 어려워 폐기했다. 새 규칙은 [docs/rule-history.md](../docs/rule-history.md)의 절차대로 사람 시험판까지 거친다.

## 기능 명세와 배포 전 점검

모든 기능의 기대 동작은 [docs/features.md](../docs/features.md)에 한 줄씩 있고, 줄마다 무엇으로 확인하는지(spec·path·fuzz·cont·shot 등)가 짝지어져 있다. 배포 전에는 `tools/run.sh check`가 통과하고 `tools/shot.gd` 스크린샷에 문제가 없으면 된다. 기능을 바꾸면 그 줄과 `tools/spec_check.gd`의 같은 id 검사를 같은 커밋에서 고친다(문서와 검사가 어긋나면 `spec`이 실패한다).

## 패치노트

게임 안 패치노트는 `CHANGELOG.md`의 `## 제목 (vX.Y.Z)` 절을 그대로 쓴다. 빌드에는 .md가 들어가지 않아 `tools/gen_patch_notes.gd`가 `scripts/patch_notes_data.gd`를 만든다(빌드 스크립트가 내보내기 전에 자동으로 돌림). CHANGELOG를 고친 뒤 직접 돌리려면:

```
godot --headless --path . --script tools/gen_patch_notes.gd
```

인터넷이 되면 게임이 GitHub main의 `CHANGELOG.md`를 받아 빌드보다 새 버전 노트도 보여 준다. 그래서 새 버전 절은 push할 때 플레이어가 읽을 수 있는 말로 쓴다.

## 게임 안 업데이트

Windows [업데이트] 버튼(scripts/updater.gd)이 서버 서명을 확인하고 zip에서 exe를 꺼낼 수 있는지 점검:

```
godot --headless --path . -s tools/update_check.gd -- 공개키.pem 서명 Bindu-windows.zip 해시 크기
```

서명은 `server/app/main.py`의 `release_payload("windows", "9.9.9", "https://github.com/lenope1214/Bindu/releases/download/v9.9.9/Bindu-windows.zip", 해시, 크기)`를 `signing.sign`한 값. 실제 바꿔 끼우기(실행 중인 exe 이름 바꾸기·다시 켜기)는 Windows에서만 확인할 수 있다.
