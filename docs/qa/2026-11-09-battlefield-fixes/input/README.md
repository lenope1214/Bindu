# 전장 입력 개선 증거

범위: BF-01·03·04·06·09·12–19, BF-05의 수정키 경계, BF-45의 적 정보 고정 입력 연결. 제품 구현은 `scripts/features/interaction.gd`만 변경했다. `placement_policy.gd`의 기존 순수 배치 규칙은 그대로 재사용한다.

## 관찰

- [수정 전](before.log): 같은 새 입력 검사 종료 코드 1, `BATTLEFIELD INPUT failures=11 ui=0`.
- [PC 100%](pc.log): 종료 코드 0, `failures=0 ui=1`.
- [폰 130% 모의](phone.log): 종료 코드 0, `failures=0 ui=0`.
- PC의 UI 경고 1건은 연속 진행 버튼과 웨이브 수 메뉴의 6px 겹침이다. 입력 소유 파일 밖 `CardDock` 통합에서 해결해야 하며 입력 기능 통과를 전체 화면 통과로 해석하지 않는다.
- Godot 4.7.2 native / 격리된 BinduTools 저장 / 서버 URL 공백 / VirtualInput / no_focus·최소화 창. 실제 폰·OS 포커스 전환·실통신 멀티 증거는 아니다.
- 도구 종료의 기존 ObjectDB 2개 경고가 남는다. 최종 PC·폰 로그에 parser·script error는 없다.

## 확인한 행동

1. 설정·도움말 뒤 카드·새로고침·넘기기·시작 단축키 차단. Ctrl 조합의 plain 명령 실행 차단.
2. 거리 24 대 11에서 가까운 대상 선택, 생성 순서가 바뀐 동률에서 위치 기준 결정.
3. 반복 선택으로 편집에 들어가지 않음. 정보창 명시적 닫기 뒤 재선택은 CHOOSE·WAVE에서 복구.
4. 정지한 0.45초 누르기는 이동하지 않음. 일반 휠은 선택 위에서도 확대.
5. 전투 Esc는 정보창 상태와 관계없이 즉시 정지.
6. 기본 자동 조준 새 설치는 방향 단계 없이 정확히 1회 완료. 연습 판은 기존 방향 학습 유지.
7. 터치 선택 추가·제외, 그룹 상대 회전, 공통 방향 편집·확정, 취소 시 원래 방향과 다중 선택 복구.
8. Tab 순환·화살표 이동, 키보드만으로 새 설치 및 대상 순환 후 강화 적용.
9. 손을 떼기 전에 무효 드래그 이유·대상을 조회하고 무효 이동은 모두 원복.

## 공개 연결점

- `additive_selection`, `set_additive_selection(on)`, `toggle_additive_selection()`, `select_all()`, `clear_selection()`.
- `cycle_selection(backward=false)`, `move_selected(world_delta) -> bool`, `rotate_selected(radians)`.
- `_edit_selected_direction()`는 선택 전체에 같은 방향을 지정하는 AIM 편집. 우클릭은 누른 오브젝트만 편집.
- `drag_preview() -> {active, valid, reason, invalid, targets}`, `drag_refusal`, `drag_invalid`는 화면의 지속 피드백용.
- `keyboard_active`, `_pointer_screen()`·`_pointer_world()`는 OS 커서를 옮기지 않고 키보드 배치 포인터를 제공한다.
- `cards_system.begin_edit(label)`·`finish_edit()`·`undo_edit()`는 존재할 때 호출. 전체 저장/RNG/기록 복원 검증은 공통 undo 구현의 책임이며 여기서는 Ctrl+Z의 잘못된 자세히 실행 차단만 검증했다.
- WAVE의 적 탭은 `field_view_system.pin_orb_at()`에 연결하고 오브젝트 정보는 닫는다. 오브젝트 명시적 선택은 `clear_orb_pin()`으로 이전 적 고정을 해제한다.

## 재실행

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_input_check.gd /tmp/bindu-input-pc 1.0
RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_input_check.gd /tmp/bindu-input-phone 1.3 phone
```

`tools/run.sh` 임시 사본의 자동 정리와 종료 코드를 확인했다. 중간 타입 추론 오류는 수정 후 재실행했고, 종료한 중간 실행의 혼합 로그는 최종 증거에서 제외했다. 통합 이후 전체 spec·기존 carry/usability·실기기 범위는 root가 별도로 검증한다.
