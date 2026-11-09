# 조준 호출 안의 사거리·목표 중심 재사용

BF-49 전체 후반 지연은 진행 중이다. 이 단계는 측정된 `_guard_pick` 한 함수에 한정한다. 프레임 간 캐시를 만들거나 사거리·피해·대상 우선순위를 바꾸지 않는다.

## 측정과 가설

제품 변경 전 [native 프로파일](baseline-profile/run.json), [공격방식별 inclusive 계측](baseline-profile/attack-times.json): 16오브젝트·약300구체·8배속·효과 전체, 준비30/측정30프레임. `_guard_pick` 7,224호출/4,625,887us, `attack` 8,256호출/7,573,514us로 조준이 공격 inclusive 비용의 약61%였다. `hit`도 inclusive이므로 세 수치를 더하면 안 된다. [재현 도구](run_profile.py)는 임시 사본에만 세 함수 wrapper를 넣었다.

한 조준 호출 동안 바뀌지 않는 사거리와 지키는 곳의 좌표를 처음 필요한 시점에 계산한다. 폭풍에서 방향에 따라 비행거리가 달라지는 직선탄·돌풍·투척 및 추적 투사체는 매 후보마다 기존 함수를 호출한다. 분사·벽 등 방향에 독립적인 방식만 재사용한다. 구체가0/1개인 경우도 별도 처리해 초기화 비용을 줄인다. 단일 후보도 사거리와 음수 band 규칙은 유지한다. 거리 제곱으로 교체하지 않아 경계의 부동소수 연산도 유지한다.

## 검사 범위 정정

이전 조준 검사에서 `set_pattern()` 거절을 무시한 결함을 찾았다. 기존14,527회의 실제15종 커버리지·방식별 headless 표기는 철회하고 [원본 기록에 정정](../targeting/README.md)했다. 공격방식·레벨을 직접 fixture로 구성하고 호환 강화만 설정했다. 실제 실행한45개 `pattern:level` 키와 호출 수를 파일에 남긴다.

- 수정 도구로 현재 제품과 원래2pass 참조를 비교: [41,564회·불일치0](../targeting/coverage-corrected/green/results.json), [실행·저장 정리](../targeting/coverage-corrected/green/run.json).
- 의도적으로 선호 band 경계를 exclusive로 바꾼 [변형](../targeting/coverage-corrected/red/results.json)은2건을 검출해 exit1이다.
- 후보와 현재 제품 비교: [41,564회·불일치0](candidate-final/results.json), [실행·저장 정리](candidate-final/run.json). 5맵·실제15종·레벨1/3/8·자동조준0/1·3방향·각도·band·정확한 경계·동률·null/해제/queued/죽음·main 없음·단일 정상 후보·seed9009 추가1,000사례. 정상 유한 좌표 범위다. 매 경우 대상과 다음 전역 RNG를 비교한다.
- 실제 전투 재생: [기준/후보570사례·6,840표본 상태와 후속 RNG 동일](replay/run.json). 기존 parity의 basic300/context225/deaths45를 각각 별도 임시 프로젝트에서 실행했다. 순서 있는 오브젝트·구체·발사체·장판 상태와 피해·상태효과 필드를 비교한다. 기존 schema의 float/좌표 정밀도는1e-5이며 모든 런타임 필드의 비트 단위 동등성을 뜻하지 않는다. [도구](run_replay.py).

## 함수 비용

[후보 함수](../../../../../tools/battlefield_guard_range_check.gd), [측정 도구](run_candidate.py). 각 조건 준비20회 후7묶음×40호출, 기준→후보/후보→기준을 번갈아 실행했다. headless CPU이며 전체 프레임·실기기 FPS를 뜻하지 않는다. 아래는 구체300개 중앙값, 단위us다. 폭풍 shot은 자동조준0으로 방향별 사거리 경로를 강제했다. iron은 호환 추적 강화3이다.

| 맵/방식 | 기준 | 후보 | 변화 |
|---|---:|---:|---:|
| plain/shot |214.40|114.35|-46.7%|
| plain/spray |899.18|89.38|-90.1%|
| plain/wall |1644.13|77.83|-95.3%|
| plain/iron |1084.63|118.30|-89.1%|
| line/shot |281.13|112.85|-59.9%|
| line/spray |936.40|87.30|-90.7%|
| line/wall |1636.33|77.33|-95.3%|
| line/iron |1154.50|116.85|-89.9%|
| storm/shot |1250.73|1201.78|-3.9%|
| storm/spray |1067.35|89.75|-91.6%|
| storm/wall |1779.65|78.30|-95.6%|
| storm/iron |1256.08|1196.93|-4.7%|

빈 목록·단일 표본도 [36조건 원자료](candidate-final/results.json)에 모두 있다. 빈 목록 중앙값은0.30–0.35→0.125us, 단일 후보는1.10–6.23→0.925–6.075us였다. 아주 짧은 호출은 타이머 분해능·호출자 차이에 민감하다. 사용자 승인 성능 허용치가 없어 임의의 FPS 예산이나 CI 시간 상한을 선언하지 않는다. 정확성 판정은 대상·RNG 불일치0이며, 실행 도구는 사례 수와 실제 패턴/레벨 누락도 실패시킨다.

초기 `candidate-before-fixture-fix/`는 잘못된 패턴 fixture, `candidate-corrected/` 첫 실행은 상대 출력 경로 때문에 결과 JSON을 회수하지 못한 로그다. 로컬에 보존하되 채택 근거는 위 `candidate-final/`과 `replay/`만 사용한다. 공통 도구의 종료 ObjectDB2개 경고는 남는다. `SCRIPT ERROR`/`ERROR:`는0이다.

## Native 비교와 제품 반영

[비교·소스 차이·정리](native/run.json), [기준 원자료](native/baseline/measurements.json), [후보 원자료](native/candidate/measurements.json). 각6조건×준비30/표본60, 두 실행 합계720표본·가상 정지12회, 행동/UI/runtime 오류0이다. 실제 native SubViewport·Dummy 오디오·포커스 비점유 창으로 순차 실행했다. 제품 소스 차이는 Tower 한 파일이고 project.godot 차이는 전용 저장을 위한 고유 이름이다. GPU 타이머0은 미제공이다.

[기준 native 로그](native/baseline/native.log)와 [후보 native 로그](native/candidate/native.log)에 조건별 관찰·정지·UI 판정을 보존했다.

| 조건 | 공격 CPU 전/후 ms | main CPU 전/후 ms | 강제 draw 간격 전/후 ms |
|---|---:|---:|---:|
| x1-full |14.85 / 8.70|21.95 / 17.49|49.24 / 46.10|
| x1-reduced |14.80 / 7.35|21.92 / 14.72|49.70 / 43.23|
| x4-full |58.12 / 28.64|94.70 / 65.34|153.47 / 125.64|
| x4-reduced |60.82 / 27.68|98.45 / 62.32|155.79 / 120.38|
| x8-full |108.97 / 54.30|193.83 / 127.47|275.34 / 213.89|
| x8-reduced |120.36 / 62.71|198.43 / 144.11|283.17 / 234.44|

6조건 모두 공격 CPU41.4–54.5%, main CPU20.4–36.7% 감소를 관찰했다. 한 쌍의 순차 측정이므로 열 상태·실행 중 그리기의 전역 RNG 소비·탄/장판 수 변동 영향을 제거한 인과 효과의 정확한 크기로 단정하지 않는다. OS 입력부터 물리 화면 표시까지의 지연이나 폰 FPS 측정도 아니다.

후보 Tower SHA-256 `b7ee6e9fe7c9eecea4ff4092349be8fe9014400ff344c5cef5f56b3c74d51652`와 동일한 제품 파일을 반영했다. **8배속 전체 지연은 여전히 남는다. BF-49를 해결로 닫지 않는다.** 프레임 전체·장판·이동·렌더·실기기 입력 과제는 후속 범위다.

초회 비교는 당시 제품 `602e344`의 guard를 기준으로 했다. 제품 반영 후 재실행이 자기 자신과 비교하는 검사가 되지 않도록 재생·후보·native 도구는 그 commit의 guard 본문을 임시 사본에 고정한다. 나머지 제품 소스는 실행 시 checkout을 사용한다. 실제 채택 제품의 원래2pass 대상/RNG 회귀 검사는 별도의 `run_targeting.py`가 담당한다.

제품 반영 후 [전체 검사](final-check.log) exit0: 명세252·협동 상태86·parity345사례/4,140표본·fuzz4·W4/8/12 복원→13·서버28 통과다. 실제 제품과 원래2pass 참조도 [41,564회 불일치0](product-green/results.json), [실행/정리 exit0](product-green/run.json)이다. [제품 해시·검증 집계](product-verification.json)에 당시 소스와 한계를 함께 기록했다.

## 재실행

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/performance/targeting/run_targeting.py --output /tmp/bindu-targeting-green
python3 docs/qa/2026-11-09-battlefield-fixes/performance/targeting/run_targeting.py --variant mutant --output /tmp/bindu-targeting-red
python3 docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_candidate.py --benchmark --output /tmp/bindu-guard-candidate
python3 docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py --output /tmp/bindu-guard-replay
python3 docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_native.py --output /tmp/bindu-guard-native
```

성능 측정은 다른 Godot QA와 겹치지 않게 순차 실행한다. 고유 프로젝트·저장 이름, 빈 서버 URL, Dummy 오디오로 분리하고 종료 뒤 임시 사본과 전용 저장 폴더를 제거한다.
