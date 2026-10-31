# 빈두 작업 규칙

- 모든 기능의 기대 동작은 `docs/features.md`에 한 줄씩 있고, 줄마다 검사(spec·path·fuzz·cont·shot 등)가 짝지어져 있다.
- 기능을 추가·변경·삭제하면 **같은 커밋에서** `docs/features.md`의 그 줄과 `tools/spec_check.gd`의 같은 id 검사를 고친다. 문서의 spec 줄을 확인하지 않거나 문서에 없는 id를 확인하면 `tools/run.sh spec`이 실패한다.
- 새 기능은 되도록 spec(자동)으로 확인할 수 있게 쓰고, 손맛·화면 배치처럼 자동으로 보기 어려운 것만 shot·수동으로 둔다.
- 배포 전: `GODOT=<godot> tools/run.sh check`가 `CHECK 통과`이고, `tools/shot.gd` 스크린샷(글자 1.0·1.3, touch)에 겹침·잘림·글 깨짐이 없을 때 배포한다.
- 점검 도구 설명은 `tools/README.md`.
