# 전장 사용성 수정 검증 기록

**최신 전달 상태:** main8704b78 rebase 뒤 [새 전체 검증](delivery/README.md)을 통과했다. 아래 수치는 수정 과정의 보존 기록이며 최신252개 명세·55 actor 통신 결과와 구분한다.

작업 진행 중. 브랜치 `codex/battlefield-usability-audit`, 기준 main `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9`. [진단 50개](../../battlefield-usability-audit-2026-11-09.md), [항목별 구현·잔여 범위](../../battlefield-usability-implementation.md). 일반 조작·협동 거래·마지막 화면 수정의 증거를 아래처럼 구분한다. 실기기·사용자 과제와 후반 고배속 전체 지연은 미해결 범위다.

## 확인한 결과

| 범위 | 관찰 결과 | 증거 |
|---|---|---|
| 공통 gate | exit0. 명세250개·전달 상태86개, 미리보기 basic300사례/3600표본·deaths45/540, 플레이 튜토리얼, fuzz4시드, W4·8·12 복원 및 W13 도달, 온라인/패치/키, 서버28개 통과 | [최신 공통 로그](final-check-after-ui.log), [소스](final-check-manifest.json) |
| 카드 읽기·정지·마지막 적용 복원·기록 읽기 | PC/폰 각각16단언·실패0·UI0 | [PC](integration/core-pc/run.log), [폰](integration/core-phone/run.log) |
| 입력 | PC26·폰25단언, 실패0·UI0 | [PC](integration/input-pc/run.log), [폰](integration/input-phone/run.log) |
| 진행·기술·실제 로컬 저장/이어하기 | 각각31단언·실패0. PC UI0, 폰 설정 모달의 의도된 뒤 HUD 겹침8건 | [PC](integration/flow-pc/run.log), [폰](integration/flow-phone/run.log) |
| 합성 중단·복귀 | 각각62단언·실패0·UI0. CHOOSE/PLACE/AIM/READY/WAVE/기술/연속 진행 × focus-out/paused 알림 | [PC](integration/lifecycle-pc/run.log), [폰](integration/lifecycle-phone/run.log) |
| 원래 객체를 보존하는 undo | PC/폰 각각43단언·실패0·UI0, 실제 버튼 뒤 키보드 포커스와 터치 중복 포함 | [별도 증거](undo/README.md) |
| 기존 카드 조작 | PC127·폰130단언, 실패0·UI0. 기존 드래그/취소/카메라 보존과 새 폰 읽기 경로 | [기존 검사 보완](legacy-native/README.md) |
| 첫 일반 판 | PC/폰 각각14단언·실패0, 기본 즉시 설치는 별도 입력 검사와 분리 | [PC](legacy-native/first_play_check-pc/run.log), [폰](legacy-native/first_play_check-phone/run.log) |
| 협동 거래 통합 뒤 일반 조작 | PC/폰16묶음·680단언·실패0·runtime ERROR0. 폰 flow의 의도된 모달 겹침8건은 별도 기록. 배치 도중 pending 전용 표시가 바뀐 소스 경계도 명시 | [최신 묶음](final-native/README.md) |
| 마지막 화면 수정 뒤 응답형 검사 | 고정 사본에서 PC70/85/100/115/130%, 태블릿130%, 폰130% 모의 ×5장면 =35장면, 겹침/잘림/화면 밖0. core PC/폰 추가2묶음0실패 | [결과](final-layout/results.json), [소스](final-layout/source-manifest.json) |
| 정보·기존 사용성 | PC/폰 실제 native 버튼·hover·touch·숫자 우선·예시 opt-in·정지·권한 | [정보](information/README.md), [상세 통합](usability/README.md) |
| 64종 카드 앞면 | 실제 Meta.fs 글꼴/폭/3줄·핵심 수치/부정어·온라인 패치 반영 및 전체 설명 보존 | [상세 통합](usability/README.md) |
| 실제 로컬 멀티 | 협동3인14조건·협동/대결2인·PC/폰 대기 표시 후속, 총67 actor 실행·651단언·행동/UI실패0. 검사 뒤 QA 종료에서 발생한 SCTP3줄과 종료 절차 교정 후 strict0을 분리 보존 | [멀티 증거](multiplayer/README.md), [거래 후속](multiplayer/gift/README.md) |
| 후반 부하 | 16개 오브젝트·약300구체, 1/4/8배속×효과 줄이기 켬/끔, 30준비+180표본/조건. main/current 동일 도구 비교 | [측정 의미·결과](performance/README.md) |
| 자동 조준 계산 | 14,527대상·다음 RNG값 동등, 의도적 경계 오류2건 검출, 함수 CPU 절감 관찰 | [대조 증거](performance/targeting/README.md) |
| 장판 추가 후보 | 동일성57개·실제 효과/RNG 일치, fallback 제거2종 검출. 짧음/밀집/이동에서 느려져 제품 반영 보류. 실제 혼합의 점 분포·조회/적용 비용도 별도 계측 | [후보 판단](performance/zones/README.md), [native 혼합](performance/zones/native-mix/README.md) |

native는 Godot4.7.2/macOS·빈 운영 URL·고유 BinduTools 저장·최소화/no_focus 창의 SubViewport 입력/렌더링이다. 각 묶음의 manifest와 로그에서 실제 소스·실행 조건을 확인한다. 시뮬레이션 결과·강제 draw 시간·GPU시간(현재 미제공)·물리 디스플레이/OS 입력을 구분한다.

## 수정 과정과 남은 범위

- [독립 통합 리뷰](review-integration.md)가 정지 중 읽기 버튼·오래된 카드의 무료 적용·터치 중복·멀티 자동 선택 계약 오류를 찾아 수정했다. 최종 core/undo 검사로 관련 회귀를 확인했다.
- 태블릿 정보창이 긴 DPS 표 아래로 밀려 하단 버튼을 덮던 문제, PC130% 중복 정보 제목 잘림, 폰 footer 상하 여백 불일치를 수정했다. `integration-layout-before-heightfix`와 `integration-layout-before-footer`는 그 전 관찰본이다.
- 기존 카드 검사 실패 중 카드 이름의 잘못된 기대값, 수동 조준 fixture 재설정, UI 뒤를 배경으로 누르던 좌표 등은 검사 오류로 분리했다. [분류 기록](legacy-native/README.md)을 참조한다. 기준을 낮춰 제품 통과로 바꾸지 않았다.
- 설정 모달의8개 경고는 하나의 모달 바탕과 뒤 HUD의 겹침이다. 입력 차단은 별도 검사했다. 모든 UI 경고를0이라고 보고하지 않는다.
- 아키텍처의 일회성 마이그레이션 감사는 main부터51개 미기록 변화가 있었다. 현재 reviewed_changes103개에 이번 실제 변경 함수의 범위·이유가 기록됐고, 남은43개는 모두 기준 main에도 있던 항목이다. 새 미검토 실패0, runtime 경계 검사0실패와 구분한다. 일회성 감사 전체가 통과했다는 뜻은 아니다. [baseline](architecture-baseline.log), [최신](architecture-final.log).
- 일부 도구는 종료 시 ObjectDB 경고2~6개를 남긴다. 오류 없이 종료했다는 사실과 누수 원인 미분석을 구분한다. undo의 WAVE 종료6개를 원래2개와 동일하다고 주장하지 않는다.
- 실제 iOS/Android, 손가락 가림·흔들림·작은 폰, 잠금/전화/OS 종료, 중급 폰 부하, 인터넷 NAT/손실, 색각·대비·스크린리더, 실제 사용자 과제 성공률은 미검증이다. 사용자는 현재 실기기 연결이 어렵다고 답했다.
- 추가 I-04(3인 동시 선물의 거절/손실)는 기존 main의 경합이다. 예약·소유자 적용·host 확정·단일 소비·완료 재시도로 수정했고, 독립 반례13개와 전달 상태86개를 통과했다. 실제 통신 결과·종료 잡음·마지막 화면 수정의 범위는 [거래 검증](multiplayer/gift/README.md)을 따른다. 기존 두 참가자 성공 자료로 이 경합을 통과 처리하지 않는다.
- `final-check.log`는 마지막 pending 표시·알림 위치 수정 직전, `final-check-after-ui.log`는 그 뒤의 전체 재검사다. 후자는 최신 제품 소스에서 exit0이며 `final-layout`·협동 PC/폰 고정 사본과 scripts 해시가 같다. 일반 native16묶음의 중간 소스 경계는 해당 README에 계속 명시한다.
- [실기기·사용자 과제](remaining-user-tasks.md)는 준비만 됐으며 미실행이다. BF-44–50의 실제 관찰 전까지 가설·물리 검증 공백을 완료로 바꾸지 않는다.

## 자료 관리

개인 게임 저장·운영 서버·배포·버전은 변경하지 않는다. `docs/qa/.gdignore`는 캡처를 게임 리소스로 import하지 않게 하며 검사·증거 파일은 그대로 보존한다. 일부 대량 카드 캡처는 격리된 `/tmp`에 생성하고 대표 그림·전수 metrics/본문·해시를 이 폴더에 남긴다. subagent별 토큰/비용의 신뢰할 수 있는 집계는 제공되지 않아 `not_available`로 기록한다.

## 현재 재개 지점

확정 사용성 수정의 로컬 구현·공통 회귀·실통신·화면 검증은 마쳤다. 목표 `전부 수정하기`는 active다. BF-49의 실제5–16점 장판·적용 비용을 기준으로 다음 최적화를 검증하고, 기기 연결 가능 시 `remaining-user-tasks.md`를 실행한다. 제품 Zone을 빠른 일부 benchmark만 보고 교체하지 않았다.
