# BF49 trail 선별 후보의 유한 실험

**동일성 검사 PASS, 무조건 제품 반영 보류.** 긴 trail에서는 함수 시간이 줄었지만 짧은 trail·밀집점·격자 이동 fallback에서는 늘었다. 제품 [`zone.gd`](../../../../../scripts/zone.gd)는 변경하지 않았다. 다른 후보나 휴리스틱은 추가하지 않았다.

최종 증거는 `final/`이다. 상위 `functional/`, `mutant-*`, `benchmark-before-condition/`은 원형 조건 검토 전 시도로 보존한다. `candidate-before-condition.gd.txt`는 그때 실행한 도구 원문이다. 최종 후보는 원본과 동일한 `pk[i] > best` 조건을 사용하며 NaN 경계도 검사한다.

## 후보와 보존 조건

[`trail_orbs`](../../../../../scripts/zone.gd#L153)는 점이 닿는 cell을 모은 뒤 각 cell의 구체마다 전체 점을 다시 검사한다. 도구 내부 후보는 같은 point→x→y 순서로 `cell → 원래 point index 배열`을 만들고 해당 index만 검사한다. cell 삽입 순서, cell 내부 구체 순서, point 순서, `pk > best`, `best >= 1` 조기 종료, `< rr²` 경계를 유지한다. 별도로 정렬하거나 최대 가중치를 다시 고르지 않는다.

격자는 오브젝트 공격 전에 만들어지므로 공격·앞 장판의 밀치기로 구체의 현재 cell이 달라질 수 있다. 현재 cell과 조회 key가 다르면 전체 점 순회로 돌아간다. 현재 구체 반지름이32보다 커도 같은 fallback을 쓴다. 현재 제품 최대 반지름은32이고 큰 반지름은 테스트용 Orb subclass로 확인했다. gore/smear에는 후보를 적용하지 않는다. 해당 경로는 한 점의 효과가 이후 점 검사 전에 위치를 바꿀 수 있다.

## 동일성·mutant

[실행 원문](final/functional/run.log), [기계 판독 결과](final/functional/result.json): **57 assertions, failures0, exit0, SCRIPT/Parse/ERROR0**.

- 빈 점, 단일 점, 음수/64단위 cell 경계, 엄격한 반지름 경계, queue_free·hp0, 처음 만난 `pk >= 1`, add/drop 뒤 index, NaN, 고정 seed32개 배치에서 **순서 있는 구체 id와 orb_k 값**을 실제 `Zone.trail_orbs`와 비교했다.
- 실제 `Zone.affect → Tower.hit`를 네 속성 묶음으로 비교했다. 불·얼음·땅 / 물·바람·금속 / 빛·시간·독 / 피·나무·환영이다. 같은 sim 중복 hit, 다음 sim 재타격, `_share_tick(0.9)` 세 번의 지연 효과를 포함한다.
- Node2D 위치·queue 상태·공개 script 변수와 피해 출처·효과 배열을 비교했다. 두 독립 fixture의 Node/instance id는 의미상 같은 id로 정규화했다. 각 묶음의 후속 global `randi()` 8개도 같다. 네 reference/candidate `.bin` 쌍은 바이트까지 동일하다.
- [stale-cell mutant](final/mutant-moved/run.log), [radius mutant](final/mutant-radius/run.log)는 각각 fallback 하나를 제거한 뒤 **일반 동일성 검사에 실패하도록** 했다. 둘 다 assertions1/failures1, exit1, SCRIPT/Parse/ERROR0. 최종 후보의 GREEN에 예상 RED를 섞지 않는다. runner는 이 두 exit1을 검사 유효성 조건으로 확인한다.

유한 fixture 검사다. 모든 전투 조합·native 표시·장시간 플레이를 포괄한다는 뜻은 아니다.

## 짧은 함수 benchmark

Apple M4 / macOS / Godot4.7.2 / headless. 순수 선별 함수만 잰다. 각 분포 구체300개, 구현당280회. 40회 묶음7개를 원본/후보 순서 교대로 실행하고 묶음당 호출 평균의 중앙값을 표에 썼다. fixture 생성·동일성 검사·draw·affect는 시간에서 제외했다. 다른 Godot이 없는 상태에서 시작했고 실행 중에도 해당 프로세스 하나만 관찰했다. [원본 숫자](final/benchmark/result.json), [동시 실행 기록](final/benchmark/run.json).

| 점 분포 | 원본 μs/호출 | 후보 μs/호출 | 후보 시간 변화 | 거리 검사 원본→후보 |
| --- | ---: | ---: | ---: | ---: |
| 짧은4점 | 33.00 | 52.48 | **+59.0%** | 130→103 |
| 긴80점 | 1469.95 | 596.73 | −59.4% | 16612→1812 |
| 꺾인80점 | 1666.68 | 506.05 | −69.6% | 18751→880 |
| 밀집80점 | 240.23 | 389.25 | **+62.0%** | 2412→2052 |
| 절반 위치 이동 fallback | 1494.33 | 1635.88 | **+9.5%** | 16916→9466 |

짧거나 겹친 점은 원본의 조기 종료가 이미 싸다. 후보의 cell별 index 배열 생성·현재 cell 확인·fallback 배열 비용이 절감을 넘었다. 거리 검사 수 감소만으로 CPU 개선을 단정하면 안 된다.

이 표는 실제 native8배속의 장판71ms 개선률이나 FPS가 아니다. 기존 측정에는 장판 subtype·점 분포별 비중이 없어 이 후보를 전체 비용으로 환산할 수 없다. root가 별도 격리 사본에서 준비하는 `native-mix/` 관찰과도 구분한다. 본 실험 결과로는 제품 무조건 교체를 권하지 않는다.

## 재현·소스

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zones/run_finite.py \
  --output /tmp/bindu-zone-finite
```

runner는 임시 BinduTools 프로젝트·빈 서버 URL을 강제하고 parser→functional→mutant2종→짧은 benchmark 순으로 실행한다. 각 실행은30초 제한이다. benchmark 전에 다른 Godot이 있으면 실행하지 않는다. 결과·실행 명령·종료코드·source hash는 [manifest](final/manifest.json)에 기록했다.

제품 Zone SHA-256 전후 동일: `b4fc8834b536da8312dd14c037fda29fdd85cbc24939614b43bafca1cf23b7f8`. 최종 도구는 [`battlefield_zone_check.gd`](../../../../../tools/battlefield_zone_check.gd), SHA-256 `baa936ec5fe13dc7bcc68c36e9d0ab72ac858113a634742c02a6de1b557bff55`다. 제품 변경·native 성능 실행은 이 작업에서 하지 않았다.
