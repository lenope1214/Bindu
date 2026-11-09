# 자동 조준의 후보 할당·두 번째 순회 제거

## 2026-11-10 검사 범위 정정

기존 도구는 공격방식을 바꿀 때 `set_pattern()`의 거절을 확인하지 않았다. 첫 비기본 방식 뒤 교체가 거절돼 **아래 14,527회가 실제 15종을 모두 실행했다는 설명과 방식별 headless 표기는 잘못됐다.** 기존 로그·측정값은 보존하지만, 15종 커버리지와 방식별 성능 근거로 사용하지 않는다. native 부하 도구는 새 Tower마다 한 번 설정하므로 이 결함과 별개다.

검사 fixture를 실제 `pattern`·`plv`로 구성하고 호환 강화만 설정하도록 수정했다. 15종 × 레벨1/3/8의 실제 실행 횟수를 기록·검증한다. 단일 정상 구체·음수 band도 추가해 총41,564회다. [수정 검사](coverage-corrected/green/results.json)는 불일치0·exit0, [의도적 경계 오류](coverage-corrected/red/results.json)는2건을 검출해 exit1이었다. [실행 기록](coverage-corrected/green/run.json)과 [변형 기록](coverage-corrected/red/run.json)에 임시 저장 정리도 남겼다. 아래 결과는 정정 전의 역사 기록이다.

제품 수정은 `scripts/tower.gd`의 `_guard_pick` 한 함수다. 각 유효·사거리 안 구체에서 전체 첫 최소 거리와 방향 선호 집합의 첫 최소 거리만 보관한다. 선호 최소값이 `전체 최소 + aim_band` 안이면 선호 후보, 아니면 전체 최소 후보를 반환한다. 음수 band의 대상 없음, strict `<` 동률 순서, 기존 거리·사거리 함수, 방향 원뿔의 `<=`, 난수 미사용을 유지한다.

[`battlefield_targeting_check.gd`](../../../../../tools/battlefield_targeting_check.gd)는 교체 전 2pass·후보 배열 함수를 참조로 보존했다. 함수명과 명시적 Tower 수신자 `t.` 외에 원문과 일치하는 것을 [별도 해시](reference-source.json)로 확인했다. 참조도 동일 기능 코드의 거리·사거리 함수를 호출하므로 해당 함수 자체의 규칙을 재검증하는 검사는 아니다.

14,527개 조합: 5맵·15방식·자동 조준0/1·3방향·선호각 음수/0/양수·band 음수/0/양수, 사거리 안/경계/밖, 정확한 band·원뿔 경계, 동률의 입력 순서 반전, 빈 목록, null/해제된 참조/queued/죽은 구체, main 없는 재사용 경로, 별도 RNG seed9009의 추가1,000사례. 모든 위치는 정상적인 유한 좌표다. 매 경우 대상 instance id와 다음 전역 난수값을 비교한다.

## 결과

- `before/`: 실제 함수를 교체 전 본문으로 되돌린 임시 사본. 14,527개0불일치·exit0.
- `green/`: 제품 최적화. 14,527개0불일치·exit0.
- `red/`: 임시 사본에서 선호 후보의 inclusive band 경계를 exclusive로 바꿨다. 최종14,527개 중 정확한 band 경계2건을 검출해 exit1. 제품에는 이 변형을 적용하지 않았다.

함수 CPU는 구체300개·고정 상태에서 60회 준비 후8묶음×200호출/함수/방식, 참조→실제와 실제→참조 순서를 번갈아 잰다. headless 함수 비용이며 native 프레임·GPU·휴대폰 성능을 뜻하지 않는다. 참조의 명시적 수신자 호출 자체에 약1~2% 비용 차이가 있어 교체 전 실제 함수도 별도로 측정했다. 최종 수치는 아래와 같다. `before`와 `green`은 별도 프로세스이고 최종 GREEN 동안 다른 통합 QA가 병행되어 절대시간이 상승했다. 각 프로세스 안의 참조→실제 차이를 읽어야 한다.

| 방식 | before 참조 / 실제 ms | GREEN 참조 / 실제 ms | GREEN 내부 감소 |
| --- | ---: | ---: | ---: |
| shot | 1.277 / 1.253 | 1.356 / 1.237 | 8.8% |
| spray | 1.266 / 1.253 | 1.333 / 1.183 | 11.2% |
| wall | 1.276 / 1.267 | 1.314 / 1.184 | 9.9% |

참조 호출자 차이에 따른 before 내부 감소는 약0.8~1.9%다. 이를 감안해도 후보 배열·두 번째 순회 제거와 반복 규칙 조회 축소에 CPU 이득이 관찰됐다. 전체 프레임 개선률로 이 비율을 확장하지 않는다. 모든 로그 `SCRIPT ERROR`/`ERROR:`0. 종료 ObjectDB2개 경고는 남아 원본 로그에 보존했다.

native 재측정도 종료했다. 이전 current와 동일 harness SHA·seed9009·16오브젝트·약300구체·고정1/60초·준비30/표본180·profiler ON·6조건을 유지했다. optimized도 exit0, 1,080표본, 가상 P18/18, 단언0·UI0·`SCRIPT ERROR`/`ERROR:`0이다. [원본](../optimized-profiled/measurements.json), [명령·정리](../optimized-profiled/run.json), [비교·소스 차이](native-comparison.json), [8배속 실제 캡처](../optimized-profiled/x8-fx-full.png).

| 조건 | 공격 CPU 전 / 후 ms | main CPU 전 / 후 ms | 강제 draw 간격 전 / 후 ms |
| --- | ---: | ---: | ---: |
| x1-fx-full | 16.19 / 14.82 | 25.09 / 23.77 | 59.06 / 57.02 |
| x1-fx-reduced | 16.07 / 14.96 | 24.91 / 23.87 | 58.92 / 57.64 |
| x4-fx-full | 65.66 / 56.47 | 110.35 / 97.02 | 177.46 / 164.98 |
| x4-fx-reduced | 62.04 / 58.54 | 100.33 / 100.00 | 166.70 / 165.52 |
| x8-fx-full | 135.67 / 123.02 | 244.00 / 240.48 | 352.35 / 352.90 |
| x8-fx-reduced | 119.90 / 117.47 | 212.22 / 235.40 | 313.36 / 345.49 |

공격 구간은6조건 모두 감소했다. native와 differential의 Tower SHA-256은 동일한 `23cff28ad623d93893f0555c148a929373eb6b583495bb73a42a5eb144af9d75`다. 함수의 CPU 이득과 대상·RNG 보존을 근거로 변경을 유지했다.

**전체 후반 프레임 문제는 해결 판정하지 않았다.** 8배속·효과 줄이기 끔의 전체 강제 draw 간격은 사실상 같았고, 켬에서는 오히려313.36→345.49ms로 악화를 관찰했다. 해당 조건의 공격은119.90→117.47ms로 줄었으나 장판·이동·렌더 비용 변동이 상쇄했다. 입력 지연을 개선했다고 확장하지 않는다. 장판·이동·렌더, 실기기에서 남은 병목을 별도 확인해야 한다.

이전 current 이후 최종 UI/통합 경계도 수정되어 비교 사본 사이 Tower 외 CardDock/Cards/Lobby/Perks/RunFlow 및 도구 등이 다르다. 정확한 해시는 `native-comparison.json`에 있다. 타겟 선택 변경 외 제품 파일을 이 최적화 단계에서 편집하지 않았다. 단일 순차 native 실행·열 상태·draw의 전역 RNG·실제 탄/장판 수 차이가 있어 전체 수치의 인과 효과를 해당 함수 하나로 단정하지 않는다. GPU 타이머는 이번에도 모두0=미제공이다. 물리 중급 폰·OS 입력→실제 화면 지연 증거는 남는다.


## 재실행

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/performance/targeting/run_targeting.py --variant before --output /tmp/bindu-targeting-before --benchmark
python3 docs/qa/2026-11-09-battlefield-fixes/performance/targeting/run_targeting.py --output /tmp/bindu-targeting-green --benchmark
python3 docs/qa/2026-11-09-battlefield-fixes/performance/targeting/run_targeting.py --variant mutant --output /tmp/bindu-targeting-red
```

각 실행은 고유 프로젝트/저장 이름·빈 서버 URL·Dummy 오디오로 분리했고 종료 뒤 임시 사본과 고유 저장 폴더를 삭제한다. `run.json`에 실제 명령·종료코드·정리, `results.json`에 소스 해시·비교·묶음별 측정값을 보존한다.
