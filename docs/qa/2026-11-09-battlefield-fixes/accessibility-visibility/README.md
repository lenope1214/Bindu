# 숨은 버튼의 native AX 실행 수정과 READY 누락 진단

**I-16 숨은 버튼 실행은 수정했다. I-17 READY 버튼 누락과 전체 접근성은 HOLD다.** 두 문제를 하나의 통과 결과로 묶지 않는다. [전체 측정·소스·제한](summary.json), [가설·실패한 실험](plan.json).

## 수정한 동작

macOS Godot4.7.2 `ed1daf0bf`의 버튼 하나짜리 격리 장면에서 버튼을 숨겨도 AX 목록에 남았고, native `AXPress`가 콜백을 실행했다. 게임 UI나 전투 계산 없이도 재현됐다. 단순히 예전 AX 트리에 이름이 남은 현상과 실제 실행을 구분했다.

`BinduUiShell`의 UI 루트에서 `Control.visibility_changed`를 접근성 갱신 요청에 연결한다. `child_entered_tree`로 이후 생성되는 카드·메뉴도 연결하며 중복 연결은 막는다. 구독은 UI 노드와 함께 종료되고 SceneTree 전역 구독·추가 프레임/입력 루프는 없다. 표시·배치·focus mode·기존 콜백과 게임 상태는 바꾸지 않는다. 지원되지 않는 서버에는 갱신하지 않는다.

현재 엔진 소스의 `CanvasItem` 표시 변경 경로는 표시 알림을 내지만 그 경로 자체에서 접근성 갱신을 예약하지 않는다. 관찰한 문제와 수정의 직접 근거는 아래 native 재현·반례이며, 엔진 전체의 모든 접근성 원인을 확정한 것은 아니다. 특히 READY 누락은 이 수정으로 해결되지 않았다.

| 실제 실행 | 결과 | 증거 |
|---|---|---|
| 최소 장면, 수정 전 | 숨은 상태3개에서 버튼이 남음. 두 번의 native 숨은 버튼 누르기로 콜백 증가 | [실행](minimal-baseline-01/run.json), [로그](minimal-baseline-01/native.log) |
| 최소 장면, 처음부터 숨김·수정 전 | 나중에 보였다 다시 숨긴 버튼 실행1회. 숨은2상태 불일치 | [실행](minimal-initial-hidden-01/run.json), [로그](minimal-initial-hidden-01/native.log) |
| 최소 장면, 수정 후 | 7전환 모두 실제 표시와 AX 일치. 숨은 버튼 실행0, 보이는 버튼 native 실행1회 | [실행](minimal-bridge-01/run.json), [로그](minimal-bridge-01/native.log) |
| 최소 장면, 처음부터 숨김·수정 후 | 같은 observer/reader의 반례와7전환 일치. 숨은 실행0, 보이는 실행1회 | [실행](minimal-hidden-bridge-01/run.json), [로그](minimal-hidden-bridge-01/native.log) |
| 제품7상태, 수정 전/후 | 전투 중 숨은 ‘웨이브 시작’의 AX 잔류가 사라짐. READY 누락은 그대로 남음 | [전](baseline-02/run.json), [후](current-01/run.json) |

최소 장면의 수정 후 실행은 boot하지 않은 세션에서 실제 제품 UI 연결 메서드만 사용했다. 게임 UI/프레임 계산은 실행하지 않았다. 수정 전후의 초기 숨김 반례는 observer·reader SHA가 같다. [최소 장면](minimal.gd), [실행 도구](run.py), [native reader](read_ax.swift). 전체 trace 원본은 로컬 보존한다.

게임의 접힌 카드가 보조기술에 계속 실행되는 문제는 이번 제품 장면에서 재현되지 않았다. [미리 보관한 카드 참조 검사](cached-baseline-01/run.json)에서 접기 전 AX 요소로 보낸 실행도 `kAXErrorInvalidUIElement`(-25202)로 거부됐고 게임 상태는 같았다. 이 경로에 불필요한 카드 콜백 guard를 추가하지 않았다. [reader](cached_ax.swift).

## READY 누락은 아직 해결되지 않았다

화면과 Godot inventory에는 READY의 ‘웨이브 시작’이 보이지만 native AX에서 찾을 수 없다. 수정 전 두 장면과 반복 조회5회에서 관찰했다. [실제 화면](current-01/ready.png), [수정 전 AX](baseline-02/ready-ax.json), [수정 후 AX](current-01/ready-ax.json). 창 제목 marker는 이 창의 상태만 식별하며 모든 자식이 최신이라는 증거가 아니다.

- 표시 갱신만 연결한 제품은 전투 중 잔류는 없앴지만 READY 누락은 남았다. [엄격한 검사](current-01/run.json)는 실패로 보존했다.
- [진단 알림](diagnostic-01/ready-notifications.json)에서 시작 버튼은 `visible=true`인 실제 접근성 갱신 알림을 두 번 받았다. 버튼에 갱신이 전혀 없다는 설명으로는 부족하다. [관찰 코드](trace_control.gd)는 임시 사본에만 붙였다.
- 부모도 갱신한 [격리 실험](parent-prototype-01/run.json)과 `FOCUS_ACCESSIBILITY`를 준 [격리 실험](focus-prototype-01/run.json)도 같은 READY 검사를 실패했다. 두 실험은 제품에 적용하지 않았다.
- [탐색 순서 조회](navigation-baseline-01/run.json)도 READY 누락을 관찰했다. `AXChildrenInNavigationOrder`를 우선 사용하고 지원되지 않으면 `AXChildren`로 내려갔다. 해당 [READY 원본](navigation-baseline-01/ready-ax.json)에 자식 조회 timeout 오류는 없었다. VoiceOver의 실제 음성/선형 탐색을 관찰한 것은 아니다.

동일 재현의 세 수정 실험에서 READY 문제는 남았다. 네 번째 추측 수정은 준비하지 않는다. 현재 UI·엔진을 유지한 원인 추적과 접근성 조작면의 구조 변경 중 다음 조사 방향을 사용자에게 질의했다. 표시 갱신의 별도 최소 재현·검증은 위 I-16 수정의 근거이며 READY의 해결 증거로 쓰지 않는다.

## 회귀와 실제 소스

[제품 전후 비교](scope-comparison.json)는 동일 observer·reader에서14개 before/after 상태 dictionary와1,148개 전체 조작부 기록이 정확히 같았다. 경로·text/name·local/tree visible·disabled·focus mode·rect와 선택한 게임 상태를 비교했다. 한 번의 의도한 native 카드 선택은 양쪽에서 같은 PLACE/들기 상태가 됐다. 제품70개 스크립트 중 변경은 `ui_shell.gd` 하나다. [당시 동일 reader 원본](read_simple_used.swift).

- [전체 검사](full-check-visibility.log): exit0, 명세252·전달86·전투345사례/4,140표본, 실제 fuzz4개 모두 DONE3,000/exit0, W4/8/12 복원·W13 도달, 서버28개. 서버 warning1은 로그에 남긴다. I-15의 이전 큐 고갈을 해결했다는 뜻은 아니다.
- [키보드](keyboard-01/run.json): PC100/130·폰130 모의, 각42개·총126단언·실패/UI0. 각 종료의 ObjectDB2 경고는 이전 cohort와 같은 문구이며 보존했다. [PC100](keyboard-01/pc100/run.log), [PC130](keyboard-01/pc130/run.log), [폰130](keyboard-01/phone130/run.log).
- [일회성 아키텍처 감사](architecture.log)는 기존41개·새 실패0이다. 전체 감사 통과와 구분한다. 공통 runtime 경계 검사는0실패다. `_build_ui`의 실제 추가 연결 범위를 review 기록에 남겼다.

제품 native `current-01`과 일부 실험은 종료 때 ObjectDB2 경고를 남겼다. 제품을 수정하지 않은 `navigation-baseline-01`에서도 같은 문구가 있었다. 이를 수정으로 새로 생겼거나 해결된 누수라고 단정하지 않는다. 원문은 보존하며 무경고 종료로 보고하지 않는다.

[전후 상태 전체 비교 입력](comparison-sources.md)에 비교 입력을 연결했다. 그 외 대량 raw·실험 장면·실패한 엄격한 검사 원본도 그대로 보존했다. 초기 [7상태 관찰](baseline-01/run.json)은 진단의 출발점이며 최종 비교는 같은 observer/reader의 `baseline-02`와 `current-01`이다.

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/run.py --minimal --start-hidden --source-ref 519f8f2 --output /tmp/bindu-ax-hidden-before-new
python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/run.py --minimal --minimal-bridge --start-hidden --require-fresh --output /tmp/bindu-ax-hidden-after-new
python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/run.py --require-fresh --output /tmp/bindu-ax-product-new
```

마지막 제품 검사는 현재 READY 누락 때문에 실패한다. 기준을 완화해 통과로 바꾸지 않는다. 새 출력 경로를 사용한다. 소유 PID의 native 창만 읽고 운영 URL·실제 저장·OS 커서·포커스/활성 창은 건드리지 않는다. 각 소유 프로세스 종료·고유 저장/임시 프로젝트 제거를 확인했다.

접근성 전체·VoiceOver·실기기·사람 과제·고배속 전체 지연은 미완료다. 목표50개는 active이며 작업별 로컬 커밋만 한다. main pull/rebase/push·PR 갱신은 전체 작업 마지막 한 번으로 유지한다.
