# 사용자용 카드 접기 버튼

2026-11-04. 기준 `64541ac`, `codex/card-tooltip-controls` 후속 수정. 기존 모바일 전용 버튼을 PC에도 노출한다.

- 하단 왼쪽 `카드 접기`를 누르면 카드·인스펙터가 접히고 `카드 보기`로 바뀐다. 다시 누르면 같은 선택지·남은 장수로 펼친다.
- 기존 F 단축키를 유지한다. V로 숨긴 상태에서도 버튼은 `카드 보기`로 표시되고 한 번 눌러 복원한다.
- 전장 카메라 배율·위치는 바뀌지 않는다. 병행 중인 별도 포인터 입력 변경은 커밋에 포함하지 않았다.

## 검증

Godot 4.7.2 macOS arm64. 저장 이름 `BinduToolsCardFold`와 빈 온라인·멀티 주소를 사용한 사본이다. 커밋 대상과 검사 사본의 해시는 `source-hashes.json`에 기록했다.

- 전체 spec: 207개 기능, 실패 0 (`spec.log`).
- Native PC 1280×720·UI 100%: `FOLD failures=0 ui=0` (`desktop.log`).
- Native 폰 화면 모의 1560×720·UI 130%, 좌우 86/하단 38 안전 영역: `FOLD failures=0 ui=0` (`phone.log`).
- 두 화면에서 버튼 클릭으로 각각 3회 접기·펼치기, 선택지·장수·카메라 보존, V 숨김 후 버튼 복원을 확인했다. 펼침·접힘·복원 캡처 총 6장을 보존했고 PC 접힘 화면을 직접 확인했다.

Native 검사는 합성 마우스 이벤트를 사용했다. 실제 터치·실기기·배포는 검증하지 않았다. 일부 종료에 기존 ObjectDB 정리 경고가 남는다. 현재 실행 중인 게임은 다시 실행해야 바뀐 버튼 노출 조건이 적용된다.

## 재실행

격리 사본에서 `capture.gd`를 실행한다. PC는 마지막 인자를 생략하고 폰 화면 모의는 마지막에 `phone`을 붙인다.

```sh
"$GODOT" --headless --path "$QA_COPY" -s tools/spec_check.gd
"$GODOT" --path "$QA_COPY" --max-fps 60 --resolution 1280x720 -s "$CAPTURE_SCRIPT" -- "$OUTPUT/desktop" 1.0
"$GODOT" --path "$QA_COPY" --max-fps 60 --resolution 1560x720 -s "$CAPTURE_SCRIPT" -- "$OUTPUT/phone" 1.3 phone
```
