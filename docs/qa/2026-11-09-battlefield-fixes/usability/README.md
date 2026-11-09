# 최신 통합 사용성·카드 요약 검증

네이티브 Godot 4.7.2 / macOS Apple M4 / no_focus·최소화 창의 VirtualInput 검사. 개인 저장과 온라인 주소를 분리했다. OS 커서·실제 사람·폰 실기기 시험은 아니다. 성능 측정 종료 뒤 실행했으며 타이밍 성능을 측정하지 않았다.

## 최종 결과

| 검사 | 조건 | 결과 |
|---|---|---|
| usability all | PC 1280×720 / 100% | 종료 0, 실패 0, UI 0 |
| usability all | 폰 2556×1179 / 130% | 종료 0, 실패 0, UI 0 |
| information | 같은 PC·폰 | 양쪽 종료 0, 실패 0, UI 0 |
| focused-preview | 같은 PC·폰, 실제 버튼·스크롤 | 양쪽 종료 0, 실패 0, UI 0 |
| card-writing + actual-font 확장 | PC·폰 모두 130% | 양쪽 종료 0, 실패 0, 요약 잘림 0 |

사용성 전체 로그: [PC](pc-final/native.log), [폰](phone-final/native.log). 정보 로그: [PC](../information/integrated-pc-final/native.log), [폰](../information/integrated-phone-final/native.log). 각 폴더에 `source-manifest.json`, import 로그, 실제 실행 명령·종료 코드가 있다. 최신 전체 검사·정보 검사는 한 소스 캐시에서 만든 네 사본이며, 완료 직후 비교에서 `scripts/` 해시가 현재 작업 트리와 모두 일치했다. 이후 소스 변경은 각 manifest를 기준으로 다시 판단한다.

## 기존 사용성 기대값 마이그레이션

[`tools/usability_check.gd`](../../../../tools/usability_check.gd)의 기존 우클릭·소유권·정지 중 조작 차단·터치 상세·모달/배지 우선순위·드래그 취소·특성 길게 누르기 검사는 유지했다. 바뀐 사용 경로를 다음처럼 검사한다.

- 같은 오브젝트 반복 클릭은 방향·선택 유지. 실제 E와 방향 버튼으로 편집하고 Esc로 기존 방향·선택 복원.
- 선택 중 실제 카드 호버는 카드를 미소비로 비교. 카드→상세 패널 이동에도 유지되고, 둘 다 벗어나면 원래 선택 정보로 복귀.
- WAVE의 첫 Esc는 선택·기술 조준보다 먼저 일시정지. 다음 Esc로 재개하고 선택은 유지한다. 선택 해제·조준 취소는 명시적 버튼을 사용한다.
- 처음 정보창은 공격 예시를 접고 수치·사거리·조준을 먼저 표시한다. 실제 버튼으로 펼치면 격리된 실제 전투가 진행되고 원본 빌드는 보존된다. 다시 접으면 simulation elapsed·SubViewport 렌더가 정지한다.
- focused-preview는 주변 공격 숨김, 실제 명중·표적 보충·전장 밖 방향 예시를 유지한다. 폰에서 수치 아래로 밀린 예시는 실제 wheel 입력으로 화면에 90% 이상 드러내는 것도 확인했다. [폰의 실제 예시](phone-focused-revealed/focused-preview.png).

초기 두 호버 실패는 `_set_card_detail→_show_offer`가 버튼을 교체한 직후 구 버튼 좌표를 읽던 검사 준비 오류였다. 새 버튼 레이아웃을 기다린 뒤 같은 강한 단언이 양쪽 통과했다. 초기 폰 특성 겹침은 주입한 협동 fixture의 `mp_act` 정리 누락이었다. 실제 남은 정보창 제목 잘림은 root가 중복 제목을 줄이거나 숨겨 수정했다. 초기 실패 자료는 [PC](pc-initial/native.log)·[폰](phone-initial/native.log)에 보존했다.

## BF-24: 자동 검사 통과와 실제 핵심 잘림을 분리

원래 card-writing 검사 자체는 양쪽 `failures=0`이었지만, 제품이 사용하는 실제 `Meta.fs(14)`·폭으로 3줄을 재계산하자 PC 4종·폰 8종의 요약이 잘렸다. 기존 검사는 폭을 고정 14pt로 계산하고 세 줄 말줄임 이후 핵심 수치/부정어의 존재를 검사하지 않았다. [PC before](card-writing-pc130-before/clipped-summary-review.json), [폰 before](card-writing-phone130-before/clipped-summary-review.json).

실제 열거 범위는 일반 카드 정의 49종(속성17·공격방식15·강화9·연계2·발동6)과 특성15종, 총 **64종**이었다. 구형 자동 조준 카드도 포함한다. 최초 요청의 62종으로 결과를 맞추지 않았다.

제품 변경은 `cards.gd:_card_simple`과 `perks.gd`의 앞면 metadata·새 `_perk_summary`뿐이다. root가 `CardDock.summary_text`에 `perk_summary` 우선 조회를 연결했다. 전체 설명용 `perk_desc`와 `_card_full/_perk_desc`는 유지했다. 두 전체 설명 함수가 HEAD와 같은지 [본문 해시](full-description-preservation.json)로도 확인했다.

- 유도: 피해 최저값을 Rules에서 읽고, `불가`와 벽·혼불·시계침·연쇄 번개 네 대상을 세 줄에 표시.
- 관통·블랙홀·모아 강타: 잘리던 뒤쪽 핵심을 세 줄로 정리. 관통의 피해·보호막·갑옷 수치는 실제 Rules를 사용.
- 조화: 감소 배율·한 번만·공격 속도 상한을 앞면에 표시.
- 동전: 새 특성 3개, 앞면 2회/뒷면 1회, 뒷면 새로고침 추가 수를 세 줄로 표시.
- 실드: 웨이브별 양·상한·피격 소모·다음 웨이브 이월 없음 표시.
- 성벽: 상한·벽 레벨합과 고른 횟수의 실제 계산 배율·밀쳐내기 표시.

최종 actual-font 결과는 **PC 64/64·폰 64/64 세 줄 이내**, 각 줄 실제 폭도 통과했다. 핵심 숫자·부정어가 보이는 세 줄에 남는지 별도 단언했다. 원래 전체 읽기·가로 overflow·상세 마지막 줄 도달 단언은 삭제하지 않았다. PC 162장·폰 165장의 native 캡처가 임시 출력에 생성됐으며 저장 위치는 manifest에 있다. 저장소에는 대표 8장씩만 남겼다.

| 증거 | PC 130% | 폰 130% |
|---|---|---|
| 실제 글꼴 64종 | [metrics](card-writing-pc130/summary-metrics.json) | [metrics](card-writing-phone130/summary-metrics.json) |
| 실행 로그 | [log](card-writing-pc130/native.log) | [log](card-writing-phone130/native.log) |
| 협공·4카드 | [협공](card-writing-pc130/link_pincer_summary.png) | [협공](card-writing-phone130/link_pincer_summary.png) |
| 잘리던 조건 | [특성](card-writing-pc130/perk_harmony.png) | [유도](card-writing-phone130/mod_homing_summary.png), [특성](card-writing-phone130/perk_harmony.png) |

격리 검사에서 Patch 값만 바꿔 동전+3·실드+2/상한5·성벽배율2/상한6·조화0.4/33%·유도42%·관통0.6/9%/30%/25%·협공13%/4초를 앞면에 반영하는 단언도 통과했다. 검사 종료 전 원래 Patch/Rules로 복원했다. 이는 외부 패치 서버·서명 수신 시험이 아니다. [PC patch proof](card-writing-pc130/patched-front-proof.json), [폰 patch proof](card-writing-phone130/patched-front-proof.json).

## 태블릿 RichText 의심 화면

2048×1536 / 130%에서 같은 dense inspector를 다시 만들고 실제 폭·최장 토큰을 기록했다. detail local 폭295px, content width294px, scroll303px·column295px(세로 막대 차이8px), 최장 unbreakable token74px, 폭 초과 토큰0. 가로 bar의 max와 page도 같았다. 첫 줄 끝 `혼불 소환` 뒤 `(영혼)`이 다음 줄로 이어지는 wrap이었다. 현재 사본에서 가로 잘림을 뒷받침하는 수치가 없어 제품을 추가 수정하지 않았다. [geometry](tablet130-richtext/richtext-geometry.json), [native 화면](tablet130-richtext/inspector-dense.png).

## 재실행과 한계

```sh
UI_SUFFIX=-final python3 docs/qa/2026-11-09-battlefield-fixes/usability/run_native.py
UI_CASES=usability UI_CASE=focused-preview UI_SUFFIX=-focused-revealed python3 docs/qa/2026-11-09-battlefield-fixes/usability/run_native.py
python3 docs/qa/2026-11-09-battlefield-fixes/usability/run_cards.py
```

`run_cards.py`는 원본 `card_writing_check.gd`를 고치지 않고 격리 사본에 실제 글꼴 metrics·64종/핵심 용어/패치 단언을 추가한다. 실행한 GDScript와 해시도 증거 폴더에 보존한다. PC는 세 번째 인자를 생략해 마우스 프로필로 실행한다(원래 도구는 인자가 있으면 touch로 간주).

독립 source 사본은 실행 종료 시 정리했다. 일부 native 종료의 ObjectDB 경고는 남으며 script runtime error와 구분했다. 실기기 손가락·OS 입력 지연·인터넷 멀티·실제 고객 과제 성공률은 이 검사 범위가 아니다. [네이티브 캡처 SHA-256](capture-manifest.json)을 함께 보존한다.
