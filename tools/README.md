# 점검 도구

게임을 바꾼 뒤 결과가 어떻게 달라졌는지 같은 방법으로 다시 재기 위한 스크립트. 기능·플레이 검사는 헤드리스, 화면·입력 검사는 native 렌더러로 돌린다. 프로젝트를 임시 폴더에 복사해서 실제 게임의 기록·이어하기 파일은 건드리지 않는다.

```
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh bots 1 32
```

UI 자동화는 아래 실행기를 사용한다. 사본에 시작 전 `no_focus`·최소화를 설정하고, 온라인 주소를 비운다. OS 창은 최소화한 채 별도 Viewport에 입력을 주입해 클릭·드래그·터치·휠·수정키를 실제 게임 GUI 경로로 보낸다. 사용자의 커서나 전면 앱을 바꾸지 않는다. 창의 물리 해상도와 논리 좌표를 분리해 큰 글자·폰 화면에서도 좌표를 맞춘다.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui carry_check.gd /tmp/carry 1.0
RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui carry_check.gd /tmp/carry-phone 1.3 phone
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui shot.gd /tmp/screens 1.3
```

출력 폴더는 절대 경로를 사용한다. `godot -s`로 원본 프로젝트에서 UI 검사를 직접 실행하지 않는다. `virtual_input.gd`가 입력·좌표 변환을 공용으로 처리하며 OS 커서 이동·전면 활성화 호출은 spec에서 금지한다. OS 자체의 포커스 전환·드라이버·실기기 입력은 이 검사의 범위가 아니다.

| 명령 | 하는 일 | 출력 |
|---|---|---|
| `bots [규칙] [판 수] [stack]` | 자동 플레이 봇(시드 1~N). `stack`은 한 오브젝트에 몰아 넣기 | 도달 웨이브 중간값·평균·최소·최대, 죽은 웨이브 분포 |
| `long [규칙] [맵] [웨이브]` | 죽지 않는 봇으로 그 웨이브까지 | 웨이브가 4분 넘게 안 끝나면 `STUCK`과 그때 구체·오브젝트 상태 |
| `cont [규칙] [맵] [웨이브]` | 4웨이브마다 게임을 끄고 이어하기, 비교 뒤 새 길목으로 재배치 | 저장 전후 상태가 다르면 `DIFF` |
| `fuzz [판 수] [프레임]` | 무작위 클릭·끌기·키·터치 | 시드별 스크립트 오류 수 |
| `elem` | 속성마다 직선탄 Lv2 하나가 30초간 준 피해/초 | 속성별 피해/초·통과 시간 |
| `rx` | 특수 반응마다 두 속성 Lv1 직선탄 하나 앞을 구체 무리(초당 3개, 폭 ±50)가 30초 지나갈 때. `RX=bell,styx`로 골라 보기, `SOLO=1`이면 반응 대신 속성 하나(Lv2)씩 | 반응 피해/초(rx)·전체 피해/초(all). 구체가 죽지 않아 처치로 터지는 효과(저주·혼불 일부)는 빠짐 |
| `compare` | 같은 시드로 기준 규칙과 새 규칙을 32판씩 (`stack`을 붙이면 몰빵 봇) | 두 규칙의 중간값·평균·상위 25% 판 평균(참고), 차이, 판정(어려움: 중간값 -2 이하 또는 평균 x0.85 미만 / 쉬움: +3 이상 또는 x1.25 초과 / 비슷함) |
| `modes` | `modes [규칙=1] [판 수=32] [모드...]`: 모드마다 같은 시드로 모드 없는 판과 비교 (모드를 쉼표로 이으면 함께 켬). 봇에 모드를 켜려면 환경 변수 `MODES=rush,steel` | 모드별 웨이브 중간값·평균 차이와 점수 손익분기 배율 (`docs/modes.md`) |
| `pat_dps.gd` | `godot --headless --fixed-fps 60 --path . -s tools/pat_dps.gd` (`PAT=lob,shot` `PLV=3` `ELEM=<번호>`): 공격방식마다 오브젝트 하나(속성 Lv1) 앞을 죽지 않는 무리가 30초 가로지를 때(cross)·정면으로 올 때(head) | 공격방식별 피해/초 |
| `miss_audit.gd` | `tools/run.sh miss` (`PAT=shot,laser` `KIND=fast`): 공격방식 x 강화 하나 x 다중 발사 0~3개마다 정면(조준한 그 방향)에 멈춘 구체를 거리 90~440에 두고 4초 피해. 사거리 안인데 0이거나 가장 잘 맞힌 거리의 15% 미만이면 `MISS` | 피해가 안 들어가는 조합 전수조사 |
| `pat_kill.gd` | 같은 방법(`HP=15` `RATE=1`): 체력 HP 구체가 정면으로 60초 올 때(lane). spiral은 비껴 도는 길이 오브젝트 앞을 지나지 않는 경우가 많아 참고만 | 공격방식별 처치율 |
| `ui_check.gd` | 스크린샷 도구(shot·mp_shot·vote_shot·path_shot·vary_shot·ui_audit)가 찍을 때마다 부름: 보이는 글·버튼·창·그림 배지끼리 겹침, 화면(폰은 안전 영역) 밖, 말줄임으로 잘린 글 | `UI OVERLAP/OFFSCREEN/CLIP <화면> …`, 없으면 `UI ok <화면>` |
| `ui_audit.gd` | `tools/run.sh ui ui_audit.gd <폴더> [글자 크기] [touch] [phone]`: 일곱 길목(점수 줄·DPS 표·버튼·웨이브 시작·안내 쪽)·큰 점수·오브젝트 14개·특성 8개·놓친 구체·긴 알림으로 꽉 채운 쉬는 시간·카드·웨이브 화면. `RESOLUTION`으로 화면비(2400x1080 20:9, 2048x1536 4:3 등), phone이면 노치 안전 영역도 흉내 | PNG + `UI BAD <수>` |
| `reflex_shot.gd` | `tools/run.sh ui reflex_shot.gd <출력 폴더> [글자 크기=1.3] [touch]`: 반응 카드 앞면·상세·후방 공격. 프로젝트 이름이 BinduTools로 시작하는 사본에서만 실행 | PNG 3장 + UI 검사 + 후방 조준·명중 검증 |
| `vary_shot.gd` | `tools/run.sh ui vary_shot.gd <폴더> [글자 크기] [touch]`: 판마다 다른 흐름 점수 줄 칩 말풍선(이벤트·예고·봉인·적응) 스크린샷 | PNG |
| `tip_shot.gd` | `tools/run.sh ui tip_shot.gd <폴더> [글자 크기] [touch] [phone]`: 별 넷·바람 곁의 행성(별+영혼 혼불)에 올린 오브젝트 정보창 기본(tip_basic)·자세히(tip_detail) | PNG |
| `rank_shot.gd` | `tools/run.sh ui rank_shot.gd <폴더> [글자 크기] [touch] [phone]`: 오브젝트 7개에 피해를 나눠 준 뒤 1위 왕관·2·3위 메달·DPS 표 순위 색 (rank, 가운데 확대 rank_zoom) | PNG |
| `nova_shot.gd` | `tools/run.sh ui nova_shot.gd <폴더> [글자 크기] [touch]`: 초신성 그림(별·행성 게이지, 85% 예고 조준 고리, 다 참, 터지는 순간·퍼지는 중) | PNG |
| `late_shot.gd` | `tools/run.sh ui late_shot.gd <폴더> [글자 크기] [touch]`: 후반 구체 다섯 종 안내(100·500웨이브 배지)·전장 위 모양(깜빡 예고·갑옷 깨짐·치유 맥동·흐림·포식 입) | PNG |
| `board_shot.gd` | `tools/run.sh ui board_shot.gd <폴더> [글자 크기] [touch] [phone]`: 서버 없이 순위를 채워 리더보드 기본·이번 주·지난 시즌·빈 기록·신고·차단 창 스크린샷. 사본의 online_config SERVER_URL은 http://127.0.0.1:9로 | PNG |
| `map_shot.gd` | `tools/run.sh ui map_shot.gd <폴더> [글자 크기] [touch]`: 맵 규칙 준비 화면 맵 줄(맵 5개)·친화 카드 선택지·십자로 길목 띠·폭풍 바람 스크린샷 | PNG |
| `newelem_shot.gd` | `tools/run.sh ui newelem_shot.gd <폴더> [글자 크기] [touch] [phone]`: 새 속성 피·환영 카드 선택지·카드 자세히·출혈·현혹 표시와 핏자국 전장·정보창·도감 속성 탭 | PNG, `UI` 줄 |
| `mp_signal.gd` | `godot --headless -s tools/mp_signal.gd -- [포트=8790]`: 멀티플레이 중개 Worker(server/mp-worker)와 같은 약속의 로컬 서버. 게임·도구는 `BINDU_MP_URL=http://127.0.0.1:8790` | 로그 |
| `mp_conn_test.gd` | 두 프로세스로 `-- host <코드 파일>` / `-- join <코드 파일>` (BINDU_MP_URL 필요): WebRTC로 이어져 메시지를 주고받고 핑을 재는지 | `MPCONN ok ... ping=Nms` / `MPCONN FAIL` |
| `mp_play.gd` | 두(이상) 프로세스로 봇 판: `MP_ROLE=host\|join MP_MODE=vs\|coop MP_FILE=<코드 파일> MP_WAVES=8 MP_N=<참가 인원>` + BINDU_MP_URL (`MP_IDLE=<역할>`이면 그 역할은 아무것도 안 함: 잠수 처리 시험). 대결은 웨이브마다 진입 방향이 같은지, 협동은 웨이브·점수·오브젝트가 같은지 | 웨이브마다 `MPW`·`MPDEALT`(주인별 피해), 끝에 `MPPLAY` |
| `mp_shot.gd` | `tools/run.sh ui mp_shot.gd <폴더> [글자 크기] [touch] [vs\|coop]`: 연결 없이 상태만 채워 시작 버튼·방 화면·상태 줄·웨이브·끝 화면 스크린샷 | PNG |
| `vote_shot.gd` | `tools/run.sh ui vote_shot.gd <폴더> [글자 크기] [touch] [phone]`: 서버 없이 응답을 채워 시작 화면 [투표]·투표 창(표·개선 의견·표 다 씀·지난 회차 결과)·판 끝 화면 버튼·이번 판 탭 스크린샷. 사본의 online_config SERVER_URL은 http://127.0.0.1:9로 | PNG |
| `card_writing_check.gd` | 온라인·멀티 주소를 비운 `BinduTools` native 사본에서 `tools/run.sh ui card_writing_check.gd <폴더> 1.0`. 130%는 `1.3`, 폰은 `2556x1179`·`1.3 phone`, 태블릿은 `2048x1536`·`1.3 touch`. 전체 62종(직선탄 정의·특성 포함) 요약·상세, 4장 선택지, 가로 넘침·본문 높이·스크롤 마지막 줄 검사 | PNG·본문/해상도 manifest·`CARD WRITING failures=0` |
| `carry_check.gd` | `tools/run.sh ui carry_check.gd <출력 폴더> <글자 배율> [phone]`: 서버 주소를 비운 native 사본에서 가상 카드 클릭·드래그·터치, 무효 대상·취소·앱 전환·확대·중복 소비 방지·카메라 독립·UI 검사 | PNG·ok/FAIL·CARRY failures |
| `first_play_check.gd` | 저장 분리 사본(`config/name`은 BinduTools로 시작)에서 `tools/run.sh ui first_play_check.gd <캡처 폴더> <글자 배율> [touch]`: 첫 기기 진입·선택형 설명·첫 2회 배치·취소·이어하기·웨이브 시작 확인. 창 필요, 실제 게임 저장에서는 실행 거부 | 항목별 ok/FAIL, 캡처 PNG, `NATIVE FIRST failures=0` |
| `spec` | [docs/features.md](../docs/features.md)에서 검사가 spec인 기능마다 기대 동작을 확인(tools/spec_check.gd), 끝에 문서와 대조 | 기능별 ok/FAIL, 실패가 있으면 끝 코드 1 |
| `tutplay` | 플레이 튜토리얼(tools/tut_play_check.gd)을 직접 해내기(PC·터치)·[건너뛰기]만·3장부터 장 고르기로 끝까지 돌리고, 끝난 뒤 이어하기·판 수·누적 수·업적·맵·규칙·모드가 그대로인지 | 항목별 ok/FAIL, `TUTPLAY 통과`, 끝 코드 |
| `tut_play_shot.gd` | `tools/run.sh ui tut_play_shot.gd <폴더> [글자 크기] [touch] [phone]`: 플레이 튜토리얼 단계별 화면 PNG (안내 칸·강조·카드 겹침) | PNG, `UI OVERLAP` 줄 |
| `notes` | `python3 tools/notes_check.py`: CHANGELOG(게임 안 패치노트)에 패치 키·코드 이름·파일 경로·서버 API 경로·커밋 해시·백틱·요청/제보 인용이 없는지 ([docs/changelog-rules.md](../docs/changelog-rules.md)). Godot 필요 없음 | 걸린 줄마다 `FAIL CHANGELOG.md:<줄> <이유>`, 끝 줄 `NOTES ok` |
| `check` | 배포 전 한 번에: 패치노트 검사 + spec + 플레이 튜토리얼 + 무작위 입력 4판 + 이어하기 13웨이브 + 온라인 서명 + 패치 키 + 서버 pytest(패키지가 있을 때). 4~5분. 이어하기는 13웨이브 도달과 4·8·12웨이브 복원 모두 필수 | `CHECK 통과` / `CHECK 실패: <항목>`, 끝 코드 |
| `patch_keys_check.gd` | `godot --headless --path . -s tools/patch_keys_check.gd`: 온라인 패치 rules의 오브젝트 수치 키(공격방식별 피해·속도·사거리, 강화·속성 수치, 규칙별 덮어쓰기)가 실제 값·설명 글에 먹는지 | 항목별 ok/FAIL, 끝 줄 `PATCHCHECK ok` |
| `perf` | 후반 부하(오브젝트 16개, 속성 3종·강화 10개씩, 구체 400개)를 1·4·8배속으로 600프레임씩 | 프레임 시간 평균·95%·최대, 화면 위 구체·탄·장판 수 |
| `uifreq` | `tools/run.sh uifreq` (`WHY=1`: 크기·자리·테마가 바뀐 호출 줄도): 쉬는 시간·카드 선택·구체 250개 웨이브에서 600프레임씩 화면 요소별 다시 그리기 횟수(신호로 그리는 함수는 ms도)·글 바뀜 횟수, 프레임 시간(노드 처리·그 밖) | `UIFREQ <장면>: …` 요약 + `draw`/`text`/`why` 줄 |

환경 변수: `SPEED`(배속, bots 4·long 8), `SMART`(기본 1: 사람처럼 중앙 가까이에서 길목 바깥쪽을 겨눠 배치, `SMART=0`은 예전 봇). `SKIP=n`: `SKIP_FROM`(기본 8)웨이브부터 웨이브 넘기기를 n개씩 쓰고, 멈추면 쌓인 것을 다 고른 뒤 다시 넘긴다. `MAPRULE=0`: 맵 규칙·친화 카드 끔 (맵별 켬·끔 비교, `MAP=<맵 id>`와 함께).

봇은 쉬는 시간마다 진입 방향이 옮겨 가 아무 길목도 겨누지 않게 된 오브젝트를 비어 있는 길목으로 옮긴다(사람이 하듯이). 2026-10-30 판 길이 목표(중간값 12~15웨이브)는 이 봇 기준이다.

봇은 같은 시드여도 판마다 1~2웨이브 흔들린다. 비교할 때는 같은 판 수(32판 이상)로, 바꾸기 전 코드와 나란히 돌린다.

UI는 바뀔 때만 다시 그린다: 매 프레임 같은 값을 다시 넣어도 다시 그리기가 일어나는 것(`set_anchors_preset`, `add_theme_*_override`, 스타일 상자 색, 자리를 두 번 나눠 정하기, 두 곳이 같은 버튼 자리를 번갈아 정하기)은 값이 다를 때만 넣는다. 새 UI를 `_process`에서 배치하면 `uifreq`로 쉬는 시간·카드 선택의 UI 다시 그리기가 0/프레임인지 볼 것.

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

운영 서버 `/v1/boot` 응답과 그 URL에서 내려받은 ZIP을 직접 확인할 때:

```sh
godot --headless --path . -s tools/update_check.gd -- --release /절대경로/boot.json /절대경로/Bindu-windows.zip
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui update_flow_check.gd /tmp/bindu-update-ui
```

`--release`는 내장 공개키로 실제 릴리스 서명·변조 거부·파일 해시·크기·단일 Windows EXE·PCK 내장을 검사한다. 파일 교체나 실행은 하지 않는다.
`update_flow_check.gd`는 저장·네트워크를 분리한 실제 홈화면에서 가상 마우스 클릭, 진행률, 실패 재시도, 중복 연결, 플랫폼별 스토어 URL을 검사한다. 다운로드 시작은 가짜 Updater로 기록하므로 Windows EXE 교체 성공 증거는 아니다.

## 하단 카드 도크 전후 비교

`tools/dock_check.gd`는 같은 시드·오브젝트 좌표·선택지를 사용해 PC/폰/태블릿 화면과 실제 Godot 입력 경로를 확인한다.
실제 저장과 분리된 `BinduTools…` 사본, 온라인·멀티 주소가 빈 설정, native 렌더러로 OS 창 포커스 없이 실행한다.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui dock_check.gd /tmp/dock-desktop 1.0
RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui dock_check.gd /tmp/dock-phone 1.3 phone
```

기준 main 사본에 같은 검사 파일을 복사하면 before 캡처도 얻을 수 있다. 전장 상태는 같고 레이아웃만 다르다.
폰/태블릿은 Mac 모의이며 실기기 조작의 증거는 아니다. 캡처와 범위는 `docs/qa/2026-11-03-card-dock/README.md` 참고.

## 아키텍처 경계 검사

`GODOT=<godot> tools/run.sh architecture`는 서비스 구독 중복/해제, 씬별 컨트롤러 독립성, WeakRef 해제, 순수 배치 규칙을 검사한다. `check`에도 포함된다.

`python3 tools/architecture_audit.py`는 메인 분리 시점의 함수 529개가 누락되지 않았는지와 참조 경로 외 변경을 기록된 기준과 대조하는 일회성 마이그레이션 감사다. 새 동작을 구현할 때는 해당 함수의 변경 이유·회귀 검증을 `docs/architecture/main-boundaries.json`의 `reviewed_changes`에 기록한다. UI와 봇의 진입점은 `main.<feature>_system`으로 갱신되어 있다.

## macOS 자체 업데이트 검증

```sh
python3 native/macos/tests/test_updater.py
python3 tools/macos_update_smoke.py
```

첫 명령은 임시 `.app`·ZIP만 사용해 코드 서명·권한·심볼릭 링크 보존, 잘못된 해시·ZIP 경로·서명·버전 거부, 실제 앱 교체·재시작·시작 실패 복구를 검사합니다. 실제 macOS 프로세스 실행과 동일한 네이티브 보조 프로그램을 사용합니다.

두 번째는 저장·접속 키가 분리된 실제 Bindu 앱 `0.0.1`·`0.0.2`를 내보냅니다. 로컬 HTTPS 서버와 시험용 릴리스 키를 사용하고 실제 홈화면 버튼 경로로 다운로드·검증·교체·새 앱 시작·진행 기록 보존·임시 파일 정리까지 검사합니다. `MACOS_SMOKE_OUT`으로 로그 출력 폴더를 지정할 수 있습니다(기본 `/tmp/bindu-macos-update-smoke`). 운영 릴리스·개인 게임 저장은 변경하지 않습니다.

`build_macos.command`와 같은 Xcode·libarchive 빌드 의존성이 필요합니다. 테스트 앱은 ad-hoc 서명이며 Apple Silicon에서의 실행 성공을 Intel 실기 실행·Developer ID 공증·운영 배포 증거로 확대하지 않습니다.
