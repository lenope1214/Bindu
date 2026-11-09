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
