# 멀티플레이 방 코드 중개 (Cloudflare Worker)

게임끼리는 WebRTC로 직접 이어지고, 이 Worker는 처음 만날 때만 쓴다: 방 코드를 만들고, 들어온 사람을 알리고, 연결 정보(SDP·ICE)를 넘겨 주고, 중계(TURN) 접속 정보를 내려 준다. 판이 시작되면 게임은 이 Worker와 연결을 끊는다. 무료 플랜(Workers + SQLite Durable Object)으로 돈다.

## 처음 한 번 배포

1. Cloudflare 대시보드 → **Realtime → TURN Server** → Create. 나온 **Turn Token ID**와 **API Token**을 적어 둔다 (저장소·메모에 넣지 않는다).
2. 이 폴더에서:
   ```sh
   npx wrangler login
   npx wrangler secret put TURN_KEY_ID      # Turn Token ID
   npx wrangler secret put TURN_KEY_TOKEN   # API Token
   npx wrangler deploy
   ```
   끝에 나오는 `https://bindu-mp.<계정>.workers.dev` 가 주소다. TURN 키를 안 넣으면 STUN만 내려 줘서, 엄격한 NAT(일부 회사·학교·통신사 망)끼리는 연결이 안 될 수 있다.
3. (선택) 대시보드 → Workers → bindu-mp → Settings → Domains & Routes에서 `mp.anon-chat.kr` 같은 도메인을 붙인다.
4. `curl https://<주소>/health` 가 `ok`면 된 것.
5. `scripts/online_config.gd`의 `MP_URL`에 주소를 넣고 빌드한다. 비어 있으면 게임에 멀티플레이 버튼이 안 보인다.

## 고치고 다시 배포

`npx wrangler deploy`. 진행 중인 판은 이미 WebRTC로 이어져 있어 영향이 없고, 대기 중인 방만 끊긴다.

## 멀티플레이 끄기·숨기기 (스위치)

대시보드 → Workers & Pages → bindu-mp → Settings → **Variables and Secrets** → Add → 이름 `MP_OFF`, 형식 Text → Deploy. 몇 초 안에 반영된다.

- `hide`: 게임이 멀티플레이 버튼을 숨긴다 (시작 화면을 열 때·멀티플레이 창을 열 때 확인).
- 다른 글(예: `연결 문제를 고치는 중이에요`): 버튼은 두고, 누르면 그 글을 보여 주며 막는다.
- 지우면(또는 빈 값) 다시 켜진다.
- 어느 쪽이든 Worker가 새 방 만들기·참가를 거절한다(0.6.0처럼 스위치를 모르는 게임도 막힘). 이미 시작한 판은 WebRTC로 이어져 있어 끝까지 간다.
- `wrangler.toml`의 `keep_vars = true` 때문에 `wrangler deploy`가 이 변수를 지우지 않는다.
- 명령으로: `echo hide | npx wrangler secret put MP_OFF` (끄기) / `npx wrangler secret delete MP_OFF` (켜기). 비밀 값으로 넣어도 똑같이 읽는다.

## 로그

`wrangler.toml`의 `[observability]`로 대시보드 → bindu-mp → **Logs**에 3일 남는다: 방 만들기(`host`)·참가(`join`, 이름은 `플랫폼 글자|닉네임`)·거절(`err`)·게임이 보낸 연결 실패 진단(`client`). 실시간은 `npx wrangler tail`.
게임 쪽 연결 부품 읽기 실패·연결 실패 진단은 printerr라 집 PC 서버 관리 페이지 "오류" 탭에도 모인다(`MP webrtc 확장`, `MP 연결 실패`).

## 로컬 시험

- `npx wrangler dev --port 8791` 후 게임을 `BINDU_MP_URL=http://127.0.0.1:8791` 로 띄운다.
- Worker 없이: `godot --headless -s tools/mp_signal.gd -- 8790` (같은 약속으로 도는 GDScript 서버).

## 약속 (WebSocket `/ws`, JSON)

- 접속: `/ws?op=host&mode=vs|coop&v=<게임 버전>&name=<이름>` 또는 `/ws?op=join&code=<6자리>&v=..&name=..`
- `GET /status` → `{on, hide, msg}` (스위치)
- 서버 → 게임: `room`(code, id, mode, ice, peers) · `join`(id, name) · `leave`(id) · `sig`(from, d) · `closed`(호스트가 나감) · `err`(code: nocode/full/version/started/off, off면 msg)
- 게임 → 서버: `sig`(to, d) · `lock`(호스트만, 판 시작 = 더 못 들어옴) · `log`(msg, 연결 실패 진단)
- 이름은 `플랫폼 글자|닉네임` (w·m·i·a·l, 닉네임 12자)
- 협동 재접속: `room`에 `tok`(자리 표)을 준다. 잠긴(시작한) 협동 방도 `/ws?op=join&code=..&tok=..`이면 원래 id로 들이고, 아직 안 닫힌 예전 연결은 조용히 닫는다. 대결은 다시 못 들어온다.
- 방은 최대 4명, 대기 중 1시간·시작한 방 6시간이 지나면 지운다. 버전이 호스트와 다르면 못 들어온다.
