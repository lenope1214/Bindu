# 카드 이름 말풍선 제거·하단 컨트롤 통일

2026-11-04, `codex/card-tooltip-controls`. 카드 이름 말풍선을 제거하고 빈 곳의 설치 안내·중앙 설치 불가 안내·대상 적용 미리보기는 유지한다. 버튼·셀렉트·드롭다운·카드·선택 헤더는 공통 표면을 재사용한다. 하단 배경은 카드 목록이 열렸을 때만 표시해 닫힌 뒤 전장 대상 선택을 막지 않는다. 배지 연결선은 카드 패널 앞에서 멈추며 확대 해제 버튼은 점수 줄 아래에 배치한다.

`CardInspector`를 커서 근처에 띄우는 변경은 의견만 논의했으며 이번 구현에 포함하지 않았다.

## 검증

Godot 4.7.2 macOS, `BinduToolsTooltipControls` 격리 사본. 온라인·멀티 주소는 비우고 실제 게임 저장과 서비스는 사용하지 않았다. 온라인 설정을 제외한 scripts/tools의 GDScript는 작업 트리와 바이트 대조했다. 검사 대상 SHA-256은 `source-hashes.json`에 기록했다.

- 전체 spec: 207개 기능, 실패 0 (`spec.log`).
- Native PC 1280×720, UI 100%: `CARRY failures=0 ui=0` (`desktop.log`).
- Native PC 1280×720, UI 130%: `CARRY failures=0 ui=0` (`large.log`).
- Native 폰 모의 1560×720, UI 130%, 좌우 86·하단 38 안전 영역: `CARRY failures=0 ui=0` (`phone.log`).
- 각 native 실행에서 16개 화면, 총 48개 캡처. 이름 말풍선 없음·설치/중앙 안내·확대/화면 끝·대상 미리보기·클릭/드래그/터치·무효 드롭·취소·일시정지·앱 전환·두 손가락 확대·드롭다운을 확인했다. 대표 7장을 보존했다.
- 화면 직접 확인: 카드 목록 100/130%·폰, 빈 곳 설치, 옵션 드롭다운, 폰 확대 화면의 설치 안내 잘림 해소.

검사 도구도 현재 동작에 맞췄다. 저장 설정 로드 이후 UI 배율을 적용해 130%가 실제로 검사되게 했으며, 터치 방향 선택 뒤에는 확정 버튼으로 설치한다. 이전 도구는 방향 선택만으로 설치를 기대해 수정 전 코드에서도 실패했다 (`baseline-native.log`).

Native 합성 입력 검사에서는 일부 첫 클릭·드래그가 간헐 실패해 재실행했다. 진단 실행에서 OS 포인터 이벤트가 합성 입력 사이에 섞이는 것을 관찰했으나 모든 간헐 실패의 원인은 확정하지 않았다. 최종 로그의 각 실행은 실패 0이며, native 입력 검사의 반복 재현성에는 한계가 남는다.

전체 배포 검사·서버 테스트·실기기·실제 멀티·배포는 실행하지 않았다. 일부 검사 종료에 기존 ObjectDB 정리 경고가 남는다.

## 재실행

저장 이름과 온라인 주소를 분리한 사본에서 실행한다.

```sh
"$GODOT" --headless --path "$QA_COPY" -s tools/spec_check.gd
"$GODOT" --path "$QA_COPY" --resolution 1280x720 -s tools/carry_check.gd -- "$OUTPUT/desktop" 1.0
"$GODOT" --path "$QA_COPY" --resolution 1280x720 -s tools/carry_check.gd -- "$OUTPUT/large" 1.3
"$GODOT" --path "$QA_COPY" --resolution 1560x720 -s tools/carry_check.gd -- "$OUTPUT/phone" 1.3 phone
```
