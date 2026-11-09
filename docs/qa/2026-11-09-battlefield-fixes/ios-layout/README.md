# 기술 조작부의 정보창·선택 안내 겹침과 첫 표시

2026-11-10. BF-37·40·50의 후속. 실제 iOS Simulator 화면에서 찾은 세 문제를 수정했다. 같은 전장/카메라를 유지하며 정보창·안내·기술 조작부의 배치를 정리한다. 실기기·사람 과제의 완료 선언은 아니다.

## 재현과 변경

- **I-05 / P1:** 전투 중 오브젝트 정보를 열면 정보창 하단이 ‘기술: 수동/자동’ 버튼과 겹친다. 원래 회피 목록은 두 기술 버튼만 포함했다. iPhone/iPad 100·130%,3기술 세트의 옵션 줄 닫힘에서12건 재현했다.
- **I-06 / P2:** 처음 보이는 기술 버튼은 정상 테두리가 없다. 아직 없는 `armed` 메타값을 false로 읽어 초기화까지 건너뛰었다. 첫 표시에도 기존 정상2px/조준3px 표면을 적용하고, 상태가 같은 뒤 프레임의 캐시는 유지한다.
- **I-07 / P2:** 130%에서 오브젝트 선택 안내의 오른쪽 끝이 기술 버튼 밑으로 들어간다. 원문·아래쪽 간격을 유지하면서 기술 왼쪽으로 옮기고, 폭이 모자라면 기존 줄바꿈으로 접는다. 원래122장면 원자료를 추가 검사하면12건이다.

`skill_controls()`가 기술2개와 모드 버튼을 함께 반환한다. 정보창·이동 패널·길목 배지·연속 진행 표시가 이 전체를 피하며, 같은 프레임의 조작부 배치 뒤 정보창을 놓는다. 정보창은 기술 조작부 위에서 끝나고 남은 내용은 기존 스크롤로 읽는다. 처음 적용되는 정상 표면의 여백에 따라 자연 최소 폭이 조금 달라질 수 있으나, 전장/카메라를 공간 확보 수단으로 바꾸지 않는다.

## 실제 검사 범위

[계획·조건·공백](plan.json), [수정 전 집계](baseline-summary.json), [최종 전수 비교](summary.json), [검사 범위/소스 확인](verification.json), [baseline 실행](baseline-measured/run.json), [현재 실행](final-native/run.json), [baseline 실행 소스](baseline-measured/source-build.json), [현재 실행 소스](final-native/source-build.json).

- iPhone17 / iPad Pro11 M4, iOS26.5 Simulator. custom ARM64 debug 엔진·별도 bundle/저장 공간, 운영 URL 비움·WebRTC 제외. 물리 기기·release 검증은 아니다.
- 수정 전122장면:2기기 ×100/130% ×3기술 세트 ×준비/재사용 대기/첫째 조준/둘째 조준/정보창 ×옵션 줄 닫힘/열림 +기기별 기본 진입1장면.
- 최종302장면: 위 조건을70/85/100/115/130%로 확장했다. 버튼·안전 영역·기술/모드 버튼 문구 폭/높이·정보창/선택 안내/조작부 겹침·첫 정상 표면을 검사했다. 최종302장면의 이 위반은0이다.
- 조건이 같은122장면에서 전장1280×720·카메라·UI 안전 영역·오브젝트/선택수를 비교했다. 현재 제품70개 GDScript 해시를 checkout과 대조하고 원래0f9fe31 대비 실제 변경4개만 확인한다.
- 양 기기에서 UIKit 터치5회로 붙잡기 선택→낙인 선택→재선택 취소→자동→수동을 실행한다. observer의 pressed callback·native touch10이상·상태/카드/오브젝트 보존을12개 단언으로 확인한다. 적이 없는 fixture여서 자동 기술은 발동하지 않는다.

구조 검사302장면은 통과했지만, I-09의 핵심 수치 읽기 때문에 시각 리뷰는88/REVISE로 유지한다. 다음 읽기 구조 수정과 같은 조건 재캡처가 필요하다. 기술/모드/정보창에 한정한 시각 verdict는 [수정 전](visual-baseline-verdict.json)과 [수정 뒤](visual-final-verdict.json), [근거·공백](visual-review.json)을 따른다. 별도 독립 리뷰2회·접근성/대비/물리 손가락·사람 인지 성공률은 없다. 점수는 전체 제품/접근성 점수가 아니다.

## 화면과 직접 입력 증거

| 조건 | 수정 전 | 수정 뒤 |
|---|---|---|
| iPhone100, 정보창/모드 | [화면](baseline-measured/phone/100-set0-inspected-closed/screen.png) · [좌표](baseline-measured/phone/100-set0-inspected-closed/state.json) | [화면](final-native/phone/100-set0-inspected-closed/screen.png) · [좌표](final-native/phone/100-set0-inspected-closed/state.json) |
| iPhone130, 선택 안내 | [화면](baseline-measured/phone/130-set0-inspected-closed/screen.png) | [화면](final-native/phone/130-set0-inspected-closed/screen.png) |
| iPad130, 정보창/모드 | [화면](baseline-measured/tablet/130-set0-inspected-closed/screen.png) | [화면](final-native/tablet/130-set0-inspected-closed/screen.png) |
| 첫 기술 표면 | [iPhone](baseline-measured/phone/native-set0-ready-closed/screen.png) | [iPhone](final-native/phone/native-set0-ready-closed/screen.png) · [스타일/좌표](final-native/phone/native-set0-ready-closed/state.json) |

직접 터치: [iPhone callback/원자료](final-native/phone/native-controls-state.json), [flow](final-native/phone/native-controls.yaml), [JUnit](final-native/phone/native-controls-junit.xml), [iPad callback/원자료](final-native/tablet/native-controls-state.json), [flow](final-native/tablet/native-controls.yaml), [JUnit](final-native/tablet/native-controls-junit.xml). [전체 콘솔](final-native.log).

전투는 유효한2오브젝트 판을 준비하고 다음 생성 타이머를 길게 고정한다. 여덟 프레임 뒤 Container 배치를 관찰하며 웨이브 진입 배너가 보일 수 있다. 일반 전투 부하·입력 지연·전체 모션 검증은 아니다. 원본 PNG의 전체 pixel 동일성을 주장하지 않고, 정한 조작부/정보창의 좌표와 문구를 판정한다.

## 검사 도구와 소스 일치

[관찰 코드](observer.gd)는 격리 앱에서만 autoload하는 [기존 lifecycle observer](../../../../tools/battlefield_ios_runtime_probe.gd)를 상속한다. 일반 게임 import에 들어가지 않도록 이 증거 폴더 안에 둔다. [앱 생성기](../ios-runtime/prepare_app.py)의 선택적 `--probe`로 바꿔 끼우며 기본 lifecycle 동작은 보존한다. 플랫폼 알림·ScreenTouch를 합성하지 않는다.

[baseline build/소스 해시](build/baseline-build.json), [최종 build/소스 해시](build/final-build.json), [최종 import](build/final-import.log), [export](build/final-export.log), [Xcode build](build/final-xcode.log). 엔진·SDK·출처와 템플릿 아키텍처의 한계는 [앞 단계](../ios-runtime/README.md)를 따른다. 각 앱의 product source SHA와 QA/pack/app/template SHA를 구분한다. [실제 설치 앱의 pack/실행 파일 해시](installed-lineage.json)도 빌드 기록과 일치한다. build의 source_ref는 빌드 당시 HEAD이며, 제품 패치는 별도 소스 해시로 연결한다.

초기 `before`는 Font 기본 줄 측정이 버튼의 줄 끝 공백 trim과 달라7단위 안팎의 오탐을 냈다. Button과 같은 mandatory/trim·언어·방향의 TextParagraph 측정으로 맞춘 뒤 `baseline-measured`를 다시 실행했다. 이 오탐을 제품 글자 잘림으로 쓰지 않는다. `product-native`는 선택 안내 겹침을 발견한 중간 소스라281장면 뒤 의도적으로 중단했고, 모든 원본을 남겼다. 최종 집계에는 넣지 않는다. [중단 기록](intermediate-stop.json).

추가 배치 함수의 Rect2 타입 선언 누락도 [import 실패](build/hint-type-error-import.log)에서 검출해 수정했다. 그 실행과 혼합/실패한 공통 검사는 채택하지 않고 현재 소스로 새로 빌드·검사했다.

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/ios-runtime/prepare_app.py --workdir /tmp/bindu-ios-layout-new --ios-template /tmp/bindu-ios-debug-sim.zip --probe docs/qa/2026-11-09-battlefield-fixes/ios-layout/observer.gd
# 별도 두 Simulator를 BinduUsabilityQA-Layout-로 시작하는 이름으로 만들고 부팅한다.
# devices.json: [{"profile":"phone","udid":"..."},{"profile":"tablet","udid":"..."}]
python3 docs/qa/2026-11-09-battlefield-fixes/ios-layout/run_native.py --devices /tmp/bindu-layout-devices.json --app /tmp/bindu-ios-layout-new/derived/Build/Products/Debug-iphonesimulator/BinduIOSQA.app --output /tmp/bindu-layout-new
python3 docs/qa/2026-11-09-battlefield-fixes/ios-layout/compare.py --baseline docs/qa/2026-11-09-battlefield-fixes/ios-layout/baseline-measured --product /tmp/bindu-layout-new --output /tmp/bindu-layout-summary-new.json
python3 docs/qa/2026-11-09-battlefield-fixes/ios-layout/run_desktop.py --output /tmp/bindu-layout-desktop-new
```

compare는 baseline122와 현재302의 원자료를 요구한다. 중간 PNG/상태 전부를 Git에 넣지는 않았으므로 clone에는 baseline 원자료가 부족할 수 있다. `publication-manifest.json`의 published 여부로 구분한다. baseline 앱/관찰 소스는 해시와 함께 기록하며 동일 baseline 재현은 해당 snapshot으로 실행한다. 현재 source는 바뀐 checkout에서 실행하면 비교가 실패하도록 한다.

## 공통 회귀와 fuzz 진단

[최종 공통 검사](full-check-verified.log), [desktop4묶음](desktop-verified/run.json), [desktop import](desktop-verified/import.log). 공통 검사는 명세252·전달 상태86·parity345사례/4140표본·fuzz4×3000프레임·W4/8/12 복원→13·서버28개를 통과했다. 서버 경고1개와 desktop 종료의 기존 ObjectDB 경고는 별도 원자료에 유지한다. 폰 모의 flow의 설정 모달과 뒤 HUD 겹침8건(ui=8)은 이전과 같은 의도된 모달 경고이며 나머지3묶음은 ui=0이다. 전체 UI 경고0으로 합치지 않는다. iOS Logger에는 양성 대조 경고1개가 있어 ‘전체 경고0’ 주장이 아니다. [일회성 감사](architecture.log)는 기존43개가 남고 [새 미검토0](architecture-comparison.json)이며 runtime 경계 검사 통과와 다르다.

이전 [full-check-final.log](full-check-final.log)의 fuzz는 오류0이지만 완료/exit 표식이 모자라 실패했다. 원래 도구가 원자료를 지워 정확한 시드·실제 종료 원인은 모른다. [입력 변경 없는 별도4시드 관찰](fuzz-observed/run.json)은 모두3000프레임·exit0이고 종료 버튼 입력은 없었다. 원래 실패의 원인을 확정하는 증거로 쓰지 않는다.

17번째 커밋은 fuzz 진단만 개선했다. 실제 exit code·완료 프레임을 출력하고 실패 원본을 보존한다. 완료 없는 fake 프로세스가 exit0이어도 실패를 유지하며 입력·기준을 완화하지 않는다. [양성/음성/경로 검사](fuzz-wrapper/run.json), [음성 fixture](fuzz-wrapper/incomplete_godot.sh), [기본 실패 보존 콘솔](fuzz-wrapper/negative-default.log). 이후 같은 제품의 전체 check를 다시 통과했고 단계별 실패를 덮어쓰지 않았다. 성공한 check의 임시 원본은 기존 정책대로 삭제되지만 console에4시드의 DONE/exit가 남는다.

[시험 Simulator/앱 정리](cleanup.json). 실제 사용자 저장·기존 Simulator·배포·버전은 바꾸지 않았다. 실제 기기·사용자 과제·고배속/PERF-01과 아래 첫 설치 설정은 미완료다.

## 다음 발견

**I-08 / P2, 미수정:** 저장 없는 첫 iOS 진입의 배율은1.0이다. 코드의 모바일 missing-key 기본값/주석은1.3이지만, `_load_best()`가 저장 파일이 없을 때 `Meta.load_into()`를 건너뛴다. [새 설치 기본 진입 원자료](final-native/phone/native-set0-ready-closed/state.json). 실제 사람의 판독 실패를 관측했다고 주장하지 않는다. 첫 설치와 기존 사용자 선택을 분리해 후속 검증·수정한다. BF-50과 전체50개 목표는 active/partial을 유지한다.

**I-09 / P2, 읽기 후속:** [iPad130 정보창](final-native/tablet/130-set0-inspected-closed/screen.png)에서는 핵심 수치 일부가 스크롤 아래에 남는다. 정보창을 조작부 위에서 끝내는 현재 배치의 제약이다. 이번 버튼 문구/겹침 통과를 정보 읽기 과제 성공으로 확대하지 않는다. 핵심 수치를 먼저 읽는 구조와 예시/부가 정보의 노출을 추가 검토한다. 실제 사람의 실패율·시간은 미측정이다.

이 단계의88/REVISE는 위 snapshot의 판정으로 보존한다. 이후 핵심 수치·고정 공격 예시 버튼·라벨 잘림을 다루는 [별도 수정과 재검증](../inspector-reading/README.md)으로 이어진다.
