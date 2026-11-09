# Rebase 충돌 해결

- main `8704b78688ee9be638e0ddd24eb91d54f3f56194`로 local main을 fast-forward pull한 뒤 feature의5개 작업 커밋을 재생했다.
- `frame.gd`: 최신 main의 결과 화면 HUD/설정 숨김을 유지하고, 전투 중에는 접힘과 독립된 정지 버튼을 유지했다.
- `run_flow.gd`: 재시작할 때 결과 상세 닫기·협동 round 닫기·편집 이력 폐기를 모두 수행한다. 두 번의 재생에서 같은 문맥 충돌을 해결했다.
- `features.md`: SAVE-08과 최신 RES-01/RES-02를 모두 유지했다. 기능 수는 검사 실행에서252개로 확인했다.
- `project.godot`, export 설정, Android build 명령, patch note 데이터는 main과 차이가 없다. 버전·빌드 번호를 새로 올리지 않았다.
- backup ref와 출발 SHA는 `rebase-before.json`에 있다. 원격 feature는 이력 재작성 전 존재하지 않았다.
