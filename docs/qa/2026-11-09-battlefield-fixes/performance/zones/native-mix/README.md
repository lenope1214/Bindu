# 실제 장판 혼합의 제한된 native 계측

제품 변경 없음. 현재 소스를 고정한 격리 사본에서 Godot4.7.2/macOS/M4 native SubViewport, 16오브젝트·약300구체·8배속·효과 줄이기 끔, 준비30·측정60프레임을 실행했다. 고정 delta1/60초이며 측정 구간의 게임시간은8초다. 실제 휴대폰·OS 입력·표시장치 제시 지연을 포함하지 않는다.

[명령·원본 소스 해시·종료·정리](run.json), [장판별 원자료](zone-breakdown.json), [계측한 클래스 원문](instrumented-zone.txt), [전체 측정](measurements.json), [로그](native.log). native exit0·단언0·UI0·runtime ERROR0, 가상 P 정지1/1 통과. 임시 프로젝트와 고유 저장 삭제를 확인했다. 첫 계측 사본은 들여쓰기 오류로 import에 실패했으며 `../native-mix-before-instrumentation-fix/`에 보존한다. 제품 실패나 성능 표본으로 세지 않는다.

`trail_orbs`, `path_orbs`, `affect`, `step` 원래 본문을 그대로 보관하고 wrapper에서 전후 시간을 잰다. 호출·RNG·반복 순서는 바꾸지 않는다. wrapper 뒤의 점 분포 집계는 개별 함수 타이머 밖이지만 전체 실행에는 비용을 더한다. **계측하지 않은 전후 FPS/개선률 비교 자료가 아니다.** 집계는 준비·fixture 정리/안정화·정지 프로브를 포함한 실행 전체 호출이다. 측정60프레임만의 원인별 시간이라고 읽지 않는다.

| 함수 | 호출 수 | 합계 ms |
|---|---:|---:|
| trail affect | 10,838 | 1,315.935 |
| gore affect | 38,641 | 676.339 |
| trail 선별 | 10,838 | 633.229 |
| vortex affect | 4,344 | 466.465 |
| rill affect | 50,889 | 322.991 |
| gore 후보 조회 | 38,641 | 161.880 |

모든 wrapper 시간 합계는3,815.328ms, 이 중 trail 선별은16.6%다. 장판 전체 프로파일러·공격·렌더·전체 프레임의16.6%라는 뜻은 아니다. 단일 실행의 계측 범위 안에서 선별 외 실제 적용 비용도 크다는 근거다.

trail 선별의 실제 점 분포는 다음과 같다. compact/spread는 점의 bounding box 최대 변 길이가 장판 지름 이하/초과인 분류이며 성능 분기 정책이 아니다.

| 점 수·분포 | 호출 | 선별 합계 ms | 관찰 최대 점 수 |
|---|---:|---:|---:|
| 1–4 compact | 1,866 | 26.246 | 4 |
| 1–4 spread | 462 | 12.110 | 4 |
| 5–16 spread | 8,510 | 594.873 | 13 |

80점 위주 함수 benchmark를 이 실제 혼합에 그대로 대입할 수 없다. 후보는 짧음·밀집·stale-grid fallback에서 회귀했고, 이 native 실행의 선별 점은 최대13개였다. 후보 제품 반영 보류를 유지한다. 후반8배속 전체 지연은 해결하지 않았다. 다음 실험은 이 실제 분포·실제 적용 경로를 기준으로 비교해야 한다.

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zones/run_native_mix.py
```

현재 제품을 새로 복사하는 재실행 명령이다. 수신·운영 URL은 빈 값이고 외부 네트워크를 쓰지 않는다. 다른 Godot 측정과 병행하지 않는다.
