# CHANGELOG 작성 규칙

`CHANGELOG.md`는 개발 기록이 아니라 **게임 안 패치노트 원본**이다. 모든 `## ` 절(버전 있는 것·없는 것 모두)이 그대로 플레이어 화면에 나오고, 배포된 게임도 GitHub main의 최신 CHANGELOG를 받아 보여 준다. 그래서 main에 push하는 순간 이미 배포된 게임에도 보인다고 생각하고 쓴다.

## 쓰는 것

- 플레이어가 게임에서 보고 느끼는 변화만: 무엇이 어떻게 바뀌었는지, 숫자 변화(`A → B`), 왜 바꿨는지 한 줄.
- 플레이어가 아는 이름만: 화면에 나오는 카드·속성·공격방식·모드·버튼 이름.
- 측정 줄은 결과 숫자만 짧게 (예: "20웨이브 측정: 보스가 3초 → 11초 버팀").

## 쓰지 않는 것

| 금지 | 예 | 대신 |
|---|---|---|
| 온라인 패치 키 | `(패치 키 rules.planet_take·planet_lv)`, `perks.coin`, `map_*` | 쓰지 않는다. 키 목록은 `server/README.md`·커밋 메시지에 |
| 코드 이름 | `wave_size`, `HP_GROWTH`, `Rules.rx_mul`, `Orb.last_rx`, `Pat.MOD_FIX` | 화면에 보이는 이름이나 풀어 쓴 말 |
| 파일·폴더·도구 | `scripts/sfx.gd`, `tools/combo_eff.gd`, `docs/modes.md`, `run.sh` | 쓰지 않는다 (점검 도구 설명은 `tools/README.md`) |
| 서버 내부 | `/v1/vote`, `/admin`, `?grow=true`, 표·열 이름 | "투표를 받지 않는 서버에서는…"처럼 플레이어가 보는 결과만 |
| 커밋 해시 | `b0b99d9` | 쓰지 않는다 |
| 요청·제보 인용 | `(사용자 요청 "…")`, `(제보 "…")`, `(사용자 선택 A)`, `(결정 "…")` | 빼고 변화만 쓴다. 경위는 커밋 메시지·프로젝트 기록에 |
| 코드 표시 | 백틱 `` ` `` | 따옴표나 그냥 글 |
| 개발 과정 | "점검 도구: …", "코드: …", "서버 재배포는 안 함" | 쓰지 않는다 |

## 검사

`python3 tools/notes_check.py`(또는 `tools/run.sh notes`)가 위 금지 패턴을 찾는다. `tools/run.sh check`(배포 전 점검)에 들어 있어 하나라도 걸리면 배포 전 점검이 실패한다. CHANGELOG를 고친 커밋에서는 push 전에 이것만이라도 돌린다 (Godot 없이 몇 초).

CHANGELOG를 고친 뒤에는 `tools/gen_patch_notes.gd`로 `scripts/patch_notes_data.gd`(게임에 든 노트)도 다시 만든다.
