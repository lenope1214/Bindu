# BF-49 성능 소스 검토

2026-11-09 작업 트리 읽기 전용 검토. 제품 수정·Godot 실행·벤치마크는 하지 않았다. 아래 순서는 **호출 구조와 예상 중복 작업에 따른 조사 우선순위**다. 프로파일러로 확인한 시간 순위나 개선 효과가 아니다. 실측 조건·결과는 [별도 측정 문서](README.md)를 따른다.

## 비용 경계와 보존 조건

- [`frame._process`](../../../../scripts/features/frame.gd#L270)는 렌더 프레임당 `ceil(game_speed)`회 `_sim_step`을 실행한다. 1·4·8배속에서 각각 1·4·8회다. 조준 감속은 `dt`만 바꾸며 조각 수를 줄이지 않는다. 이 분할과 이동→생성→공격→장판→탄 충돌→처치 순서를 유지해야 한다.
- [`_resolve`](../../../../scripts/features/combat.gd#L250)는 매 조각 구체 목록·격자를 다시 만들고 오브젝트·장판·발사체를 순회한다. 비용 기호는 조각 수 `S`, 자동 조준 오브젝트 수 `A`, 대상 구체 수 `N`, 발사체 수 `P`, 장판 수 `Z`다. 수량은 실제 관측값과 구분한다.
- 화면 UI/레이아웃·`_soften_fx`는 렌더 프레임마다 한 번이다. `_draw` 비용·GPU 비용은 동기 `_process` 타이머와 별도다. 현재 부하 도구의 `main_frame_cpu_ms`는 UI도 포함한다. 내장 `UI·효과` 항목도 예약된 draw 실행 전체나 GPU 시간을 뜻하지 않는다.
- 수량·시뮬레이션 조각·배속·사거리·충돌·효과 적용·입력 판정을 줄이는 방안은 제외했다. 실제 미리보기 전투도 간략한 가짜 애니메이션으로 바꾸지 않는다.

## 우선순위 1 — 자동 조준의 전체 대상 순회·후보 할당

**위치:** [`Tower._guard_pick`](../../../../scripts/tower.gd#L1794), [`_update_aim`](../../../../scripts/tower.gd#L1893), [`reflex_range`](../../../../scripts/tower.gd#L1776).

자동 조준은 매 조각 전체 `targets`를 훑고 `[orb, goal_distance, preferred]` 배열을 후보마다 만든 뒤 다시 순회한다. 첫 순회는 `S×A×N`, 두 번째는 최대 같은 수다. 가정상 `A=16, N=300, S=8`이면 첫 순회 38,400회와 후보 순회 최대 38,400회/렌더 프레임이다. 실제 fixture에는 자동 조준 제외 방식·범위 밖·죽은 구체가 있어 이 수를 실측 호출 수로 쓰면 안 된다.

**최소 변경 후보:** 함수 호출 동안 불변인 `aim_pref`, `aim_band`, 전장 중앙/문 좌표, 오브젝트의 레벨·크기·강화값을 지역값으로 한 번 계산한다. 후보별 중첩 Array는 재사용 버퍼/평행 배열로 바꾼다. 유한 사거리 방식만 현재 `near_t`의 보수적 범위와 원래 `targets` 순서를 이용하는 후보 축소를 따로 검토한다. 전장 끝까지 겨누는 방식에는 축소 이득이 작다.

**무효화·주의:** 위치·방향·온라인 규칙·맵 바람은 조회에 반영해야 한다. 앞 오브젝트 공격의 밀쳐내기로 다음 오브젝트가 보는 구체 위치가 바뀌므로, 구체의 `goal_distance`나 최종 선택을 프레임/조각 전체에 무조건 캐시하면 안 된다. 현재 `aim_band` 기준 최소 거리→방향 선호→거리, 동률의 원래 순서를 그대로 유지한다. `near_t`의 40px 여유와 대형 범위 전체 반환도 유지한다.

**동등성 검증:** 사거리 안/밖 경계, 같은 거리·선호 방향 동률, 회랑/바람 맵, 먼저 맞고 밀린 구체, 죽은 후보, 구형 reflex 강화의 마지막 동률 선택을 포함해 조각마다 대상 instance id·aim·명중 순서를 원본과 대조한다. 고정 seed의 피해·처치·발동·다음 난수 상태도 비교한다.

## 우선순위 2 — 장판 경로의 정적인 격자 셀 재생성

**위치:** [`Zone.path_orbs`](../../../../scripts/zone.gd#L131), [`trail_orbs`](../../../../scripts/zone.gd#L153), [`Combat._resolve`](../../../../scripts/features/combat.gd#L275).

각 경로 장판은 매 조각 `pts`의 모든 점에서 겹치는 셀 Dictionary를 새로 만든다. 이후 trail은 후보마다 모든 점을 다시 검사해 가장 센 `pk`를 찾는다. 점이 유지되는 동안에도 셀 합집합을 반복 생성한다. 핏자국 한 줄의 점 상한은 현재 80개다.

**최소 변경 후보:** 장판마다 점 revision에 연결된 **셀 키 목록만** 캐시한다. 현재 전투 격자의 구체 목록과 실제 점-구체 거리·`orb_k`는 매 조각 다시 읽는다. 다음 단계로 셀별 관련 점 index를 보관해 실제 점 검사 범위를 줄일 수 있다.

**무효화·주의:** `add_pt`, `add_gore_pt`, `_drop_pts`, trail의 직접 slice, radius·GRID 변경, 저장/네트워크 복원 시 셀 캐시를 버린다. pts는 월드 좌표다. 원래 셀 최초 삽입 순서·구체 순서도 보존해야 난수 호출 순서가 같다. `pk`만 바뀌면 셀 키는 재사용할 수 있지만 최대 세기 계산은 갱신해야 한다. 대상 Array 자체를 오래 캐시하면 이동·밀림·새 구체·처치가 누락된다.

**동등성 검증:** 점 추가/만료/80점 절단, 셀 경계·음수 좌표, 서로 겹친 약한/강한 점, 같은 오브젝트의 복수 trail, maker 제외, 점별 쿨다운을 대조한다. `trail_hit`의 조각당 중복 방지·`orb_k`·피해 출처·상태 효과가 같아야 한다. 참조 검사에서 구체 처리 순서까지 비교한다.

## 우선순위 3 — 읽기 UI가 바뀌기 전 상세 계산을 반복함

**위치:** [`CardDock._update_side`](../../../../scripts/card_dock.gd#L750), [`InfoPanel.show_tower`](../../../../scripts/info_panel.gd#L68), [`AttackPreview.configure`](../../../../scripts/attack_preview.gd#L62), [`Hud._refresh_dps`](../../../../scripts/features/hud.gd#L135).

정보창은 프레임마다 카드 전체 설명·모든 대상 비교·미리보기용 동료 build Dictionary 및 문자열 signature를 만든다. `side_signature`는 이 작업 뒤에 검사한다. 공격 예시를 접어도 `show_tower→configure`가 호출되어 동료 build 전체 직렬화와 동일 font override가 실행된다. **접힌 예시의 전투 advance/render는 이미 정지한다**. DPS도 folded/signature 반환 전에 매번 피해 Dictionary·정렬·title을 만든다. 전투 중 정보창을 열었거나 카드를 읽을 때 조사할 비용이며, 아무 정보창 없는 부하 결과의 원인으로 단정하면 안 된다.

**최소 변경 후보:** 숨긴 예시는 source와 dirty 표시만 보관하고 펼칠 때 실제 `configure`한다. font는 실제 객체가 바뀔 때만 override한다. 카드 비교는 카드+오브젝트 build/소유권/요청 revision으로, DPS 값/정렬은 기존 표본 revision으로 캐시한다. 정보창의 build 설명과 매 프레임 변하는 피해 몫·상태는 별도 갱신한다.

**무효화·주의:** 카드 교체·속성/방식/강화·소유권/요청·오브젝트 추가/삭제·undo·load·멀티 수신·전역 규칙/특성·위치/방향/기맥·맵·폰트/배율을 해당 캐시에 반영한다. 숨긴 동안 바뀐 build를 다시 펼쳤을 때 반드시 최신 실제 전투 clone을 만든다. 예시를 펼쳐 둔 상태의 재설정·진행 상태 의미를 바꾸지 않는다. DPS의 패널 이동/높이·키보드 focus·터치 선택은 수치 캐시와 분리한다.

**동등성 검증:** 예시 접힘 중 수정→펼침, pause·resume, 대상 삭제, 카드 비교를 읽던 중 요청 수신/undo, DPS 접기·정렬 변경·스크롤·focus 유지, PC/폰130% 캡처를 비교한다. [`preview_parity_check.gd`](../../../../tools/preview_parity_check.gd)·[`battlefield_information_check.gd`](../../../../tools/battlefield_information_check.gd)는 관련 회귀 검사다. 이 검토에서 실행하지 않았다.

## 우선순위 4 — 반복 조회의 반환 Array·공유 효과 계산

**위치:** [`Combat.near`](../../../../scripts/features/combat.gd#L434), [`Tower.well_spots`](../../../../scripts/tower.gd#L1678), [`_nova_pick`](../../../../scripts/tower.gd#L2353), [`Share.k/aff`](../../../../scripts/share.gd#L102), [`Share.carry/apply`](../../../../scripts/share.gd#L214).

`near`는 호출마다 Array를 만들고, 우물/초신성 후보마다 근처 조회의 `.size()`를 다시 계산한다. Share는 같은 hit에서 여러 번 효과별 k·상성 bitmask를 구한다. 다만 상성 쌍 자체는 이미 `_aff`에 캐시돼 있다. 우선 1·2 결과를 본 뒤 조사한다.

**최소 변경 후보:** `.size()` 전용 조회는 같은 셀 방문·queued 제외 규칙의 `near_count`로 할당만 없앤다. Share는 같은 호출 내 불변인 상성/효과 계수를 지역 context로 넘긴다. 재귀 carry·시간 되풀이가 있어 전역 scratch Array를 공유하면 안 된다.

**무효화·주의:** `near(...).size()`는 정확한 원형 110px 안 개수가 아니라 padding을 포함한 셀 후보 개수다. 이를 실제 원형 거리 개수로 바꾸면 현재 우물 위치 결정이 달라진다. 재사용은 grid generation·조회 범위·queued 상태를 포함해야 한다. Share context는 속성 레벨/강화/패치 revision을 반영하고, 대상의 저항·현재 상태·거리·난수 결과는 캐시하지 않는다. 효과·후보 순서와 난수 소비 수를 보존한다.

**동등성 검증:** 우물 위치/동률, 초신성 표적, 동일 조각의 queued 구체, 재귀/지연 carry, 냉기·묶임·환영 확률·금속 피해와 피해 출처를 대조한다.

## 렌더 경로와 기존 최적화: 오진 금지

- [`_draw_fx`](../../../../scripts/features/field_view.gd#L595)는 활성 선/파동/번개/입자/숫자를 매번 그린다. 숫자는 그림자 포함 두 번, 번개는 세 polyline이다. [`_soften_fx`](../../../../scripts/features/field_view.gd#L511)의 `fx_low`는 주로 알파 조절이다. 효과 수·시뮬레이션·draw 수를 줄이지 않아 켜기만으로 큰 속도 개선을 보장할 수 없다. 동일 형상 배치/불변 geometry 재사용은 renderer CPU가 지배적일 때 후속 후보이며, 효과·가시성을 삭제하는 방안은 제외한다.
- 번개 geometry와 파편/popup은 전역 `randf`를 사용한다. draw/연출 호출을 합치거나 생략하면 전투의 다음 난수까지 바뀔 수 있다. 렌더 최적화도 난수 소비·명중 parity를 검사해야 한다. 프레임 수가 다른 두 실행의 damage만 비교해 동일성을 단정하지 않는다.
- [`Orb._redraw_if_changed`](../../../../scripts/orb.gd#L299)는 이미 프레임당 상태 signature 1회와 상태 변화 시 redraw를 사용한다. 단순 위치 이동만으로 다시 그리지 않는다. Tower body/reaction·조각별 피해 배율 캐시, 공간 격자, 큰 범위 `near_t` 전체 반환도 이미 존재한다. 이들을 새 해결책으로 제안하지 않는다. 여러 `queue_redraw()` 호출 수를 실제 draw 실행 횟수와 혼동하지 않는다.
- [`step_entities`](../../../../scripts/features/combat.gd#L502) 이전의 projectile/zone Array를 `_resolve`까지 무조건 재사용하면 이번 조각의 공격이 생성한 새 탄·장판을 누락한다. 반대로 이동 루프에서 생성한 구체를 즉시 순회하면 원래 snapshot 순서를 바꾼다. registry 전환 시 생성/삭제 경계를 반드시 보존한다.
- `_wind_buffs`는 현재 `winds=[]`라 O(T) 초기화다. 바람 지원 O(T²) 병목으로 분류하면 틀리다. 검토 중 `support_summary`의 기존 “바람 지원 범위 N개”가 비활성 순풍 기능을 암시함을 찾아 root에 보고했다. root가 실제 기능인 “밀쳐내기 역할”로 수정하고 관련 정보 검사 기대값도 고쳤다. 성능 개선과 구분한 사실성 수정이다.

## 다음 실험

같은 소스·seed·fixture에서 1/4/8배속×효과 줄이기 on/off를 비교하고, 프로파일러의 이동/목록·격자/오브젝트 공격/장판/발사체와 native 렌더 시간을 함께 읽는다. 가장 큰 항목 하나의 위 후보만 적용→동등성 검사→동일 native 재측정 순서로 진행한다. 정보창 닫힘/열림·예시 접힘/펼침은 별도 조건이다. 가상 P의 동기 dispatch 시간은 이전 긴 프레임에 막힌 실사용자 입력 대기시간을 포함하지 않는다. 중급 폰 실기기·OS 입력→실제 화면 지연은 별도 증거가 필요하다.
