# 협동 선물 경합 독립 검토

2026-11-09. 제품 파일은 수정하지 않았다. [계획](../gift-race-plan.md)과 서비스·lobby/multiplayer 연결을 읽고, 저장/서버 URL을 분리한 사본에서 결정론 probe를 실행했다. **실제 WebRTC·3인 native·물리 기기 검증과 구분한다.** 스캐폴드와 686행 중간 구현에서 찾은 반례를 수정 사본에서 다시 확인했다.

## 현재 오류·해결·미검증

| 항목 | 현재 판정 | 근거·남은 경계 |
| --- | --- | --- |
| G-01 AFK/fence 선택 버림 | 수정 후 probe 통과 | pending 선택2회 불변. 정산 대기 없는 force는 실제 카드 완료 로그2회·READY·barrier ready1회. |
| G-02 정상 wave가 fence에 막힘 | 소스 수정 확인 | host packet 전 prepare 검사, participant의 round/fence 허가 소비. 실제 wave 통신 순서 미검증. |
| G-03 기존 즉시 소비 | 소스 수정 확인 | give는 begin_gift에 위임, 기존 receive는 no-op. 구버전 소비 fallback 제거. |
| G-04 Escape로 ACK 문맥 불일치 | 소스 수정 확인 | cancel/back-to-choose 등의 gift guard. 실제 입력 검증은 별도. |
| G-05 다음 wave의 old ACK 오류 | 수정 후 probe 통과 | 지운 after_context를 읽지 않음. ScriptError0. |
| G-06 미확정 owner state 선반영 | 수정 후 일부 경로 관측 | winner 결과 유실 중 loser rejected 결과 공개 보류. TW/choice/settled도 accepted receipt 뒤로 보류하는 소스 확인. 실제 재접속·나중 loser 배출 필요. |
| G-07 settled 유실 뒤 재시도 없음 | 수정 후 probe 통과 | host tick에서 ACK 재전송2건. 실제 complete 도달까지의 복구는 별도. |
| G-08 일반 B 카드 body/context 분리 | 수정 후 probe 통과 | 실제 after_place→current_state→ingest→rejoin에서 body Lv2·선택0 복원. 실제 reroll만으로 revision 증가. |
| G-09 terminal 복원 뒤 원본 문맥 재복원 | 수정 후 probe 통과 | 선택1·generation11 유지. 중간 구현의 선택2·generation10 역행 사라짐. |
| G-10 settled replay의 최신 문맥 덮기 | 수정 후 probe 통과 | generation15 유지, complete만1회 재전송. |
| G-11 transport 단절을 영구 retire로 처리 | 수정 후 probe 통과 | drop 뒤 retired=false, peer-up 뒤 in_game=true. 명시 leave/kick 통신 정책은 별도. |
| G-12 caps 재협상 중 fence 우회 | 수정 후 probe 통과 | armed=true/caps3=0에서도 시작false·waiting[2,3]. |
| G-13 방향 편집 AIM→무료 카드 PLACE 복원 | 수정 후 probe 통과 | moving 편집은 READY 복원·carrying 아님. 신규 카드 AIM은 PLACE로 복구. |
| G-14 구host·newclient2명의 TW 상호 무시 | 수정 후 제한된 probe 통과 | 실제 publish/receive 함수에서 protocol0 plain TW 확인. socket 없는 relay 모사이며 혼합3인 통신은 미검증. |

현재 표에 남은 항목은 소스 확인 또는 제한된 fixture의 관측이다. I-04 전체 완료 판정은 실제3인 통신·오류 주입 gate 전까지 보류한다. 아래 초기 반례 설명은 역사로 보존하며 이 표를 현재 상태로 읽는다.

## 결정론 실행 증거

- [최종 단일 사본 13case](review-probe/final/run.json): 모두 exit0·ScriptError0. 서비스 `6ecbf9f4`, multiplayer `abc0855a`, Mp `acd819933745`, CardDock `bf192b8b94ca`로 root의 최종 핵심 소스 해시와 일치한다. 최신 판정의 근거는 이 실행이다.
- [686행 중간 사본](review-probe/run.json), [파일별 해시](review-probe/frozen.json): terminal rejoin 선택1→2, ACK 재시도0, owner body만 반영 후 rejected, 일반 B body+선택 부활을 각각 exit1로 관측했다. old ACK는 after_context ScriptError1인데 프로세스 exit0였다. 통과로 세지 않았다.
- [수정 사본 round4](review-probe/round4/run.json): 7case exit0·ScriptError0. terminal rejoin, ACK 재시도, 일반 카드 실제 완료, 실제 reroll, old ACK, loser 결과 보류, temporary drop/rejoin을 확인했다.
- [추가 round6](review-probe/round6/run.json): 5case exit0·ScriptError0. settled replay, caps 재협상 fence, pending 중 force, 정산 대기 없는 force의 실제 자동 완료, 방향 편집/신규 카드 AIM 복원을 확인했다.
- round2는 probe 예약어 변수명 parse 오류, round5는 작성 중 mp.gd 들여쓰기 오류로 import하지 못했다. 실행 결과 증거에서 제외하고 수정 후 실행과 구분해 로그를 보존했다.

한 SceneTree에서 일부 역할을 전환했고 `_send`는 기록만 했다. 네트워크가 없는 서비스 반례 재현이다. 최신 수정 사본의 원문은 각 디렉터리 `service-under-review.txt`, 실제 명령/소스 해시/관측값/종료코드/임시 프로젝트·고유 저장 정리는 각 run.json에 있다.

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/multiplayer/gift/review-probe/run_frozen.py --freeze-current --output /tmp/bindu-gift-independent
```

현재 소스를 새로 복사하는 명령이다. 이미 정리된 과거 임시 경로를 재사용하는 명령은 아니다.

## 추가로 확인한 핵심 반례

- G-06은 regular TW만 막는 것으로 부족했다. winner accepted 결과가 유실된 동안 loser rejected 결과가 최신 winner body를 host에 공개하면, host receipt에는 loser만 남고 owner 재접속 후 winner가 rejected로 바뀔 수 있었다. gift_choice와 다른 거래의 settled state도 같은 출구다. 수정 사본은 미확정 accepted receipt를 우선 보내고 나머지 state 공개를 보류한다.
- G-07은 donor가 ACK 뒤 pending을 비우고 owner도 ACK 뒤 재시도를 멈추는데 settled만 유실되면 아무도 재전송하지 않는 문제였다. host ACK 재시도와 gift_complete 확인이 추가됐고, complete 전 다음 선택은 잠근다.
- G-08은 A 완료 뒤 일반 B 카드가 body만 먼저 전송되고 문맥은 뒤따르는 사이 재접속하면 B를 다시 받는 문제다. 모든 TW가 body와 choice_context를 같은 revision으로 보내고, context-only 변화도 revision에 넣는 수정이 확인됐다.
- G-09는 terminal의 정상 after_context 복원 뒤 루프 끝의 host 원본 context가 다시 덮는 문제였다. G-10은 이미 settled인 옛 확인 패킷이 새 offer 문맥을 다시 쓰는 문제였다. 둘은 별도 경로이며 각각 probe로 확인했다.
- G-11에서 transport drop은 in_game을 지우므로 이를 영구 retire 신호로 쓰면 안 됐다. G-12는 같은 판의 caps 재협상 순간 legacy 시작으로 되돌아가 fence를 생략하면 in-flight gift를 놓치는 문제였다. 명시적 retire 집합과 round 단조 protocol_armed로 구분됐다.
- G-13에서 이미 소비한 카드가 picked에 남은 채 방향 편집 AIM을 저장하고 PLACE로 복원하면 무료 카드처럼 취급될 수 있었다. moving의 move_return을 저장하는 방향으로 구분했다.
- G-14에서 구host가 중계한 gift_round 빈 값 TW를 newclient가 거절했다. protocol0에서는 plain TW를 보내도록 분기했다.

## 최종 송신 guard 검토

`Mp._send_bytes`의 get_peer 딕셔너리·채널 검사는 공식 API와 맞는다. 기본 peer는 세 데이터 채널을 만들고 connected는 세 채널이 모두 열린 상태를 뜻한다. 이 프로젝트도 추가 채널 없이 create_server/create_client를 호출한다. 따라서 모든 채널 OPEN을 확인하는 것을 잘못된 transfer-mode 채널 선택으로 보지 않았다. [Godot 공식 WebRTCMultiplayerPeer 문서](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html).

guard는 멤버십·epoch·retire 상태를 바꾸지 않고 닫힌 채널의 실제 전송만 건너뛴다. 기존 get_peer 상태가 아직 connected로 남아 있는 close 경계를 보수적으로 막는 목적과 맞다. 반환값은 적용 ACK가 아니며 send는 여전히 void다. 따라서 이 검사만으로 선물 성공을 정산하면 안 되고 서비스 retry/receipt/complete가 필요하다. 검사 직후 native 채널이 닫히는 경쟁까지 원자적으로 없앤다는 보장도 하지 않는다. 이 범위에서 새 멤버십/채널 선택 오류는 찾지 못했다.

## 초기 중간 구현의 오류와 수정 방향

### G-01 — fence가 AFK 자동 처리를 막으면 현재 fallback은 선택을 버린다

현재 [`cards._on_pick`](../../../../../scripts/features/cards.gd)는 `mp_auto_now`를 보기 **전에** `_gift_blocked()`로 반환한다. [`lobby._mp_auto_rest`](../../../../../scripts/features/lobby.gd)는 `_mp_auto_pick()`가 false면 반복을 끝낸 뒤 CHOOSE이면 `picks_left=0; _enter_ready()`를 실행한다.

반례: 선택2회인 참가자에게 `local_fence` 설정 → 호스트 force/AFK가 자동 선택 요청 → 카드 적용은 guard로 거절 → fallback이 선택2회를0으로 만든다. pending PLACE도 취소 경로로 CHOOSE에 들어가면 같은 위험이 있다. 이는 스캐폴드가 활성화될 때 발생하는 **소스 수준 반례**이며 이번 검토에서 런타임 재현하지 않았다.

필요한 구분은 `미정산 예약`과 `새 선물 차단`이다. 미정산 예약은 변경하지 않고 먼저 정산한다. 그다음 호스트가 승인한 자기 카드 자동 처리 → READY → 선택 freeze → `barrier_ready` 순서가 필요하다. `mp_auto_now`로 모든 gift guard를 우회하면 예약 중인 카드도 소비할 수 있다. 자동 선택 실패를 선택 포기로 취급하는 fallback도 이 경계에서는 실행하면 안 된다.

### G-02 — 준비 fence를 유지하면 정상 wave도 거절될 수 있다

[`run_flow._start_wave`](../../../../../scripts/features/run_flow.gd)는 host·participant 모두 `gifts.before_wave()`를 호출한다. 현재 스캐폴드의 `before_wave`는 `local_fence`가 있으면 false다. READY에서 freeze를 유지한 채 정상 host `wave`가 와도 participant가 시작하지 못한다.

허가된 wave가 `round/rest/fence_id`와 연결되어 fence를 소비하도록 해야 한다. host도 `_mp_try_go`의 `mp_ready.clear()`·`wave` 전송 **이전**에 전체 fence 완료를 확인해야 한다. packet을 보낸 뒤 host만 시작 guard에서 반환하면 기기 간 phase가 갈라진다.

### G-03 — 기존 즉시 소비 함수는 아직 남아 있다

검토 시 [`lobby._mp_give`](../../../../../scripts/features/lobby.gd)는 기존 `gift` 전송 직후 성공 연출·`_after_place()`를 호출하는 본문이었다. 기존 `_mp_recv_gift`도 결과 ACK 없이 거절할 수 있었다. 이는 계획이 다루는 기존 I-04이며 새로 구현된 서비스의 결함으로 세지 않는다. 새 UI가 fail-closed여도 이 본문이 안전한 예약 경로가 된 것은 아니다. 활성화 전에 진입점과 기존 packet handler를 서비스로 교체하고 구버전 fallback을 닫아야 한다.

### G-04 — pending 중 Escape가 ACK 정산 문맥을 깨뜨린다

후속 `_ack`는 `_context() != pending.context`면 반환하며 `_context`에는 phase가 포함된다. 현재 [`interaction._cancel_step/_back_to_choose`](../../../../../scripts/features/interaction.gd)에는 gift guard가 없어, pending PLACE에서 Escape/우클릭으로 CHOOSE에 돌아갈 수 있다. 카드와 선택 수는 같아도 phase가 달라 accepted/rejected ACK를 계속 무시하게 된다.

pending 취소 입력을 정확한 안내와 함께 차단하거나, 예약의 동일 choice identity가 유지됐음을 확인한 뒤 안전하게 예약 phase를 복구해 정산해야 한다. 무조건 전체 문맥을 덮어쓰거나 현재 선택에 ACK를 적용하는 해결은 안 된다. 이 역시 서비스 활성화 전 소스 반례이며 네트워크 실행 결과는 아니다.

## 계획·구현에서 반드시 닫아야 할 반례

| 경계 | 반례 | 필요한 처리 |
| --- | --- | --- |
| owner 적용 후 host commit 전 재접속 | owner 로컬에는 accepted receipt, host snapshot에는 미적용 상태. 로컬 owner ledger를 그대로 merge하면 retry가 옛 accepted/full TW를 되살린다. | donor reservation은 유지하되 owner receipt ledger는 **host 확정 ledger로 교체**. 미확정 적용은 snapshot과 함께 롤백하고 새 epoch에서 다시 검증. old epoch 결과는 무효. |
| 더 최신 TW 앞에 늦은 commit | host는 revision13, owner의 accepted 캐시는 revision12. host가 덮으면 이후 편집 손실. 단순 재조회하면 owner가 캐시12만 반복해 barrier가 영원히 남는다. | `receipt.applied_revision`과 최신 `state_revision/full TW`를 분리하거나 최신 TW에 receipt 포함을 증명. 이미 host terminal이면 ACK만 재전송. 오래된 전체 목록으로 덮기 금지. |
| donor rejoin·READY 복원 | 현재 `_mp_resync`는 rest에서 READY로 들어간다. pending card A의 offer/선택을 복원하지 않고 ACK를 적용하면0개 또는 새 카드 B를 차감한다. | 예약의 phase/card/offer/generation/picks/bank/rerolls를 정확히 복구한 뒤 A만 정산. rejected는 같은 카드로 실제 다른 사용을 계속할 수 있어야 한다. 복원 과정에서 새 offer를 추가 공개하지 않는다. |
| ACK 정산이 새 offer를 여는 순간 | A accepted → `_after_place(A)`가 남은 선택의 offer B를 생성 → A 중복 ACK 도착. | terminal/정산중 상태를 원자적으로 먼저 잡고 동일 token은 소비 재진입 금지. B의 선택 수·offer·RNG에 변화0. 정상 A 소비가 남은 선택의 새 offer를 **한 번** 여는 것과 재접속/replay가 추가로 뽑는 것을 구분. 계획의 “새 offer를 뽑지 않는다”는 후자를 금지한다는 의미로 명확히 해야 한다. |
| donor kick·명시적 나가기 | host accepted 뒤 donor가 영구 퇴장하면 `gift_settled`를 받을 수 없다. ACK 대기 barrier를 그대로 두면 강제 시작도 영구 정지한다. | 구현자가 제안한 retired donor terminal 정리를 명시적으로 적용. 단순 `gone`은 retire와 다르다. 재접속이 허용되면 host의 authoritative terminal이 옛 reservation 복원을 막아야 한다. 이미 적용된 선물을 남긴 채 원래 선택을 되돌려주면 안 된다. owner 미응답 중의 retire는 적용 유무 결정을 먼저 해야 한다. |
| fence 중 아직 host가 모르는 request | D가 pending을 만든 직후 host fence를 받고, request는 아직 host에 도착하지 않았다. host가 “ledger 없음”만 보고 wave를 시작할 수 있다. | 모든 참가자가 새 reservation 생성부터 잠근 뒤 자기 pending을 terminal/settled로 비우고 ready를 보낸다. ready는 round/rest/fence/connection epoch 일치. fence 도중 재접속/새 연결은 이전 ready를 재사용하지 않는다. |

서비스 구현자가 위 owner epoch/ledger 교체·최신 상태 재조회·retire·pre-wave fence를 반영하겠다고 전달했다. **설계 수신 사실이며 구현/통신 통과 증거는 아니다.**

후속 부분 소스의 `_send_result`는 보관한 receipt의 `applied_revision`과 `current_state()`의 최신 revision/전체 목록을 분리해 재포장한다. 따라서 위 “캐시12만 영원히 재송신” 반례를 해소하는 방향은 확인했다. `ingest_state`가 아직 false placeholder여서 host commit·rejoin까지 실제로 수렴한다는 증거는 없다.

## 전송·식별자 세부 조건

- 현재 [`Mp.send`](../../../../../scripts/mp.gd)는 client의 `to=1` 호출에서 `msg.to`를 추가하지 않는다. host `_on_bytes`는 `to`가 없으면 다른 peer에 먼저 relay하고 그다음 host packet handler를 실행한다. 따라서 `send(request,1)`만으로 host 전용 적용 경로가 보장되지 않는다. 이후 스캐폴드 `_send`에는 명시적 `to` envelope가 추가됐다. 실제 owner `gift_apply` handler의 host 발신 검사와 통신 검증은 남는다.
- host `send(...,1)`는 자신에게 loopback하지 않는다. 이후 스캐폴드 `_send`에는 자기 id면 `receive`를 호출하는 경로가 추가됐다. owner=host·donor=host도 같은 transaction handler를 거치며 별도의 즉시 성공 경로를 두지 않는지 확인한다.
- fingerprint는 정규화한 불변 요청 필드(round/rest/donor/gift/choice/owner/nid/request/e/lv)에 한정한다. `t/f/to/epoch/retry/state_revision`까지 넣으면 host relay·재접속·최신 상태 재포장이 같은 token의 payload 변조로 오인될 수 있다.
- offer generation은 실제 새 추첨에서만 증가한다. `_show_offer`는 detail 토글 등 재렌더에도 호출된다. 읽기만으로 choice id가 바뀌면 안 된다. pending 중 Escape/우클릭/carry cancel도 예약 phase를 바꾸어 정산을 막지 않는지 확인한다.
- request id·이번 rest 수신 사실은 full TW와 rejoin snapshot에 포함되어야 한다. Tower metadata만 갱신하고 `mp_state/mp_apply/_mp_resync`를 빠뜨리면 재접속 뒤 과거 요청이 부활하거나 모든 전달이 막힌다.
- caps는 connection epoch마다 재확인한다. 예전 peer의 VERSION1 caps를 같은 id로 들어온 구버전 peer에 재사용하면 안 된다. old round/caps/fence ACK도 현재 namespace를 열면 안 된다.

## 무해하거나 이미 계획이 올바르게 구분한 항목

- host `_on_bytes`가 참가자의 `f`를 실제 연결 id로 덮는다. 단순히 packet의 `f=1`을 넣어 host ACK를 사칭할 수 있다는 지적은 현재 transport에는 맞지 않는다. receiver의 host 발신 검사까지 연결해야 한다.
- 같은 reliable 채널의 정상 순서는 보장되지만, 이것이 게임 적용 ACK나 재접속 이후의 중복 방지를 대신하지 않는다. 정상 순서만으로 G-01/재접속 반례가 해결되지는 않는다.
- `_mp_recv_towers`가 목록에 없는 owner tower를 지우는 것은 전체 snapshot에 맞는 기존 동작이다. commit에 **owner 전체 목록**을 전달하면 된다. 단일 gift target만 넣는 것은 오류다.
- accepted receipt를 현재 request 검사보다 먼저 재생하는 계획은 맞다. 적용 뒤 `req_e=-1`이 됐다는 이유로 같은 token을 rejected로 바꾸면 안 된다.
- 멀티플레이에서는 [`BinduEditHistory.begin_edit/can_undo`](../../../../../scripts/edit_history.gd)가 차단된다. “owner가 Ctrl+Z로 들어온 선물만 되감는다”는 반례는 현재 지원 경계에는 해당하지 않는다.
- 현재 `note_new_offer` hook은 `_show_offer`가 아니라 `_make_choices`에 있다. 따라서 단순 재렌더마다 generation을 올리는 잘못된 연결은 현재 코드에 없다. 실제 복원·정산 때의 호출 횟수는 런타임으로 확인해야 한다.
- nonce/sequence를 새 round마다 무조건0으로 되돌릴 필요는 없다. 모든 ledger/token이 round namespace를 지키면 단조 증가 유지도 안전하다. 반대로 `close_round` 호출만 있고 재개 시 옛 owner state/caps를 새 round에 섞으면 안 된다.

## 필수 검증

1. 실제3 native process에서 같은 request에 donor2명 선착순을 양방향으로 바꾼다. accepted1/rejected1, owner 총 레벨 증가1회, donor 선택 소비1/0, loser offer/bank/rerolls 불변과 거절 뒤 실제 대안 사용까지 확인한다. host owner·participant owner 모두 필요하다.
2. 실제 relay hook으로 결과·ACK·settled를 각각 지연/중복/유실시킨다. token별 owner apply/host commit/donor consume/settled 카운터를 분리한다. snapshot 값 직접 주입만으로 통신 증거를 대체하지 않는다.
3. owner 적용 후 commit 전/후 끊고 재접속한다. commit12 뒤 TW13, TW13 앞 뒤늦은 commit12도 만든다. old epoch 결과가 overwrite하지 않고 receipt/최신 상태가 수렴하며 barrier가 유한하게 풀리는지 확인한다.
4. donor의 PLACE pending을 rest READY rejoin으로 복원한다. accepted·rejected, 남은 선택0/1/2, bank 포함, 같은 값 카드2장, 새 offer 공개 직후 중복 ACK, old rest/round replay를 각각 검사한다. ACK가 reserved choice만 정확히 한 번 바꿔야 한다.
5. fence와 request를 교차시키고 AFK/force를 실행한다. pending 정산 전 선택 불변, 그 뒤 자기 카드만 자동 완료, 모든 peer READY/freeze, 유효한 ready 수신 뒤만 wave 시작을 확인한다. fence 도중 재접속·old ready·불일치 epoch도 필요하다.
6. pending 중 Escape/우클릭·다른 카드·reroll·skip·ready·모달 열기·연결 복구를 실제 입력으로 시도한다. 허용된 읽기/카메라/일시정지는 유지하고 예약을 덮는 동작은 정확한 이유와 함께 막혀야 한다.
7. terminal 전/후 donor retire·owner kick·GAMEOVER·새 판, 구버전 재접속을 검사한다. host 진행 영구 정지나 선물 적용+선택 환불이 없어야 한다. 앱 강제 종료 후 reservation 디스크 복원·host migration은 현재 계획의 지원 증거가 아니다.

서비스 본문과 연결이 추가됐고 독립 fixture의 수정 후 결과도 나왔다. 실제3인 통신·오류 주입·재접속/퇴장 결과는 별도 gate이므로 I-04 전체 완료 판정은 보류한다.

일반 참가자의 rest 재접속은 기존 READY 정책이다. `_remember_context`가 보관하는 카드 복원은 해당 rest의 gift donor 기록이 있는 문맥이다. 실제 모바일 중단·강제 종료의 모든 선택 복원을 검증한 결과로 확장하지 않는다. 최종 파일별 검토 식별자는 [review-final-source.json](review-final-source.json)을 따른다.

## 최종 국소 UI 검토: pending 표시·toast·행동 버튼 회피

읽기 전용으로 `field_view.gd`의 gift_waiting 분기, `frame.gd`의 toast_top과 카드 위 이동, `ui_layout.gd`의 mp_act blocker 추가만 검토했다. 제품 수정·새 native 실행은 하지 않았다.

- `field_view`: blocked PLACE에서 기존 거절/새 설치 미리보기 대신 중립 고리와 보관 안내를 만든다. 변경 쓰기는 `place_note` 표시 캐시이며 draw 함수만 호출한다. phase·picked·선택·tower/orb·점수·난수·카메라를 바꾸는 새 호출은 없다. `refuse=false`이므로 place note의 빨간 X 경로도 타지 않는다.
- `frame`: 실제로 보이는 mp_bar/mp_act의 아래끝+8을 toast의 하한으로 쓴다. tutorial/guide가 올린 하한도 보존한다. 카드 위로 옮기는 후속 보정이 멀티 행동 버튼 쪽으로 다시 올리지 않도록 같은 하한을 사용한다. 변경은 toast의 UI 위치·표시 경로에 한정된다. 전투 dt·배속·카메라·카드 소비 경로는 이 국소 수정에 없다.
- `ui_layout`: mp_act의 global rect를 기존 UI 좌표 변환으로 회피 목록에 추가한다. 숨은 행은 제외하며 기존 위치 탐색의 입력 Rect만 바뀐다. blocker 목록이 cache key에 들어가므로 새 행의 위치/크기가 바뀔 때 옛 배지 위치를 고정 재사용하지 않는다. 바뀌는 것은 배지/안내의 그리기 위치다.

이 세 국소 변경에서 새 전투·카메라·선택 변이나 확정된 새 겹침 결함은 찾지 못했다. 새로운 native 통과 주장은 이 검토에 포함하지 않는다.

남은 배치 한계는 구체적인 세로 공간 조건 하나다. `toast_top + toast_height + 4 > card_panel_top`이면 `max(toast_top, card_panel_top - toast_height - 4)`는 toast_top을 그대로 유지한다. banner가 없으면 현재 hide 조건도 적용되지 않아 카드 위 공간 부족 자체를 해결하지 못한다. 이는 실제 실패를 관측한 결과가 아니라 코드의 조건부 한계다. root가 실행 중인 최신 PC/폰3조건·7프로필35상태에서 실제 rect와 함께 판정해야 한다. 공간이 충분한 현재 화면까지 결함으로 세지 않았다.


## 부분 구현 검토 시점 소스 식별

2026-11-08T17:02:41.522142+00:00 기준 파일별 해시. 작성 중인 소스이며 이후 구현의 자동 통과를 뜻하지 않는다.

```text
a9e3286506321a80a392064e89ab3077e4f2198b2ddd11eac541253e0f8520e6  scripts/app/gift_transactions.gd
37f575ce22da6da6562782e52918d327edfc6ffc4562e4ca541c2f163144115c  scripts/features/multiplayer.gd
39a8453cd28b6f97987a9e28196a194a816bdade1ae18e2e9c48c55a08eee3ea  scripts/features/lobby.gd
e046ab6190e09964446b852d97f39ef9624f754fd79c1db862a3af07fa98bc2b  scripts/features/cards.gd
a27932f6eab1fb00d4a5d48d33128f81401c4925bbfa478dbacf5fa73ab47211  scripts/features/run_flow.gd
471a20dcd45ed02d5256262ec20642a9886f3f197ef26cec1a6f81f3ccaef70d  scripts/features/interaction.gd
8db1065d63d50f681839c813bee5e01b4dca7d2ba969d7e643d87098018e2e39  scripts/mp.gd
aa9d9e7fda6da45452290138e38e541b1e3ee37bdcd7ecba5ba508b0073007d0  scripts/edit_history.gd
ec7ec746420710d6bffacef004be5c8117e6f080352cf4c9fea81b9d912315bb  docs/qa/2026-11-09-battlefield-fixes/multiplayer/gift-race-plan.md
```


UI review snapshot UTC 2026-11-09T14:51:48.445744+00:00
```text
c16a745b04bca8f133681c18a64524aec199ff704cdede6c50b5ec2c6ff6d985  scripts/features/field_view.gd
80656d6d238bbdd25bf079e7b3abfed6bc7b06ccc8b46c65ed82d6fbe6f0eee8  scripts/features/frame.gd
0cbd2450e0c4943bf58da62a5a336999759a18e82025544af76b8a55dfe54e63  scripts/features/ui_layout.gd
```
