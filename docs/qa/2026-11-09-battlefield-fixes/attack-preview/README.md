# 공격 예시를 요청한 자리에서 바로 읽기

2026-11-10. I-11 후속. [앞 단계](../inspector-reading/README.md)는 핵심 수치·고정 버튼을 개선했지만, 실제 ‘공격 예시’ 터치 뒤 애니메이션이 스크롤 아래에 남아89/REVISE였다. 이 작업은 명시적으로 요청한 예시의 전체 노출과 읽기 복귀를 다룬다.

## 동작

- 공격 예시를 펼치면 레이아웃 반영 뒤 예시의 시작으로 이동한다. 접으면 스크롤0의 핵심 수치로 돌아간다.
- 실제 예시 TextureRect는 원본320×180의16:9 비율을 유지하며 내용 폭·실제 스크롤 높이 안에 맞춘다. 정수 스크롤 위치와 소수점 크기 차이를 위한1논리 단위 여유를 둔다. 본 전장의 크기·카메라·예시 내부의320×180 렌더/전투 조건은 유지한다.
- ScrollContainer의 실제 내용 폭을 사용해 세로 스크롤바가 차지하는 폭을 반영한다. 예시 제목·전체 그림이 함께 들어가는지 실제 Control 좌표로 확인한다.
- 창 닫기·명시적 대상 선택·다시 토글하면 이전 노출 요청을 무효화한다. 같은 대상을 닫고 바로 다시 열어도 이전 callback이 새 읽기 세션을 스크롤하지 않는다. 대상·모드·인스턴스·가시성 확인도 유지한다.

## 증거와 범위

[계획·조건](plan.json), [현재 집계](summary.json), [현재 실제 iOS 실행](native-guarded/run.json), [앱/소스 해시](build-evidence/build.json), [import](build-evidence/import.log), [export](build-evidence/export.log), [Xcode](build-evidence/xcode.log). 생성기는 [별도 도구](../ios-runtime/prepare_app.py)를 사용한다.

두 실제 iOS Simulator의5배율×단일/다속성×좌/우 선택, 펼친 예시를 둔 스크롤0의40조건을 검사한다. 앞 단계의 같은40조건과 수치/라벨·카메라·전장·카드 횟수·오브젝트를 대조한다. 이 조건에서는 핵심 수치를 먼저 보는 상태이며, 실제 버튼으로 요청하는 노출 경로는 따로 실행한다.

기기별130% 다속성 상세에서 UIKit 펼침→직접 스크롤→접기를 실행한다. 펼침 뒤 예시 전체가 clip 안에 보이고, 접기 뒤 scroll=0과 수치 복귀를 검사한다. 각 동작 뒤 카드·오브젝트·기술 사용·phase도 그대로인지 확인한다. 입력/알림을 합성하지 않는 별도 bundle·운영 URL 없음·WebRTC 없는 custom ARM64 debug 앱이다. 물리 기기·release·멀티 증거는 아니다.

[현재 desktop2프로필](desktop-all-phases/run.json)은 실제 가상 GUI 클릭/터치로 WAVE/READY/CHOOSE와 빠른 토글·대상 변경·닫기·같은 대상 즉시 재열기·pending 중 scene 종료를 검사한다. [정보/카드 기존4묶음](compatibility/run.json), [전체 회귀](full-check.log)와 구분한다. desktop 폰은 모의 프로필이며 native iOS와 합산하지 않는다.

| 실제 사용 경로 | iPhone | iPad |
|---|---|---|
| 펼친 직후 | [화면](native-guarded/phone/native-expand.png) · [상태](native-guarded/phone/native-expand-state.json) · [입력](native-guarded/phone/native-expand.yaml) · [로그](native-guarded/phone/native-expand.log) | [화면](native-guarded/tablet/native-expand.png) · [상태](native-guarded/tablet/native-expand-state.json) |
| 직접 내려 읽기 | [상태](native-guarded/phone/native-scroll-state.json) | [상태](native-guarded/tablet/native-scroll-state.json) |
| 접어 수치 복귀 | [화면](native-guarded/phone/native-collapse.png) · [상태](native-guarded/phone/native-collapse-state.json) | [화면](native-guarded/tablet/native-collapse.png) · [상태](native-guarded/tablet/native-collapse-state.json) |

## 실패 원본과 한계

[중간 실패](intermediate-failures.json)를 보존한다. 첫 iOS 수정은 예시가 실제 clip보다 약1px 커서 실패했다. PC에서는 실제 GUI callback 이후 built-in reveal의 소수점/정수 스크롤 차이로 하단이1.2187viewport 단위 잘렸다. 포함 기준0.1을 그대로 유지하고 실제 내용 좌표로 시작을 맞춘다. `desktop-reopen-before`는 닫고 같은 대상을 즉시 다시 여는 경합을 실제 재현한 음성 대조다.

처음 desktop QA는 pending spawn 없는 WAVE가 delta0에서도 종료돼 카드 줄이 다시 떠 입력을 받았다. `callback=[]`, hovered CardDock 진단으로 fixture를 수정했다. 이는 제품 입력 차단 버그로 사용하지 않는다. 앞 단계와 같은 대기 생성1개/긴 타이머로 고정한 뒤 실제 버튼 callback과 경합을 재검증한다. 실패·의도 중단 원본은 삭제·덮어쓰지 않는다.

[native 관찰기](observer.gd)는 앞 단계의 실제 그리기 recorder와 동일한 fixture에 예시/제목 Rect2·렌더 크기 관찰만 추가했다. [native 실행기](run_native.py), [desktop 경합 검사](../../../../tools/battlefield_preview_check.gd), [desktop 실행기](run_desktop.py), [호환 검사 실행기](run_regressions.py).

시각 판정은 [새 round](visual-verdict.json)와 [관찰/공백](visual-review.json)을 따른다. Logger 양성 경고·기존 desktop 종료 경고는 runtime 오류와 구분한다. 사람의 이해도·실물 손가락·대비/색각·접근성·고배속 성능·독립2리뷰는 관측하지 않았다. 전체50개 목표와 BF-44–50의 물리/사람/성능 과제는 계속 별도다. 원본 전체가 Git에 포함되지는 않으며 [manifest](../publication-manifest.json)의 published 여부를 따른다.

최종 결과:40조건 위반0·200상태 비교 불일치0·제품70개 스크립트 해시 일치. 기기별 실제 펼침/스크롤/접기6동작과 desktop26단언·기존 정보/카드4묶음이 통과했다. 공통 명세252·전달86·parity345사례/4140표본·fuzz4×3000/exit0·복원W4/8/12→13·서버28도 통과했다. [일회성 아키텍처 비교](architecture-comparison.json)는 기존43·추가0이다. 앞 단계의89/REVISE는 그대로 보존하고, 이 소스/예시 읽기 범위의 새 판정은92/PASS다. 전체 목표는 완료가 아니다.
