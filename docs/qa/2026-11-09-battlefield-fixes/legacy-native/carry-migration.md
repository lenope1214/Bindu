# carry_check 현재 조작 명세 마이그레이션

2026-11-09. `tools/carry_check.gd`만 수정. 제품 geometry 수정은 root가 담당했다. 원래 RED는 `carry_check-pc-before/`, `carry_check-phone-before/`에 보존했다.

최종 canonical `carry_check-pc/run.log`: **127조건·failures0/UI0·exit0**. `carry_check-phone/run.log`: **130조건·failures0/UI0·exit0**. 각 로그의 CARRY SOURCE 해시와 `carry-manifest.json` 참고. 폰 touch-selected/browse-expanded/element-aim 캡처를 직접 열어 선택·정보·여백·수동 조준 상태를 확인했다.

## 판정

- 카드 fixture는 `mod:pierce`인데 이름을 `다중 발사`로 기대했다. `picked == card`와 실제 이름 `관통 놓는 중`을 함께 검사한다.
- 기본 auto_aim 즉시 설치는 새 input 도구가 검증한다. 기존 수동 AIM·취소·확정 검사는 `auto_aim=0`을 명시한다. 중간 fixture._fresh()가 Rules를 다시 적용하므로 터치 수동 AIM 구간에도 0을 다시 둔다. AIM/선택수/오브젝트 수 기대값을 완화하지 않았다.
- 기존 `(220,620)` 대상은 새 폰 하단 편집 toolbar에 가려졌다. PLACE의 카드 줄 뒤 대상 검사는 그대로 두고, 정보/선택 검사만 노출된 `(280,300)`으로 이동했다. `over_ui=false` precondition을 추가했다.
- 폰의 큰 카드 패널 header는 world core까지 올라온다. 이전 '빈 배경' 클릭의 `old_core_over_ui=true`를 native에서 확인했다. 실제 빈 전장 `(640,200)`은 `over_ui=false`이며, 미리보기/picks뿐 아니라 offer/reroll도 불변인지 강화했다.
- **제품 결함**: 폰 옵션 bar 상하 여백은 20/8이었다(높이40, footer68). 12/12 기대를 유지해 root에 전달했다. root가 CONTROL_HEIGHT 최소높이·offset 및 footer를 정렬한 뒤 실제44h/12/12 확인. PC는 원래36h/12/12 유지.
- 새 폰 정책은 별도 실제 touch 조건으로 검증한다. 카드가 열린 상태의 명시 object select는 카드 접기+전체 정보, preview 기본 접힘, X는 원래 카드/picks 복원. 방향 편집은 카드가 이미 접힌 별도 상태에서 검사한다. hover 정보의 preview 기본 접힘도 추가했다.

기존 드래그·무효 대상·화면 밖·Esc·focus loss·pause·pinch·touch emulation on/off·카메라 불변·스크롤·방향·배속 조건을 삭제하지 않았다. `carry_check-phone-migration.log`는 두 잔여 원인, `carry_check-phone-layout-probe.log`는 빈 배경 fixture 해결과 제품 bar 여백 RED 한 개를 보여 준다.

네이티브는 macOS Godot+가상 ScreenTouch이며 실제 모바일 장치 증거가 아니다. 종료 ObjectDB 2-instance 경고는 원래 RED와 최종에 동일하며 Script/Parse Error는 없다.
