# 빈두 서버

온라인 패치(JSON 데이터), 새 버전 알림, 리더보드(시즌제), 선택 통계를 한 서버에서 처리합니다.
FastAPI + PostgreSQL, Caddy가 HTTPS 인증서를 자동으로 받습니다.

## 처음 설치

서버로 쓸 컴퓨터(VPS 등)에 Docker가 있어야 합니다. 도메인의 DNS A 레코드를 그 서버로 맞춰 두세요.

```sh
git clone https://github.com/lenope1214/Bindu && cd Bindu/server
./setup.sh https://bindu.example.com     # 비밀값·서명 키·게임 접속 설정 생성 (한 번만, Windows는 setup.ps1)
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

### 집 PC(Windows) + Cloudflare Tunnel

공유기 포트를 열지 않고, IP가 바뀌어도 동작합니다. PC가 켜져 있어야 접속됩니다.

1. Docker Desktop 설치·실행.
2. 저장소 폴더에서 `powershell -ExecutionPolicy Bypass -File server\setup.ps1 https://bindu.anon-chat.kr -Tunnel`
3. `cd server` 후 `docker compose up -d --build` (Caddy가 80 포트 HTTP로만 받음). 80·8000을 다른 프로그램이 쓰고 있으면 `server/.env`에 `HTTP_PORT=8080`, `API_PORT=8001`처럼 적고 5번의 Service도 그 포트로.
4. Cloudflare 대시보드 → Zero Trust → Networks → Tunnels → Create a tunnel → Cloudflared → 이름 `bindu` → Windows 설치 명령을 관리자 PowerShell에 붙여 넣기.
5. 같은 화면 Public hostname: Subdomain `bindu`, Domain `anon-chat.kr`, Service `HTTP` / `localhost:80`. DNS 레코드는 Cloudflare가 자동으로 만듦.
6. 브라우저에서 `https://bindu.anon-chat.kr/health`가 `{"ok":true}`이면 성공.
7. 만들어진 `scripts/online_config.gd`를 커밋·push하고 게임을 다시 빌드.

로컬 시험(도메인 없이): `./setup.sh http://localhost:8000` 후 `docker compose up -d --build db api`.

### 자동 배포 (집 PC)

main에 `server/` 변경이 올라오면 집 PC가 5분 안에 알아서 다시 띄웁니다.

- 켜기(관리자 PowerShell, 저장소 폴더에서 한 번): `powershell -ExecutionPolicy Bypass -File server\install-autodeploy.ps1`
- 끄기: 같은 명령에 `-Remove`
- 손으로 바로 배포: `powershell -ExecutionPolicy Bypass -File server\deploy.ps1 -Force`
- 기록: `server\deploy.log`

`deploy.ps1`이 하는 일: `git fetch` → `server/`가 바뀌었을 때만 fast-forward 후 `docker compose up -d --build`(이 폴더의 compose 프로젝트만, 다른 프로젝트는 그대로) → `http://127.0.0.1:HTTP_PORT/health`를 90초 확인 → 실패하면 이전 api 이미지로 되돌림(코드 폴더는 새 커밋 그대로, 고친 커밋을 push하면 다시 시도). 이 폴더에 로컬 커밋이나 겹치는 수정이 있으면 건드리지 않고 기록만 남깁니다. Docker Desktop이 켜져 있어야 합니다.

## 관리 페이지

`https://도메인/admin` → 오른쪽 위에 `.env`의 `ADMIN_TOKEN`을 넣고 저장.

- **통계**: 특성·카드별 나온 횟수, 선택률, 고른 판의 평균 도달 웨이브 / 판이 끝났을 때 들어 있던 속성·공격방식·강화·연계의 비율, 평균 레벨, 평균 피해 몫 / 규칙 버전별 평균 웨이브 / 웨이브 분포. 규칙·맵·게임 버전·패치·기간으로 거르고 CSV로 내려받기.
  - 밸런스 표(선택률·구성·피해 출처·규칙·모드와 위 요약 숫자)는 **5웨이브 이상 간 판만** 셉니다. 그 전에 끝난 판은 지우지 않고 "이탈" 표(끝난 웨이브별 판 수·비율·기기 수, 이탈 CSV)로만 봅니다. 기본값은 환경 변수 `STATS_MIN_WAVE`(기본 5), 관리 페이지 "최소 웨이브" 칸이나 API `min_wave`로 그때그때 바꿀 수 있습니다(0이면 모든 판). 웨이브 분포 표는 모든 판.
- **패치**: JSON을 붙여 넣고 올리면 서버가 서명해서 배포. 켜기·끄기, 게임 버전 범위, "새 시즌 시작".
- **새 버전**: 플랫폼별 최신 버전과 받는 곳 URL. 게임이 시작 화면에 "새 버전 받기" 버튼을 띄움. Windows는 게임 안 업데이트(아래).
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

### Windows 게임 안 업데이트

`PUT /admin/releases/windows`에 `sha256`을 안 주면 서버가 그 URL의 zip을 받아 해시·크기를 계산해 저장합니다(못 받으면 422, 이전 값 그대로).
`/v1/boot`는 `latest`에 `sha256`·`size`·`sig`(패치와 같은 키로 `bindu-release|플랫폼|버전|URL|해시|크기`에 서명)를 붙이고,
게임(scripts/updater.gd)은 서명이 맞을 때만 [업데이트] 버튼을 띄워 zip을 받고 해시를 확인한 뒤 안의 exe로 바꿔 끼웁니다.

- URL은 **버전이 든 주소**(`https://github.com/lenope1214/Bindu/releases/download/vX.Y.Z/Bindu-windows.zip`)를 쓰세요. `latest/download`나 `/download/` 덮어쓰기 주소는 서버 등록 전에 파일이 먼저 바뀌면 해시가 안 맞아 업데이트가 실패합니다(게임은 원래 버전 그대로 두고 [직접 받기]로 바꿈).
- `url`을 비우면 지난번 주소를 그대로 쓰고 해시는 다시 계산합니다. zip을 새로 올렸으면 버전을 그대로 두고 다시 PUT하면 해시가 갱신됩니다.
- 서명 호환 점검: `godot --headless --path . -s tools/update_check.gd -- 공개키.pem 서명 zip 해시 크기`

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
| `rules.all` / `rules."N"` | 규칙 버전 N 값 덮어쓰기. `all`이 먼저, 버전별이 나중. `max_elems`, `max_mod`, `crowd_log`(오브젝트 수 보너스 계수 0.10: 피해 x(1 + 값 x ln(오브젝트 수)). 예전 `crowd`는 무시), `pincer_frac`(협공 폭발, 최대 체력 대비 0.10), `orb_mul`, `tax_step`, `mod_decay`(true/false), `picks`, `hp_growth`, `resist_from`, `sturdy_from`, `orb_hp`(구체 체력 배율 1.0), `trait_mul`(형태 성질 1.0), `rx_mul`(새 반응 65개 0.5). 조합 효율 조정(0.5.3, `Rules.TUNE`): `wood_cap`(규칙 1 기본 99=상한 없음), `wind_buff`(0.08), `mod_fix`(강화 보정표 세기 1, 0=끔)(나무 부가효과 최대 레벨 3), `clock_dmg`(시계침 0.9), `vortex_speed`(블랙홀 속도 90)·`vortex_dmg`(날아가는 동안 초당 1.5)·`vortex_end`(붕괴 3.0), `gust_push_lv`(돌풍 미는 힘 최대 레벨 2), `sound_cd`(울림 음파 다시 터지는 간격 1.0초), `sound_pulse`(울림 음파 피해 0.9), `strip_ring`(울림 균열·메아리 물결 울림 0.2), `wall_dmg`(벽 초당 3.0), `prison_iv`(빙결 감옥 5초)·`prison_dmg`(3.0), `styx_dmg`(망자의 강 1.5). 판마다 다른 흐름(0.6.0 시험, `scripts/vary.gd`): `vary_on`(1, 0=끔), `vary_seal_elem`(3)·`vary_seal_pat`(4)·`vary_seal_link`(1), `vary_event_every`(10), `vary_event_k`(0.4, 도파민 x1.5), `vary_adapt_from`(30), `vary_adapt_step`(0.02), `vary_adapt_max`(0.2). 협동 짧은 판(0.7.1): `coop_orb_per`(한 사람당 구체 수 +0.6), `coop_hp_per`(한 사람당 구체 체력 +1.0), `coop_ramp`(웨이브마다 구체 체력 x1.28). 멀티 잠수·대결(다음 버전): `mp_wait`(45초)·`mp_wait_force`(15초)·`mp_afk_after`(2번), `vs_idle`(90초)·`vs_idle_out`(3번), `vs_send3`(0.7)·`vs_send4`(0.5)·`vs_recv_cap`(1.5). 후반 곡선(다음 버전): `hp_late_from`(150)·`hp_growth_late`(1.03), `orb_n_cap_w`(구체 수가 멈추는 웨이브 150, 넘는 몫은 체력으로), `orb_spd_cap_w`(속도가 멈추는 웨이브 450). 후반 구체(다음 버전): `late_blink_from`(100)·`late_armor_from`(175)·`late_heal_from`(250)·`late_phase_from`(350)·`late_devour_from`(500), `late_share`(0.08)·`late_share_step`(10웨이브마다 0.01)·`late_share_max`(0.2), `late_blink_iv`(3.5초)·`late_blink_dist`(90), `late_armor`(구체 체력 대비 0.04)·`late_armor_break`(0.02)·`late_armor_floor`(0.5)·`late_armor_min`(0.3), `late_heal_iv`(2.5초)·`late_heal_r`(120)·`late_heal`(0.06)·`late_heal_max`(웨이브당 4), `late_phase_on`(2.5초)·`late_phase_off`(1.5초)·`late_phase_dmg`(0.3), `late_devour_n`(2)·`late_devour_take`(0.5)·`late_devour_core`(5) |
| `rules` 오브젝트 수치 (0.5.4, `Rules.STAT`) | 같은 `rules.all`/`rules."N"` 안에 넣는다. 값은 배율이 아니라 그 수치 자체(괄호 안이 지금 값). 카드·정보창 설명 글도 이 값으로 바뀜. **공격방식별** `dmg_<id>`(피해 배율 1, 반응 피해 제외)·`spd_<id>`(공격 속도 배율 1, 반응 제외)·`range_<id>`(사거리 배율 1. 관통 연사·파편탄·철구·레이저는 화면 끝까지라 효과 없음, 블랙홀은 날아가는 속도로), id: shot spray thorn stream chain gust shard wall vortex laser lob iron sonic clock wisp path. **레벨·피해**: `lv_dmg`(공격방식 레벨마다 피해 +0.5)·`lv_spd`(공격 속도 +0.2)·`lv_reach`(사거리 +0.1), `dmg_base`(기본 피해 배율 1.43), `dmg_sum`(속성 레벨 합 1마다 피해 +0.35), `shot_range`(직선탄 사거리 400)·`shot_range_lv`(레벨 합마다 +50). **강화**: `multi_dmg`(다중 발사 한 발 0.55)·`multi_decay`(0.15)·`multi_angle`(0.22라디안), `split_ch`(분열 확률 0.12/개)·`split_max`(0.6)·`split_dmg`(파편 피해 0.5), `size_k`(크기 0.12/개)·`size_dmg`(0.04), `rapid_k`(속사 0.1/개), `pierce_hit`(뚫은 탄 피해 0.5)·`pierce_dmg`(탄 아닌 공격 0.06), `bounce_hit`(튕긴 탄 0.4)·`bounce_dmg`(0.04), `homing_k`(유도 휘는 힘 0.8), `dice_mid`·`dice_top`. **속성 부가효과**(레벨마다): `fire_dps` 0.8·`fire_t` 2, `poison_dps` 0.5·`poison_t` 4, `wood_dmg` 0.2, `water_slow` 0.8(낮을수록 느림)·`water_t` 0.8, `elec_ch` 0.3·`elec_dmg` 0.5, `wind_buff` 0.08·`wind_range` 240, `ice_chill` 0.6, `earth_ch` 0.2·`earth_max` 0.7·`earth_t` 0.8, `dark_vuln` 0.3·`dark_t` 2, `light_ch` 0.12·`light_max` 0.6·`light_mul` 2, `metal_dmg` 0.4·`metal_stagger` 4, `sound_t` 3, `time_base` 0.15·`time_lv` 0.05·`time_max` 0.4·`time_t` 2, `soul_t` 3·`soul_base` 0.2·`soul_lv` 0.1·`soul_max` 0.6. **연계**: `reso_k` 0.12·`reso_r` 150, `prism_dmg` 0.2, `pincer_t` 3·`pincer_cd` 1.5(세기는 `pincer_frac`). **발동**: `trig_max` 5, `echo_n` 3·`echo_dmg` 0.8·`echo_cd` 0.5, `van_spd` 2·`van_t` 5·`van_t_add` 2.5, `charge_r` 220·`charge_k` 1(축적 강타 표 배율), `third_k` 1·`third_size` 1.3, `finish_hp` 0.3·`finish_mul` 1.6·`finish_add` 0.3, `answer_r` 220·`answer_cd` 0.6·`answer_dmg` 0.6·`answer_add` 0.15. **별**: `star_r` 220·`star_take` 0.1·`star_lv` 0.03·`star_self` 0.2·`star_pure` 1.5, `planet_take` 0.3·`planet_max` 3·`star_max` 3(별·행성 합친 수), `star_need` 8(웨이브 구체 체력 x)·`star_mul` 3·`star_rx` 0.3. **반응별** `rxd_<반응 id>`(피해 배율 1, 맞혀서 주는 반응 피해. 화상·중독 같은 지속 피해는 `rx_mul`), id는 scripts/elem.gd REACTIONS. 모르는 키·숫자 아닌 값은 무시, 음수는 0. 점검: `tools/patch_keys_check.gd` |
| `rules_desc."N"` | 시작 화면 규칙 설명 |
| `perks` | 특성 수치: `power` 0.15, `haste` 0.12, `reach` 0.12, `core` 3, `reroll` 1, `luck` 0.2, `regen` 1(처음 고른 회복의 웨이브당 체력), `regen_more` 0.5(겹친 회복 하나당, 소수 가능), `slow` 0.08, `harmony` 0.5, `shield` 1·`shield_max` 3·`shield_all` 4(실드), `rampart` 1·`rampart_max` 4·`rampart_push` 140(성벽), `riposte` 0.6(보통 구체 체력 배)·`riposte_more` 0.5·`riposte_r` 160(반격 파동), `overflow` 2(넘친 회복 실드 최대) |
| `perk_desc` | 특성 카드 설명 (수치를 바꾸면 같이 바꾸기) |
| `cards` | 카드 종류 비율(`elem`·`pat`·`mod`·`link`, 합이 1이 아니어도 됨), 대격변 확률 `cata`, Lv2 확률 `lv2_base + lv2_wave × 웨이브`(최대 `lv2_max`) |
| `elem_dmg` | 속성별 피해 배율. 오브젝트에 넣은 속성마다 곱함. 키: fire wood water electric wind ice earth dark light poison metal sound time soul |
| `pat_dmg` | 공격방식별 피해 배율. 키: shot spray thorn stream chain gust shard wall vortex laser lob iron sonic clock wisp |
| `modes` | 모드 점수 배율 (값이 배율 자체, 예 `{"rush": 1.4}`). 키: rush swarm steel glass narrow early angry stroll fort three soft ease. 서버 점수 상한도 같은 값을 씀 (`docs/modes.md`) |
| `garden` | 정원 모드 경제 (값 자체). 키: `dew_kill`(처치 이슬 8) `dew_growth`(웨이브마다 이슬 x1.05) `hp_growth`(9웨이브부터 구체 체력 x1.10) `hp_early`(1웨이브 체력 0.8배 → 12웨이브 1배) `cost_new`(20) `cost_level`(10) `cost_elem`(40) `cost_pat`(100) `cost_mod`(60) `cost_trig`(70) `cost_link`(80) `offline`(꺼 둔 동안 0.5) `stem_per`(줄기 단계마다 일반 판 피해 0.005) `mastery_per`(숙련 단계마다 그 속성 피해 0.006) `hero_xp`(영웅 Lv0→1 경험치 100, 레벨마다 x1.5) `hero_garden`(정원 안 영웅 속성 피해 0.02/Lv) `hero_norm`(일반 판 0.005/Lv) `hero_card_lv`(일반 판 영웅 카드 보장 5) `plant`(키우기형 심기 20, 심은 칸마다 x`plant_mul` 2.2) `grow_base`(키우기 Lv1→2 값 8, 레벨마다 x`grow_mul` 1.12) `hero_disc`(영웅 속성 칸 키우기 0.8배) `next_delay`(단계 사이 0.8초) |
| `message` | 시작 화면 공지 |

## 리더보드와 시즌

- 리더보드는 **맵 × 규칙 버전 × 시즌**으로 나뉘고, 계정마다(계정이 없는 예전 기록은 기기마다) 최고 기록 하나만 올라갑니다. 전체·이번 주(7일).
- 모드: 어렵게 모드만 쓴 판은 배율을 곱한 점수로 같은 리더보드에 오릅니다(점수 상한도 배율만큼 올라감). 쉽게 모드를 하나라도 쓴 판은 통계에는 들어가고 리더보드에서는 빠집니다(`hidden`). 모르는 모드·반대 쌍이 든 판은 검증 실패.
- 판도가 바뀌는 패치는 올릴 때 "새 시즌 시작"을 켭니다. 그 패치를 받기 전의 게임으로 한 판은 시즌 0(리더보드 제외, 통계에는 들어감)이 됩니다.
- 새 빌드로 판도가 바뀌면 패치 탭 아래 "새 빌드로 새 시즌 열기"에 그 게임 버전을 적습니다.
- 지난 시즌 기록은 지우지 않습니다 (`/v1/leaderboard?season=N`).
- 씨앗 나무(정원 모드)를 켠 판은 모드 목록에 `grow`가 붙어 '성장' 리더보드로 따로 갑니다 (`/v1/leaderboard?grow=true`). 안 붙은 판은 '순수'(기본). 정원 판 자체는 올리지 않습니다.

## 점수 검증

서버가 게임 공식(`app/validate.py`, main.gd의 웨이브 크기·구체 체력·처치 점수를 옮긴 것)으로 넉넉한 상한을 잡아 넘는 기록은 리더보드에서 뺍니다.
웨이브 대비 점수·처치 수 상한, 웨이브 진행 시간 하한, 기기당 20초·IP당 시간당 60판 제한, 판 기록 HMAC 서명.
HMAC 키는 게임 안에 들어 있어 마음먹은 사람은 뚫을 수 있으니, 수상한 기록은 관리 페이지에서 빼고 기기를 차단합니다.
**게임의 웨이브·점수 공식을 바꾸면 `app/validate.py`도 같이 고칩니다.**

## 수집하는 것 (익명)

게임은 판이 끝날 때 한 번 보냅니다: 기기 무작위 id, 닉네임(선택), 플랫폼, 게임 버전, 패치 번호, 맵, 규칙 버전, 웨이브, 점수, 처치, 최고 콤보, 플레이 시간, 고른 특성, 나온 선택지와 고른 것, 마지막 오브젝트 구성과 피해 몫.
IP는 저장하지 않고 소금 친 해시만 둡니다(빈도 제한용). 게임 설정의 "기록 보내기"를 끄면 아무것도 보내지 않습니다. 오프라인이면 30판까지 모아 뒀다 다음에 보냅니다.
개인정보처리방침은 `app/privacy.md`이고 `https://도메인/privacy`로 보입니다(Google Play·App Store 등록에 쓰는 주소). **보내는 항목을 바꾸면 이 글과 스토어 데이터 보안 신고도 같이 고칩니다.**

### 진행 중 판 (0.5.1 다음 버전부터)
게임은 판마다 판 번호(`run`)를 만들어 이어하기 저장에 넣고, 5·10·15… 웨이브를 막을 때마다 그때까지의 기록을 `ended: false`로, 게임 오버 때 `ended: true`로 보냅니다. 서버는 같은 기기·판 번호면 한 줄을 고치고(선택·구성·피해 출처 표는 갈아 끼움), 웨이브가 오르지 않은 진행 기록이나 끝난 판에 온 기록은 `ignored`로 버립니다. 기기당 간격(`RUN_MIN_INTERVAL`)·IP당 시간 한도(`RUN_PER_IP_HOUR`)는 새 줄에만 걸립니다. 한 번 검증에 걸린 판은 이후 기록이 정상이어도 무효로 남습니다.
진행 중 판도 리더보드에 지금까지 점수로 오르고(`ended: false`, 게임은 "▶ 진행 중" 표시), 관리 페이지 통계의 "끝난 판만"으로 뺄 수 있습니다. `/v1/boot`가 `snap: true`를 줄 때만 게임이 진행 기록을 보내서, 이 서버로 바꾸기 전에는 지금처럼 게임 오버 때만 보냅니다(outbox에는 판마다 최신 기록 하나만 남김).

## 계정과 진행 저장 (0.5.3)

어느 기기(Windows·Mac·iOS·Android)에서든 같은 진행을 이어 가려고 **계정**과 **로그인 수단**을 나눴습니다 (`app/accounts.py`).

- `accounts`: 플레이어. `identities`: 로그인 수단 (`device` = 기기 id + 비밀값 해시, 나중에 `google`·`apple`). (provider, subject)는 계정 하나에만.
- 게임은 처음 켤 때 기기 비밀값(32바이트, `user://account.cfg`)을 만들고 `POST /v1/auth/device`로 **익명 계정**을 받습니다. 그 기기가 예전에 남긴 판 기록은 이때 계정으로 묶입니다. 같은 기기 id에 다른 비밀값이 오면 403(`device_taken`): 저장 파일을 복사해 온 경우라 게임이 새 기기 id를 만듭니다.
- 토큰: `계정.기기.만료.HMAC`, `AUTH_SECRET`(비면 `ADMIN_TOKEN`에서 만듦)으로 서명, `AUTH_TOKEN_DAYS`(30)일. 키를 바꾸면 게임은 401을 받고 기기 인증으로 다시 받습니다.
- 진행(`saves`, `app/progress.py` 형식 1): 맵별 최고 기록·업적·도감·본 안내·처치/판 수(기기별 칸)·선택(맵·규칙·모드·모양·선호 표시·닉네임). 소리·글자 크기 같은 설정은 기기별이라 넣지 않습니다. **덮어쓰지 않고 합칩니다**: 업적·도감 합집합, 최고 기록 키마다 큰 값, 처치·판 수 기기마다 큰 값, 선택은 늦게 고친 쪽. 순서와 상관없이 결과가 같아서 충돌을 묻지 않습니다. 게임(`scripts/progress.gd`)과 서버가 같은 규칙. **클라우드 진행은 리더보드에 쓰지 않습니다** (리더보드는 검증한 판 기록만).
- 진행 중 판(`run_saves`): 쉬는 시간마다 이어하기 저장(run.cfg 글)을 올립니다. 같은 계정의 다른 기기는 시작 화면에 "다른 기기에서 하던 판 이어하기"가 뜨고(같은 게임 버전만, 그 기기에 하던 판이 없을 때), 가져가면(`claim`) 한 판을 그 기기만 이어 합니다. 원래 기기는 다음에 올릴 때 409를 받고 그 판을 지웁니다. 계정당 5판, 30일.
- 소셜 연결(`POST /v1/auth/link`): 처음 보는 소셜이면 지금 계정에 붙이고, 다른 계정에 이미 붙어 있으면 **지금 계정을 그 계정에 합칩니다**(진행 합치기, 판 기록·진행 중 판·로그인 수단을 옮김, 없어진 계정은 `merged_into`). Google·Apple ID 토큰(RS256)은 공개키(JWKS)로 서명·iss·aud·만료를 확인합니다. `GOOGLE_CLIENT_IDS`·`APPLE_CLIENT_IDS`를 비워 두면 501(`provider_not_configured`). 게임 쪽 로그인 화면은 아직 없습니다.
- 차단: 기기를 차단하면 그 기기가 붙은 계정째로.
- `DELETE /v1/account`: 진행·진행 중 판·로그인 수단을 지우고 판 기록은 이름을 지워 리더보드에서 뺀 채 통계로만 남깁니다 (Apple 심사: 로그인을 넣으면 계정 삭제가 필요).
- 마이그레이션: 새 표는 켤 때 만들고, `runs.account_id`는 빈 값 허용 열로 더합니다. 예전 게임(토큰 없음)은 그대로 기기 기록. 예전 서버 이미지로 되돌려도 새 표·열을 안 쓸 뿐이라 다시 올리면 이어집니다. 올리기 전에 아래 백업을 한 번.

### 업적·도감 수집 (0.5.5)
- 진행에 `tally` 칸 `{기기 id: {키: 수}}`: 게임 `scripts/ach.gd`의 누적 수. `pick:<통계 키>`는 카드·특성을 고른 횟수(도감 수집), `rx_kills`·`boss_kills`는 누적, `max:...`는 한 판 최고값. 기기·키마다 큰 값으로 합치고 게임이 보여 줄 때 기기끼리 더합니다(`max:`는 가장 큰 값). 형식 번호는 그대로 1 (칸만 추가: 예전 게임은 `tally`를 안 보내고, 예전 서버는 버림).
- 지난 기록 채우기: `PUT /v1/save` 때 올린 기기의 `past-<기기 id>` 칸이 없으면 그 기기가 0.5.5 전 버전으로 남긴 판 기록(`picks`)으로 카드 고른 횟수를 한 번 채웁니다 (`accounts.past_picks`).
- 칭호: 진행 `lww.title`(업적 id), 판 기록 `title` → `runs.title` 열(켤 때 ALTER로 더함). 닉네임처럼 바꾸면 지난 기록에도. 리더보드 줄마다 `title`.
- `GET /v1/ach_rates`: 업적 보유율 `{players, rates: {id: 0~1}}`. 계정 진행 중 `STATS_MIN_WAVE`(5) 웨이브 이상 기록이 있는 것만 분모, 10분마다 다시 셉니다.

### 소셜 로그인을 붙일 때 남은 일
1. Google Cloud·Apple Developer에서 클라이언트 id를 만들고 `.env`의 `GOOGLE_CLIENT_IDS`·`APPLE_CLIENT_IDS`에 (쉼표로 여러 개: Android·iOS·웹).
2. 게임: 플랫폼마다 로그인 플러그인(Android Credential Manager, iOS Sign in with Apple, Windows·Mac 브라우저 로그인)으로 ID 토큰을 받아 `POST /v1/auth/link {provider, credential}` → 응답의 토큰을 `Account.take`. 설정에 연결·해제·계정 지우기 버튼.
3. iOS에 Google 로그인을 넣으면 Sign in with Apple도 같이 (App Store 4.8).

## 오류 로그

게임(scripts/errlog.gd, Godot 4.5+ `OS.add_logger`)이 엔진 오류·스크립트 오류·경고·printerr을 백트레이스와 같이 모읍니다. 한 번 켤 때 서로 다른 오류 20개까지, 같은 오류는 횟수만 셉니다. 오류마다 그때의 맵·규칙 버전·모드·웨이브·오브젝트 모양을, 보낼 때 게임 버전·패치·플랫폼·OS·기기 id를 붙입니다. `user://logbox.json`에 쌓았다가 30초마다 보내고, "기록 보내기"를 끄면 보내지 않습니다.
관리 페이지 "오류" 탭에서 같은 오류(종류·엔진 위치·스크립트 첫 줄)끼리 묶어 횟수·기기 수·버전을 보고, 줄을 누르면 최근 기록과 백트레이스가 보입니다. 환경 변수 `LOG_PER_DEVICE_HOUR`·`LOG_PER_IP_HOUR`·`LOG_KEEP_DAYS`로 한도·보관 일수를 바꿉니다.

## API

| | |
|---|---|
| `GET /v1/boot?game=&platform=&patch=` | 맞는 패치(서명 포함), 새 버전, 지금 시즌 |
| `POST /v1/runs` | 판 기록 (헤더 `X-Bindu-Mac`: 본문 HMAC-SHA256). `run`·`ended`가 있으면 같은 판을 한 줄로 고침 |
| `GET /v1/leaderboard?map=&rules=&season=&period=all\|week&device=` | 순위 (토큰이 있으면 "나"는 계정 기준) |
| `GET /v1/ach_rates` | 업적 보유율 (0.5.5) |
| `POST /v1/auth/device` | `{device, secret, nick}` → `{token, expires, account, nick, linked, new}` |
| `GET /v1/me` | 계정·붙은 수단 (헤더 `Authorization: Bearer 토큰`, 아래 모두 같음) |
| `GET`·`PUT /v1/save` | 진행 받기 / `{data}` 올리면 서버 것과 합쳐 `{rev, data}` |
| `GET /v1/save/runs`, `PUT`·`DELETE /v1/save/runs/{run}`, `POST /v1/save/runs/{run}/claim` | 진행 중 판 목록·올리기·지우기·가져오기 (다른 기기가 가진 판은 409) |
| `POST /v1/auth/link`, `DELETE /v1/auth/link/{provider}` | 소셜 연결·해제 (`provider`: google·apple) |
| `DELETE /v1/account` | 계정 지우기 |
| `GET /v1/seasons` | 시즌 목록 |
| `POST /v1/logs` | 게임 오류 (헤더 `X-Bindu-Mac`, 한 번에 20개까지, 기기당 시간당 100줄·IP당 300줄, 30일 보관) |
| `GET /privacy` | 개인정보처리방침 (`app/privacy.md`) |
| `/admin/...` | 관리 (헤더 `Authorization: Bearer ADMIN_TOKEN`) |

## 개발

```sh
cd server
pip install -r requirements-dev.txt
pytest -q
```

게임 쪽 점검(서명·HMAC·패치 적용, 서버 없이): 저장소 루트에서 `godot --headless --path . -s tools/online_check.gd`.

계정·진행 맞추기(로컬 서버 + 두 기기): `AUTH_TEST_PROVIDER=1`로 uvicorn을 띄우고, `SERVER_URL`을 그 주소로 바꾼 사본 두 개(config/name이 달라야 user:// 폴더가 다름)에서 `tools/sync_check.gd`를 `a1` → `b` → `a2` 순서로 (창이 있어야 Net이 켜져서 xvfb-run). 자세한 건 스크립트 머리말.

백업: `docker compose exec db pg_dump -U bindu bindu > backup.sql`, 그리고 `server/keys/`.
