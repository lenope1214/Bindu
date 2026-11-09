# 장판 적용 비용과 상성 조회 재사용

BF-49의 후속 조사다. 기준 `9426f14`의 실제 장판 적용·반복 상성 조회를 계측한다. 전체 고배속 지연·PERF-01·실기기/사용자 검증은 미완료다. 배속·피해·조준·사거리·카메라·제품 사운드 정책을 바꾸지 않는다.

## 현재 적용 비용

[native 계측 명령·소스·정리](current-verified/run.json), [원자료](current-verified/application-times.json). 오브젝트16개·구체400개 유지 목표, 8배속·효과 전체, 고정 delta1/60·준비30/측정60이다. timer는 측정 구간에만 켜고 정지 프로브·준비·캡처는 제외했다. 실제 구체 평균400개였다.

| 경로 | 호출 | 합계 ms |
|---|---:|---:|
| Tower.hit 직접 |71,566|1,480.894|
| Tower.hit 장판 문맥 |70,421|1,367.926|
| trail affect |8,622|1,461.826|
| trail _hit |58,586|1,246.799|
| Share.carry |94,377|1,284.554|
| gore affect |41,104|888.257|
| Share.gore_step |28,490|473.310|
| trail _rapid |58,586|34.535|

모두 inclusive 시간이며 서로 중첩된다. 합산 비율이나 무계측 전후 FPS로 사용하지 않는다. wrapper bookkeeping도 상위 timer에 섞인다. 작은 `_rapid` 호출 최적화보다 실제 적용과 반복 조회를 먼저 본다. [도구](run_profile.py).

## 후보와 정확성

Tower마다 상성 결과와 속성 사본을 보관한 [초기 후보](cache-typed/run.json)는2,982개 정확성 검사를 통과했지만 단일·빈 속성·대체 객체 경로가 느려 보류했다. 최종 비교 후보는 **마지막 속성 값 사본 하나와 비트마스크 하나**만 Share 내부에 보관한다. 입력이 같으면 기존 `_aff` 전역 결과를 그대로 조회한다. 입력이 바뀌면 원래 비트마스크 계산을 수행한다.

속성 값을 사본으로 보관하므로 Dictionary의 직접 추가·삭제·레벨 변경·비우기·교체·alias 변경을 감지한다. 객체 ID나 Tower 참조를 보관하지 않고 메모리는 마지막 사본 하나로 제한한다. 기존 결과 Dictionary의 공유 관계를 유지하며 `_aff.clear()` 뒤 같은 입력도 다시 조회한다. 피해·속성 값·RNG·세이브·프로토콜을 바꾸지 않는다.

[순수 함수 최종 검사](cache-final/run.json), [잘못된 사본 alias 변형](cache-mutant-final/run.json). 정상2,988개 단언 통과, 잘못된 alias12건 검출이다. 17종의 최대3개 속성 multiset969개, 빈 입력·fallback·직접 수정·다른 객체·공유 결과·전역 캐시 비우기·후속 RNG를 포함한다. [후보 생성 도구](run_cache.py), [검사](../../../../../tools/battlefield_affinity_cache_check.gd).

[실제 전투 재생](replay/run.json)과 [세 속성 재생](replay-triples/run.json)은 총1,110사례·13,320표본의 상태·지연 예약·거울·핏자국 상태와 후속 RNG가 원본과 같았다. 기존 parity schema의 float/좌표1e-5 정규화를 사용하며 모든 runtime field의 bit 비교는 아니다. 공격방식·강화·단일/쌍/세 속성·5맵/3방향·사망 문맥을 포함한다. [재생 도구](run_replay.py).

## 미세 측정과 한계

7묶음×각20,000회 선후 교대, 단위us/call이다. 동적 GDScript 호출 공통 비용을 포함한다.

| 입력 | 원래 중앙값 | 후보 중앙값 |
|---|---:|---:|
| Tower 세 속성 |0.48185|0.39170|
| Tower fallback |0.42850|0.37820|
| Tower 단일 속성 |0.39840|0.36900|
| Tower 빈 속성 |0.35335|0.36690|
| 대체 객체 세 속성 |0.49325|0.39705|
| 대체 객체 fallback |0.43295|0.38120|
| 매 호출 속성 교체 |0.54470|0.78790|

빈 값과 매 호출 입력 교체에서는 비용이 증가한다. 일부 hot 입력의 감소를 전체 개선으로 바꾸지 않는다.

## 전체 전투 비교의 제어

[native 비교](native/run.json)는 실제16오브젝트·400구체 유지 목표, 각6조건/360표본, 합계720표본·정지12회를 통과했다. main CPU는0.82–4.17% 감소했지만, 강제 draw 간격은1배속 효과 줄이기에서1.58% 증가하고8배속 전체 효과에서0.0044% 증가했다. 단일 별도 실행의 관찰이며 모든 프레임 무회귀 증거가 아니다. [도구](run_native.py).

[초기 headless ABBA](uncontrolled-summary.json)도 mixed 전체 효과 main CPU가2.30% 증가하고 효과 줄이기는12.56% 감소하는 등 편차가 컸다. Sfx.play는 실제 시간 MIN_GAP에 따라 전역 randf를 소비한다. 단순히 seed를 고정하고 렌더만 빼도 동일 전투량이 보장되지 않는다. 이 단계 수치를 후보의 인과 효과로 채택하지 않는다.

제어 비교는 QA 사본의 `main.sfx.muted=true`로 시간 의존 난수 소비를 제거한다. 제품 사운드 코드는 수정하지 않는다. mixed·금속/땅/피3속성의 실제400구체 전투를 ABBA로 반복하고, 같은 조건의4실행 모두 구체/발사체/장판 수의 전체 시퀀스·끝 상태·후속 RNG가 같아야 비교를 채택한다. 표본 생성 이후에 상태를 수집하며 main CPU timer에는 포함하지 않는다. [도구](run_cpu.py). 전체 프레임·물리 입력·실기기 FPS 증거는 아니다.

[제어 비교 집계·명령·소스 해시](controlled-summary.json). 8실행·960표본에서 같은 조건4실행의 구체/발사체/장판 수 시퀀스·끝 상태·후속 RNG가 모두 일치했다. 값은 조건별 두 실행의 main CPU 평균이다.

| 실제400구체·8배속 | 원래/후보 ms | 차이 |
|---|---:|---:|
| 혼합·전체 효과 |136.303 / 135.259|−0.766%|
| 혼합·효과 줄이기 |142.699 / 141.239|−1.023%|
| 금속/땅/피·전체 효과 |142.937 / 141.094|−1.289%|
| 금속/땅/피·효과 줄이기 |148.939 / 147.130|−1.214%|

작은 계산 비용 감소가 반복돼 마지막 입력 값 재사용 후보만 제품에 반영했다. Tower별 캐시는 넣지 않았고 Zone·사운드 코드는 바꾸지 않았다. 빈 입력/매번 바뀌는 입력의 미세 검사 증가와 native draw 일부 증가를 보존한다. 물리 입력 지연·전체 FPS·PERF-01·고배속 문제가 해결됐다는 뜻은 아니다.

## 제품 반영 확인

[제품 함수 검사](product-contract/run.json)는 현재 Share 원문을 복사해 동결 참조와 비교한다. `--product`는 동결 후보를 다시 만드는 방식과 달리 실제 checkout의 함수를 검사한다. [반영 뒤 전체 회귀](product-full-check.log)는 명세252·전달 상태86·parity345사례/4140표본·fuzz4·W4/8/12 복원→13·서버28 통과다. 최종 제품 해시·release 소스/pack의 연결·미완료 범위는 [제품 검증](product-verification.json)에 기록한다. [export 직전 모든 소스 해시](product-release-verified/source-before-export.json)가 현재 checkout과 운영 URL 비우기 외 일치한다. [macOS release](product-release-verified/run.json)는 template=true/debug_build=false/editor=false, PC100/폰130% 각각221개·총442개 단언·runtime/행동/UI 오류0이다. 원래 res 소스 파일의 runtime SHA를 주장하지 않는다.

## 재실행

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zone-application/run_cache.py --product --output /tmp/bindu-affinity-contract
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zone-application/run_cache.py --mutant-alias --output /tmp/bindu-affinity-mutant
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zone-application/run_replay.py --output /tmp/bindu-affinity-replay
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zone-application/run_replay.py --triples-only --output /tmp/bindu-affinity-triples
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zone-application/run_native.py --output /tmp/bindu-affinity-native
python3 docs/qa/2026-11-09-battlefield-fixes/performance/zone-application/run_cpu.py --controlled --output /tmp/bindu-affinity-cpu
```

새 출력 폴더에서 순차 실행한다. 원본 프로젝트 import·개인 저장·운영 서버·배포·버전은 변경하지 않는다. 각 고유 BinduTools 저장·임시 프로젝트의 정리를 기록한다. 최초 profile wrapper의 인자 없는 함수 regex 오류는 [제외](current/exclusion.json)했고 Godot 실행 전 실패였다. 일부 일반 QA 종료의 ObjectDB2 경고는 runtime 오류0과 구분한다.
