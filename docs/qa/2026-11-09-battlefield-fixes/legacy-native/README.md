# 기존 native 검사 마이그레이션

현재 일반 판의 기본 자동 조준·명시적 방향 편집·폰 정보 확장 정책에 맞춰 기존 검사의 기대값과 초기 상태를 갱신했다. 기존 카메라 불변·중복 소비 방지·취소·무효 대상·드래그·스크롤 검사는 유지한다.

- [carry PC](carry_check-pc/run.log):127단언, exit0, `failures=0 ui=0`.
- [carry 폰130% 모의](carry_check-phone/run.log):130단언, exit0, `failures=0 ui=0`.
- [첫 일반 판 PC](first_play_check-pc/run.log), [폰](first_play_check-phone/run.log):각14단언, exit0, `NATIVE FIRST failures=0`.

## 실패 분류와 보완

1. 순환 횟수 버튼의 이전 기대값을 직접 선택 메뉴 열기·선택·무소비 검증으로 바꿨다. 카드 이름은 fixture의 관통 카드와 일치시켰다.
2. 기본 즉시 설치는 `battlefield_input_check`에서 검증한다. 기존 AIM 취소·확정 구간은 `auto_aim=0`을 명시해 수동 조준 지원을 계속 확인한다. fixture 재설정이 Rules를 다시 적용하므로 각 수동 구간에서 설정한다.
3. 폰 정보 검사 대상이 새 조작 툴바 뒤에 있던 좌표를 노출된 전장으로 옮기고 `over_ui=false` 전제를 확인한다. 카드 뒤 대상을 들고 적용하는 별도 검사는 유지한다. 카드가 열린 상태의 ‘빈 배경’도 실제 카드 헤더 밖의 전장인지 확인한다.
4. 폰 명시적 선택→카드 자동 접힘→전체 정보→X로 같은 카드 복원을 추가로 검증한다. 접힌 공격 예시를 직접 열어 기존 스크롤/공격 검사를 수행한다.
5. 실제 제품의 폰 옵션 줄 여백은20/8로 달랐다. 기준12/12를 낮추지 않고 `CONTROL_HEIGHT=44`와 아래12를 맞춰 고쳤다. 최종 실측12/12·높이44다. 왼쪽 조작 버튼도 같은 높이/아래 여백으로 맞췄다.

`*-before`, `*-migration.log`, `*-layout-probe.log`는 중간 실패를 보존한다. 최종 통과는 위 canonical `run.log`만 사용한다. 합성/native 결과는 물리 손가락이나 iOS·Android의 이벤트 순서를 증명하지 않는다.
