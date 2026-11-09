# 협동 거래 통합 뒤 일반 조작 회귀

16묶음(PC/폰 × core·input·undo·flow·lifecycle·information·carry·first-play), 680단언·실패0, 모든 프로세스 exit0·runtime `SCRIPT ERROR`/`ERROR:`0. [집계](results.json), [진행 로그](../final-native-progress.log). 폰 flow는 설정 모달과 뒤 HUD의 의도된 겹침8개를 기록한다. 다른 UI 검사는0이다. 일부 도구의 종료 ObjectDB 경고는 원본 로그에 남아 있다.

실제 거래 서비스·멀티 연결·Mp 송신 guard·CardDock pending 비활성화 수정 이후 실행했다. 단, 전체 배치 시작 때 파일 목록을 한 번 기록하고 각 tools/run.sh 호출이 따로 사본을 만들었다. 배치 도중 `field_view.gd`의 **협동 pending 전용 표시**가 수정되어, 각 사본의 이 파일 해시를 모두 확정할 수 없다. manifest의 `batch_start_source_hashes`는 배치 시작 목록이며 각 실행의 완전한 고정 snapshot이라고 주장하지 않는다. 이후 toast 배치도 추가 수정됐다.

마지막 UI 소스는 고정 사본의 [35장면·core2 재검사](../final-layout/results.json) 및 실제 [협동 PC/폰 pending 후속](../multiplayer/gift/README.md)으로 분리한다. 프로토콜 소스의 고정·3인 경합·유실 후 수렴은 이 일반 조작 검사로 대체하지 않는다.

실행은 Godot4.7.2 native SubViewport·VirtualInput, PC1280×720/100%, 폰2556×1179/130% 모의다. `tools/run.sh ui`가 빈 운영 URL·BinduTools 저장으로 격리하고 실행 뒤 임시 프로젝트를 정리했다. 물리 터치·OS 중단·실제 휴대폰 성능 검증은 아니다.
