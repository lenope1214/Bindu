# 통합 입력 경계 리뷰

2026-11-09, 기준 HEAD `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9` + 작업 트리. 미커밋 병렬 통합 중 관찰본이며 최종 승인 아님. `BinduEditHistory`는 이 리뷰어가 구현했으므로 helper 자체는 독립 승인으로 계산하지 않는다.

범위: cards/history/frame/session/card_dock/interaction의 입력·소비·undo·pause 경계, multiplayer/lobby의 소유권·속성 전달, BF-44 지난 웨이브 정보. 실제 diff와 HEAD baseline을 비교했다. 성능 측정 중 native 실행을 중단했고, 아래 native 증거는 그전에 분리된 BinduTools 사본에서 실행한 결과다.

## 발견 및 조치 상태

### I-01 · P1 · 오래된 카드 읽기 버튼으로 선택 수 0에서 무료 적용 가능

수정 전 `scripts/card_dock.gd:173–174`의 `이 카드 들기` callback은 `_on_pick(reading_card)`를 직접 호출했다. `:886`의 노출 조건은 reading_card 비어 있지 않음뿐이었다. `scripts/features/cards.gd:723`의 `_on_pick()`에는 단계·남은 선택·현재 offer 검증이 없었다.

구체 경로: CHOOSE에서 카드 정보 열기 → S로 선택 보류/연속 진행 → `_bank_rest()`가 picks=0, offer.clear() 하지만 reading_card는 유지 → READY에서 Tower 선택 → Tower 정보에도 오래된 `이 카드 들기` 표시 → 누르면 PLACE → 기존 Tower에 적용. `_after_place()`가 picks를 -1로 감소시킨다. 같은 버튼으로 WAVE에서 PLACE로 바뀌면 진행 상태까지 손상될 수 있다. root에 source 경로로 전달했으며 새 native 재현은 아직 하지 않았다.

root 수정 반영 확인: `_on_pick()`에 CHOOSE/picks>0/!perk_mode/card in offer/!input_blocked 중앙 가드, use_btn 노출·disabled 조건, inspect_object의 reading_card 정리, `_bank_rest()`의 close_inspector. root core의 stale callback 회귀를 포함해 `integration/core-pc/run.log`, `core-phone/run.log` failures0/UI0 및 `integration/results.json` exit0을 이 리뷰어가 읽어 확인했다. **수정·native 회귀 확인.**

### I-02 · P2 · 정지 중 카드 읽기 버튼이 CHOOSE→PLACE를 실행

카드 정보 → 일시정지 → `이 카드 들기`. `card_dock.gd:579–580`은 인스펙터를 pause 막 위 z21에 유지하며 `input_blocked(false)`로 읽기를 허용한다. 이전 use_btn은 활성 상태였고 callback/`_on_pick()`에 pause 가드가 없어 전장 상태 변경이 가능했다. 카드를 아직 소비하지 않아도 정지 UI에서 의도하지 않은 편집이 시작된다.

I-01과 같은 중앙 가드 + use_btn.disabled가 root에 의해 반영됐다. 인스펙터를 정지 중 읽을 수 있는 정책은 유지한다. root core의 실제/직접 paused callback 차단 조건 PC·폰 통과를 읽어 확인했다. **수정·native 회귀 확인.**

### I-03 · P2 · 폰 carried-card와 Tower 드래그가 충돌할 수 있음

기존 main부터 터치 PLACE는 `CardDock.handle_input()`의 carried-card drop 경로다. PC의 held-card Tower 이동과 동일한 제스처라고 가정하면 안 된다. 그런데 emulated MousePress가 먼저 오면 `_unhandled_input()`이 `_begin_press()`로 Tower 이동을 준비하고, 원래 ScreenTouch는 CardDock가 카드 드래그로 따로 잡을 수 있었다.

native 증거: `undo/phone-touch-assumption.log` 및 `undo/phone-final.log`. 후자는 고정된 손가락 도착점(원래 Tower에서 64 world px 옆)으로 무효 강화 카드 drop을 보냈는데, Tower·선택 수 불변 및 취소 후 이력 없음 조건 두 개가 실패했다. 나머지 undo/identity/runtime/profile/BF-44 UI 복구는 통과, UI0. 당시 로그에 중간 상태값이 없어 실제 emulated 이벤트 순서를 직접 관찰했다고 주장하지 않는다.

root 허가 후 `interaction.gd:_unhandled_input` 앞에 `InputEventMouseButton + DEVICE_ID_EMULATION + PLACE + carrying()` 가드 추가. 원래 ScreenTouch drop 하나만 전장 행동을 담당하며 실제 Mouse 이동·AIM·일반 object touch는 유지한다. `undo/phone-latest.log:43–44`에서 press/release 모두 phase=PLACE/picks=1/pos=(280,300)/mod=0/object_press=false, 해당 두 조건 GREEN 확인. 같은 실행의 유일한 실패는 I-06이다. **touch 수정 native 확인.**

### I-04 · P2 · 협동 속성 전달 거절 시 보낸 카드가 소실됨 (baseline 존재)

`scripts/features/lobby.gd:283–294` `_mp_give()`는 전송 직후 성공 토스트 및 `_after_place()`로 donor 선택을 소비한다. `:297–309` `_mp_recv_gift()`는 요청 불일치/상한이면 owner에서 거절만 하고 donor에 ACK·실패 응답·환불을 보내지 않는다. 이 코드는 HEAD에도 동일하다. 이번 변경의 회귀로 분류하지 않는다.

구체 경로: 3인 협동에서 두 donor가 같은 owner의 같은 속성 요청을 거의 동시에 본다. 둘 다 전달하면 owner는 첫 카드만 받고 요청을 지운다. 나중 카드는 거절되지만 두 donor 모두 카드를 이미 소비했다. 2인에서도 요청 변경·상한 도달과 전달이 경합하면 같다. 멀티 undo가 금지되어 사용자 복구 경로가 없다.

성공 확인 뒤 소비하는 전달 transaction 또는 거절 ACK에 따른 동일 카드/선택 복구가 필요하다. **source 경로·baseline 확인, 실제 3-client 경합 미재현.** 기존 실제 2인 WebRTC 성공 증거는 이 경합을 검증하지 않는다. root에 전달했다.

### I-05 · P1 · 새 카드 guard와 멀티 자동 선택 호출부의 계약 불일치

I-01 수정 뒤의 `cards._on_pick()`는 읽기/정지 중 `input_blocked()`로 반환한다. 그런데 `lobby.gd:435–481`의 `_mp_auto_rest()`는 `mp_auto_now=true`로 자동 선택을 수행하며, `:485–509`의 `_mp_auto_pick()`는 `_on_pick(o)` 성공 여부를 확인하지 않고 `_place_on(t)`, `_apply_card(t)`, `_place_tower()`, `_after_place()`를 계속한다. 멀티 `_mp_rest_tick()`은 frame의 paused/reading 반환보다 앞에 있다.

구체 경로: 멀티 CHOOSE에서 도움말/정지를 열고 자동 선택 제한 시간이 지난다. `_on_pick`는 거절하지만 호출부가 stale picked로 적용을 시도한다. picked가 비어 있으면 type/e 접근 오류, 이전 카드가 남아 있으면 잘못된 카드 적용·선택 소비 위험이 있다. source에서 새 guard 도입 전에는 이 거절이 없었으므로 이번 통합에서 새로 생긴 계약 불일치다.

root 수정 확인: `_on_pick()->bool`, 검증된 `mp_auto_now && mp_mode != ""`에서만 modal guard 예외, CHOOSE/picks/offer/perk 검증은 유지. `_mp_auto_pick()`의 세 호출부 모두 false면 적용 전에 중단한다. root core의 modal 자동 선택 및 거절 후 stale picked 미적용 조건 PC·폰 통과를 읽어 확인했다. **수정·native 회귀 확인.**

### I-06 · P2 · 전체 선택 toolbar 클릭 뒤 방향키가 전장 이동 대신 GUI focus를 이동

`card_dock.gd:229`의 select_all_btn은 `_action_button()`의 FOCUS_ALL(:242)을 사용한다. READY에서 실제 `전체 선택` 클릭 → selected.size=2 → Right를 보내도 두 Tower 위치가 바뀌지 않았다. `tools/battlefield_undo_check.gd:371–374`의 실제 입력 조건이며 `undo/pc-latest.log` / `undo/phone-latest.log` 모두 동일 실패, exit1/UI0. 기존 검사는 select_all API·Ctrl+A를 써서 버튼 focus 경로를 놓쳤다.

root가 전장 edit actions(undo/additive/select_all/group_direction) pressed 뒤 release_focus를 연결했다. 읽기 prev/next/expand의 키보드 focus는 유지한다. **`undo/pc-verified.log` / `phone-verified.log` 각각 43/43, failures0/UI0/exit0.** toolbar 실제 입력·그룹 방향키 이동·Space 시작 및 native 캡처를 직접 확인했다.

## 확인한 방어와 한계

- BF-05: 원래 Tower를 유지하는 in-place 복구, 실제 이동·그룹·방향·마지막 카드·새 설치·공격방식 cd 복구, 로그/보류/업적/도감/누적 및 격리 디스크 저장을 검사했다. 최종 PC·폰 각각 failures0/UI0/exit0. provenance는 `undo/README.md`와 `undo/manifest.json`에 기록했다.
- 새 offer 값이 우연히 같아도 `_make_choices()` 명시 clear가 이력을 폐기한다. Q·perk 공개·wave 시작·progress_synced·다른 run id·profile 충돌의 fail-closed 경계도 검사했다. PLACE/AIM 중 undo는 거절하고 진행 중 편집을 보존한다.
- 소유권: select_all/rotate/move/방향 그룹은 mine 필터를 통과한다. 친구 explicit select는 읽기만, 속성 전달은 요청 속성 + can_take가 필요하다. gift 거절 이후 소비는 I-04 별도 문제다.
- pause/focus: 싱글 focus loss는 drag를 거둔 뒤 pause, 멀티는 자동 pause 제외. WAVE Esc는 inspector/skill보다 즉시 pause. 새로운 읽기 shortcut 경계는 Ctrl/Cmd 조합과 모달을 구분한다.
- BF-44: factual leak_review_text, reading_review 우선 표시, 선택 카드와 구분, 닫을 때 카드 복귀 flag, READY countdown 보류 확인. 정보가 열려 있던 상태의 이동 undo는 PC·폰 native에서 통과했다. 새 flags는 undo snapshot에 포함된다.
- toolbar pointer activation 뒤 그룹 방향키 이동·전장 재선택 후 Space를 실제 입력으로 추가 검사했다. 방향키의 확인된 결함은 I-06. 모든 읽기 버튼의 완전한 키보드 focus traversal을 승인한 것은 아니다.
- 인터넷 지연·패킷 손실·3-client 경합, 실제 모바일 장치의 touch event ordering은 미검증. 폰 native는 macOS Godot의 2556×1179 요청/130%/ScreenTouch 경로다(실제 창 높이는 1180으로 반올림).

## 검토 관찰본 SHA-256

```
b1bae77a47164d885cdbb465024fa82fb101951cb376f4805ac0b6c834ff2b27 scripts/features/cards.gd
aa9d9e7fda6da45452290138e38e541b1e3ee37bdcd7ecba5ba508b0073007d0 scripts/edit_history.gd
6ea7e5b2915b6b5d7f77c1f57d8f23422eaa124d16044c2ef4f7bc65662cb453 scripts/features/frame.gd
b94c40c73a9c165a97099811fed109a93580b1cd9522cb714ada07b6760f5803 scripts/app/session.gd
52d654f1ac73b2e8add6e60f070fb1df16f6cb94d2f597a7ceee08acd1bc4829 scripts/features/multiplayer.gd
bc38288b8591ad58216f7fd75d57b6ea580dac21dc4c5653e156a535326baac5 scripts/card_dock.gd
471a20dcd45ed02d5256262ec20642a9886f3f197ef26cec1a6f81f3ccaef70d scripts/features/interaction.gd
1b3d2dbc6464601d681f3a26aed9b6c1e4fe7bcb547c728fcbe8db9a7d5748f7 scripts/features/lobby.gd
```
