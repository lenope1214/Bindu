# I-04 협동 선물 경합: 최소 수정·검증안

2026-11-09 소스 검토에 따른 **구현 제안**. 제품 변경·Godot 실행·실제 3인 경합 시험은 하지 않았다. [통합 리뷰 I-04](../review-integration.md), [기존 실제 2인 증거](README.md)와 구분한다. 기존 2인 정상 전달 통과는 이 경합의 검증이 아니다.

## 확인한 실패 경계

[`_mp_give`](../../../../scripts/features/lobby.gd#L283)는 전송 직후 성공 표시·로컬 요청 지우기·`_after_place()`를 실행한다. [`_mp_recv_gift`](../../../../scripts/features/lobby.gd#L294)는 요청 변경/충족·상한이면 반환하고 donor에게 결과를 보내지 않는다. 두 donor가 같은 요청을 보내면 한 owner 이벤트 루프에서 첫 건만 적용되고, 양쪽 donor 선택은 이미 소모된다. 현재 receiver는 `mp_req_got_w`·쉬는 시간·판 식별자도 검사하지 않는다.

단순 ACK 추가로 끝낼 수 없는 경계도 있다.

- [`Mp.send`](../../../../scripts/mp.gd#L565)는 전송 불가 때 조용히 반환하는 `void`다. reliable 전송은 **게임 적용 확인**이 아니다. 참가자 간 메시지는 호스트를 경유한다.
- [`_mp_tick`](../../../../scripts/features/multiplayer.gd#L405)의 owner tower 전송은 0.25초마다다. owner가 적용 후 이 전송 전에 끊기면 호스트가 가진 상태에는 선물이 없을 수 있다.
- [`_mp_resync`](../../../../scripts/features/multiplayer.gd#L303)는 기존 오브젝트를 버리고 호스트 상태로 복원한다. 쉬는 시간 복귀는 READY이며 기존 donor offer/선택을 복원하지 않는다. 메모리 pending만 남겨도 ACK 때 `_after_place()`를 부르면 다른 선택/0개 선택을 차감할 수 있다.
- [`_mp_auto_rest`](../../../../scripts/features/lobby.gd#L437), [`_mp_try_go(force)`](../../../../scripts/features/multiplayer.gd#L700)는 미완료 선택을 대신 고르거나 웨이브를 강제로 넘길 수 있다. 늦은 ACK가 현재 선택을 소모하지 않게 해야 한다.

## 최소 보장과 식별자

1. owner가 수락한 고유 선물 하나당 속성 적용 **최대 한 번**, donor 선택 소비 **정확히 한 번**. 명시적 거절은 원래 카드·offer·선택 수·보류 선택을 유지한다.
2. donor별 pending은 한 건만 둔다. 전송 시작은 소비가 아닌 **선택 예약**이다. ACK 전 다른 사용·reroll·skip·자동 선택·준비는 해당 선택을 바꾸지 못한다. 정보 읽기·카메라·일시정지·연결 복구는 가능하다.
3. 요청은 `request_id`를 가진다. owner가 요청 생성/변경/삭제/충족할 때 증가시켜 `tw`에 넣는다. 같은 속성을 다시 요청해도 예전 선물이 새 요청을 채우면 안 된다.
4. host가 판마다 새 `round_id`를 `start`와 `re`에 보낸다. 방 코드는 재사용 가능하고 coop의 `mp_seed`는 0이므로 둘 다 판 식별자로 부족하다. `rest_id`는 해당 쉬는 시간의 식별자다(`wave` 번호를 쓰더라도 round와 함께 비교).
5. `gift_id`는 donor의 재접속에도 유지되는 instance nonce+증가 seq다. 재시도할 때 같은 id·payload를 쓴다. `choice_id`는 offer generation+slot처럼 **동일 값 카드끼리도 구분**한다. `(round_id, donor_id, gift_id)`와 payload fingerprint를 결과 ledger 키로 쓴다. rejoin 인증 tok 자체는 패킷/로그 식별자로 쓰지 않는다.

## 최소 메시지와 적용 순서

기존 owner가 자기 오브젝트를 수정하는 권한 모델을 유지한다. host는 이미 참가자 통신의 경유점이므로 **결과 보관·재접속 복원 지점**으로만 추가한다. host가 stale tower 복사본에 대신 `add()`하는 방식은 owner의 다음 `tw`에 덮이므로 피한다.

```text
gift_request = {v, round_id, rest_id, gift_id, choice_id,
                owner_id, nid, request_id, e, lv}
gift_result  = {v, round_id, rest_id, gift_id, donor_id,
                status: accepted|rejected, reason,
                payload_fingerprint, owner_revision, owner_towers, receipt}
gift_ack     = {v, round_id, rest_id, gift_id, choice_id,
                status, reason, payload_fingerprint}
gift_settled = {v, round_id, rest_id, gift_id, choice_id}
```

1. **donor `_mp_give`:** 현재 요청/카드/권한을 재검사하고 `pending`에 원본 카드, offer 전체, picks/bank/rerolls, choice generation, 대상·요청 id를 저장한다. 성공 토스트·burst·요청 삭제·`_after_place()`는 실행하지 않는다. “전달 확인 중”과 연결 상태를 표시하고 host에 요청한다. 송신 실패/ACK timeout도 소비하지 않는다.
2. **host request handler:** 보낸 id는 실제 연결의 sender를 사용한다. 같은 token은 pending/result를 조회한다. 새 요청이면 rest 경계에 등록 후 owner로 보낸다. 이미 끝난 건은 저장한 최종 ACK를 donor에게 재전송한다.
3. **owner `_mp_recv_gift`:** 타입/범위·현재 coop/round·실제 sender를 확인한 뒤 ledger부터 찾는다. 같은 token의 결과가 있으면 **rest/현재 요청을 다시 검사하기 전에** 그 결과를 재전송한다. 같은 token에 다른 payload면 거절한다. 신규 token만 현재 rest/쉬는 시간, `nid` 소유자, `request_id`+속성, 이번 쉬는 시간 이미 수신했는지(`mp_req_got_w`), `can_take`를 검사한다.
4. **owner 직렬 적용:** 별도 await 없이 한 이벤트에서 `add`→요청 해제→`mp_req_got_w` 갱신→영구적인 이 판 receipt 기록을 처리한다. 다른 donor의 같은 요청은 이후 거절된다. `accepted` 결과와 **업데이트된 owner tower 전체 목록**을 하나의 `gift_result`로 host에 보낸다. 단일 tower만 기존 `_mp_recv_towers`에 넘기면 목록에 없는 owner tower가 삭제되므로 금지한다.
5. **host commit:** owner 연결·round/token·payload를 검증하고, owner state와 결과 ledger를 함께 반영한 뒤 donor ACK를 보낸다. 같은 owner의 이전 `tw`가 되돌리지 않도록 owner revision을 `tw`와 commit에 적용한다. owner=host도 같은 handler/ledger 경로를 쓴다. owner receipt가 host에 확정되기 전 donor 성공을 알리지 않는다.
6. **donor ACK:** host 발신이며 pending token/round/choice/payload가 모두 일치하는 경우만 정산한다. accepted면 예약한 카드로 `_after_place(saved_card)`를 **한 번만** 호출한다. 기존 `_after_place(card)`도 picks/bank와 현재 단계에 작용하므로 같은 choice context가 유지됐음을 먼저 검사한다. 성공 연출은 이때 실행한다. rejected면 예약을 풀고 원래 카드를 그대로 든 상태·선택 수로 복귀하며 정확한 거절 이유와 다른 사용 가능 행동을 보인다. 정산 후 `gift_settled`를 host에 보낸다. 중복 ACK는 재차 소비하지 않고 settled만 다시 보낸다. host의 진행 barrier는 결과 생성만으로 풀지 않고 donor의 이 확인 뒤 푼다. 이 확인이 없으면 강제 시작이 ACK보다 먼저 도착할 수 있다.

`owner_towers+receipt`를 같이 host에 보관하는 이유: 적용은 보이는데 결과가 없어 donor가 환불받는 상태와, donor는 소비했는데 rejoin snapshot에서 적용이 사라지는 상태를 막기 위해서다. 기존 `tw`와 ACK를 서로 독립적인 fire-and-forget 메시지로 보내는 것만으로는 이 불변식을 만족하지 못한다.

## timeout·재접속·늦은 응답·경계

- **재시도:** `_mp_tick`에서 연결 가능할 때 동일 pending token을 backoff로 재전송한다. timeout은 “아직 확인 못 함”이며 자동 거절/환불이 아니다. owner가 이미 적용했을 수 있으므로 새 token 생성·다른 카드 사용으로 풀지 않는다. retry 간격 수치는 제품 정책이며 현재 제안에서는 정하지 않는다.
- **donor 통신 재접속:** `Mp._reset()`은 transport만 초기화한다. lobby/session의 reservation·정산 ledger는 지우지 않는다. `_mp_resync`는 host의 token 결과를 먼저 조회한다. 같은 rest의 미확정/거절이면 저장한 원본 offer/선택 context를 복원한 뒤 재시도/복귀한다. accepted면 정확히 그 예약만 정산하고 새 offer를 뽑지 않는다. `_mp_resync→READY`의 현 동작을 그대로 통과시키면 안 된다.
- **owner 재접속:** `re`에 host가 확정한 receipt ledger·request id·owner revision을 포함한다. host에 commit된 건은 duplicate retry에 동일 ACK, host에 commit되지 않아 snapshot으로 롤백된 건은 복원된 요청 상태에서 다시 검증한다. 이전 프로세스 결과가 뒤늦게 도착하지 못하게 owner connection incarnation/revision도 검사한다.
- **웨이브 전환:** 최소 구현은 host가 unresolved reservation을 가진 동안 `_mp_try_go(force)`까지 전환을 보류한다. donor의 `_mp_auto_rest`, 직접 카드 사용·reroll/skip도 pending guard를 공유한다. 최종 결과를 정산한 뒤 원래 대기/자동 선택을 계속한다. “연결 끊긴 채 무조건 새 웨이브로 진행”까지 유지하려면 host의 선택 이월/보상 ledger라는 추가 설계가 필요하다. pending을 삭제하고 ACK를 나중에 무시하는 우회는 금지한다.
- **늦은 ACK:** 진행 중인 다른 선택/다음 쉬는 시간/새 판을 차감하지 않는다. 이미 terminal인 token이면 no-op. 같은 판의 미정산 결과는 원래 reservation ledger에서 처리한다. 일반 전환 보류 정책이면 미해결 token이 다음 rest로 넘어가는 것은 오류로 잡는다.
- **GAMEOVER·나가기·kick·새 판:** 현재 판 namespace를 닫고 pending을 현재 선택에서 분리한다. 새 `round_id`가 온 뒤 옛 ACK/gift/tw는 무효다. host 종료는 현재 제품에서도 방 종료이므로 호스트 장애 후 판 복구/host migration은 이 최소안에 포함하지 않는다. 강제 종료한 donor 앱 재실행까지 보장하려면 reservation/receipt를 rejoin 저장과 함께 원자적으로 디스크에 보존해야 하며, 메모리 retry와 구분해서 시험한다.
- **버전 호환:** start에서 gift protocol version을 합의한다. ACK 없는 구버전 peer에는 성공한 것으로 소비하는 fallback을 두지 않는다. 지원하지 않는 조합에서는 선물 동작을 명확히 비활성화한다.

## 구현 위치

- `lobby.gd`: `_mp_req_set`, `_req_ok`, `_mp_give`, `_mp_recv_gift`, 자동 선택/요청 UI의 pending barrier.
- `multiplayer.gd`: packet 4종 handler, tick retry, `_mp_begin` round 생성/초기화, `_mp_peer_up` receipt 포함, `_mp_resync` reservation 복원, `tw` revision, `_mp_try_go(force)` barrier.
- `cards.gd`/interaction 호출부: `_on_pick`·reroll·skip·place가 예약 선택을 덮거나 소비하지 않도록 공통 guard. callback/직접 호출도 같은 정책을 따른다.
- 전용 작은 transaction service 또는 session 필드: pending·terminal result·choice revision. transport가 재연결할 때와 판이 바뀔 때의 reset을 분리한다. ledger는 판 종료까지 유지하고 임의 시간 TTL로 accepted token을 지워 중복 적용을 허용하지 않는다.

## 반드시 남길 증거

1. **실제 3 native process+로컬 signaling:** owner 1명·donor 2명이 같은 request id를 본 뒤 실제 카드→같은 오브젝트를 겹쳐 선택. 정확히 한 accepted/한 rejected, owner 레벨 한 번 증가, winner picks−1/loser picks·offer·bank 불변. 양 donor에 서로 다른 결과 문구. 양 donor 선착순을 바꿔 반복한다.
2. 실제 요청을 보낸 뒤 owner가 요청 변경/취소·레벨 상한 도달/다른 요청 수신을 먼저 처리하게 조정한다. donor는 미소비·같은 카드로 정상 대안을 사용할 수 있어야 한다. 카드가 같은 값으로 두 장 있어도 choice id 하나만 예약/소비한다.
3. 실제 연결 위에서 test-only relay hook으로 동일 gift 2회, 결과/ACK 유실·지연·중복을 만들고 token별 적용/소비 횟수 1을 기록한다. 제품 상태 직접 주입 검사는 이 실제 통신 증거를 대신하지 않는다.
4. donor 단절: 전송 전/owner 적용 전/host commit 후 ACK 전/ACK 후 로컬 정산 전 각각 재접속. owner 단절도 적용 후 host commit 전/후로 나눈다. host snapshot·receipt·donor 선택이 최종적으로 같은 결과를 가리키는지 검사한다.
5. pending 중 reroll·다른 카드·skip·ready·AFK 자동 선택·강제 시작을 실제 버튼/키/시간 경로로 시도해 미소비와 전환 보류를 확인한다. rejected 뒤 정상 선택·accepted 뒤 남은 선택/ready가 다시 진행돼야 한다.
6. old-rest/old-round gift·ACK, 잘못된 sender/owner/request id/payload, 동일 token 다른 payload를 재생한다. 새 선택·새 판 변화 0. host owner와 participant owner 양쪽 모두 시험한다.
7. 명시적 나가기·kick·GAMEOVER의 정리, reconnect 중 안내, 구버전 비활성 표시도 캡처한다. OS 강제 종료/재실행은 디스크 reservation을 구현했을 때 별도 시험한다. 모든 결과에 실제 source hash와 각 프로세스 로그·선택 수·target state·token trace를 보존한다.

단계별 적용/소비 카운터가 있어야 “겉보기 성공”과 중복·손실을 구분할 수 있다. 기존 2인 native 시나리오는 유지하고 이 3인 경합·오류 주입 시나리오를 추가해야 I-04를 완료로 표시할 수 있다.
