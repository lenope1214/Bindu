# 최신 main rebase 뒤 전달 검증

본 표는6번째 전달 snapshot이다. 이후 조준·hit·release 진단·[상태 문구 표시 후속](../performance/feedback-density/README.md)이 있다. 문구 표시 변경 뒤 전체 check252/86/28과 별도 native/release 검증을 다시 통과했다. 이전55 actor 실통신을 최신 FieldView 변경 뒤 재실행한 것으로 읽지 않는다.

기준 main `8704b78688ee9be638e0ddd24eb91d54f3f56194`. v1.0.0·결과 상세·Android/iOS 빌드 설정을 보존했다. [충돌 해결](rebase-resolution.md), [출발·복구 ref](rebase-before.json), [통합 집계·제품 해시](rebased-verification.json).

| 실행 | 관찰 결과 | 증거 |
|---|---|---|
| 전체 check | exit0, 명세252·전달 상태86·parity345사례/4140표본·fuzz4·W4/8/12 복원→13·서버28 통과 | [로그](rebased-check.log) |
| 일반 native | 7프로필35상태 + PC/폰16묶음680단언, 모두 exit0·runtime ERROR0. 폰 설정 모달의 의도된 뒤 HUD 겹침8개 별도 | [집계](native/results.json), [고정 소스](native/source-manifest.json), [진행 로그](rebased-native-progress.log) |
| 실제 WebRTC | 3인14조건·협동/대결2인·폰3조건 =55 actor 실행,543단언, 행동/UI/runtime 오류0·경고0 | [3인](../multiplayer/gift/delivery-rebased/summary.json), [폰](../multiplayer/gift/delivery-rebased-phone/summary.json), [2인 로그](rebased-two-progress.log) |
| 조준 대상/RNG | 14,527비교·불일치0, 최신 Tower 해시 일치 | [결과](targeting-rebased/results.json), [명령·정리](targeting-rebased/run.json) |
| 최신 결과 상세 | 실제 game over·버튼·개별 줄 pointer·Esc·닫기, PC/폰 각각7단언·UI0·runtime ERROR0 | [PC](result-pc.log), [폰](result-phone.log), [폰 화면](result-phone/result-object.png) |
| 결과 기록과 undo | 새 main의 hist·wave_kills를 기존 편집 런타임 검사에 추가, 원래 객체·기록 보존 | [PC](native/undo-pc/run.log), [폰](native/undo-phone/run.log) |
| 아키텍처 감사 | 최신 main52개 미기록 변화, rebased43개. 새 미검토 변화0. 일회성 감사 전체 통과와 구분 | [비교](architecture-comparison.json), [main](architecture-main.log), [rebased](architecture-rebased.log) |

[카드 읽기](native/core-phone/read-card.png), [폰 협동 대기](../multiplayer/gift/delivery-rebased-phone/race/peer_b/pending-reservation.png), [폰 요청 알림](../multiplayer/gift/delivery-rebased-phone/race/host/owner-final.png)은 최신 소스의 대표 캡처다. 모든 원본의 공개/로컬 보존 여부는 [증거 정책](../publication.md)을 따른다.

네트워크는 loopback signaling·실제 native WebRTC, 화면 조작은 native SubViewport·VirtualInput이다. 실제 고객·인터넷/NAT·실물 폰·OS 중단·손가락 가림·사용자 과제 검증을 대신하지 않는다. 결과 목록의 폰 검사는 pointer 경로이며 실물 touch-to-mouse 변환 증거는 아니다. 전체 후반 고배속 지연은 해결하지 않았고 장판 후보는 제품에 넣지 않았다. Draft PR로 전달하고50개 목표는 계속 열어 둔다.
