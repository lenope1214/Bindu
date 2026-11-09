# 저장 없는 모바일 첫 실행의 기본 배율

2026-11-10. I-08 수정. 모바일 missing-key 기본값과 설명은1.3이지만 저장 파일이 없으면 `_load_best()`가 `Meta.load_into()`를 건너뛰어 static 초기값1.0으로 시작했다. 두 iOS Simulator의 실제 첫 실행에서1.0을 다시 확인했다.

제품 변경은 `Meta.ui_scale`의 static 초기값 한 줄이다. 모바일은1.3, desktop은1.0으로 시작한다. 기존 설정 파일의 유효한70/85/100/115/130% 값은 그대로 읽는다. 잘못된 저장값의 기존1.0 복구 규칙도 유지한다. 게임 진행·다른 설정·전장/카메라·버전/배포 설정은 변경하지 않는다.

## 실제 시작 경로

[현재 집계](summary.json), [수정 전2개 첫 실행](baseline/run.json), [현재16개 cold 시작](product/run.json), [현재 소스](build-evidence/product-build.json), [기준 소스](build-evidence/baseline-build.json).

기기마다 실제 프로세스를 종료한 뒤 새 PID로 다음8경우를 실행한다. `Meta.ui_scale`에 시험값을 직접 대입하지 않고, main이 시작되기 전 격리 앱의 best.cfg만 준비한다. 실제 `_load_best()` 이후의 값·UI root scale을 관찰한다.

| 시작 데이터 | 기대값 |
|---|---|
| 저장 파일 없음 | 모바일1.3 |
| 파일 있으나 배율 키 없음 | 기존 모바일 기본값1.3 |
| 저장한5개 유효 배율 | 각각 저장한 값 유지 |
| 잘못된0.93 저장 | 기존 복구 규칙1.0 유지 |

저장한 경우 게임 횟수7·음량0.37도 유지하는지 확인한다. 수정 전/후는 같은 observer·ARM64 debug 템플릿을 사용하고, 제품70개 스크립트 중 Meta 한 개만 바뀌었는지 검사한다. 최초 static 값과 파일 유무, main 로드 후 값, 실제 UI root scale, OS/mobile/template/debug 플래그, Logger도 기록한다. 기존 native QA bundle만 지우고 새 저장 공간을 사용한다. 사용자 실제 저장은 접근하지 않는다.

[폰 새 설치 이전](baseline/phone/fresh/screen.png) · [이후](product/phone/fresh/screen.png) · [상태](product/phone/fresh/state.json), [iPad 새 설치 이전](baseline/tablet/fresh/screen.png) · [이후](product/tablet/fresh/screen.png), [폰 저장85% 유지](product/phone/saved-0.85/state.json), [iPad 저장100% 유지](product/tablet/saved-1.0/state.json).

## 도구·회귀·한계

[관찰기](observer.gd), [native 실행기](run_native.py), [앱 생성기](../ios-runtime/prepare_app.py). observer는 격리 이름·빈 운영 URL을 확인한 뒤 해당 앱의 저장 fixture만 준비한다. main 실행 전에 Master audio를 일시적으로 mute하며 Meta의 음량 설정 자체를 바꾸지 않는다. 실제 시작 값을 읽고 카메라나 UI 배율을 덮어쓰지 않는다.

[현재 import](build-evidence/product-import.log), [export](build-evidence/product-export.log), [Xcode](build-evidence/product-xcode.log), [desktop 기본/설정 검사](desktop/run.json) · [상태](desktop/state.json), [전체 공통 회귀](full-check.log). desktop8단언은 실제 macOS headless 초기값·missing/유효5개/무효 설정 읽기이며 desktop GUI 증거는 아니다. 스크린샷은 최초 화면의 설정 적용을 보여 주는 증거이며 전체 onboarding의 시각/사용자 과제 통과가 아니다.

이 검증은 실제 iOS26.5 Simulator의 custom ARM64 debug 싱글 QA다. 물리 기기·Android·release·스크린리더·사람 판독 성공률은 미검증이다. 앞 단계의 [정보 읽기](../inspector-reading/README.md)152조건과 [예시 읽기](../attack-preview/README.md)40조건은 각 소스 단계의 결과이며 최신 Meta 수정 뒤 재실행했다고 주장하지 않는다. BF-44–50의 실기기/사람 과제·고배속/PERF-01과 전체 목표는 계속 별도다.

최종 결과: 기준2개 fresh 실행은1.0, 현재16개 cold 시작은 모두 기대값이었다. 같은 관찰기/엔진·제품70개 해시를 확인했고 변경 스크립트는 Meta 한 개다. desktop8단언과 공통 명세252·전달86·parity345사례/4140표본·fuzz4×3000/exit0·W4/8/12→13·서버28을 통과했다. 서버 경고1개·Logger 양성 경고는 별도 유지한다. [아키텍처 비교](architecture-comparison.json)는 기존43·추가0이다.
