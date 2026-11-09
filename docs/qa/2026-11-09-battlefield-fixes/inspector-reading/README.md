# 정보창의 핵심 수치와 고정 공격 예시 버튼

2026-11-10. I-09의 후속. 앞 단계의 읽기 리뷰88/REVISE에서 핵심 수치가 아래로 잘린 문제를 재현했다. 전장·카메라·전투 계산을 유지하고 읽는 순서와 정보창의 배너 회피만 수정한다. 실제 사용자의 이해도·실기기 검증 결과는 아니다.

## 바뀐 동작

공격방식 제목 바로 아래에 피해·공격 횟수·기본 공격 계산/초·치명타 또는 사거리의 네 수치를 둔다. 속성 칩이 많아져도 이 영역을 밀어내지 않는다. 속성·조준·지원·펼친 공격 예시·세부 계산은 그 뒤에 이어진다. 전체 정보 높이와 실제 수치 계산은 보존한다.

공격 예시 버튼은 스크롤 밖 하단에 고정한다. 긴 세부 정보를 내려 읽은 뒤에도 같은 자리에서 펼치고 접는다. 타일의 보조 라벨은 왼쪽 여백8부터 전체 폭을 써 긴 문구의 마지막 글자를 보존한다. 카드의 이전/다음/들기 버튼은 기존처럼 카드 정보 위에 남고, 표시할 버튼이 없는 줄은 접는다. 잠깐 뜨는 배너 아래로 창을 내릴 때 헤더·핵심 수치·고정 버튼이 들어갈 높이를 확보한다. 정보창이 기술 조작부 위에서 끝나는 규칙은 유지한다. 왼쪽 정보창을 오른쪽 경계로 오인해 웨이브 배너가 제목을 덮던 분기도 수정했다. 배너는 좌우 정보창을 구분하고 남은 가로 공간 안에 배치한다.

## 재현·검증

[검증 상태](verification.json), [계획과 조건 전수 목록](plan.json), [최종 집계](summary.json), [수정 전 실행](baseline-final/run.json), [수정 뒤 실행](final-verified/run.json), [대조 도구](compare.py).

- iPhone17 / iPad Pro11 M4, iOS26.5 Simulator. 기존 custom ARM64 debug 엔진, 운영 URL 비움·별도 bundle/저장·WebRTC 제외.
- 수정 전16조건 중14조건에서 수치/라벨 잘림을 관찰했다. 최종152조건의 지정한 수치/라벨/안전 영역/배너 겹침 위반은0이다. 같은16조건80개 상태 비교도 일치했다. 아래 숫자는 이 범위의 구조/내용 검사이며 전체 사용성 성공률이 아니다.

- 수정 전16조건: 두 기기 ×100/130% ×단일/다속성 ×좌/우 선택 ×WAVE 기본 읽기.
- 수정 뒤152조건: WAVE에서5배율 ×단일/다속성 ×좌/우 선택 ×기본/상세/공격 예시, READY·CHOOSE 전체 정보에서100/130% ×단일/다속성 ×좌/우 선택. 각 조건은 먼저12프레임을 기다린다. 웨이브 배너가 활성인 조건이며 일반 전투 부하나 전체 모션 검증이 아니다.
- 관찰기는 실제 `InfoPanel._tile` 그리기 호출의 네 Rect2와 라벨·수치를 기록한다. 예상 좌표를 검사기 안에 복제하지 않는다. 실제 ScrollContainer clip 안에 네 타일이 모두 들어가는지, 실제 라벨 글꼴/폭이 지정된 그리기 폭 안에 들어가는지, scroll=0인지, 정보창이 세 기술 조작부와 안전 영역을 지키는지, 웨이브 배너가 정보창과 겹치지 않는지도 검사한다.
- 같은16조건의 수치/라벨·카메라·전장·선택 횟수·오브젝트를 각각 대조한다. 공격 예시 펼치기→세부 정보 스크롤→예시 접기를 UIKit 터치로 별도 실행하며, 뒤 전장의 횟수·오브젝트·기술 사용·진행 상태도 보존하는지 확인한다.

## 화면과 입력

| 조건 | 수정 전 | 수정 뒤 |
|---|---|---|
| iPhone130 단일 속성 | [화면](baseline-final/phone/1.3-simple-wave-left-basic/screen.png) | [화면](final-verified/phone/1.3-simple-wave-left-basic/screen.png) · [실제 그리기/clip](final-verified/phone/1.3-simple-wave-left-basic/state.json) |
| iPhone130 다속성 | [화면](baseline-final/phone/1.3-dense-wave-right-basic/screen.png) | [화면](final-verified/phone/1.3-dense-wave-right-basic/screen.png) |
| iPad130 다속성 | [화면](baseline-final/tablet/1.3-dense-wave-left-basic/screen.png) | [화면](final-verified/tablet/1.3-dense-wave-left-basic/screen.png) |
| iPhone130 상세·예시 | — | [상세](final-verified/phone/1.3-dense-wave-left-detail/screen.png) · [예시](final-verified/phone/1.3-dense-wave-left-preview/screen.png) |

실제 터치: [iPhone 펼침](final-verified/phone/native-expand-state.json) · [스크롤](final-verified/phone/native-scroll-state.json) · [접기](final-verified/phone/native-collapse-state.json), [iPad 펼침](final-verified/tablet/native-expand-state.json) · [스크롤](final-verified/tablet/native-scroll-state.json) · [접기](final-verified/tablet/native-collapse-state.json). [iPhone 최종 화면](final-verified/phone/native-collapse.png), [iPad 최종 화면](final-verified/tablet/native-collapse.png). 플랫폼 터치나 알림을 합성하지 않는다.

## 빌드·회귀·한계

[관찰 코드](observer.gd), [native 실행기](run_native.py), [읽기 확대 모음 생성기](make_contacts.py)와 [macOS 이미지 도구](contact_sheet.swift), [앱 생성기](../ios-runtime/prepare_app.py). 생성기의 `--source-ref`는 로컬 Git commit의 보관본으로 baseline을 만든다. 현재 checkout을 바꾸지 않는다. 수정 전/후에 같은 관찰기·엔진을 쓰고 원래 제품70개 스크립트 해시, QA/pack/app 해시를 구분한다. build의 source_ref는 기준 commit이며 미커밋 제품 패치는 스크립트 해시로 식별한다.

[baseline 빌드](build-evidence/final-baseline-build.json), [제품 빌드](build-evidence/verified-product-build.json), [제품 import](build-evidence/verified-product-import.log), [제품 export](build-evidence/verified-product-export.log), [제품 Xcode](build-evidence/verified-product-xcode.log), [iPhone 설치 해시](final-verified/phone/installed-hashes.json), [iPad 설치 해시](final-verified/tablet/installed-hashes.json).

[공통 전체 검사](full-check.log): 명세252·전달 상태86·parity345사례/4140표본·fuzz4×3000/exit0·W4/8/12→13·서버28개. 서버 경고1개는 유지한다. [desktop4묶음](desktop-verified/run.json)은 정보/진행 PC130·폰 모의130에서 통과한다. [카드 읽기/정지/복원2묶음](card-regression-verified/run.json)도 같은 최종 소스에서 실행했다. 기존 폰 설정 모달의 ui=8과 desktop ObjectDB 종료 경고는 별도 기록이며 전체 경고0으로 합치지 않는다. [일회성 아키텍처 비교](architecture-comparison.json)는 기존43·추가0이다.

첫 [버튼 없는 baseline](baseline/run.json)과 [중간 제품 실행](product/run.json)은 base lifecycle fixture가 기술 세트를 초기화하지 않은 조건이었다. 실제 세 기술 버튼 조건의 증거로 쓰지 않는다. 이 범위 공백을 확인하고 제품 중간 실행을 의도적으로 중단했다. [중단·수정 사유](fixture-correction.json). [기술 버튼을 켠 중간 제품](product-skills/run.json)도130%에서 둘째 수치 줄 하단과 긴 라벨이 잘려 채택하지 않았다. [발견·중단 기록](intermediate-reading-failure.json)을 남기고, 고정 버튼 앞 간격과 라벨 내부 여백을 수정했다. [다음 중간 실행](final-native/run.json)은 네 타일/라벨이 보였으나 왼쪽 정보창 제목을 웨이브 배너가 덮어 채택하지 않았다. [실제 발견 기록](banner-overlap-discovery.json)을 남기고 배너/정보창 겹침·안전 영역 검사를 추가했다. 모든 원본은 보존하고 최종 비교는 `baseline-final`/`final-verified`만 사용한다. 관찰 timeout을 실패로 삼거나 통과 기준을 낮추지 않았다.

스크린샷의 읽기 판정은 [새 round](visual-verdict.json)와 [관찰·공백](visual-review.json)에 분리한다. 네 타일의 clip 통과는 사람의 판독·접근성·대비·키보드·전체 앱 시각 품질·물리 손가락 성공을 증명하지 않는다. 독립 리뷰2회/높은 신뢰도 주장은 없다. 첫 설치 배율 I-08, BF-44–50의 실기기/사람 과제, 고배속/PERF-01은 계속 별도다.

## 실제 버튼 사용에서 추가 발견

[I-11](preview-followup.json):130% 다속성 상세에서 공격 예시를 누르면 버튼은 ‘예시 접기’로 바뀌지만, 실제 예시는 스크롤 아래에 남는다. 위 native 펼침 화면과 scroll=0에서 직접 확인했다. 핵심 수치/고정 버튼의 구조 통과와 요청한 예시를 바로 볼 수 있는지는 구분한다. 예시 영역180은 이 조건의 스크롤 높이146보다도 커서 단순 auto-scroll만으로 전체 예시를 보여 주는 해결을 확정하지 않는다. 별도 표시 방식·대상 변경/닫기 경계를 검토하고 같은 native 경로를 다시 실행해야 한다. 전체 목표와 시각 읽기 흐름은 REVISE로 유지한다.

재실행은 격리 앱 생성기의 `--source-ref <읽기 수정 commit>`와 이 폴더의 observer를 사용한다. `run_native.py --devices <owned Reading devices.json> --build <build.json> --output <새 빈 폴더> --full --require-pass` 뒤 `compare.py`로 baseline16/제품152를 대조한다. 현재 checkout이 해당 제품 소스와 다르면 비교기가 실패한다. 로컬 원본 중 일부만 PR에 포함하며 포함 여부는 [게시 manifest](../publication-manifest.json)를 따른다.

native 실행 흐름: [폰 펼침](final-verified/phone/native-expand.yaml) · [로그](final-verified/phone/native-expand.log), [폰 스크롤](final-verified/phone/native-scroll.yaml) · [로그](final-verified/phone/native-scroll.log), [폰 접기](final-verified/phone/native-collapse.yaml) · [로그](final-verified/phone/native-collapse.log), [태블릿 펼침](final-verified/tablet/native-expand.yaml) · [로그](final-verified/tablet/native-expand.log), [태블릿 스크롤](final-verified/tablet/native-scroll.yaml) · [로그](final-verified/tablet/native-scroll.log), [태블릿 접기](final-verified/tablet/native-collapse.yaml) · [로그](final-verified/tablet/native-collapse.log).
