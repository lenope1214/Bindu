# 전장 사용성 브랜치 전달 기록

2026-11-10. 사용자 지시에 따라 작업별 커밋 → 최신 main pull → 현재 브랜치 rebase → PR 생성 순서로 전달한다. 전체50개 목표와 물리 검증 공백은 [구현 기록](battlefield-usability-implementation.md)에 유지한다. PR을 만드는 것과 모든 가설을 해결하는 것은 다른 상태다.

## 작업별 커밋

1. 전장 행동50개 진단·native 재현 증거.
2. 서로 의존하는 조작·카드 읽기·정보·되돌리기·진행 개선. 협동 거래 wiring을 별도 index 버전으로 분리했고 이 중간 커밋의 명세250개를 독립 사본에서 통과했다.
3. 협동 속성 전달 예약·정산·재접속·pending 표시. staged 사본의 전달 상태86개를 통과했다.
4. 자동 조준 순회 최적화와 후반 성능 검증. 장판 후보는 회귀 때문에 보류했다.
5. 공통 문서·검증·미완료 범위 정리.

최근 commit subject는 한국어 설명형이며 별도 PR template·DCO 규칙은 찾지 못했다. 커밋/PR의 테스트 결과는 실제 로그에서만 옮긴다. 관련 없는 UID와 대량 로컬 중간 자료는 [증거 포함 정책](qa/2026-11-09-battlefield-fixes/publication.md)에 따라 보존한다.

## main 반영 전 원격 상태

- feature: `codex/battlefield-usability-audit`, 시작점 `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9`, 같은 이름의 원격 브랜치·PR 없음.
- 최신 원격 main 관찰: `8704b78688ee9be638e0ddd24eb91d54f3f56194`. 결과 상세·v1.0.0·Android/iOS 빌드 변경4개가 추가됐다.
- 로컬 main: `8fdfefe`에서 뒤처진 상태다. pull은 fast-forward만 허용한다.
- rebase 전 feature와 로컬 main의 backup ref를 만든다. 이력 복구는 이 ref를 기준으로 하며 원격 main에는 push하지 않는다.

## Rebase와 검증 결과

최신 main8704b78 위로5개 커밋을 rebase했다. frame·재시작·기능표 충돌은 양쪽 의도를 보존하며 해결했다. 명세252개와 공통 전체 검사, native23묶음, 실제 통신55 actor·543단언, 조준14,527비교, 결과 상세 PC/폰 추가 검증을 통과했다. [전달 증거](qa/2026-11-09-battlefield-fixes/delivery/README.md).

6번째 커밋은 이 호환 확인·재실행 도구·검증 자료를 담는다. 남은 실기기·사용자 과제·후반 전체 지연을 PR에 명시하고 Draft로 전달한다. 병합·배포는 수행하지 않는다.

## PR과 후속 작업

17번째 커밋은 fuzz 진단의 실제 종료 코드·완료 표식·실패 원자료를 보존한다. 입력/종료 동작/통과 기준은 유지하며, 완료 없는 exit0 음성 반례도 실패로 검출했다.

18번째 작업은 [기술 조작부 가림·초기 표시](qa/2026-11-09-battlefield-fixes/ios-layout/README.md)다. 정보창과 선택 안내의 가림, 첫 정상 테두리를 수정하고 현재 iOS Simulator302장면·native12단언·122조건 카메라/상태 비교·전체 회귀·desktop4묶음을 검증했다. I-08 모바일 첫 설치 기본 배율과 실기기·사용자·고배속 지연은 미완료로 유지한다.

16번째 작업은 [실제 iOS Simulator lifecycle](qa/2026-11-09-battlefield-fixes/ios-runtime/README.md)이다. 제품 코드 변경 없이 같은 소스의 custom ARM64 debug 앱에서7상태129개 native 단언·보류 카드/연속 진행/조준 원자료35개 검사를 통과했다. 빌드 아키텍처·좌표·fixture 오류와 채택 결과를 분리하고 공통 회귀252/86/28도 재확인했다. 실기기·전화·잠금·Jetsam·멀티·사람 과제·고배속 지연은 남긴다.

15번째 작업은 [혼합 버전 협동과 지원 안내](qa/2026-11-09-battlefield-fixes/multiplayer/mixed-version/README.md)다. 기존 main·수정 전 브랜치·현재 소스의 실제3인 WebRTC를 비교하고, 미지원과 지원 확인 중을 구분해 업데이트·새 판 복구 행동을 표시한다. 최신 제품 PC/폰15actor426단언과 전체 회귀252/86/28을 통과했다. QA ICE 조건과 이전 STUN 미사용 주장의 정정도 증거에 포함한다.

14번째 작업은 [효과 설정 구분과 폰 안전 영역](qa/2026-11-09-battlefield-fixes/fx-controls/README.md)이다. 전장 빠른 메뉴에서 장식 줄이기와 공격 진하기를 따로 고르고 설정창 상태를 맞춘다. 실제 클릭·터치·키보드·저장/복원과 고정 카메라·옵션 줄·안전 영역을 확인한 뒤 별도 커밋으로 전달한다. 기존 Draft PR #17에 반영하며 실기기·사용자 과제·고배속 전체 지연은 미완료로 유지한다.

[Draft PR #17](https://github.com/lenope1214/Bindu/pull/17)을 생성했다. `41cb142`는 실제15종·레벨1/3/8을 실행하도록 조준 검사 fixture를 수정하고 기존 범위 주장을 정정한 별도 커밋이다. 기존14,527회 실행 자체는 사실이지만15종 커버리지·방식별 headless 표기의 근거로 사용하지 않는다.

8번째 성능 작업은 [호출 내 사거리·목표 중심 재사용](qa/2026-11-09-battlefield-fixes/performance/guard-range/README.md)으로 분리한다. 실제 전투 상태/RNG 비교와 동일 native6조건에서 개선을 관찰했다. 제품 반영 후 전체 회귀·원래2pass 참조 검사도 다시 통과했다. 전체50개 목표와 BF-49의 남은 지연은 미완료다.

9번째 작업은 [없는 특징의 hit 후처리 생략](qa/2026-11-09-battlefield-fixes/performance/hit-factors/README.md)이다. 상태·예약·RNG885사례/10,620표본, 조건 오류 변형75사례 검출, native6조건·headless ABBA와 제품 반영 후 전체 회귀를 기록한다. 혼합8배속의 반복 비용은 줄었지만 모든 조합/렌더 조건의 개선을 주장하지 않는다.

10번째 작업은 [macOS release QA export와 입력 큐·오류 진단 검증](qa/2026-11-09-battlefield-fixes/performance/export-runtime/README.md)이다. 제품 코드를 바꾸지 않고 고배속 큐 대기가 release에도 남는 것을 확인했다. 원래 스택 추적 설정은 유지했고, 중복 상태 문자의 가림을 다음 수정 대상으로 기록했다. 실패/중첩 QA 표본은 제외·보존하고 성공한 실행과 분리했다.

11번째 작업은 [겹치는 상태 문구의 표시 정리](qa/2026-11-09-battlefield-fixes/performance/feedback-density/README.md)다. 원본 popup·피해 숫자·수명·RNG를 보존하며 같은 문구/색/크기의 겹침만 최신 표시로 줄인다. 실제 그리기 콜백·동일 장면·macOS release 확인을 기존 검증과 구분한다. 별도 성능 실행의 일부 증가를 숨기지 않고 PERF-01과 고배속 지연은 미완료로 남긴다.

12번째 작업은 [같은 속성 입력의 상성 비트키 재사용](qa/2026-11-09-battlefield-fixes/performance/zone-application/README.md)이다. Tower별 캐시는 보류하고 Share에 마지막 값 사본 하나만 둔다. 실제 전투량·끝 상태·RNG까지 같은 ABBA와 제품/전투/release/전체 검사를 통과했으며, 제어되지 않은 이전 성능 수치는 인과 개선률로 쓰지 않는다. 배속·사운드·밸런스·카메라는 유지한다.

13번째 작업은 [저강도 FX의 장식 생략](qa/2026-11-09-battlefield-fixes/performance/fx-quality/README.md)이다. 장식 외 명령·기본 모드·원본/snapshot·같은 draw 순서의 RNG를 보존한다. 계측 raw viewport CPU의 이전 draw 혼입을 제외하고 직접 callback과 강제 반환 시간을 구분했다. 기본 끔·카메라·배속·판정은 유지하며 고배속 지연과 물리 검증은 계속 미완료다.
