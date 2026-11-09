# BF-05 in-place 편집 되돌리기

HEAD `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9` 위 미커밋 통합 작업. `scripts/edit_history.gd` / `tools/battlefield_undo_check.gd`. 제품 실행·저장은 고유 이름의 임시 BinduTools 사본, 서버 주소 빈 값, OS 커서·포커스를 점유하지 않는 native SubViewport에서만 검사했다.

## 복구 계약

- 이동/그룹 이동/회전/방향 편집은 원래 Tower의 위치·방향만 복원한다. 모든 기존 Tower identity, 현재 주사위·쿨다운·mirror_src·queued Callable은 유지하며 경과한 런타임까지 되감지 않는다.
- 카드 복구는 기존 Tower script 변수의 깊은 container snapshot을 제자리에 적용한다. Node·Resource·Callable 참조는 복제하지 않는다. 새 설치로 생긴 Node만 제거한다. picks/offer/보류 선택/로그/도감/업적/누적/한 판 통계 및 카드·정보창 상태를 같이 복원하고 로컬 저장한다.
- 실제 새 draft/재추첨/특성 공개/웨이브/다른 판/진행 동기화는 경계다. 새 offer가 우연히 같은 값이어도 이력은 폐기한다. undo 중 새 난수를 뽑거나 draft를 재생성하지 않는다.
- PLACE/AIM/press/drag 중 undo는 거절한다. 취소·no-op는 새 이력을 만들지 않는다. 카드 취소 뒤 다음 편집은 새 snapshot을 사용한다. profile이 다른 진행에 의해 바뀌었으면 카드 undo가 그 진행을 덮어쓰지 않고 거절한다.
- 싱글 전용, 최근 20회. 제한 이유는 `last_reason`으로 UI tooltip·toast에 노출한다. 디스크 이어하기 포맷을 메모리 undo 포맷으로 재사용하지 않는다.

## root 연결

`BinduCards`가 lazy `BinduEditHistory.new(session)`을 보유하고 `begin_edit/finish_edit/undo_edit/clear_edit_history/can_undo`를 위임한다. 기존 edit_history/pending_edit는 getter로 유지한다. undo 버튼은 `can_undo()`와 `last_reason`을 사용한다.

명시 경계: cards._make_choices / reroll / perk_reroll, perks._start_perk / _on_perk, run_flow의 wave/skip/end/reload, persistence._clear_run. interaction._back_to_choose는 카드 취소 뒤 finish_edit로 held-card 중 변경을 확정한다. helper는 PLACE/AIM의 중간 finish를 보류한다.

## 실행 및 증거

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_undo_check.gd /absolute/output 1.0
RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_undo_check.gd /absolute/output 1.3 phone
```

- `before-pc.log` / `before-pc/`: legacy ConfigFile 전체 재생성 undo. 22개 조건 중 9개 실패, UI0, exit1. identity/runtime/Callable/selection/취소 snapshot/profile 충돌 방어 실패. 이 RED 뒤 검사를 40개로 확장했다.
- `pc.log` / `pc/`: 첫 helper 통합 39개 통과, failures0/UI0, exit0.
- `pc-final.log` / `pc-final/`: reading_review 복구까지 40개 통과, failures0/UI0, exit0. 최종 touch guard 추가 전 관찰본.
- `phone-touch-assumption.log` / 동명 폴더: 39개 검사 중 1개 실패. PC held-card 이동을 폰에도 가정한 검사였으므로 그대로 제품 결함 1개로 집계하지 않았다.
- `phone-final.log` / `phone-final/`: 폰의 기존 carried-card drop 계약에 맞춘 40개 검사 중 2개 실패, UI0. 고정된 빈 도착점으로 강화 카드 touch drop을 보냈을 때 Tower·선택 수 불변이 깨지는 경합을 포착했다. undo의 다른 38개 조건 및 reading_review 복구는 통과.
- `pc-latest.log` / `phone-latest.log`: touch guard 포함, 43개로 확장. touch 경합 조건은 GREEN. 두 환경 모두 toolbar pointer 선택 뒤 방향키가 GUI focus에 잡히는 1개 조건만 실패, UI0/exit1.
- `pc-verified.log` / `pc-verified/` 및 `phone-verified.log` / `phone-verified/`: root toolbar focus 복귀 수정 포함. **각 43/43 통과, failures0/UI0, exit0.** touch drop·실제 toolbar 선택→그룹 방향키 이동→Space 시작 모두 통과. 각 native 캡처 7장 생성. PC toolbar, 폰 카드 undo/지난 웨이브/toolbar 캡처를 직접 열어 확인했다.

touch 경합 수정은 PLACE + carrying 상태의 emulated MouseButton이 별도의 Tower press를 시작하지 않게 interaction에 guard를 둔다. 최종 폰 진단은 press/release 모두 PLACE/picks=1/pos=(280,300)/mod=0/object_press=false다. 원래 ScreenTouch drop 경로가 단독 처리함을 확인했다. 실제 Mouse 이동·AIM·일반 object touch는 별도 경로를 유지한다.

각 GREEN 실행 로그는 실제 복사된 helper/cards/interaction/card_dock/tool의 SHA-256과 viewport·배율·플랫폼을 기록한다. 폰 요청 해상도 2556×1179는 macOS native 창에서 높이 1180으로 반올림됐다. 실제 모바일 기기 검증으로 표현하지 않는다.

검사 내용: 실제 키·마우스·ScreenTouch 카드 적용/undo, 그룹·방향·이동, dice_miss/dice_x/dice_t/side_cd/side_n 및 cd/clock/cont_acc/answer/notify/light, mirror_src/Callable 실행 가능성, 새 Node만 제거, 공격방식이 비운 cd 복구, 보류/통계/로그 중복 방지, 업적/도감 복구, 격리 디스크 재독출, 새 정보/동기화/다른 판 경계, BF-44 인스펙터 상태 복구.

최종 실행에서 복사한 helper/cards/interaction/card_dock/tool SHA는 현재 파일과 모두 일치한다. 해시·캡처 목록은 `manifest.json`에 기록한다.

기존 rest `Tower.fade_fx()`는 focus_t를 즉시 0으로 만드는 규칙이다. 최초 RED의 복합 runtime 조건에는 3.7→0 baseline 초기화도 섞였으므로 그 항목을 독립적인 focus 손실 증거로 계산하지 않는다. 최종 검사는 rest의 focus_t=0을 기준으로 하고 별도 identity/dice/side/cd/Callable 손실을 검증한다. 최종 도구는 toolbar→Space로 WAVE에서 끝나며 ObjectDB 6-instance 종료 경고가 남았다(이전 READY endpoint는 2). 원인 분석하지 않았고 기존과 같다고 주장하지 않는다. Script/Parse Error는 없고 두 프로세스 모두 종료 0이다.
