# 없는 특징의 hit 후처리 호출 제거

BF-49 전체 지연의 후속 조사다. 직전 조준 변경 이후에도 native8배속 전체 효과의 공격54.30ms·장판44.26ms가 남았다. 이 단계의 후보는 Tower.hit의 세 후처리를 활성 속성이 있을 때만 호출한다. 피해식·적용 순서·RNG·실제 활성 특징은 보존하며 프레임 간 캐시는 추가하지 않는다.

## 현재 병목과 보류한 후보

- [현재 Tower 프로파일](baseline-profile/run.json), [공격방식별 계측](baseline-profile/attack-times.json): 준비30/표본30·8배속·전체 효과. hit144,687호출/3,065,554us, attack8,256호출/3,648,697us, guard7,224호출/680,335us. hit는 장판 등 공격 밖 호출도 포함하므로 attack 대비 비율을 계산하거나 세 합계를 더하지 않는다. 직전의 [계측 도구](../guard-range/run_profile.py)를 새 출력 경로로 실행했다.
- [상성·특징 상세 계측](affinity-profile/run.json), [원자료](affinity-profile/share-times.json): aff1,054,536호출/547,886us, k1,548,840호출/855,257us, am463,752호출/766,465us. 모두 inclusive이고 서로 중첩된다. wrapper 비용이 섞인 한 번의 위치 확인이며 무계측 전후 성능 비교가 아니다.
- [피해 출처 배열 계측](attribution-profile-fixed/run.json), [루프 원자료](attribution-profile-fixed/attribution-times.json):145,446호출/64,633us로 조사한 다른 비용보다 작았다. 이 루프는 수정하지 않았다. 최초 `attribution-profile/` 실행은 두 `if lit` 위치를 하나로 가정한 도구 assertion에서 import 전에 멈췄다. 대상 루프 뒤의 첫 위치로 좁혀 도구를 고쳤다.
- `_els`의 eff 속성 읽기를 지역 변수로 줄인 [별도 후보](els-candidate/results.json), [검사 소스](../../../../../tools/battlefield_share_els_check.gd)는 정상 값·RNG·사전 alias20조건을 통과했다. 그러나 fallback 중앙값0.181–0.185→0.187–0.188us로 소폭 느려졌다. 비어 있지 않은 eff는0.181–0.187→0.165–0.168us였다. 효과가 작은 이 후보는 제품 반영을 보류했다. **제품 Share.gd는 변경하지 않는다.**

[상세 계측 도구](run_profile.py)는 임시 프로젝트의 Share 세 함수만 감싼다. attribution 옵션에서 Tower의 해당 루프도 감싼다. 기존 함수 본문·난수·순회 순서를 유지하며 기록은 함수 타이머 밖에 둔다. 그 기록 비용도 전체 실행에는 영향을 준다.

## 활성 조건과 동등성 근거

현재 Share.condense는 금속 k가0이면 반환한다. 금속이 없는 Tower는 `carry_n` 계산까지 건너뛴다. Share.on_hit은 땅 다짐·시간 되풀이만 만들고, Share.mark는 피 핏자국·환영 비춤만 만든다. 해당 속성이 없으면 기존 경로도 피해·상태·예약·RNG를 바꾸지 않는다. 각 원래 함수 내부의 레벨·전역 배율·쿨다운·구체 생존 조건은 유지한다. 조건이 참인 함수들의 기존 순서도 유지한다.

판정에는 hit 시작 시 고른 eff 또는 elements를 쓴다. extra가 있으면 원래 속성의 상위 집합으로 복사하므로 필요한 기존 특징을 누락시키지 않는다. 현재 hit 중에는 Tower.eff를 교체하거나 속성을 삭제하는 경로가 없다. 부가 속성 때문에 불필요한 호출이 남을 수는 있지만 효과를 새로 만들지는 않는다.

## 실제 전투 재생

[재생·변형 결과](replay/run.json), [재현 도구](run_replay.py). 기준 hit는 `ef82a09` 본문으로 고정한다. 제품이 바뀐 뒤에도 기준/후보가 같은 함수를 실행하는 검사가 되지 않게 했다. 나머지 소스는 현재 checkout을 쓴다.

- 기본300 + 단일 속성17종/상성13쌍×공격방식15종450 + 죽음45 = **795사례·9,540표본**. 기준/후보의 순서 있는 전투 상태와 후속 RNG가 일치했다.
- 기존 parity 필드 외 시간 되풀이 예약 타이머·구체 rep_cd·피 표식 지속/소유자 유효성·환영 시간/배율/쿨다운/소유자 유효성도 비교했다. float/좌표는 기존 schema의1e-5 정밀도다. 모든 런타임 필드의 비트 단위 동등성은 아니다.
- 의도적으로 땅/시간의 `or`를 `and`로 바꾼 변형은450사례 중 **75사례에서 차이**를 검출했다. 해당 변형은 제품에 적용하지 않는다. 인스펙터도 같은 제품 코드를 쓰는 단순 parity 통과만으로 동등성을 판단하지 않고, 별도 기준 실행의 trace와 비교했다.
- 세 후처리 동시 활성·땅/시간·빛/금속/환영·불/얼음/피 등 [세 속성6조합×15방식90사례](replay-triples/run.json)도1,080표본 상태와 후속 RNG가 일치했다. 합계 **885사례·10,620표본**이다.

## Native 전후 관찰

[비교·소스 차이·정리](native/run.json), [기준 측정](native/baseline/measurements.json), [후보 측정](native/candidate/measurements.json). [도구](run_native.py)는 16오브젝트·약300구체·고정 delta1/60초·준비30/표본60을 각6조건에서 실행했다. 기준/후보 합계720표본·가상 정지12회, 행동/UI/runtime 오류0이다. 제품 소스 차이는 Tower 한 파일, project.godot 차이는 전용 저장 이름뿐이다.

[기준 native 로그](native/baseline/native.log)와 [후보 native 로그](native/candidate/native.log)에 조건별 정지·UI·종료 판정을 보존했다.

| 조건 | 공격 CPU 전/후 ms | main CPU 전/후 ms | 강제 draw 간격 전/후 ms |
|---|---:|---:|---:|
| x1-full |7.17 / 6.58|14.26 / 13.63|41.87 / 42.25|
| x1-reduced |6.92 / 6.53|13.96 / 13.49|41.34 / 42.38|
| x4-full |28.18 / 25.76|63.57 / 59.71|121.49 / 117.80|
| x4-reduced |28.29 / 25.15|64.15 / 60.23|121.34 / 117.03|
| x8-full |53.25 / 48.57|132.78 / 126.21|220.22 / 215.17|
| x8-reduced |55.28 / 56.47|137.20 / 135.32|226.73 / 225.84|

main CPU는6조건 모두1.4–6.1% 감소했지만, 마지막 조건의 공격은2.2% 증가했고1배속 강제 draw 간격도 소폭 늘었다. 한 번의 순차 비교로 인과 효과 크기나 전 조건의 개선을 단정하지 않는다. GPU 타이머0은 미제공이다.

이를 구분하려고 [ABBA CPU 도구](run_cpu.py)는 실제 simulation을 headless로 기준→후보→후보→기준 순서로 실행한다. 기존 혼합과 세 후처리가 모두 활성인 합법적인 금속·땅·피 조합을 별도로 잰다. headless는 그리기·스크린샷을 제외하므로 native 수치와 합치지 않는다.

[ABBA 결과](cpu-abba/run.json):2혼합×4실행×2조건, 각 준비30/표본60으로 총960표본이다. 아래는 조건별 두 실행 평균이다. 양수도 그대로 기록한다.

| 조합/효과 | main CPU 전/후 ms | main 변화 | 공격 CPU 변화 |
|---|---:|---:|---:|
| 기존 혼합/full |134.58 / 128.09|-4.83%|-10.13%|
| 기존 혼합/reduced |127.44 / 124.42|-2.37%|-2.60%|
| 모두 활성/full |149.62 / 149.84|+0.15%|+0.83%|
| 모두 활성/reduced |149.90 / 149.12|-0.52%|-1.35%|

기존 혼합에서 반복 비용 감소를 확인해 조건부 호출을 제품에 반영했다. 모두 활성인 경로에는 조건 검사가 추가되고 큰 이득은 없다. 이 변경이 모든 조합에서 더 빠르다거나 수치상 성능 상한을 만족했다고 주장하지 않는다. 제품 Tower SHA-256은 측정한 후보와 같은 `fc9510c7d5463bf9610bb6c2acc4d57964122a4c12d0c5eaaced577df8e5764d`다. Share.gd와 피해식은 그대로다.

**BF-49 전체 지연은 미해결이다.** native8배속 main CPU126–135ms·강제 draw 간격215–226ms가 남았다. 이 수치를 실기기 FPS나 OS 입력 지연으로 읽지 않는다. 최종 export 실행·실제 입력 큐와 장판/이동/렌더 비용이 후속 범위다.

제품 반영 후 [전체 검사](final-check.log) exit0: 명세252·협동 상태86·parity345사례/4,140표본·fuzz4·W4/8/12 복원→13·서버28 통과다. [제품 해시와 검증 집계](product-verification.json)에 채택한 소스·누락 범위·증가를 관찰한 조건도 함께 기록했다. 각 단계의 별도 측정 감소율을 서로 곱해 누적 개선률로 사용하지 않는다.

다른 Godot 작업과 병행하지 않는다. 실기기·OS 입력→물리 화면 지연·사용자 승인 FPS 예산은 제공되지 않았다. 임의의 CI 시간 상한을 선언하지 않는다.

## 재실행

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_profile.py --output /tmp/bindu-hit-tower
python3 docs/qa/2026-11-09-battlefield-fixes/performance/hit-factors/run_profile.py --output /tmp/bindu-hit-affinity
python3 docs/qa/2026-11-09-battlefield-fixes/performance/hit-factors/run_profile.py --attribution --output /tmp/bindu-hit-attribution
python3 docs/qa/2026-11-09-battlefield-fixes/performance/hit-factors/run_replay.py --mutant --output /tmp/bindu-hit-replay
python3 docs/qa/2026-11-09-battlefield-fixes/performance/hit-factors/run_replay.py --triples-only --output /tmp/bindu-hit-triples
python3 docs/qa/2026-11-09-battlefield-fixes/performance/hit-factors/run_native.py --output /tmp/bindu-hit-native
python3 docs/qa/2026-11-09-battlefield-fixes/performance/hit-factors/run_cpu.py --output /tmp/bindu-hit-cpu
```

모두 고유 BinduTools 프로젝트·저장 이름, 빈 서버 URL, Dummy 오디오를 사용한다. 관찰을 덮어쓰지 않도록 새 출력 경로를 사용한다. 종료 뒤 전용 저장과 임시 프로젝트를 제거한다. 기존 도구의 ObjectDB2개 종료 경고는 남는다.
