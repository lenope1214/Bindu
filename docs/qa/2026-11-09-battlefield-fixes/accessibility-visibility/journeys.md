# 실제 선택·배치·장면 복귀의 접근성 비교

I-17은 미해결이다. 고정된 진행에서 선택·배치·시작 경로는 통과했지만, 시작 화면 복귀 뒤 ‘이어하기’가 native AX에서 누락됐다. 일반 시간 진행을 유지한 별도 검사에서도 READY 시작과 일시정지의 ‘시작 화면’이 누락됐다. 인위적인 READY 경계나 게임 진행 고정에만 국한된 문제로 볼 수 없다. 제품 스크립트70개는 `2457eda`와 같다. [전체 실행·해시 집계](journey-summary.json), [관찰 도구](ready_journey.gd), [호스트 실행 도구](run.py), [native reader](read_ax.swift).

## 실제 조작과 경계 검사를 구분한다

실제 경로는 고립된 저장과 오프라인 QA 사본에서 native AX 카드 선택 두 번, `VirtualInput.send`의 Enter 누름·뗌으로 두 번 배치한 뒤 native AX ‘웨이브 시작’을 실행했다. 초기 W12·오브젝트 둘·선택권 둘은 공통 fixture다. 이 설정 이후 선택권 차감과 READY 진입은 제품 경로가 수행한다. OS 키보드·손가락·VoiceOver 조작은 아니다.

아래 기존 표의 게임 루프는 스냅샷 중 `set_process(false)`로 고정하고 단계 사이 `frame_system._process(0)`를 네 번 호출한다. Godot/native 창의 프레임·접근성 서버는 계속 실행된다. 이는 지원되는 콜백과 고정된 상태 경계의 증거이며, 일반 실시간 게임의 발생률·지연을 입증하지 않는다. 일반 시간 진행을 유지하는 대조는 별도로 분리한다.

`ready-only` 등은 선택권을 직접 0으로 설정하고 `_enter_ready()`를 호출한다. 이들은 상태 경계와 접근성 갱신을 분리하는 검사이며 전체 사용자 과제 통과로 세지 않는다. 같은 경계에서 일반 입력 F17과 실제 Tab 정보창 열기의 차이를 비교했다.

| 검사 | 관찰 | 증거 |
|---|---|---|
| READY부터 조회 | 화면상 시작 버튼 누락, 5회 조회. Space 대체 경로로 WAVE 진입 | [ready-first-01](ready-first-01/run.json) |
| CHOOSE를 먼저 조회한 뒤 READY | 누락 유지. 단순한 native 조회 선행만으로는 해소되지 않음 | [choose-ready-01](choose-ready-01/run.json) |
| 경계 전에 F17 입력 | 누락 유지. 어떤 입력이든 한 번 보내면 해결된다는 설명 배제 | [ready-with-key-01](ready-with-key-01/run.json) |
| 실제 카드 선택·배치·시작 | 4상태 표시/AX 일치. 시작 AXPress 한 개 발견·실행 성공 | [native-journey-01](native-journey-01/run.json) |
| 같은 실제 경로에서 Esc로 정보창 닫기·Tab으로 열기 | 정보창 닫힌 READY를 포함한 6상태 일치 | [native-close-02](native-close-02/run.json) |
| READY 경계에서 Tab으로 정보창 열기 | 시작 버튼 발견. 새 배치 없이도 현상 변화 | [ready-with-inspector-02](ready-with-inspector-02/run.json) |
| 실제 일시정지·시작 화면·이어하기 | 시작 화면 AXPress는 성공하여 실제 장면 재생성. 보이는 ‘이어하기’는 native AX에서 찾지 못함 | [native-resume-01](native-resume-01/run.json), [이어하기 AX](native-resume-01/continue-ax.json), [화면·모델](native-resume-01/continue-ready.json), [캡처](native-resume-01/continue.png) |

첫 복귀 검사는 누락을 관찰한 뒤 다음 단계의 시작 버튼 조건에서 host assertion으로 종료됐다. 그 실패를 ‘이어하기 성공’으로 해석하지 않는다. 호스트 검사는 leave/continue의 native 발견 1개·실행 오류 0을 즉시 검사하도록 보강했다. [두 번째 복귀 실행](native-resume-02/run.json)도 새로운 장면·화면상 이어하기 표시·native 검색 0개를 관찰하고 `native action not discoverable or rejected`로 실패했다. 실행한 이 두 복귀 검사에서 모두 관찰됐다는 뜻이며 일반 발생률의 추정은 아니다. 두 실행 모두 소유 프로세스 종료·임시 프로젝트·고유 저장 제거를 확인했다.

`native-close-01`과 `ready-with-inspector-01`은 QA GDScript의 `focused` 타입 추론 오류로 관찰 전 종료했다. 제품 실패나 유효한 비교 표본으로 세지 않는다. 이후 `Control` 타입을 명시했고 실행 전 `--check-only`를 추가했다. [실패1](native-close-01/run.json), [실패2](ready-with-inspector-01/run.json).

## 일반 시간 진행 대조

[native-resume-live-02](native-resume-live-02/run.json)는 초기 fixture 이후 main 처리를 켜고, 수동 게임 루프 호출 없이 실제 프레임을 기다렸다. READY 관찰 전후 `run_real`이 약33.7초→68.4초로 증가하고 phase는 READY로 유지됐다. 이 구간에도 화면상 시작 버튼은 native AX에 없었다. 실제 키 P로 일시정지한 뒤 보이는 ‘시작 화면’ 역시 native 검색0개였다. [READY AX](native-resume-live-02/saved_ready-ax.json), [일시정지 모델](native-resume-live-02/leave-ready.json), [일시정지 AX](native-resume-live-02/leave-ax.json), [실제 캡처](native-resume-live-02/leave.png).

이 실행은 ‘시작 화면’ native 조작을 못 찾아 종료됐다. 실시간 모드에서 장면 재생성·이어하기까지 성공하거나 실패했다고 주장하지 않는다. 앞선 고정 모드의 이어하기 누락2회와 구분한다. 정보창이 보이는 상태에서도 이 누락이 발생했으므로 정보창 열기를 보장된 우회법으로 제시하지 않는다.

첫 [실시간 실행](native-resume-live-01/run.json)은 [로그](native-resume-live-01/native.log)에 `native AX observed saved_ready` 실패가 있다. 30초 관찰 제한 후 다음 상태로 진행하여 host 조회와 상태가 섞였으므로 제품 표본에서 제외했다. 관찰 timeout은 이제 즉시 exit2로 종료하고, 실시간 모드는 handshake120초·전체600초로 분리했다. 이는 제품 지연에 sleep을 넣은 수정이 아니라 QA 프로토콜의 실패 처리다. 재실행 live02에는 해당 timeout이 없으며 누락된 ‘시작 화면’에서 명시적으로 실패했다. 소유 프로세스·임시 프로젝트·고유 저장은 정리됐다.

19개 실행의 실제 `observer-used.gd`는 기록한 SHA와 일치한다. base/reader6개 버전의 [입력 소스](journey-input-sources.jsonl)도 실행 때 기록한 SHA와 정확히 맞췄다. 일부 이전 base는 현재 소스에서 관찰/timeout 추가 전 상태를 복원하여 SHA로 검증한 것이다. 나머지 공통 helper3개는 현재 파일과 모든 실행의 SHA가 같다. 제외된 실행도 삭제하지 않았다.

마지막 관찰 도구의 Python 문법과 [Godot parse](final-parse-result.json)를 다시 확인했다. 제품 소스는 변경하지 않아 이번 진단에서 전체 게임 회귀를 반복 실행하지 않았다. 이전 I-16 커밋의 전체 회귀·키보드 결과와 이번 새 관찰을 구분한다.

## 좌표·배율 관찰

[누락 장면](ready-geometry-01/run.json)과 [정보창을 연 장면](inspector-geometry-01/run.json)의 모델 Window/UI 크기·변환·시작 버튼 조상 경로는 같다. [전체 비교](geometry-comparison.json)에 실제 native 좌표와 모델 조상을 함께 보존했다. UI 루트는 1280×720, native 내용 영역은 640×360이며, 시작 버튼이 발견된 장면의 AX 좌표·크기는 모델의 정확히 0.5배다. 모델 조상의 Control clipping은 꺼져 있다. 해당 관찰은 잘못된 Retina 배율·화면 밖 배치를 지지하지 않는다. native 트리의 실제 부모 연결·필터 상태까지 확정한 것은 아니다.

실제 VoiceOver 음성·선형 탐색, 모바일 보조기술, 실기기와 사람 과제는 미관찰이다. 발견된 일부 버튼과 위 경로의 성공을 전체 접근성 통과로 확대하지 않는다. I-16 숨은 버튼 실행 수정과 I-17 누락은 계속 분리한다.

## 엔진 경계 진단

표시 갱신·부모 갱신·접근성 focus 실험이 같은 누락을 해소하지 못했다. 네 번째 제품 수정 대신 동일 Godot 소스의 별도 진단 빌드에서 outgoing AccessKit 노드를 기록했다. [엔진 경계 비교](engine.md)에서 전달 직전 시작 버튼·조상의 선택 필드는 같고 정상인데 native 발견은 0개/1개로 갈렸다. 실제 전달·소비 트리·필터/캐시·macOS 노출 중 원인은 아직 미확정이다. 제품 수정이나 접근성 통과로 처리하지 않는다.

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/run.py --journey native-journey --require-fresh --output /tmp/bindu-ax-native-journey-new
python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/run.py --journey native-resume --require-fresh --output /tmp/bindu-ax-native-resume-new
python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/run.py --journey native-resume-live --output /tmp/bindu-ax-native-resume-live-new
```

두 번째 명령은 현재 누락을 실패로 보존한다. 새 출력 경로를 사용한다. 작업별 로컬 커밋만 유지하며 main 갱신·rebase·push·기존 PR 갱신은 전체 작업 마지막 한 번이다.
