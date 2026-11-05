# 사용성 개선 5개 항목

2026-11-04. `codex/card-tooltip-controls`에서 항목별로 커밋했다. Godot 4.7.2, macOS 가상 GUI 입력으로 검증했다.

1. 카드 접기: 하단 버튼 하나와 F/V가 같은 접힘 상태를 토글한다. 같은 선택지·장수로 반복 복원하며, 카드를 접어도 오브젝트 상세는 읽을 수 있다. (`01-panel-spec.log`)
2. 인스펙터: 스크롤 밖 고정 헤더에 ×. Esc는 진행 중 조작 취소 → 선택·상세 해제 → 일시정지 순서다. 같은 대상 위에서 닫아도 다시 열리지 않고, 터치 카드 미리보기·속성 범위도 닫힌 상태를 유지한다. (`02-inspector-spec.log`)
3. 오브젝트: 클릭/터치는 선택·상세 확인. 쉬는 시간에 내 오브젝트 하나를 선택하면 [방향 변경]으로 편집한다. 취소는 원래 방향·선택 복원, 확정은 선택 해제. 끌어서 이동·다중 선택·우클릭 조준은 유지한다. 전투 중에는 읽기 전용이다. (`03-selection-spec.log`, `03-selection-ui.log`)
4. 넘기기: `N웨이브 ▸`로 단위를 명시하고, 실행 툴팁에 보류할 카드 선택·새로고침(특성 중에는 특성 1회)을 안내한다. 수 변경만으로 시작하지 않는다. (`04-skip-spec.log`)
5. 상태 안내: 카드 배치·설치 방향·기존 방향 편집·이동·영역 선택·선택 개수와 취소 방법을 공통 하단 상태 칸에 표시한다. 새 카드 선택·대상 삭제 시 오래된 선택을 정리한다. 설치 안내·적용 미리보기·인스펙터가 상태 칸과 조작 버튼을 피한다.

## 최종 검증

- 전체 명세 210개 통과: `05-final-spec.log`.
- PC 1280×720, 글자 100%·130% / 모바일 모의 화면 1560×720, 글자 130%·안전 영역에서 모두 `CARRY failures=0 ui=0`.
- 환경별 27회 렌더 캡처에서 UI 겹침·화면 밖 배치·잘림 0건. 대표 화면 14장을 보존했다.
- 반복 버튼·F/V 토글, 카드/오브젝트 인스펙터 유지·휠 스크롤·대상 변경·×, Esc 3단계, PC/터치 방향 편집·취소·배경 해제, 넘기기 단위·수 변경, 배속 그룹, 카드 클릭·드래그·취소·앱 전환·두 손가락 확대·잘못 놓기·카메라 독립성 검사.
- 설치·적용 안내의 실제 렌더 사각형과 상태·취소 버튼이 겹치지 않는지도 별도 검사했다.
- 무작위 입력 2판 × 2,000프레임, 스크립트 오류 0개: `05-fuzz.log`.
- 실행 도구가 저장 데이터를 분리하고 온라인 주소를 비운 사본을 사용한다. OS 커서 불변·no_focus·minimized·포커스 미점유를 검사했다.

## 대표 화면

- [PC 패널 130%](desktop130/browse-expanded.png), [PC 선택](desktop100/object-selected.png), [방향 편집](desktop100/direction-edit.png)
- [PC 적용 미리보기](desktop100/held-target.png), [인스펙터 스크롤](desktop100/inspector-scrolled.png), [10웨이브](desktop100/skip-ten.png)
- [모바일 패널](phone130/browse-expanded.png), [터치 선택](phone130/touch-selected.png), [터치 방향 편집](phone130/touch-direction.png), [터치 카드 배치](phone130/touch-held.png)

## 재현

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh spec
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui carry_check.gd /tmp/bindu-usability-final/desktop100 1.0
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui carry_check.gd /tmp/bindu-usability-final/desktop130 1.3
RESOLUTION=1560x720 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui carry_check.gd /tmp/bindu-usability-final/phone130 1.3 phone
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh fuzz 2 2000
```

검증 대상 파일 해시는 `sources.sha256`. 실기기·실제 OS 입력·멀티플레이·배포는 검증하지 않았다. UI 도구 종료 시 기존 `2 ObjectDB instances were leaked at exit` 경고가 남으며, 기능 실패·스크립트 오류는 없었다.
