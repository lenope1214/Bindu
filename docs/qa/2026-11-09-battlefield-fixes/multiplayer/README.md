# BF-46 실제 로컬 멀티플레이 검증

아래는 첫 두 참가자 통합의 보존 기록이다. 이후 협동 동시 전달 프로토콜·같은 웨이브 재접속·실제 PC/폰 표시를 다시 확인한 현재 결과는 [거래 후속 검증](gift/README.md), [기계 판독 집계](gift/verification-summary.json)를 따른다. 이 문서 안의 ‘최종’은 당시 묶음의 최종을 뜻한다.

두 독립 Godot 프로세스가 로컬 중개 서버를 통해 실제 WebRTC로 연결됐다. 실제 게임의 협동 요청·속성 전달·소유권·준비·재접속 및 대결 시작·연결 중단 탈락을 확인했다. 단순 주입 상태 캡처와 구분한다.

## 실행 조건

- Godot `4.7.2.stable.official.ed1daf0bf`, macOS Apple M4, 프로젝트에 포함된 `addons/webrtc` macOS universal native 확장.
- 연결 시험은 별도 headless 호스트·참가자, 게임 시험은 별도 native 호스트·참가자와 1280×720 VirtualInput Viewport.
- 현재 작업 트리를 한 번 고정해 세 격리 사본을 만들고 각 `config/name`은 `BinduToolsMPNative…`로 바꿨다. 일반 서버·멀티 URL은 공백, 환경 변수 `BINDU_MP_URL`만 `http://127.0.0.1:<임시 포트>`다.
- 로컬 중개는 `tools/mp_signal.gd`. 전달된 ICE 설정은 빈 배열이라 외부 STUN/TURN을 사용하지 않는다. 운영 방·실사용자·프로덕션 서버는 사용하지 않았다.
- 임시 프로젝트에 `addons/webrtc`를 포함하고 `--headless --import` 후 실행했다. 기존 `tools/run.sh ui` 사본은 addons를 복사하지 않으므로 그 실행만으로 실제 멀티 연결을 검증할 수 없다.
- 리비전은 `e25b6ea`에 당시 작업 트리 변경을 더한 상태다. [coop-source-manifest.json](coop-source-manifest.json), [vs-source-manifest.json](vs-source-manifest.json)은 최종 성공한 두 모드의 정확한 파일별 해시다. 한 소스 스냅샷으로 모든 참가자를 만들었다.

## 실제 연결 결과

| 역할 | 결과 |
|---|---|
| 연결 호스트 | `MPCONN ok host ping=6ms`, 종료 0 |
| 연결 참가자 | `MPCONN ok join ping=5ms`, 종료 0 |
| 협동 호스트·참가자 | 양쪽 `MPUX coop … failures=0`, 종료 0 |
| 대결 호스트·참가자 | 양쪽 `MPUX vs … failures=0`, 종료 0 |

[connection-host.log](connection-host.log), [connection-join.log](connection-join.log), [coop-host.log](coop-host.log), [coop-join.log](coop-join.log), [vs-host.log](vs-host.log), [vs-join.log](vs-join.log).

최종 실행은 네 참가자 모두 `failures=0`, `ui_messages=0`이었다. 이는 아래 경로와 화면의 결과이며 인터넷·실기기·모든 멀티 상태의 통과를 의미하지 않는다.

## 실제 게임에서 수행한 경로

1. 초기 소개를 실제 버튼으로 닫고 로컬 방을 생성·참가했다. 실제 연결된 peer id는 호스트 1, 참가자 2였다.
2. 호스트가 현재 제품의 `_mp_start()`를 실행했다. 이후 실제 카드 선택지에서 카드 클릭→빈 위치 클릭으로 각자 설치했다. 카드나 오브젝트 상태를 주입하지 않았다.
3. 협동 참가자의 실제 다음 속성 카드 종류를 테스트 조정 패킷으로 알렸다. 이 패킷은 행동 순서만 조정하며 게임 상태를 쓰지 않는다.
4. 호스트가 화면의 `속성 요청`→자기 오브젝트→실제 속성 팝업 버튼을 클릭했다. 참가자가 생산 코드의 tower 상태 전송으로 그 요청을 수신했다.
5. 참가자가 호스트 오브젝트를 실제로 드래그했다. 좌표는 보존됐다. 이어서 요청한 실제 카드→원격 오브젝트 클릭으로 선물을 보냈다. 보낸 사람 선택은 1회 소모, 받은 사람 선택은 유지됐다. 호스트는 생산 코드의 gift 수신으로 속성 레벨이 증가하고 요청이 해제됐다.
6. 호스트만 준비했을 때 웨이브는 시작하지 않았다. 호스트 화면은 대기 인원수, 상태 줄은 상대 이름과 선택 대기 시간을 표시했다. 같은 버튼으로 호스트 준비를 취소하자 `true→false`, 참가자 대기 타이머도 해제됐다. 참가자도 준비→취소를 실제 클릭해 `ready=false, wait_left=-1, wait_show=-1`을 확인했다. 이후 다시 양쪽 준비를 마치자 W1로 전환했다.
7. 참가자에서 기존 끊김 시험 방식 `Mp._fail("로컬 연결 중단 시험")`으로 실제 연결을 닫았다. 기존 자동 재접속이 로컬 중개·WebRTC를 다시 연결하고 W1·소유 오브젝트 1개를 복원했다. 호스트도 같은 참가자의 복귀를 수신했다.
8. 대결은 각각 실제 카드 두 장을 설치하고 시작했다. 두 참가자의 W1 진입각이 동일했다. 참가자 연결을 닫자 참가자는 GAMEOVER, 호스트는 상대 `alive=false, gone=true` 및 탈락 알림을 표시했다. 대결에서 재접속을 보장한다고 해석하지 않는다.

스크린샷: [권한 거절 후 정보](coop-join/peer-permission.png), [요청 설정](coop-host/request-set.png), [실제 선물 수신](coop-host/gift-received.png), [협동 준비 대기](coop-host/waiting-for-participant.png), [참가자 재접속 중](coop-join/reconnecting.png), [복원 후](coop-join/recovered.png), [대결 연결 중단](vs-join/vs-disconnect.png).

## 발견 후 수정·재검증한 사용성 항목

### 준비 취소 경로

초기 실행에서는 협동 준비 후 같은 버튼을 다시 클릭해도 `before=true, after=true`였고 준비 취소 경로가 없었다. root가 준비 bool 전송·취소 처리·대기 타이머 해제를 추가했다. 최종 `ready-second-click`은 `before=true, after=false`, 버튼은 `준비 완료`다. 참가자의 true→false와 타이머 해제 후 재준비·W1 전환도 통과했다. [실제 캡처](coop-host/ready-second-click.png).

위치: [`_mp_coop_ready`](../../../../scripts/features/multiplayer.gd#L667), ready·wait_cancel 패킷 처리. 인원수뿐 아니라 양쪽 대기·자동 선택 타이머가 해제되는지 실제 통신으로 검증했다.

### 읽을 수 있으나 수정할 수 없는 오브젝트의 설명

초기 실행에서 친구 오브젝트 드래그는 안전하게 거절됐지만 이유 알림과 인스펙터의 소유자·수정 권한 문구가 없었다. root가 정보창의 간단히·전체 정보에 소유자와 편집 권한을 넣었다. 최종 실제 친구 선택 화면에서 `로컬 호스트`·`소유자만` 문구를 확인하고 드래그 좌표 보존도 다시 검증했다.

위치: [`_begin_press`](../../../../scripts/features/interaction.gd), [`_select_tower`](../../../../scripts/features/interaction.gd), [`CardDock._update_side`](../../../../scripts/card_dock.gd), [기존 소유자 고리·이름](../../../../scripts/tower.gd#L2569).

### 신규 저장 상태 버튼 겹침

초기 WAVE에서 `저장 상태` 버튼 `[12,672 120×36]`과 버전 라벨 `[16,698 114×17]`이 겹쳤다. root의 배치 수정 뒤 실제 사각형 비겹침 단언과 협동·재접속·대결 캡처 모두 UI 경고 0이었다.

## 재실행

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/multiplayer/run_native.py
# 협동만
MP_QA_MODES=coop python3 docs/qa/2026-11-09-battlefield-fixes/multiplayer/run_native.py
```

실행기는 실제 로컬 리스너 준비를 확인한 뒤 참가자를 켜며 각 프로세스는 145초 제한을 둔다. 완료·실패 모두 프로세스를 종료하고 TemporaryDirectory의 소스 사본을 정리한다. 캡처·로그·격리 BinduTools 저장 기록은 증거로 남으며 개인 Bindu 저장을 바꾸지 않는다.

초기 도구 시도는 소개 모달을 닫지 않았고 레이아웃 안정화 전에 클릭해 카드 들기 대기에서 종료했다. 모달의 실제 건너뛰기 버튼과 프레임 안정화를 추가한 뒤 위 경로를 재실행했다. 이는 제품 카드 선택 실패로 분류하지 않았다. 최종 결과 파일이 확인한 경로를 따른다.

ObjectDB 종료 경고는 협동 2개·대결 4개가 남는다. native 확장 로드·연결·요청·동기화 성공과 구분한다. 실제 iOS/Android 두 기기, 인터넷 NAT/TURN, 3~4인, 높은 지연·손실, OS 강제 종료 후 재접속은 검증하지 않았다. 이번 연결 중단은 `Mp._fail`로 유도했으며 실제 네트워크 단절·기기 종료 시험을 대신하지 않는다.

중간 수집에서 진행 중인 CardDock 수정의 이름 중복으로 import가 중단된 적이 있다. 그 시도는 참가자를 시작하지 않고 임시 사본을 정리했다. root 수정 뒤 새 공유 소스 스냅샷으로 양 모드를 다시 실행한 최종 자료만 위 결과에 사용했다.
