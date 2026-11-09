# 전장 사용성 개선 실행 기록

범위: [진단 BF-01–50](battlefield-usability-audit-2026-11-09.md) 전부. 사용자의 `전부 수정하기` 지시에 따라 구현과 검증을 진행한다. 밸런스 수치·자동 조준 우선순위·전장 크기·사거리·사용자 카메라 배율은 보존한다.

## Phase checklist

- [x] Bootstrap and baseline verification
- [x] Input implementation and local verification — input owner
- [x] Information implementation and local verification — information owner
- [x] Flow implementation and local verification — flow owner
- [x] Core UI integration and local verification — root
- [x] Independent local review — separately assigned read-only reviewer
- [x] Local evidence and cleanup — root; physical evidence remains pending

## Ownership and dependency topology

세 구현 묶음은 아래 파일 소유권을 지키며 병렬 진행한다. 공유 API 변경은 root에게 먼저 알린다. 공통 명세·기존 검사 수정·핵심 UI 통합은 root가 단독 수행한다. 모든 구현이 끝난 뒤 root가 전체 check와 native 입력·화면 검사를 수행하고, 별도 읽기 전용 리뷰를 거친다.

- input owner: `scripts/features/interaction.gd`, `scripts/domain/placement_policy.gd`, 신규 `tools/battlefield_input_check.gd`와 해당 증거.
- information owner: `scripts/info_panel.gd`, `scripts/attack_preview.gd`, `scripts/features/hud.gd`, `scripts/features/field_view.gd`, 신규 `tools/battlefield_information_check.gd`와 해당 증거.
- flow owner: `scripts/features/run_flow.gd`, `scripts/features/abilities.gd`, `scripts/features/menu.gd`, `scripts/features/progression.gd`, `scripts/features/persistence.gd`, `scripts/meta.gd`, 신규 `tools/battlefield_flow_check.gd`와 해당 증거.
- root: `scripts/card_dock.gd`, `scripts/features/cards.gd`, `scripts/features/frame.gd`, `scripts/features/ui_shell.gd`, `scripts/features/viewport.gd`, `scripts/app/session.gd`, `scripts/features/perks.gd`, 공통 명세·기존 검사·추가 UI 파일·문서·통합.

## Decisions

- 전투 중 즉시 정지를 항상 노출하고 싱글 포커스 상실 정지는 기본 켬. 멀티 판은 임의로 전체 정지하지 않는다.
- 자동 조준이 적용되는 새 설치는 기본 방향으로 완료하고, 방향 선호 편집은 별도 명시적 행동으로 유지한다. 연습 판의 방향 학습 단계는 보존한다.
- 일반 카드는 기존 한 번 눌러 들기·드래그를 유지하면서 별도 소비 없는 읽기 경로를 제공한다. 읽기와 실행을 같은 제스처에 겹치지 않는다.
- 되돌리기는 새 무작위 정보를 더 얻지 않는 결정적 복원이 필요하다. 카드 적용·이동·회전의 복원 범위와 무작위 상태·기록을 함께 검증한다. 재추첨·특성·진행 경계가 복원을 제한할 수 있다。
- 가설 BF-44–50도 구현·재현 과제로 남긴다. 실제 기기·실통신·성능·접근성 증거가 없으면 완료로 표시하지 않는다.

## Verification

각 소유자는 새 검사에서 수정 전 실패와 수정 후 통과를 기록하고 격리 native 화면을 확인한다. 공통 gate는 `GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh check`, 기존 carry/usability/first-play 검사, PC 100/130%·폰 130%·태블릿 화면 검사다. 구현된 변경에 맞는 명세와 검사를 같은 변경 범위에서 갱신한다.

현재 상태: 세 구현 묶음과 공통 UI를 통합했다. 공통 gate(명세250·전달 상태86·서버28개 포함)와 PC/폰 native16묶음은 통과했다. 협동3인 전달·재접속·유실14조건과 PC/폰 후속은 로컬 검증을 마쳤으며, 후반 고배속 전체 지연은 아직 해결하지 못했다. 실기기는 사용자가 현재 연결하기 어렵다고 답했으므로 물리 검증 항목을 미확인으로 유지한다. 항목별 상태는 `.omh/goals/battlefield-usability.json`에 기록한다. 미관찰 결과를 통과로 표시하지 않는다.


## 구현과 확인 범위

아래 ‘연결 검사’는 구현을 확인할 검사이며 최종 통과 선언이 아니다. 묶음별 초기 로그와 최신 통합 결과를 구분한다. [입력 증거](qa/2026-11-09-battlefield-fixes/input/README.md), [정보 증거](qa/2026-11-09-battlefield-fixes/information/README.md), [진행 증거](qa/2026-11-09-battlefield-fixes/flow/README.md), [실통신 증거](qa/2026-11-09-battlefield-fixes/multiplayer/README.md), [부하 관찰](qa/2026-11-09-battlefield-fixes/performance/README.md).

| 진단 | 구현·변경 | 연결 검사 |
|---|---|---|
| BF-01 | 읽기 모달 단축키 차단, 정지·오래된 정보 버튼의 카드 선택 재검증 | input, core |
| BF-02 | 카드별 정보 버튼·소비 없는 전체 읽기·이전/다음·닫기 복원 | core |
| BF-03 | X 뒤 명시적 재선택으로 정보 재열기 | input |
| BF-04 | 화면상 가장 가까운 대상과 생성 순서 독립 동률 선택 | input |
| BF-05 | 기존 Tower·Callable·공격 카운터를 보존하는 편집 이력, 표시된 경계 뒤 무효화 | undo, core |
| BF-06 | 전투 Esc 한 번 즉시 정지 | input |
| BF-07 | 싱글 포커스 상실 정지 기본 켬·설정 저장·명시적 재개 | flow, lifecycle |
| BF-08 | 선택·명시적 읽기 동안 시작 카운트다운 유예 | spec, lifecycle |
| BF-09 | 기본 자동 조준 일반 설치에서 별도 방향 단계 생략 | input |
| BF-10 | 위치 다시 정하기·카드 돌려놓기·편집 취소를 단계에 맞게 표시 | core, carry |
| BF-11 | 하단 상태에 든 카드 이름 표시 | spec, carry |
| BF-12 | 재클릭은 선택 유지, 방향은 명시 버튼·E | input, usability |
| BF-13 | 정지한 꾹 누르기는 이동 안 함 | input |
| BF-14 | 일반 휠 확대·Alt+휠 회전 | input, spec |
| BF-15 | 기존 빨간 무효 고리 유지·구체적인 거절 이유를 drag 중 하단 표시 | input |
| BF-16 | 선택 추가·제외와 전체 선택 화면 버튼 | input |
| BF-17 | 선택 그룹 공통 방향·상대 회전·취소 원복 | input, undo |
| BF-18 | 선택 반경·끌기 기준을 화면 좌표에서 계산 | input |
| BF-19 | Tab 순환·화살표 배치/이동·Enter 적용·버튼 포커스 | input |
| BF-20 | 폰 명시 선택 시 목록을 접고 정보 공간 확보, 내용 전체 스크롤 | core, layout |
| BF-21 | 핵심 수치 먼저, 공격 예시는 별도 열기 | information, usability |
| BF-22 | 정보창·진행 배지·조작 안내 실제 사각형 회피 | layout |
| BF-23 | 선택 유지 중 카드 호버는 임시 카드 비교, 이탈 후 선택 정보 복귀 | usability |
| BF-24 | 카드 높이·핵심 요약 최대 세 줄, 긴 협공 요약 축약 | card_writing, layout |
| BF-25 | 전체 정보에서 대상별 적용 가능·변화·새 조합·거절 이유 비교 | information, core |
| BF-26 | 평소 전투 저장 상태·정지 메뉴에 실제 성공/실패·복원 경계 | flow, lifecycle |
| BF-27 | 현재 자동 조준·방향 선호·상한·조작 설명 갱신, 오래된 README 규칙 보관 | spec, 문서 대조 |
| BF-28 | 대상별 거절 이유와 가능한 대안 후보 읽기, 무효 drag 구체적 이유 | information, input |
| BF-29 | 다시 뽑기와 잔여 수 표시, 0회는 disabled 상태 유지 | spec, layout |
| BF-30 | 1·3·5·10 직접 선택 메뉴 | flow, carry |
| BF-31 | ‘연속 진행’, 실제 전투·카드 선택 보류 설명 | flow |
| BF-32 | 현재 웨이브 뒤 멈춤과 즉시 정지 구분 | flow |
| BF-33 | 보류 특성·카드·다시 뽑기 횟수 노출 | flow |
| BF-34 | 설정 접힘과 독립된 상단 즉시 정지 | core |
| BF-35 | 시작 직후 450ms 단축키 가속 방지, 명시 버튼 즉시 반응 | flow |
| BF-36 | 싱글 수동 기술 조준 0.25 감속 기본 켬·선택 해제 가능 | flow |
| BF-37 | 기술 버튼에 실제 효과·대상, 자동/수동 상태 | flow |
| BF-38 | 게임 초와 배속을 반영한 실제 약 대기시간·웨이브 재충전 설명 | flow |
| BF-39 | 조준 중 유효/면역 개수·고리·무효 소비 방지 | information |
| BF-40 | 전투 화면에서 기술 자동/수동 직접 전환 | flow |
| BF-41 | DPS 행 클릭·터치·Enter로 전장 대상 선택 | information |
| BF-42 | 기본 공격 계산치·실전 피해/시간·포함 범위 구분 | information |
| BF-43 | 직접 피해와 제어/전달 역할 구분. 비활성 순풍을 바람 지원으로 설명하던 신규 오류도 리뷰에서 제거 | information |
| BF-44 | 지난 웨이브 방향·종류·실제 손실·통과 시 저항/보호막/면역 읽기 UI. 모든 누수를 빈 길목으로 단정하던 기존 안내도 수정. 원인별 3과제·행동 성공률 비교는 미확인 | core, 후속 과제 |
| BF-45 | 움직이는 적 명시적 정보 고정·선택 전환·소멸 해제. 실제 폰 추적은 미확인 | information, input, 실기기 대기 |
| BF-46 | 권한/요청 설명·준비 취소·대기 타이머 해제. 로컬2인 협동/대결·3인 전달14조건·PC/폰 후속 검증. 최신 혼합 소스3인과 지원 안내는15actor426단언 통과 | multiplayer, 실기기/인터넷 대기 |
| BF-47 | 합성 알림과 실제 iOS Simulator7상태의 UIKit 전환·native 재개·새 PID 저장 복원. 실기기 잠금·전화·Jetsam·멀티는 미확인 | [iOS 후속](qa/2026-11-09-battlefield-fixes/ios-runtime/README.md), lifecycle, 실기기 대기 |
| BF-48 | 가림 실패를 실재 결함으로 확정하지 않음. 좌우손·작은 폰 실기기 비교 후 오프셋/렌즈 최소 개입 결정 필요 | 실기기 대기 |
| BF-49 | 조준·타격 비용 절감과 없는 지속/성장 호출 생략. 실제 전투885사례·직접48사례·400live 제어 CPU/native 비교. 고배속 합성 요청 대기170–212ms·전체 지연·PERF-01·실기기 확인은 미완료 | performance, zone-hit, feedback-density, 실기기 대기 |
| BF-50 | PC 70/85/100/115/130·태블릿/폰 모의 레이아웃과 화면 버튼/문구/포커스 경로 검사. 실제 색각·대비 과제·스크린리더는 미확인 | layout, 후속 과제 |

## 새로 찾은 회귀 위험

- 카드 정보창의 ‘이 카드 들기’가 정지 상태와 보류 이후 이전 offer를 재검증하지 않던 경로를 수정했다. 중앙 진입점에서 CHOOSE·양수 선택수·현재 offer·일반 카드·입력 허용을 모두 확인한다. `core`에서 정지·늦은 callback을 따로 검증한다.
- 카드 편집 복원을 저장 파일 역직렬화로 처리하면 기존 Tower의 지연 함수·런타임 카운터를 잃는다. 별도 이력 서비스로 바꾸고 기존 객체를 제자리 복원한다. 초기 스냅샷 API는 제품에서 제거했다.
- 협동 3인 이상에서 동시에 같은 속성 요청을 충족시키려 할 때 기부자 카드만 소모될 가능성이 소스 리뷰에서 추가 발견됐다. 기존 main에도 있던 경로이며 두 참가자 성공 검증으로 배제되지 않는다. 예약 → 소유자 적용 → host 확정 → 기부자 단일 소비 프로토콜로 수정했다. 같은 offer·선택 문맥·연결 epoch·요청 revision을 묶고, 재접속·완료 유실·강제 시작·명시 퇴장과 중립 대기 표시·폰 알림 겹침을 로컬에서 검증했다. 인터넷/실기기·OS 종료 증거는 남는다. [구현](qa/2026-11-09-battlefield-fixes/multiplayer/gift/implementation.md), [독립 반례 검토](qa/2026-11-09-battlefield-fixes/multiplayer/gift/review.md).

기록된 자동/합성 성공을 인간 사용성·실기기 성공으로 바꾸지 않는다. 가설의 사용자 과제·물리 증거가 남아 있으므로 ‘50개 전부 해결’로 보고하지 않는다.

## 잔여 검증 재개점

[실기기·사용자 과제](qa/2026-11-09-battlefield-fixes/remaining-user-tasks.md)에 BF-44–50의 실제 과제·관찰·현재 미실행 상태를 정리했다. BF-49의 8배속 장판/공격 비용은 로컬에서도 추가 개선 대상이다. 장판 선별 후보는 동일성57개를 통과했지만 짧음/밀집에서 느려져 제품 반영을 보류했고, 실제 혼합의 최대13점·적용 비용을 별도 계측했다. 최신 UI 뒤 공통 전체 검사도 다시 통과했다. 실기기 부재 때문에 로컬 성능 문제까지 해결한 것으로 처리하지 않는다.

[조준 후속](qa/2026-11-09-battlefield-fixes/performance/guard-range/README.md): 이전 검사에서 거절된 공격방식 교체를 무시한 범위 오류를 정정했다. 실제15종·레벨1/3/8의41,564비교와 실제 전투570사례/6,840표본을 확인했다. 호출 안에서 사거리·목표 중심만 재사용해 native6조건에서 공격 CPU41–54%, main CPU20–37% 감소를 관찰하고 반영했다. 단일 순차 비교이며 실기기/물리 입력 지연 개선률은 아니다. BF-49는 부분 구현·미완료로 유지한다.

[hit 후속](qa/2026-11-09-battlefield-fixes/performance/hit-factors/README.md): 없는 금속·땅/시간·피/환영 특징의 호출과 불필요한 운반 개수 계산을 생략했다. 실제 전투885사례/10,620표본의 상태·예약·RNG 동등, 잘못된 조건 변형75사례 검출, 전체 검사252/86/28 통과다. 기존 혼합8배속 ABBA에서 main CPU2.4–4.8% 감소했고 모두 활성인 조합에서는 큰 이득이 없었다. 남은 고배속 지연과 실기기 검증은 계속 미완료다.

[release/큐 후속](qa/2026-11-09-battlefield-fixes/performance/export-runtime/README.md): 로컬 macOS release QA 앱의 실제 template/debug 플래그를 확인했다. 현재8배속 main CPU100.75ms, 합성 요청→dispatch130–145ms, dispatch→정지 상태 약0.14ms로 큐 대기가 남았다. 물리 OS 입력 측정은 아니다. 스택 추적을 끈 임시 사본은 큐 지연 이득이 없고 오류의 스크립트3프레임이 사라져 제품 설정을 유지했다. release 캡처에서 동일 상태 문자의 겹침도 확인해 다음 표시 개선 대상으로 유지한다.

[표시 밀도 후속](qa/2026-11-09-battlefield-fixes/performance/feedback-density/README.md): 동일 문구·색·크기의 화면상 겹침만 렌더 단계에서 줄인다. 피해 숫자·서로 다른 상태·원본 popup과 수명·전투·카메라·RNG는 유지한다. PC/폰100·130% 검사와 동일 정지 장면의 실제 재그리기를 구분해 기록한다. 별도 실행 성능은 일부 증가·변동이 있어 PERF-01을 통과 처리하지 않는다.

[상성 조회 후속](qa/2026-11-09-battlefield-fixes/performance/zone-application/README.md): 같은 속성 입력의 비트키를 재사용한다. 제품2,988단언·실제 전투1,110사례/13,320표본 동등·잘못된 alias12건 검출·반영 후 전체 회귀와 release442단언 통과다. 전투량/끝 상태/RNG가 같은 제어 ABBA에서 main CPU0.77–1.29% 감소를 관찰했다. 매번 입력 교체와 빈 입력의 미세 비용 증가, native draw 일부 증가·전체 고배속 지연은 남는다.

[효과 줄이기 후속](qa/2026-11-09-battlefield-fixes/performance/fx-quality/README.md): 알파만 낮추던 모드에서 후광·보조 고리·작은 장식 입자를 생략한다. 기본 모드 명령 인자/순서와 저강도의 장식 외 명령·원본/snapshot/카메라·같은 draw 순서의 RNG가 일치했다. 정지 장면 강제 재그리기에서 FX callback약57%·반환약31% 감소를 관찰했으며, 실제 FPS·고배속 전체 지연의 해결로 읽지 않는다. 제품 저강도 release442단언·전체 회귀 통과, 기본 설정은 끔 그대로다.

[효과 설정 후속](qa/2026-11-09-battlefield-fixes/fx-controls/README.md): 전장 빠른 메뉴에서 후광·작은 입자 줄이기와 약한 공격 진하기를 독립 선택하고 설정창과 동기화한다. 폰 메뉴가 홈 영역을 덮던 경로도 UI 안전 영역에 맞춘다. 기본 설정·옵션 줄·전장·카메라·배속을 유지하며 실제 기기에서의 발견/조작 성공률은 미확인이다.

## 최신 main 반영과 전달

[혼합 버전 후속](qa/2026-11-09-battlefield-fixes/multiplayer/mixed-version/README.md): 구host 판의 미지원과 프로토콜1의 참가자 지원 미확인을 구분하고 hover 없이 복구 행동을 표시한다. 최신 제품 PC/폰15actor426단언에서 실제 WebRTC·카드 보관·정상 자기 편집/TW·준비/W1·전원 신규의 단일 소비/정산을 통과했다. 기존 STUN 미사용 주장을 실제 ICE 기록으로 정정했으며 제품 네트워크 기본값은 바꾸지 않았다. 실기기·인터넷/NAT·OS kill·구release 바이너리와 사람 과제는 미완료다.

[2026-11-10 전달 기록](battlefield-delivery-2026-11-10.md)에 작업별 커밋·복구 ref·main pull/rebase·충돌 해결을 기록했다. 최신 main의 결과 상세·v1.0.0·빌드 설정을 유지하며 [전체 재검증](qa/2026-11-09-battlefield-fixes/delivery/README.md)을 마쳤다. 실기기·사용자 과제와 후반 전체 지연은 그대로 미완료다.

[실제 iOS Simulator 후속](qa/2026-11-09-battlefield-fixes/ios-runtime/README.md): 제품 코드 변경 없이 별도 ARM64 debug 앱에서7상태129개 native 단언·원자료35개 검사를 통과했다. 실제 UIKit 알림과 재개 터치, 실제 프로세스 종료 뒤 새 PID에서 저장 복원을 기록했다. 운영 URL/저장/bundle을 격리하고 WebRTC를 제외했다. 실기기·손가락 release 유실·잠금·전화·Jetsam·Android·release·멀티·성능·사람 과제를 대체하지 않으며 BF-47은 partial, 전체50개는 active다.

[실제 iOS 기술 조작부 후속](qa/2026-11-09-battlefield-fixes/ios-layout/README.md): I-05 정보창/모드 가림, I-06 첫 표면 누락, I-07 선택 안내/기술 가림을 수정했다. iPhone/iPad5배율302장면, 실제 UIKit 선택·취소·자동/수동12단언,122조건 카메라/전장/상태 비교와 공통 전체 회귀·desktop4묶음을 통과했다. 폰 flow의 기존 설정 모달 UI8경고·desktop ObjectDB 종료 경고·기존 감사43개를 구분한다. I-08 첫 설치의 모바일 배율 기본값 불일치는 미수정이며 전체50개는 active다.

[정보 읽기 후속](qa/2026-11-09-battlefield-fixes/inspector-reading/README.md): I-09의 제목 아래 핵심 수치 네 개·스크롤 밖 고정 공격 예시 버튼·긴 라벨 폭·좌우 정보창을 구분하는 배너 배치를 수정한다. 중간 화면의 남은 잘림/배너 겹침과 최종 재검증을 구분한다. 첫 설치 배율 I-08·실기기/사람 과제·BF-49/PERF-01은 별도 미완료다.

[공격 예시 후속](qa/2026-11-09-battlefield-fixes/attack-preview/README.md): I-11의 전체 예시 노출·16:9/실제 clip 맞춤·접기 수치 복귀·닫고 같은 대상 재열기의 오래된 callback을 수정했다. native40조건/200상태 비교·실제6동작·desktop26단언과 기존4묶음·공통 전체 회귀를 통과했다. 새 예시 읽기 범위92/PASS와 전체50개 active는 구분한다.

[첫 모바일 배율 후속](qa/2026-11-09-battlefield-fixes/mobile-default/README.md): I-08의 저장 없는 경로만 static 초기값1.3/desktop1.0으로 일치시켰다. 두 기기16cold 시작에서 유효 저장5개·다른 설정·기존 무효값 복구·카메라/전장을 보존했다. 실제 이전fresh2개·desktop8단언·전체 공통 회귀와 구분한다. 전체50개·물리/사람/고배속 과제는 active다.

[키보드 읽기 후속](qa/2026-11-09-battlefield-fixes/keyboard/README.md): 정보창 진입 키가 없어 GUI 포커스가 비던 실제 경로를 F6 전환·창 안 순환·스크롤로 수정한다. Tab 선택/이동 뒤 방향 편집의 오래된 포인터도 초기화한다. 3프로필126단언과 모달 보호를 확인하며 BF-50 전체 접근성·스크린리더·색각/대비·실기기 과제는 HOLD로 유지한다.

[지속/성장 호출 후속](qa/2026-11-09-battlefield-fixes/performance/zone-hit/README.md): 조건에 맞지 않는 helper4줄 생략을 반영했다. 전투885사례/10,620표본·잘못된 guard30검출·직접48사례와 동일 부하/RNG 제어 비교다. 혼합/금속·땅·피 CPU약2%, native혼합8배속약3% 감소와 함께 모든 효과 활성 CPU+0.08–0.30%,1배속 draw 간격 증가도 기록한다. 합성 큐 대기·전체 성능 판정은 미완료이며 다음은 입력 처리와 긴 계산 분리의 격리 시제품 검토다.

[계산 중 입력 처리 실험](qa/2026-11-09-battlefield-fixes/performance/input-service/README.md): 제품70개 스크립트는 유지하고 격리 사본만 시험했다. native ABBA240표본의 전투/난수/시간 동일,28개 실제 계산 중 버퍼 입력과 재진입/삭제를 확인했다. 정지 큐114–154ms→7–12ms와 CPU+0.19–0.30%를 구분하며, 즉시 force-draw의 메뉴 미표시도 기록했다. 실제 UIKit 수신·일반 조작·첫 화면 표시를 증명하지 못해 제품 적용은 보류한다. 전체50개와 BF-49/PERF-01은 미완료다.
