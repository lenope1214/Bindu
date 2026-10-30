# 빈두 서버

온라인 패치(JSON 데이터), 새 버전 알림, 리더보드(시즌제), 선택 통계를 한 서버에서 처리합니다.
FastAPI + PostgreSQL, Caddy가 HTTPS 인증서를 자동으로 받습니다.

## 처음 설치

서버로 쓸 컴퓨터(VPS 등)에 Docker가 있어야 합니다. 도메인의 DNS A 레코드를 그 서버로 맞춰 두세요.

```sh
git clone https://github.com/lenope1214/Bindu && cd Bindu/server
./setup.sh https://bindu.example.com     # 비밀값·서명 키·게임 접속 설정 생성 (한 번만)
docker compose up -d --build
```

`setup.sh`가 만드는 것:

| 파일 | 내용 | git |
|---|---|---|
| `server/.env` | 관리자 토큰, DB 비밀번호, 판 기록 HMAC 키 | 올리지 않음 |
| `server/keys/patch_private.pem` | 패치 서명 개인키. **잃어버리면 이미 배포한 게임이 새 패치를 못 받음** → 따로 백업 | 올리지 않음 |
| `scripts/online_config.gd` | 서버 주소, 공개키, HMAC 키 (게임에 들어감) | 커밋해서 빌드에 넣기 |

이미 있는 `.env`·키는 덮어쓰지 않으니 다시 실행해도 됩니다(주소만 바꿀 때).
`scripts/online_config.gd`의 `SERVER_URL`이 비어 있으면 게임의 온라인 기능은 모두 꺼집니다.

로컬 시험(도메인 없이): `./setup.sh http://localhost:8000` 후 `docker compose up -d --build db api`.

## 관리 페이지

`https://도메인/admin` → 오른쪽 위에 `.env`의 `ADMIN_TOKEN`을 넣고 저장.

- **통계**: 특성·카드별 나온 횟수, 선택률, 고른 판의 평균 도달 웨이브 / 판이 끝났을 때 들어 있던 속성·공격방식·강화·연계의 비율, 평균 레벨, 평균 피해 몫 / 규칙 버전별 평균 웨이브 / 웨이브 분포. 규칙·맵·게임 버전·패치·기간으로 거르고 CSV로 내려받기.
- **패치**: JSON을 붙여 넣고 올리면 서버가 서명해서 배포. 켜기·끄기, 게임 버전 범위, "새 시즌 시작".
- **새 버전**: 플랫폼별 최신 버전과 받는 곳 URL. 게임이 시작 화면에 "새 버전 받기" 버튼을 띄움.
- **판 기록**: 검증에 걸린 기록 보기, 리더보드에서 빼기, 기기 차단.

## 빌드 내려받기 (새 버전 알림)

`server/downloads/`에 빌드 파일을 넣으면 `https://도메인/download/파일이름`으로 받을 수 있습니다.
이름은 `Bindu-windows.zip`, `Bindu-macos.zip`으로 고정해 두고 새 빌드마다 덮어쓰면 됩니다.
관리 페이지 "새 버전" 탭에 플랫폼별 버전과 주소를 적습니다:

| 플랫폼 | 주소 |
|---|---|
| windows | `https://bindu.anon-chat.kr/download/Bindu-windows.zip` |
| macos | `https://bindu.anon-chat.kr/download/Bindu-macos.zip` |
| android | `https://play.google.com/store/apps/details?id=kr.chat.anon.bindu` |
| ios | App Store 등록 후 앱 페이지 주소 |

## 패치 JSON

게임을 켤 때 받아서 **다음 판부터** 적용됩니다(판 도중에 수치가 바뀌지 않음). 오프라인이면 지난번에 받은 패치를 씁니다.
코드가 바뀌는 변경은 패치로 못 하고 새 빌드가 필요합니다(iOS 심사 규정).

```json
{
  "rules": {
    "all": {"orb_hp": 1.05},
    "1": {"max_mod": 4, "hp_growth": 1.06},
    "4": {"orb_mul": 1.3}
  },
  "rules_desc": {"1": "속성 3종 · 강화 종류별 4개 · 11웨이브부터 체력 +6%씩"},
  "perks": {"power": 0.18, "slow": 0.1},
  "perk_desc": {"power": "모든 피해 +18%", "slow": "모든 구체 이동 속도 -10%"},
  "cards": {"elem": 0.42, "pat": 0.25, "mod": 0.23, "link": 0.10, "cata": 0.01, "lv2_base": 0.2, "lv2_wave": 0.02, "lv2_max": 0.5},
  "elem_dmg": {"electric": 0.9, "water": 1.1},
  "pat_dmg": {"laser": 1.15},
  "message": "시즌 2 시작! 전기 하향, 물 상향"
}
```

| 키 | 뜻 (기본값) |
|---|---|
| `rules.all` / `rules."N"` | 규칙 버전 N 값 덮어쓰기. `all`이 먼저, 버전별이 나중. `max_elems`, `max_mod`, `crowd`, `link_range`, `orb_mul`, `tax_step`, `mod_decay`(true/false), `picks`, `hp_growth`, `resist_from`, `sturdy_from`, `orb_hp`(구체 체력 배율 1.0) |
| `rules_desc."N"` | 시작 화면 규칙 설명 |
| `perks` | 특성 수치: `power` 0.15, `haste` 0.12, `reach` 0.12, `core` 3, `reroll` 1, `luck` 0.2, `regen` 1, `slow` 0.08, `harmony` 0.5 |
| `perk_desc` | 특성 카드 설명 (수치를 바꾸면 같이 바꾸기) |
| `cards` | 카드 종류 비율(`elem`·`pat`·`mod`·`link`, 합이 1이 아니어도 됨), 대격변 확률 `cata`, Lv2 확률 `lv2_base + lv2_wave × 웨이브`(최대 `lv2_max`) |
| `elem_dmg` | 속성별 피해 배율. 오브젝트에 넣은 속성마다 곱함. 키: fire wood water electric wind ice earth dark light poison metal |
| `pat_dmg` | 공격방식별 피해 배율. 키: shot spray thorn stream chain gust shard wall vortex laser lob iron |
| `message` | 시작 화면 공지 |

## 리더보드와 시즌

- 리더보드는 **맵 × 규칙 버전 × 시즌**으로 나뉘고, 기기마다 최고 기록 하나만 올라갑니다. 전체·이번 주(7일).
- 판도가 바뀌는 패치는 올릴 때 "새 시즌 시작"을 켭니다. 그 패치를 받기 전의 게임으로 한 판은 시즌 0(리더보드 제외, 통계에는 들어감)이 됩니다.
- 새 빌드로 판도가 바뀌면 패치 탭 아래 "새 빌드로 새 시즌 열기"에 그 게임 버전을 적습니다.
- 지난 시즌 기록은 지우지 않습니다 (`/v1/leaderboard?season=N`).

## 점수 검증

서버가 게임 공식(`app/validate.py`, main.gd의 웨이브 크기·구체 체력·처치 점수를 옮긴 것)으로 넉넉한 상한을 잡아 넘는 기록은 리더보드에서 뺍니다.
웨이브 대비 점수·처치 수 상한, 웨이브 진행 시간 하한, 기기당 20초·IP당 시간당 60판 제한, 판 기록 HMAC 서명.
HMAC 키는 게임 안에 들어 있어 마음먹은 사람은 뚫을 수 있으니, 수상한 기록은 관리 페이지에서 빼고 기기를 차단합니다.
**게임의 웨이브·점수 공식을 바꾸면 `app/validate.py`도 같이 고칩니다.**

## 수집하는 것 (익명)

게임은 판이 끝날 때 한 번 보냅니다: 기기 무작위 id, 닉네임(선택), 플랫폼, 게임 버전, 패치 번호, 맵, 규칙 버전, 웨이브, 점수, 처치, 최고 콤보, 플레이 시간, 고른 특성, 나온 선택지와 고른 것, 마지막 오브젝트 구성과 피해 몫.
IP는 저장하지 않고 소금 친 해시만 둡니다(빈도 제한용). 게임 설정의 "기록 보내기"를 끄면 아무것도 보내지 않습니다. 오프라인이면 30판까지 모아 뒀다 다음에 보냅니다.

## API

| | |
|---|---|
| `GET /v1/boot?game=&platform=&patch=` | 맞는 패치(서명 포함), 새 버전, 지금 시즌 |
| `POST /v1/runs` | 판 기록 (헤더 `X-Bindu-Mac`: 본문 HMAC-SHA256) |
| `GET /v1/leaderboard?map=&rules=&season=&period=all\|week&device=` | 순위 |
| `GET /v1/seasons` | 시즌 목록 |
| `/admin/...` | 관리 (헤더 `Authorization: Bearer ADMIN_TOKEN`) |

## 개발

```sh
cd server
pip install -r requirements-dev.txt
pytest -q
```

게임 쪽 점검(서명·HMAC·패치 적용, 서버 없이): 저장소 루트에서 `godot --headless --path . -s tools/online_check.gd`.

백업: `docker compose exec db pg_dump -U bindu bindu > backup.sql`, 그리고 `server/keys/`.
