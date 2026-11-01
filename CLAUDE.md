# 빈두 작업 규칙

- 모든 기능의 기대 동작은 `docs/features.md`에 한 줄씩 있고, 줄마다 검사(spec·path·fuzz·cont·shot 등)가 짝지어져 있다.
- 기능을 추가·변경·삭제하면 **같은 커밋에서** `docs/features.md`의 그 줄과 `tools/spec_check.gd`의 같은 id 검사를 고친다. 문서의 spec 줄을 확인하지 않거나 문서에 없는 id를 확인하면 `tools/run.sh spec`이 실패한다.
- 새 기능은 되도록 spec(자동)으로 확인할 수 있게 쓰고, 손맛·화면 배치처럼 자동으로 보기 어려운 것만 shot·수동으로 둔다.
- 배포 전: `GODOT=<godot> tools/run.sh check`가 `CHECK 통과`이고, `tools/shot.gd` 스크린샷(글자 1.0·1.3, touch)에 겹침·잘림·글 깨짐이 없을 때 배포한다.
- 점검 도구 설명은 `tools/README.md`.
- `CHANGELOG.md`는 게임 안 패치노트로 플레이어에게 그대로 보인다(main push 즉시 배포된 게임에도). 플레이어용 문장만 쓰고 패치 키(`rules.…`)·코드 이름·파일 경로·커밋 해시·요청/제보 인용은 넣지 않는다. 규칙은 `docs/changelog-rules.md`, 검사는 `python3 tools/notes_check.py`(run.sh check에 포함). CHANGELOG를 고친 커밋은 push 전에 이 검사를 돌린다.
