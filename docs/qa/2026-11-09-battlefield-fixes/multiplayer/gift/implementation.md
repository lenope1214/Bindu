# I-04 선물 예약 구현

새 `BinduGiftTransactions`가 donor 예약→owner 적용→host 원자 commit→donor 소비→host 정산 확인을 담당한다. 기존 `gift` 패킷은 적용하지 않는다. 구host 판은 기존 plain TW를 유지해 newclient끼리의 오브젝트 동기화도 계속되며, 전달 기능은 비활성이다. `_mp_give`도 전송 직후 소비하지 않는다. 요청 생성·변경·삭제·충족마다 request id를 올리고 즉시 동기화한다.

`gift_request/apply/result/ack/settled/complete`는 round/rest/token/choice/실제 donor·owner/대상/요청 id/속성·레벨/fingerprint를 공유한다. host 전용 packet에는 `to=1`을 명시해 transport 자동 relay를 피한다. retry는 같은 token이다. owner ledger는 적용 전에 조회하며, host는 owner 전체 상태와 receipt를 함께 확정한 뒤 ACK를 보낸다. terminal receipt는 판 종료까지 보존하고 임의 TTL로 지우지 않는다.

미확정 owner accepted가 있는 동안 다른 apply·result·TW·카드 소비를 보류한다. 일반 TW에도 Tower 목록과 choice context를 같은 revision으로 묶는다. 따라서 미확정 적용이 다른 snapshot으로 새거나, 정상 후속 카드 적용만 저장되고 선택 소비는 되돌아가는 분리가 없다. 이미 끝난 settled는 확인만 재전송하며 새 문맥을 쓰지 않는다.

ACK 수신은 예약 당시 전체 카드 문맥이 정확히 같은 경우만 소비한다. pending 중 취소·카드 적용·편집·reroll·skip·AFK는 중앙 guard가 막는다. accepted 소비와 다음 offer 공개는 한 번만 수행한다. host settlement 확인 전까지 다음 선택을 잠그며, ACK·settled·complete 각각의 유실에도 재전송으로 수렴한다. 읽기·카메라·일시정지는 유지한다.

재접속은 두 정책을 구분한다. 일반 참가자는 기존처럼 READY로 돌아온다. **해당 rest에 gift donor로 예약한 사람만** host가 가진 카드 문맥을 복구한다. 새 offer를 다시 뽑아 복원하지 않는다. owner는 host 확정 receipt로 ledger를 교체하고 새 connection epoch에서 미확정 요청을 다시 검증한다. commit 전 적용은 host snapshot으로 롤백하며 `mp_req_got_w`도 확정 상태로 맞춘다. 로컬 terminal 복원과 host 원본 예약 복원은 한 경로만 선택한다. 방향 편집 중 AIM은 원래 READY/CHOOSE로 직렬화해 소비한 카드를 PLACE로 되살리지 않는다. 기존 gesture의 Tower 참조는 snapshot 적용 전에 정리한다. 전투 중 rejoin snapshot은 host 확정 ledger를 확인한 별도 승인으로 같은 wave에 복귀한다.

wave는 모든 미정산 결과와 participant fence를 기다린다. 이미 지원 협상을 마친 판은 재접속 caps0 구간에도 fence를 생략하지 않는다. round/rest/fence/connection epoch가 일치하는 승인만 시작한다. 일시 RTC 단절은 영구 퇴장이 아니다. 명시 lobby/host kick만 retired로 표시하며, donor 영구 퇴장의 확정 결과는 barrier에서 정리한다. owner 영구 퇴장의 미확정 요청은 donor 미소비 거절로 끝낸다.

공개 연결:

- `multiplayer_system.gifts()`는 session별 service를 반환한다.
- `blocks_local_choice()`, `pending_notice()`, `offer_status(tower,card)`는 중앙 mutator와 UI가 공유한다.
- `note_new_offer()->bool`은 실제 신규 추첨에서만 generation을 올린다. UI 재렌더는 올리지 않는다.
- `before_wave()`, `prepare_wave(force)`, `accept_wave(packet)`, `accept_rejoin_wave(state)`, `wave_started()`는 진행 경계를 묶는다.
- `current_state()`, `ingest_state()`, `rejoin_state()`, `restore_rejoin()`는 receipt와 revision·문맥을 복구한다.
- `awaiting_settlement()`, `debug_state()`는 동작 확인용 조회다. readiness flag는 실제 통합 구현에 켜져 있으며 우회 stub을 사용하지 않는다.

지원 한계: host 종료/host migration은 기존처럼 판 종료다. host가 아직 받지 못한 예약의 앱 강제 종료·디스크 복원은 보장하지 않는다. 이미 host에 등록된 예약은 현재 재접속 상태와 host ledger로 복원한다. 연결이 끊긴 참가자가 돌아오지 않으면 host가 내보내기 전까지 정산·wave가 안전하게 기다릴 수 있다.

검증: [결정론 상태 게이트](state/README.md), [독립 리뷰](review.md), [실제 3인 native](README.md)를 각각 본다. 소스별 결과·실패·재실행을 보존하며 최종 통신 판정은 native 보고서의 source hash 기준이다.
