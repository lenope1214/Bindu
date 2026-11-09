# 입력·되돌리기 독립 리뷰

검토 기준: `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9` 위의 미커밋 통합 변경. 2026-11-09. 파일이 병렬 수정되는 중이므로 아래는 관찰한 revision의 결과이며 최종 승인 아님.

검토 범위: cards/card_dock/interaction/frame/ui_shell, persistence의 저장·복원, Tower 런타임 상태, Ach/Meta/Progress의 통계 부작용, 키·터치 모달 경계. 기존 native 입력 검사를 읽고 폰 core 검사를 실행했다. 제품 파일은 리뷰 중 수정하지 않았다.

후속 상태: 별도 구현 요청으로 `BinduEditHistory`와 undo 회귀 도구를 작성했다. 최종 `undo/pc-verified.log` / `phone-verified.log`는 각각 43/43, failures0/UI0/exit0. 원본 Tower·runtime·Callable·카드/통계·새 정보 경계 복구를 직접 검증했다. ReadCard/paused/stale callback 관련 root 통합 core 로그와 results.json도 PC/폰 failures0/UI0/exit0 확인했다. 아래 발견 기록은 수정 전 관찰본으로 보존한다. 최종 통합 범위·잔여 항목은 `review-integration.md` 참고.

## 확인한 결함

### P1 — BF-05: 이동 되돌리기가 모든 Tower를 다시 생성해 전투 상태를 바꾼다

관찰본: `scripts/features/cards.gd:42–54`의 `undo_edit()` → `scripts/features/persistence.gd`의 `restore_run_state()` → `_restore_info()`가 모든 Tower를 해제한 뒤 `Tower.new()/load_save()`로 복구한다. `scripts/tower.gd:1180–1183`의 `to_save()`는 디스크 저장 항목만 포함한다.

재현: 주사위 강화 Tower가 있는 전투를 마친다. 다음 쉬는 시간에 임의의 Tower를 움직이고 되돌린다. 모든 Tower identity가 바뀌고 `dice_miss/dice_x/dice_t`가 기본값으로 돌아간다. `wave_begin()`(326–332)은 이 값을 초기화하지 않으므로 원래 웨이브 경계에서도 유지되던 전투 상태를 잃는다. `dice_miss`는 대박 보장 누적(1326–1335), `dice_x`는 실제 공격 배율(1972)에 쓰인다.

같은 누락: `side_cd/side_n`, `cd`, `clock_ph`, `cont_acc`, `answer_cd`, `notify_cd`, `light_cd`, `mirror_src`, `later`의 Node·Callable 참조, 읽기 전 유지해야 하는 `new_reactions`. 단순 필드 몇 개를 디스크 저장에 추가해도 모든 기존 참조가 새 객체를 가리키게 바뀌는 문제는 남는다. 원래 Node를 보존하는 in-place undo 필요. 부모가 수정 대상으로 수락했다. 별도 `undo/` 증거로 회귀 검증 예정.

### P1 — BF-02: 폰 정보 버튼이 카드 선택으로 라우팅된다 (수정 전 RED)

관찰본: `scripts/card_dock.gd`의 `handle_input()` ScreenTouch 선택지 사각형 판정(수정 전 372–388)이 자식 `ReadCard` 영역까지 먼저 소비한다. `scripts/features/interaction.gd:329–330`가 이벤트를 handled로 만들어 버튼의 GUI 이벤트가 도달하지 않는다.

재현: 폰 CHOOSE → 카드의 `정보`를 1회 탭. 읽기 대신 PLACE에 진입한다. 닫기는 같은 카드 목록을 복구하지 못한다.

증거: `review-core-phone.log` / `review-core-phone/`에 native ScreenTouch RED. `BF-02 정보 버튼은 횟수·선택 상태를 소비하지 않음`, `BF-02 읽기 닫으면 같은 카드 복원` 실패, 프로세스 exit 1. 같은 실행의 BF-05 실패는 취소되지 않은 pending snapshot이 fixture 간 남은 연쇄 오염 가능성이 있어 독립적인 undo 증거로 계산하지 않았다. 부모가 ReadCard 명시 경로 수정 뒤 PC·폰 core `failures=0 ui=0` 재검증했다고 통보했다. 이 리뷰어는 그 GREEN 실행을 직접 수행하지 않았다.

### P2 — BF-14: 회전 단축키 안내가 실제 조작과 다르다

관찰본 `scripts/card_dock.gd:698`: `Ctrl+휠: 회전`. 실제 입력 `interaction.gd`는 Alt+휠로 회전한다. Ctrl+휠을 따라 하면 확대되어 의도한 조작을 찾지 못한다. `Alt+휠`로 정정 필요. 부모에게 전달했다.

### 관찰 메모 — compact inspector의 중복 visible 대입

관찰본 `scripts/card_dock.gd:831`: compact 분기에서 `detail.hide()`, 같은 함수 `:840`에서 `detail.visible = text != ""`로 다시 표시. 다만 `detail`의 부모 scroll도 compact에서 숨긴다. 실제 긴 설명 노출이나 조작 불가를 입증하지 못했으므로 확정 사용자 결함·P2 집계에서 제외한다.

## 방어 경계·추가 검증

- 키 입력: 읽기 모달·Ctrl/Cmd 조합 경계, WAVE Esc 우선 정지, 명시 선택의 inspector 복구, nearest screen target·동률 규칙 확인. 기존 input native PC/폰 검사 통과는 별도 `input/README.md`에 있다.
- undo: 취소한 held card의 pending snapshot이 다음 이동에 재사용되지 않아야 한다. PLACE/AIM/drag 중 undo는 원자적으로 거절해야 한다. 새 draft가 이전과 같은 값으로 나와도 무작위 정보 공개 경계이며 undo 불가여야 한다. offer dictionary의 값 비교만으로 경계를 판단하면 안 된다.
- profile: `Meta.tally/achieved/codex` 전체 대입은 비동기 `progress_synced`로 생긴 다른 진행까지 되돌릴 수 있다. 동기화 중 기록하지 않거나 동기화 이벤트에서 이력을 폐기하고, 카드 undo 직전 profile 충돌을 검증해야 한다. 서버의 grow-only counter/sets에 이미 공개한 효과를 로컬 감소로 취소할 수 있다고 가정하면 안 된다.
- keyboard focus: 새 `_action_button()`은 FOCUS_ALL이다. 버튼을 클릭한 뒤 Space/방향키/Tab이 UI accept/focus navigation에 잡혀 전장 명령이 막히는지 아직 runtime 재현하지 않았다. 확정 결함으로 계산하지 않는다.

## 관찰 파일 SHA-256

최종 재해시 시각에도 부모가 수정 중. ReadCard RED보다 뒤의 card_dock 해시이므로 RED 관찰본과 구별한다.

```
b3c30e4beca59eac261d1e91c3a62e65f8cebe8617d8cebcb6b58ef47d79e697 scripts/features/cards.gd
b3dd4c8a4193b218b80e281ab2f45154f9854fb5ecad929c0f2adb02b99cfe96 scripts/features/persistence.gd
561df0ba88377bf61c89d95b3eaac4738d300476db53c11fe27a58eb5f2e8c3d scripts/card_dock.gd
22bfb18b4688eb61ce1f225e14603d59b8895b18440b0cd328a54aa1e3e69ce3 scripts/features/interaction.gd
94863002c0802363cb371ed26e75f2b272e9e9f7d380e88132691acc34a0fe2c scripts/features/frame.gd
358a022e620b60e6c47c44cfbc3b0ec1ece03a0a96f93e4b5666363f5838b11f scripts/features/ui_shell.gd
```
