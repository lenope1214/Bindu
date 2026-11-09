# Native 부하·입력 응답·화면 경계 관찰

후속 장판 검토: [선별 후보](zones/README.md)는 동일성57개를 통과했지만 짧음·밀집·이동 fallback에서 느려져 제품 반영을 보류했다. [실제8배속 혼합 계측](zones/native-mix/README.md)에서 선별 이외 적용 비용도 크고, 관찰한 trail은 최대13점이라80점 함수 개선률을 전체 전투에 적용할 수 없었다. 제품 Zone은 그대로다. 후반 전체 지연의 해결 판정은 보류한다.

BF-49·50의 제한된 기계 측정. 실제 고객의 과제 성공률·손가락 조작·중급 폰 성능을 대신하지 않는다. 이 측정 단계에서는 제품 파일을 변경하지 않았다. [측정 도구](../../../../tools/battlefield_load_check.gd)만 추가했다.

## 조건과 측정 의미

- macOS / Apple M4 / Godot 4.7.2 / OpenGL Compatibility. 저장·서버 URL을 분리한 `BinduTools` 임시 프로젝트, no_focus·최소화 native 창의 실제 SubViewport 렌더링이다. headless 측정은 아니다. 실제 화면 제시와 OS 입력 지연은 포함하지 않는다.
- 전장에 오브젝트 16개. 공격방식 15종과 직선탄 1개, 각 3속성(Lv3+2+2)·속사5·다중발사5. 별의 2속성 특례를 피하기 위해 별을 제외한 속성 풀을 사용한다. 실제 규칙의 피해·범위·공격 우선순위는 변경하지 않는다.
- 움직이는 구체 약 300개 유지. 일반·빠른 구체, 기본 속도8, 기본 체력10,000,000. 실제 처치로 생기는 효과나 모든 후반 종류를 포괄하는 최악 부하는 아니다. 중앙 체력99,999는 측정 중 게임 오버를 피하기 위한 fixture다.
- 1·4·8배속 각각 `fx_low` 끔/켬, 조건마다 동일 seed9009와 새 부하 상태. 시뮬레이션은 프레임마다 고정1/60초, 30프레임 준비 뒤180프레임 측정한다. FPS 제한·VSync는 끈다. 비교 조건 사이 잔여 탄·효과를 정리한다. 측정구간의 게임시간은 각각3·12·24초이며 준비구간은 별도다.
- 실제 플레이는 지연된 프레임의 delta가 달라진다. 이 고정 delta·강제 draw 표를 실시간 플레이 FPS나 체감 속도로 환산하지 않는다.
- `forced_render_interval_ms`: 연속 `RenderingServer.force_draw()` 반환 사이 실제 시간. 최소화 창은 자동 draw를 보장하지 않으므로 매 표본 명시적으로 native SubViewport를 그린다. 정지/재개 프로브의 추가 프레임은 제외한다.
- `simulation_to_force_draw_return_ms`: 시뮬레이션 시작부터 해당 강제 draw 반환까지 실제 시간. GPU 완료나 표시장치에 픽셀이 도착했다는 뜻은 아니다.
- `main_frame_cpu_ms`: `main.frame_system._process(1/60)` 호출에 걸린 시간. 실제 시뮬레이션과 공통 UI 계산을 포함한다. 순수 물리·AI 비용만 분리한 값은 아니다.
- `viewport_render_cpu_ms`·`viewport_render_gpu_ms`: Godot 렌더러가 노출한 Viewport 타이머. `nonzero_samples=0`이면 해당 측정 경로에서 시간값이 제공되지 않은 것으로 취급하며 GPU 작업이0이라고 해석하지 않는다.
- 매60프레임 한 번, 프레임 사이에 가상 `P`를 주입해 정지 상태·메뉴 표시를 확인한다. `dispatch_to_state_ms`는 가상 입력 동기 처리 시간, `dispatch_to_force_draw_return_ms`는 그 입력부터 강제 draw 반환까지다. 긴 시뮬레이션 도중 도착한 입력의 대기시간·물리 키/터치→OS→실제 화면 지연은 포함하지 않는다.

각 `measurements.json`에 실제 임시 사본의 제품 소스 전체·도구 SHA-256, 해상도·논리 크기·배율·엔진·렌더러·관찰값을 기록한다. 리비전은 출발점이며, 변경 중인 작업 트리이므로 **실제 소스 식별은 파일 해시**를 사용한다. 프로필별 해시가 다르면 동일 소스 전후 비교로 취급하지 않는다.

## 최초 current 측정

[`native-pc/measurements.json`](native-pc/measurements.json): profiler 끔, 6조건×180=1,080표본, 가상 정지18/18, exit0·검사실패0·UI0. `frame_interval_ms`·`frame_sim_to_render_ms`·`dispatch_to_frame_post_draw_ms`라는 초기 필드명은 위 강제 draw 반환의 의미다. 자동 `frame_post_draw`를 기다리던 첫 시도는 최소화 창에서 진행하지 않아 종료했으며 결과에 넣지 않았다. [진단](minimized-await-diagnosis.txt).

| 배속·효과 줄이기 | 강제 draw 간격 평균 / p95 ms | main CPU 평균 ms | renderer CPU 평균 ms |
| --- | ---: | ---: | ---: |
| 1·끔 | 58.29 / 68.60 | 25.06 | 17.19 |
| 1·켬 | 58.59 / 69.22 | 25.27 | 17.24 |
| 4·끔 | 167.98 / 190.81 | 101.63 | 30.17 |
| 4·켬 | 164.63 / 182.96 | 100.14 | 29.61 |
| 8·끔 | 326.34 / 376.80 | 214.82 | 48.80 |
| 8·켬 | 363.47 / 471.78 | 256.21 | 47.02 |

이 부하에서 긴 CPU 프레임을 관찰했다. `fx_low`만으로 개선된다는 증거는 없다. 실행순서가 고정된 한 번의 측정이라 온도·시간 경과 영향과 제품 변경 효과를 분리하지 못한다. GPU 타이머는 모든 표본0이므로 사용할 수 없다.

## baseline/current 동조건 비교

양쪽 native exit0·각6조건×180=1,080표본·가상 정지18/18·검사실패0·UI0. 준비30프레임/조건은 표본에서 제외했다. baseline 실행4분14초, current 실행시간은 `run.json`에 기록했다. 양쪽 동일 harness SHA-256 `a3eafad64e19ca5c41dd0681cda43fda2954cddad51821ea2992af9d3a49653b`다. [기계 판독 비교](comparison.json), [baseline 원본](baseline-profiled/measurements.json), [current 원본](current-profiled/measurements.json).

| 배속·효과 줄이기 | 간격 평균 baseline / current ms | 간격 p95 baseline / current ms | main CPU baseline / current ms | renderer CPU baseline / current ms |
| --- | ---: | ---: | ---: | ---: |
| x1-fx-full | 57.60 / 59.06 | 67.89 / 70.56 | 24.73 / 25.09 | 17.08 / 17.43 |
| x1-fx-reduced | 58.19 / 58.92 | 69.28 / 69.02 | 24.94 / 24.91 | 17.32 / 17.52 |
| x4-fx-full | 167.40 / 177.46 | 185.23 / 219.62 | 103.18 / 110.35 | 29.49 / 30.55 |
| x4-fx-reduced | 167.77 / 166.70 | 190.81 / 187.34 | 104.67 / 100.33 | 29.31 / 30.38 |
| x8-fx-full | 383.78 / 352.35 | 513.70 / 417.72 | 268.99 / 244.00 | 50.15 / 47.22 |
| x8-fx-reduced | 319.43 / 313.36 | 376.34 / 423.46 | 216.56 / 212.22 | 45.76 / 44.33 |

배속별 두 효과 조건 중 **main CPU 대부분은 공격과 장판**이었다. current 8배속·효과 줄이기 끔에서 공격135.67ms, 장판71.01ms, 이동20.08ms, 발사체12.18ms, 목록·격자1.97ms, `UI·효과`1.18ms/표본이다. `UI·효과`는 frame 내부에서 타이머가 시작된 이후 구간이며 모든 UI/draw/GPU 비용을 포괄하지 않는다. profiler만으로 `_guard_pick` 개별 비용을 확정할 수 없다.

이는 이미 baseline에도 있던 큰 후반 CPU 비용을 보여준다. 단일 순차 실행, 열 상태, native draw의 전역 RNG 소비가 섞이므로 수 퍼센트 차이를 제품 회귀/개선이라고 단정하지 않는다. 같은 seed라도 실제 탄·장판 평균이 소폭 다르며 각 원본에 기록했다. 피해·사거리·공격 순서·시뮬레이션 조각 수·1/60초는 낮추지 않았다. 이번 단계에서 제품 성능 최적화는 하지 않았다.

이 본측정 이후 별도 단계에서 `Tower._guard_pick`만 최적화했다. 교체 전 참조와의 대상/RNG differential, 함수 CPU, 후속 native 관찰은 [targeting 증거](targeting/README.md)로 구분한다. 위 current 수치를 해당 최적화 이후 결과로 읽으면 안 된다.

가상 입력의 상태 전환 최댓값은 baseline0.202ms/current0.250ms, 강제 draw 반환까지는26.435/24.869ms였다. 프레임 사이 동기 dispatch만 측정했으므로, 앞의 수십~수백 ms CPU 프레임에 막힌 실사용자 입력 대기를 포함하지 않는다. **실사용 입력 지연이 이 수치라는 주장은 하지 않는다.**

양쪽 GPU 타이머1,080표본 모두0이어서 GPU 시간은 미제공이다. native 로그에 입력 이벤트 재사용 경고1종과 종료 시 ObjectDB2개 경고가 남았고 `SCRIPT ERROR`/`ERROR:`는0이다. 장시간 반복 플레이 메모리 누수는 이 검사로 판정하지 않았다.

baseline은 `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9`의 `git archive`다. 새 도구가 읽는 `Meta.skill_aim_slow=false` 선언만 baseline 임시 사본에 추가했으며 baseline 게임 코드는 이 값을 사용하지 않는다. current는 실행 시작 시 작업 트리 사본이다. 실제 GDScript 파일 해시는 각 원본, 차이26개는 `comparison.json`에 있다. Tower/Zone/Orb/Projectile 소스는 양쪽 동일하고 Combat 차이는 누수 안내 문구다. [`scene-manifest.json`](scene-manifest.json)은 변경 없는 main.tscn도 대조한다. current 입력 소스는 `471a20dcd45ed02d5256262ec20642a9886f3f197ef26cec1a6f81f3ccaef70d`다.

## 화면 경계 관찰

각 프로필5상태(선택·정보창·카드 접힘·대기·전투), native 렌더·검사 exit0. 아래 UI 개수는 **초기** overlap 탐지 건수이며 사용자 성공률이 아니다. 루트가 후속 레이아웃을 고치는 동안 얻은 스냅샷으로 보존한다.

| 프로필 | 물리 / 논리 크기 | UI overlap | 관찰 |
| --- | --- | ---: | --- |
| PC70 | 1280×720 / 1280×720 | 0 | 해당5상태 탐지없음 |
| PC85 | 1280×720 / 1280×720 | 0 | 해당5상태 탐지없음 |
| PC115 | 1280×720 / 1280×720 | 1 | 선택 헤더와 펼친 DPS |
| PC130 | 1280×720 / 1280×720 | 0 | 해당5상태 탐지없음 |
| 태블릿130 | 2048×1536 / 1280×960 | 3 | 선택 헤더·DPS, 대기 편집버튼·시작, 시작·DPS |
| 폰130 | 2556×1179 / 1560.916×720 | 3 | 인스펙터와 하단 카드 헤더 제어 |

캡처·로그·실제 해시는 각 `layout-*` 디렉터리/동명 로그에 있다. 겹침 좌표와 캡처를 root에 전달한 뒤 root가 공통 레이아웃을 수정했다. 후속 [최종 매트릭스](../integration-layout/results.json)는 PC70/85/100/115/130·태블릿130·폰130, 7프로필×5=35상태 모두 exit0·단언0·UI0이다. 해당 JSON과 각 프로필 원본을 재확인했다. 물리 태블릿/폰에서 손가락 도달성·텍스트 판독·세이프영역·프레임 제시 검증은 남는다.

## 재실행

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/performance/run_comparison.py --source baseline --output /tmp/bindu-baseline-profiled
python3 docs/qa/2026-11-09-battlefield-fixes/performance/run_comparison.py --source current --output /tmp/bindu-current-profiled
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_load_check.gd /tmp/bindu-native-load 1.0 pc load 180
RESOLUTION=2048x1536 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_load_check.gd /tmp/bindu-tablet-layout 1.3 tablet layout
RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_load_check.gd /tmp/bindu-phone-layout 1.3 phone layout
```

비교 current 사본 이후 root가 카드 선택/멀티 자동선택 guard를 추가 수정했다. 해당 UI 경계 변경은 이 직접전투 fixture의 측정 소스에 포함되지 않으며 최종 통합 QA 대상이다.

비교 driver는 `git archive`/작업 트리를 별도 임시 프로젝트로 복사하고 고유 `user://` 이름·빈 서버 URL·Dummy 오디오로 실행한다. native 종료 후 임시 프로젝트와 해당 고유 저장 폴더를 지우며 `run.json`에 명령·종료코드·정리 결과를 남긴다. baseline/current는 순차 실행했다. 각 실행의 `concurrency.txt`는 표본 수집 중 Godot 프로세스 한 개를 확인한 기록이다.

PC 화면 검사는 두 번째 인자로0.7·0.85·1.15·1.3을 지정한다. 레이아웃은 카드 선택·대상 정보·접힌 카드·대기·전투5상태다. 큰 점수·많은 오브젝트·펼친 DPS 표를 의도적으로 사용한 경계 사례이며 평소 화면의 사용 빈도는 추정하지 않는다.
