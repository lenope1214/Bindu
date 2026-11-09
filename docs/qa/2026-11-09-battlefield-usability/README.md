# 전장 사용성 진단 증거

진단 본문: [전장 행동 전반 사용성 진단](../../battlefield-usability-audit-2026-11-09.md).

## 기준과 범위

- 기준: `origin/main` = `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9`. 조사 중 `git fetch origin main`, 종료 전 `git ls-remote origin refs/heads/main`으로 확인.
- 브랜치: `codex/battlefield-usability-audit`. 게임 버전 `0.11.5`, Godot `4.7.2.stable.official.ed1daf0bf`, macOS / Apple M4 / OpenGL Compatibility.
- 변경: 진단 문서·증거·진단용 도구만 추가. 기존 제품 소스·규칙·저장 방식·카메라는 변경하지 않음.
- `tools/run.sh ui`가 임시 사본을 만들고 `config/name=BinduTools…`, 서버·멀티 URL 공백, no_focus·최소화 창, 별도 VirtualInput Viewport를 사용함. 개인 Bindu 저장 및 OS 커서를 사용하지 않음.
- 상태 준비에는 fixture·직접 상태 주입 사용. 진단 행동에는 실제 GUI 입력 이벤트 사용. 시간 진행은 `main.frame_system._process(delta)`로 관찰. 실제 사용자 관찰 시험과 구분.

## 실행 결과

| 실행 | 물리 해상도 | UI 배율 | 입력 | 관찰값 | PNG | 결과 |
|---|---|---|---|---:|---:|---|
| actions-pc | 1280×720 | 100% | 마우스·키 | 25 | 21 | 관찰 완료, script error 0 |
| pc130 | 1280×720 | 130% | 마우스·키 | 25 | 21 | 관찰 완료, script error 0 |
| actions-phone | 2556×1179 | 130% | ScreenTouch·에뮬레이션·키 | 26 | 22 | 관찰 완료, script error 0 |
| first-phone | 2556×1179 | 130% | 기존 첫 판 검사 | 기존 TUT 단언 | 7 | `NATIVE FIRST failures=0` |
| pc·phone shot | 위와 동일 | 100%·130% | 합성 화면 | 레이아웃 참고 | 2장 보존 | 전체 로그 보존 |

폰의 게임 Viewport 논리 크기는 `1560.916…×720`, 안전 영역은 `Rect2(86,0,86,38)` 모의다. 물리 px·게임 논리 좌표·UI 내부 좌표를 혼용하지 않는다. PC·폰 UI에서 키보드 분기를 함께 실행했으며, 폰에 키보드가 항상 있다는 가정은 하지 않는다.

주요 관찰 76개는 독립 결함 76개가 아니다. 같은 행동을 기기·배율별로 반복한 결과다. 문서는 중복 원인을 묶어 재현 21개, 코드 확인 22개, 가설 7개로 정리했다.

## 현재 확인된 결정적 결과

| 관찰 ID | 결과 | 문서 |
|---|---|---|
| settings-number-key | 설정 visible 상태에서 CHOOSE→PLACE | BF-01 |
| help-reroll-key | 도움말 visible 상태에서 새로고침 1→0 | BF-01 |
| settings-space-start | 설정 visible 상태에서 READY→WAVE | BF-01 |
| help-skip-key | 도움말 visible 상태에서 bank 2, skip 3 | BF-01 |
| phone-card-detail-hold / release | 자세히 켬·0.45초 누르기에도 미리보기 없음, release 후 PLACE | BF-02 |
| wave-explicit-close-reopen | 닫기 전 정보 visible, 다른 대상+Z 뒤에도 dismissed·비표시 | BF-03 |
| nearby-target | 첫 대상 거리 24, 둘째 11, 첫 대상 선택 | BF-04 |
| undo-after-card | Ctrl+Z 후 관통 1·선택 1 유지, 자세히 켜짐 | BF-05 |
| wave-first-escape / second | 첫 Esc는 비정지, 둘째 정지 | BF-06 |
| focus-out-wave | 합성 포커스 상실 후 시간 0→0.05, tree 비정지 | BF-07 |
| auto-start-while-inspecting | 정보창 visible 상태였으나 2.1초 뒤 WAVE | BF-08 |
| new-placement-needs-direction | auto_aim=true, 새 설치는 AIM 대기 | BF-09 |
| inspector-with-cards | 폰 본문 높이 79, 내용 그림 최소 높이 400 | BF-20 |
| dps-row-tap | 표 강조·정보는 존재, 전장 선택 수 0 | BF-41 |

## 캡처·로그

- [actions-pc.log](actions-pc.log), [actions-phone.log](actions-phone.log), [pc130.log](pc130.log), [first-phone.log](first-phone.log).
- 각 실행 폴더 `observations.json`: 입력 후 상태·남은 횟수·선택·크기 등 관찰값.
- [capture-manifest.json](capture-manifest.json): 저장된 모든 PNG의 경로·크기·SHA-256·대상 소스 리비전과 상태 이름.
- `01` 방향 대기, `02` 한 번 취소, `03` Ctrl+Z, `04` 반복 선택, `05` 길게 누르기, `06` PC 휠, `07` 가까운 대상, `08–11` 창 뒤 단축키, `12` 자동 시작, `13` 포커스 상실, `14` 기술 조준, `15` Esc 정지, `16` Space, `17–18` 넘기기, `19` 정보 재열기, `20–21` 폰 카드 읽기, `22` 정보 높이, `23` DPS 표.
- 폰에는 PC 전용 `06`이 없고 PC에는 폰 전용 `20–21`이 없음. 일부 번호의 실제 PNG는 본문과 JSON에서 함께 해석한다.
- `shot.gd` 실행 로그는 게임 밖 메뉴를 포함하지만 보존한 캡처는 카드 비교 2장뿐. 이전 합성 카드·의도적으로 화면 밖에 준비한 오브젝트·검사 중 입력 모드 변경은 결함 근거에서 제외했다.

자동 UI 검사 메시지는 PC 9, PC130 16, 폰 31이다. 대부분은 설정·도움말과 뒤 HUD의 의도적 겹침이다. 검토 없이 56개 결함이라고 해석하면 안 된다. 본문에 포함한 정보창/넘기기 배지 겹침은 실제 PNG도 확인했다. 반대로 카드 요약의 말줄임은 `UI ok`여도 판단 정보가 누락됐다.

도구 종료에 `ObjectDB instances were leaked at exit` 경고가 일부 남는다(진단 도구 실행에서 2개, 기존 shot 4개). 런타임 충돌·제품 메모리 누수로 확장하지 않았다. 중간 작성 과정의 도구 오류는 수정 후 다시 실행했고, 보존한 최종 로그에 `SCRIPT ERROR`·`ERROR:`가 없음을 확인했다.

## 재실행

저장 분리를 위해 아래 실행기를 사용한다. 원본 프로젝트에서 `godot -s`로 직접 실행하지 않는다.

```sh
BINDU_AUDIT_REVISION=$(git rev-parse HEAD) GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_usability_audit.gd /tmp/bindu-audit-pc 1.0
BINDU_AUDIT_REVISION=$(git rev-parse HEAD) GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_usability_audit.gd /tmp/bindu-audit-pc130 1.3
BINDU_AUDIT_REVISION=$(git rev-parse HEAD) RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_usability_audit.gd /tmp/bindu-audit-phone 1.3 phone
RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui first_play_check.gd /tmp/bindu-audit-first-phone 1.3 touch
```

진단 도구는 제품이 옳은지를 단언하는 회귀 테스트가 아니다. PC는 25·폰은 26개의 관찰이 모두 기록돼야 종료 코드 0이다. 개선 뒤에는 현상 값이 바뀌어야 하므로 이를 보존하는 테스트로 사용하면 안 된다. `BINDU_AUDIT_REVISION`이 없으면 리비전은 `unrecorded`로 남는다. 도구의 fixture는 규칙 1·평원·wave 12·두 오브젝트·고정 카드 3장이다. 첫 판 검사는 별도 초기 상태를 사용한다.

## 판정과 남은 범위

현행 화면은 개선 필요. [시각 관찰 판정](visual-verdict.json)은 현재 캡처를 본 단일 전문가의 정성 평가이며 고객 만족도·과제 성공률·성능 측정값이 아니다. 수정·재캡처는 이번 문서화 범위 밖의 다음 작업이다.

- 실제 OS 입력 포커스·트랙패드·손가락 가림: 미관찰.
- iOS·Android 실기기·실제 앱 중단·태블릿: 미관찰.
- 실제 두 참가자 연결·협동·대결·재연결: 미관찰.
- 후반 대량 구체·GPU 렌더 부하·입력 지연: 미측정.
- 스크린리더·색각·실측 대비·모든 배율·모든 화면 크기: 미검증.
- 사람 대상 과제 시험·실제 VOC 분류·빈도·인과·개선 효과: 미측정.
- 독립된 두 번째 리뷰·픽셀 전후 비교·수정 후 검증: 미수행.

전체 제품 QA 통과·접근성 통과·실기기 사용성 통과·배포 준비 완료를 의미하지 않는다. 구현·전체 check·커밋·push·PR·배포는 이번 작업에서 수행하지 않았다.
