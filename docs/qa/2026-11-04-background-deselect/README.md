# 배경 클릭으로 오브젝트 선택 해제

2026-11-04, 기준 `c962755`. 선택·대기·전투에서 빈 배경을 일반 클릭하면 오브젝트 선택과 유지된 인스펙터·터치 상세 참조를 지운다. 수정키로 선택을 추가하는 기존 규칙은 유지한다. 기존 오브젝트 방향 편집은 원래대로 확정한 뒤 상세 참조를 지운다. 카드 설치·방향 확정과 인스펙터 내부 클릭·스크롤, 카드 미리보기는 유지한다.

접힌 설정 줄 전체의 투명한 HBox 영역이 배경 입력을 막지 않도록 보이는 자식들의 합친 영역으로 UI 판정을 제한했다. 펼친 설정 줄의 버튼 사이 간격은 계속 UI로 처리한다.

## 검증

Godot 4.7.2 macOS arm64. 저장과 온라인 주소를 분리한 사본에서 검사했다. UI 검사는 `tools/run.sh ui`가 설정하는 no_focus·최소화·Dummy 오디오와 VirtualInput을 사용하며 OS 커서·포커스를 변경하지 않는다.

- 전체 spec 208개 기능, 실패 0 (`spec.log`).
- PC 1280×720, UI 100%: `CARRY failures=0 ui=0` (`desktop.log`).
- 폰 화면 모의 1560×720, UI 130%·안전 영역: `CARRY failures=0 ui=0` (`phone.log`).
- 선택 상태와 터치 상세 참조를 둔 뒤 빈 배경 클릭으로 모두 해제됨을 확인했다. 투명 설정 영역, 패널 내부 클릭·휠 스크롤, 해제 후 새 오브젝트 호버, 실제 오브젝트 클릭→방향 편집→배경 확정→상세 해제, 카드 미리보기·남은 장수 보존을 GUI 이벤트로 확인했다. 기존 카드 클릭·드래그·터치·취소·확대·배속 회귀 검사도 통과했다.
- PC 인스펙터 유지/배경 클릭 후와 폰 클릭 후 캡처를 보존했다. 검사 대상 파일을 사본과 바이트 대조하고 SHA-256을 기록했다.

실기기·OS 입력 드라이버·실제 멀티·배포는 미검증이다. 일부 검사 종료에 기존 ObjectDB 정리 경고가 남는다.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh spec
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui carry_check.gd /tmp/background-pc 1.0
RESOLUTION=1560x720 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui carry_check.gd /tmp/background-phone 1.3 phone
```
