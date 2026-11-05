# 건너뛰기 그룹·하단 패널 여백

2026-11-04. `codex/card-tooltip-controls`, 기준 `2f4710f` 위 후속 수정.

## 변경

- 카드 선택 헤더와 웨이브 시작 대기에서 `넘기기 / N개 ▸`를 하나의 연결 그룹으로 표시한다. 가운데 구분선만 두고 바깥 모서리를 공유한다. 기존 실행·개수 버튼의 입력과 단축키는 유지한다.
- 헤더 컨트롤 높이 36, 헤더 위·아래 간격 8, 카드 아래 간격 8, 옵션 줄 위·아래 여백 각 12. 옵션 줄의 오른쪽 여백도 12로 맞췄다.
- 벡터 아이콘을 버튼 글의 왼쪽에 임의로 덧그리는 대신 native Button에 18px 아이콘 칸과 8px 간격을 확보한다. 투명 아이콘으로 native 텍스트 배치를 유지하고 실제 벡터 그림은 그 텍스트 옆에 배치한다. 관련 엔진 동작은 [Godot 4.7 Button 구현](https://github.com/godotengine/godot/blob/4.7/scene/gui/button.cpp)을 확인했다.
- 단축키가 있는 하단 버튼은 오른쪽 24px를 비워 본문·그림과 키 배지를 분리한다. 자세히 96, 새로고침 80, 필드 보기 64 너비를 사용한다.
- CardInspector 위치·동작은 변경하지 않았다.

## 검증

Godot 4.7.2 macOS arm64. 저장 이름 `BinduToolsGroupSpacing`, 온라인·멀티 주소를 비운 사본에서 실행했다. 온라인 설정을 제외한 scripts/tools GDScript는 작업 트리와 바이트 대조했다. `source-hashes.json`은 검사 대상 소스·계약의 SHA-256이다.

| 검사 | 결과 | 근거 |
|---|---|---|
| 전체 spec | 207개 기능, 실패 0 | `spec.log` |
| PC 1280×720, UI 100% | `CARRY failures=0 ui=0` | `desktop.log` |
| PC 1280×720, UI 130% | `CARRY failures=0 ui=0` | `large.log` |
| 폰 모의 1560×720, UI 130% | `CARRY failures=0 ui=0` | `phone.log` |

폰은 좌우 86·하단 38 안전 영역을 적용했다. Native 각 18개 화면, 총 54개 캡처를 실행했다. 실제 GUI 입력으로 개수 버튼의 1→3→5→10→1 순환·미소비, 실행/개수 버튼 인접 배치, 아이콘의 버튼 내부 배치, Q/Z/S/V 배지와 본문 사이 여백, 옵션 줄 상하 각 12를 확인한다. 기존 카드 클릭·드래그·터치·취소·앱 전환·확대·일시정지·시작 대기 검사도 함께 통과했다.

PC·큰 글자·폰의 펼친 옵션 줄, 자세히 활성 상태, 시작 대기 그룹을 직접 확인했다. 원본 대표 6장과 PC 하단 부분만 자른 `controls-preview.png`를 보존했다. 캡처 자르기 외 그림 수정은 하지 않았다.

실기기·실제 멀티·배포·서버 테스트·전체 배포 검사는 실행하지 않았다. 일부 검사 종료에 기존 ObjectDB 정리 경고가 남는다. Native 합성 입력 검사의 반복 재현성 한계는 이전 QA 기록과 같다.

## 재실행

저장과 온라인 주소를 분리한 사본에서 실행한다.

```sh
"$GODOT" --headless --path "$QA_COPY" -s tools/spec_check.gd
"$GODOT" --path "$QA_COPY" --resolution 1280x720 -s tools/carry_check.gd -- "$OUTPUT/desktop" 1.0
"$GODOT" --path "$QA_COPY" --resolution 1280x720 -s tools/carry_check.gd -- "$OUTPUT/large" 1.3
"$GODOT" --path "$QA_COPY" --resolution 1560x720 -s tools/carry_check.gd -- "$OUTPUT/phone" 1.3 phone
```
