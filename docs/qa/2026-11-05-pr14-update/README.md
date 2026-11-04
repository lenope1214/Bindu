# PR #14 최신 main 통합 검사

2026-11-05, Godot 4.7.2, macOS Apple M4. main `43351c4`를 병합하고 사용성 수정 13개 커밋을 기존 PR 브랜치에 반영했다.

- 새 속성·특성 길게 누르기·DPS 표 이동을 보존했다. UI-34·35는 기존 자동 검사·상태 줄 명세를 유지하고 새 점수 줄/DPS 입력 명세를 UI-36으로 분리했다.
- 인스펙터 내부 입력은 패널이 받는다. 점수 줄 아래 오브젝트 예외는 칩과 오브젝트가 동시에 반응하지 않도록 검사했다.
- 신규 화면 검사 도구도 `tools/run.sh ui`와 VirtualInput을 사용한다. 저장 사본·온라인 주소 비움·최소화·포커스 비점유 상태에서 실행했다.
- 병합 후 튜토리얼 정보창 단계가 과거 `tip_frame`만 검사해 멈추던 문제를 수정했다. 실제 현재 상세 대상 기준으로 판정하고 회귀 검사도 프레임 값 주입 대신 오브젝트 선택으로 실행했다.
- 카드 설명 검사는 공통 헤더로 변경된 뒤 남은 카드명 비교 조건을 갱신했다. 실제 카드명과 본문 전체 검증은 유지했다.
- PR 템플릿 없음. 최근 커밋의 Conventional Commit 한국어 제목·불릿 본문 형식을 사용했다. 필수 서명·추가 트레일러는 확인되지 않았다.

## Tested

아래 `GODOT`은 `/Applications/Godot.app/Contents/MacOS/Godot`. 최종 검사 대상 소스는 [sources.sha256](sources.sha256)에 기록했다.

| 명령 | 종료 | 관찰 결과 | 근거 |
|---|---|---|---|
| `GODOT=… tools/run.sh check` | 0 | 명세 231개·튜토리얼 4개 경로·fuzz 4×3000프레임·이어하기 13웨이브·온라인·패치/규칙 목록 통과 | [check.log](check.log), [spec.log](spec.log), [tutplay.log](tutplay.log) |
| `RESOLUTION=1560x720 GODOT=… tools/run.sh ui usability_check.gd /tmp/bindu-pr14-usability-final 1.3 phone all` | 0 | 모바일 상세·소유권·정지·방향 편집·반복 겹침 클릭·HUD 단독 선택·특성 길게 누르기, failures=0 ui=0 | [로그](usability-phone130.log) |
| `GODOT=… tools/run.sh ui carry_check.gd /tmp/bindu-pr14-carry-pc 1.3` | 0 | PC 카드 접기/복원·선택·인스펙터·연결 배속 그룹, failures=0 ui=0 | [로그](carry-pc130.log) |
| `RESOLUTION=1560x720 GODOT=… tools/run.sh ui carry_check.gd /tmp/bindu-pr14-carry-phone 1.3 phone` | 0 | 모바일 카드 접기/복원·선택·인스펙터·연결 배속 그룹, failures=0 ui=0 | [로그](carry-phone130.log) |
| `RESOLUTION=1560x720 GODOT=… tools/run.sh ui card_writing_check.gd /tmp/bindu-pr14-card-writing-final 1.3 phone` | 0 | 전체 카드 설명·본문·가로 넘침·끝줄 도달, failures=0 captures=162 | [로그](card-writing-phone130.log) |
| `RESOLUTION=1560x720 GODOT=… tools/run.sh ui newelem_shot.gd /tmp/bindu-pr14-newelem 1.3 touch phone` | 미수집 | 새 속성 카드·전장·정보·도감 6장 캡처. 도감 모달 자동 겹침 경고는 아래 한계에 분리 | [로그](newelem-phone130.log) |
| `git diff --check` | 0 | 공백 오류 없음 | 로컬 실행 |

실패를 먼저 관찰한 기록은 [check-before.log](check-before.log)와 [card-writing-before.log](card-writing-before.log)에 보존했다. 전자는 튜토리얼 정보창 단계와 패치 목록 동기화, 후자는 헤더 검증 조건이 원인이다.

## 화면 확인

[오브젝트 상세](object-detail.png), [일시정지 중 인스펙터](paused-inspector.png), [특성 길게 누르기](perk-long-press.png), [새 속성 카드](new-elements.png), [도감 모달](codex-modal.png), [피 상세 끝줄](blood-detail-bottom.png), [환영 상세 끝줄](illusion-detail-bottom.png).

## Not-tested / 남은 한계

- 서버 pytest는 현재 python3에 fastapi·pytest·httpx가 없어 전체 check가 명시적으로 건너뛰었다. 과거 서버 로그를 최신 검사로 사용하지 않았다.
- 실기기·실제 OS 드라이버 입력·Windows/Linux·실제 네트워크 멀티·배포는 미검증이다. 모바일은 Mac에서 화면비·안전 영역·터치를 모의했다.
- 일부 native 검사 종료 시 ObjectDB 정리 경고 2개가 남는다.
- 새 속성 도감 캡처에서 모달과 배경 HUD/배지 사이 자동 겹침 경고 10건이 나온다. 모달이 전장 위를 덮는 상태를 눈으로 확인했다. 전체 UI 스트레스·투표·기본 shot의 기존 경고들은 이번에 재실행하지 않았다.
