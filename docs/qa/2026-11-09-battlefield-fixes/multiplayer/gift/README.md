# 협동 선물 실제 3인 검증

2026-11-09. 최종 제품 snapshot의 실제 native 결과는 아래 실행 결과를 기준으로 읽는다. [`gift-race-plan.md`](../gift-race-plan.md)·[`review.md`](review.md)는 구현 도중의 설계 검토이며 런타임 증거가 아니다.

## 실행 구조와 경계

[`run_native.py`](run_native.py)는 현재 작업 소스의 단일 snapshot을 만든 뒤 고유 `BinduToolsGift*` 프로젝트 4개로 복제한다. 로컬 headless signaling 하나와 native Godot 세 참가자(host/peer_a/peer_b)를 실행한다. `addons/webrtc`의 실제 native 확장과 실제 `Mp` reliable transport를 쓴다. `OnlineConfig.SERVER_URL/MP_URL`은 격리 사본에서 빈 값이고 `BINDU_MP_URL`만 `127.0.0.1` 임시 port로 지정한다. 실제 사용자·운영 방·외부 signaling·STUN/TURN을 사용하지 않는다.

결정적 fixture는 초기 Lv1 속성 카드 3장·남은 선택2회·donor 보류 선택1회·새로고침1회를 준비하는 범위다. `donor_edit_rejoin`만 실제 자기 오브젝트 설치 후 남은 마지막 유효 Water offer를 결정적으로 준비한다. owner의 설치·속성 요청, donor의 카드 선택·타깃 선택은 실제 GUI 입력을 사용한다. 거래 pending/receipt/결과·owner 레벨·선택 소비는 fixture로 만들지 않는다.

오류 주입은 **실제 RTC로 수신된 원본 packet**을 격리 사본의 `_mp_packet` 진입 직전 보류·폐기하는 callback뿐이다. repository 제품 파일은 수정하지 않는다. 재전송은 원래 token/payload를 실제 RTC로 다시 보낸다. owner=host의 로컬 dispatch는 제품 service의 정상 경로이고, host donor의 수신 owner는 별도 native 참가자다. 재접속은 실제 `Mp._fail`로 transport를 닫은 뒤 제품의 자동 rejoin을 기다린다. OS kill·앱 재실행·디스크 reservation 복구를 증명하지 않는다.

각 조건의 `source-manifest.json`은 원본 scripts/tools SHA-256과 test-only 수신 hook SHA를 보존한다. `packets.bin`은 Godot Variant를 손실 없이 보존하며 JSON trace·프로세스별 결과·log·PNG와 함께 확인한다. exit0이어도 script error·결과 누락·단언/UI 오류가 있으면 runner는 실패한다.

## 조건

| 조건 | 실제 검증 경계 |
| --- | --- |
| race / race_reverse | 같은 request에 두 donor가 실제 전송. 양방향 선착순, accepted1/rejected1, owner +1, 소비1/0, loser offer/picks/bank/rerolls 보존·동일 카드 정상 대안 사용 |
| ack_loss | 첫 실제 ACK 폐기 후 같은 token 자동 retry·결과 수렴 |
| complete_loss | 첫 실제 완료 packet 폐기. 다음 선택 잠금 유지→같은 token settled 자동 재송신→실제 완료 재수신으로 해제 |
| donor_rejoin_before_commit / donor_rejoin | host 처리 전 / host 확정 후 ACK 전 donor transport 단절·같은 예약 복원 |
| owner_rejoin_before_commit / owner_rejoin | owner 적용 후 host 확정 전 / 확정 후 owner 단절·snapshot/receipt 일치·적용1회 |
| old_round | 실제 GAMEOVER→방 유지→새 main/대기방→실제 start. 옛 request·ACK가 새 선택/오브젝트를 바꾸지 않음 |
| host_donor | host donor→remote owner의 실제 전달·중복 결과 재전송·소비1회 |
| force_fence | pending 중 자동/force 보류, 정산 뒤 실제 강제 선택·fence·3인 WAVE 수렴 |
| retire_owner | apply 수신을 보류한 owner를 실제 내보내기 UI로 퇴장. donor 미소비·이유 표시·종료 뒤 지연 apply 무효 |
| retire_donor | 확정 ACK를 보류한 donor를 실제 내보내기 UI로 퇴장. host ledger 정산·owner 적용 보존·생존 donor 수렴 |
| donor_edit_rejoin | 실제 마지막 선택을 선물로 소비해0회 READY→자기 오브젝트 선택+E 방향 편집→실제 rejoin. READY/선택0/gesture 정리·소비 카드 부활/추가 설치0 |

공통: pending 중 카드 키/Q/S/Esc/우클릭·reroll/skip/AFK callback가 예약을 바꾸지 않아야 한다. 취소·진행·다시 뽑기·편집 버튼은 disabled와 확인 문구로 표시한다. accepted는 새 offer generation 생성 뒤 중복 ACK를 받아도 추가 소비0, rejected는 구체적인 화면 이유와 원래 카드가 남아야 한다. 자연 offer를 사용하는 2인 회귀는 실제 ACK 전 미소비→complete 후 소비1회와 전투 중 rejoin의 **같은 wave·같은 오브젝트 id/속성**까지 확인한다.

## 명령

```sh
GIFT_SCENARIOS=race GIFT_OUTPUT_SUBDIR=attempt-01 \
  python3 docs/qa/2026-11-09-battlefield-fixes/multiplayer/gift/run_native.py
GIFT_OUTPUT_SUBDIR=final \
  python3 docs/qa/2026-11-09-battlefield-fixes/multiplayer/gift/run_native.py
python3 docs/qa/2026-11-09-battlefield-fixes/multiplayer/gift/run_two_native.py
python3 docs/qa/2026-11-09-battlefield-fixes/multiplayer/gift/summarize.py
```

`GODOT` 기본 경로는 `/Applications/Godot.app/Contents/MacOS/Godot`. `parser-current/`는 `--import`와 `--check-only` 통과 자료이며 네트워크·거래 증거가 아니다. 기존 2인 검증은 [상위 README](../README.md)와 별도 유지한다. 최종 제품 snapshot에서 다시 실행해야 회귀 통과를 주장할 수 있다.

## 실행 결과

[`verification-summary.json`](verification-summary.json)·`summarize.py` exit0. **67개 native 참가자 프로세스 결과, 651개 성공 단언, 행동 실패0, UI 메시지0.** 모든 참가자의 실제 WebRTC 연결을 역할/id/peer 목록·native 확장 로드 상태로 기록했다.

| 증거 | 결과 |
| --- | --- |
| [`final/summary.json`](final/summary.json): 실제3인14조건 | 42 actor의 행동/UI/프로세스 exit 모두0. 원래 strict 집계는 아래 QA 종료 중 SCTP 로그 때문에1 |
| [`two-participant-final/`](two-participant-final/): 자연 offer의 협동·대결 | 4 actor exit0·행동0·UI0·참가자 runtime ERROR0·warning0. 협동 전투 rejoin은 wave1·원래 id/속성 복원 |
| [`pending-pc-before-toast-fix/owner_rejoin_before_commit/`](pending-pc-before-toast-fix/owner_rejoin_before_commit/): 종료 조정 뒤 동일 회복 조건 | 3 actor strict0·warning0 |
| [`pending-pc/summary.json`](pending-pc/summary.json): 최신 시각 수정, race/reverse/ACKloss | 9 actor strict0·warning0,1280×720·100% |
| [`pending-phone/summary.json`](pending-phone/summary.json): 같은3조건 실제 touch 입력 | 9 actor strict0·warning0,폰 글꼴·130%·safe area. 요청2556×1179, 실제 native PNG2556×1180 |

`strict0`은 프로세스 exit뿐 아니라 단언·UI·참가자 script/native ERROR를 함께 검사한 결과다. 이전 source의 통과를 최신 제품 전체 통과로 바꾸지 않는다. 원래14조건과2인 회귀는 **동일 제품 snapshot**이다. 이후 변경된 제품 파일은 `field_view.gd`의 중립 pending 표시, `frame.gd`·`ui_layout.gd`의 toast/협동 버튼 회피3개뿐이다. 최신 PC/폰6조건의 manifest는 현재 scripts 전체 SHA와 일치한다. 거래 서비스·멀티플레이·송신·CardDock hash는 모든 최종 증거에서 같다.

```text
gift_transactions.gd  6ecbf9f4ec22542a73461102d503732f58f9dbce2e24532183dda71828326aa3
multiplayer.gd        abc0855a27ace293408725eef48c0c18d0c97d8ae9d7d64f0bddbfc7103286e5
mp.gd                 acd8199337450400dca5fbc5a53aefd7698f353f6e46e9dc31b855bc9d2c30ec
card_dock.gd          bf192b8b94ca58da311c363e6551e6703565729c286da248b83bf879e177e5a7
field_view.gd         c16a745b04bca8f133681c18a64524aec199ff704cdede6c50b5ec2c6ff6d985
frame.gd              80656d6d238bbdd25bf079e7b3abfed6bc7b06ccc8b46c65ed82d6fbe6f0eee8
ui_layout.gd          0cbd2450e0c4943bf58da62a5a336999759a18e82025544af76b8a55dfe54e63
```

직접 확인한 대표 캡처: [폰 대기 중립 표시·비활성 버튼](pending-phone/race/peer_b/pending-reservation.png), [폰 결과 알림과 협동 버튼 분리](pending-phone/race/host/owner-final.png), [거절 후 같은 카드 정상 사용](pending-phone/race/peer_b/rejected-valid-alternative.png), [선택0 방향 편집 rejoin 뒤 READY](final/donor_edit_rejoin/peer_a/zero-picks-edit-recovered.png), [같은 전투 wave 복원](two-participant-final/coop-join/recovered.png). 대기 화면의 `refuse=false`·확인 제목·disabled 상태도 별도 단언했다.

## 종료 로그와 검증 한계

원본14조건의 `owner_rejoin_before_commit/host`에서는 **마지막 제품 단언·`UI ok owner-recovery-coordinator` 뒤**, QA 종료 방송을 받은 참가자들이 먼저 `leave()`하고 host가350ms 대기하는 동안 `_send_pings→_send_bytes`가 native SCTP errno32/25 오류3줄을 남겼다. 각 참가자의 행동·UI·프로세스 exit는0이지만 원본 strict 집계는 실패로 보존했다. [`cohort-boundary.json`](final/cohort-boundary.json)과 원본 [host.log](final/owner_rejoin_before_commit/host.log)를 함께 읽는다.

후속 도구는 **행동 검사 종료 뒤에만** shared done marker를 만들고 모든 actor의 Mp processing을 중지한 뒤 함께 transport를 닫는다. 동일 owner 회복 조건 재실행은 참가자 runtime ERROR0·warning0였다. 이 변경은 제품 단절/재접속 시험을 생략하지 않는다. 제품의 채널 open 검사는 native 하부 SCTP의 비동기 close와 실제 송신 사이 원자성을 보장하지 않는다. 사용자 행동 중 오류가 나오면 이 QA 종료 분류로 숨기지 않고 별도 실패로 처리한다.

로컬 `mp_signal.gd`는 WebSocket 전용이다. 앱의 `Mp.check_status→GET /status`와 기존2인 runner의 TCP listener probe 때문에 signal 로그에 invalid-upgrade가 남을 수 있다. 참가자 RTC packet 처리 오류와 구분했다. 외부 `/status`·외부 signaling 접촉은 없다.

현재 증거는 macOS의 실제 native WebRTC·동일 기기 loopback, phone은 폰 글꼴/레이아웃·touch 입력 모사다. 인터넷 NAT/TURN·다른 기기·실물 iOS/Android·OS kill 뒤 앱 재실행/디스크 reservation 복원·host migration·실제 구버전 바이너리 조합은 검증하지 않았다. 프로토콜 결과를 주입한 상태 검사는 이 실행 결과에 포함하지 않았다.

최신 PC/폰3조건 캡처는 각17장·합계34장이며 UI 겹침0이다. `toast_top+height+4`와 card panel 사이의 정확한 여유는 도구가 Control geometry를 저장하지 않아 소급 측정하지 않았다. 소스상의 조건부 반례와 실제 관측 범위는 [toast-headroom.md](toast-headroom.md)에 구분했다.

이전 시도도 보존했다.

- `attempt-01`: root의 누수 기록 루프 변수 `trait`가 Godot 예약어여서 import 중단. 실제 거래 전이며 root가 `status_name`으로 수정했다.
- `attempt-02`: 최초 실제 3인 race 통과. `attempt-03`: 실제 donor/owner 재접속 4조건 통과.
- `attempt-04-pre-stable`: 제품 최종 저장이 snapshot 뒤에 발생해 의도적으로 중단. 그때까지 통과한 조건만 기록하며 전체 통과로 세지 않는다.
- `attempt-05-before-complete-retry`: 12조건 행동·UI·36 actor process exit 모두0. QA 종료 방송이 이미 kick된 수신자에 보내져 strict error 검사1건 실패. QA 방송에서 kick된 수신자를 제외했다. 제품 거래 실패와 구분한다.
- `attempt-06-before-wave-resync-fix`: 완료 유실 복구를 포함한13조건·39 actor strict 통과. 이후 기존2인 회귀의 `recovered.wave=0` 관측에서 전투 rejoin guard의 실제 회귀를 발견했다. 제품은 host 재접속 snapshot의 별도 승인 경로로 수정했고 최종2인은 같은 wave를 강하게 검사한다.
- `two-participant-before-complete-retry`: 의도적인 연결 단절 직후 기존 `_mp_send_snap→Mp.send`에서 native `channel->isClosed()` 오류1건, 이후 실제 재접속은 완료. root가 실제 송신 직전에 peer/채널 open 상태를 검사하도록 수정했다.
- `two-participant-before-wave-resync-fix`: wave0 관측과 UI frame 갱신 전 geometry 단언 실패 자료. 실제 `wave.png`에는 저장 상태/버전 겹침이 없었고, 최종 도구는 frame 전후 rect를 기록한 뒤 실제 갱신된 geometry를 검사한다. wave 복원 단언은 추가로 강화했다.
- `pending-phone-before-toast-fix`: pending 중립 표시는3조건 모두 통과했지만 race/reverse의 요청/거절 toast가 실제 협동 버튼줄과 겹쳐 UI4건 실패. PNG로 확인하고 root가 실제 버튼 bottom을 회피하도록 수정했다. 최신 PC/폰3조건씩 UI0로 재검증했다.

이전 일부 종료의 ObjectDB 경고는 활성 Dummy audio WAV/Playback 인스턴스로 분리됐다. 최종 도구는 검사 종료 때 음원을 stop/해제하고100ms 후 main을 해제한다. 경고가 남으면 최종 logs의 별도 warnings에 보존한다.
