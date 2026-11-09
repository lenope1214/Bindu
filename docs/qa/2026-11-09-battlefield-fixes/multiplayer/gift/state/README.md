# I-04 결정론 상태 게이트

`GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh gift`로 실행한다. BinduTools 임시 프로젝트와 빈 서버 URL을 강제한다. 실제 session, 중앙 카드 선택·소비, Tower.add, gift handler, rejoin 복원, fence를 사용하며 전송 큐만 메모리 대역이다. 실제 WebRTC 검증은 [3인 native 증거](../README.md)와 별도다.

현재 `battlefield_gift_state_check.gd`는 86 assertions, failures=0, exit0. SCRIPT ERROR/Parse Error/ERROR 및 종료 warning 0을 확인했다. 결과는 [run.log](run.log), 공통 실행 경로는 [gate.log](gate.log), 소스 식별은 [manifest.json](manifest.json)에 기록한다. 이 폴더의 단독 결과만으로 실제 통신 통과를 주장하지 않는다.

검사 범위:

- 동일 요청 경합에서 owner 적용1회, 수락 donor 소비1회, 거절 donor의 카드·offer·선택·bank·새로고침 유지. 동일 token/ACK/payload 변조의 재적용 방지.
- pending 취소·직접 설치·AFK·강제 웨이브가 문맥을 바꾸지 않음. 완료 수신 뒤 다음 선택 재개.
- settled/complete 유실 때 동일 token 재전송 수렴. 중복 settled가 최신 offer를 되감지 않음. 지난 rest ACK가 지운 문맥을 접근하지 않음.
- owner accepted 미확정 동안 일반 TW 및 후속 rejected snapshot 보류. owner 재접속은 host 확정 receipt로 교체하며, 옛 epoch result 무효·원래 token 재검증.
- Tower와 카드 문맥을 같은 revision으로 host에 반영. 동일 revision의 다른 문맥·과거 revision·다른 epoch 거절. terminal rejoin 뒤 원래 예약 문맥을 재차 복원하지 않음.
- 방향 편집 중 AIM은 원래 READY/CHOOSE로 복원하고 신규 카드 AIM만 PLACE로 복구. host WAVE rejoin snapshot은 새 wave 명령의 fence와 구분해 승인하고 실제 `_mp_resync`가 같은 wave로 돌아옴.
- 신규 판·구버전·잘못된 sender/필드 타입·legacy gift·owner/donor 명시 퇴장·일시 연결 단절 구분. 재협상 caps0 중에도 이미 활성화한 판의 fence 생략 금지.

수정 전 독립 RED는 [review-probe](../review-probe/)의 동결 686줄 소스와 로그다. `terminal-rejoin`, `settled-retry`, `owner-before-commit`, `ordinary-choice`가 상태 불변식 실패를, `old-ack`가 ScriptError를 기록한다. 후속 [round4](../review-probe/round4/)는 같은 반례 7개가 별도 독립 검사에서 GREEN인 증거다. 과거 스냅샷 결과와 현재 단독 게이트를 섞지 않는다.

추가 방향 편집 재접속 RED는 [direction-rejoin-before.log](direction-rejoin-before.log): 80개 중 2실패, exit1. 수정 뒤 같은 검사와 WAVE 복귀 회귀를 포함해 83/83 GREEN(당시 버전). 각 버전 hash는 manifest를 본다.

구host 판의 newclient 간 TW 호환 RED는 [legacy-tw-before.log](legacy-tw-before.log): 실제 송수신 메서드에서 86개 중 2실패, exit1. protocol0 plain TW 유지 뒤 86/86 GREEN. gift는 구host에서 계속 비활성이다.
