# 실제 iOS Simulator 중단·복귀·프로세스 재실행

2026-11-10. BF-07·BF-47의 증거를 합성 focus 알림에서 실제 iOS Simulator UIKit 경로로 확장한다. **실기기 완료는 아니다.** 제품 소스는 변경하지 않고 격리 QA 앱·관찰 도구만 추가한다.

## 검사 구조와 범위

- iPhone17 Simulator / iOS26.5, Xcode27.2(27B52), Simulator SDK27.2, Godot4.7.2 소스 `ed1daf0bf001b61586d9930840f2f1394092c079`, Maestro2.11.0. [실제 환경](bootstrap/environment.json).
- 제품70개 GDScript의 원본 해시를 기록한다. 복사본의 운영 URL 두 개만 비우고 WebRTC 확장을 복사하지 않는다. QA bundle `dev.bindu.usabilityqa.lifecycle`, 앱 이름 `BinduToolsIOSLifecycle`과 저장 공간을 별도로 사용한다. [첫6상태 앱·소스·PCK·엔진 해시](bootstrap/adopted-build.json), [연속 재검사 앱/관찰 코드 해시](bootstrap/continuous-build.json). 두 앱은 같은 제품70개 소스를 쓰며 QA 관찰 코드만 다르다. [첫 관찰 코드](bootstrap/adopted-monitor.gd), [READY 관찰 추가 코드](bootstrap/continuous-monitor.gd)를 각각 해시와 함께 보존한다.
- [관찰 autoload](../../../../tools/battlefield_ios_runtime_probe.gd)는 유효한 싱글 판을 준비하고 실제 알림·입력·저장·오류를 기록한다. 플랫폼 알림이나 `ScreenTouch`를 합성 주입하지 않는다. 전투는 생성 타이머를 길게 고정하므로 전투 부하/성능 시험이 아니다.
- 실제 설정 앱으로 전환하고 다시 foreground한다. 같은 PID에서 UIKit PAUSED2015/FOCUS_OUT2017와 RESUMED2014/FOCUS_IN2016을 관측한다. [호스트 실행기](run_lifecycle.py).
- XCTest를 쓰는 Maestro가 실제 재개 버튼을 누른다. `launchApp.stopApp:false`로 프로세스를 보존하고, native 방향을 LANDSCAPE_RIGHT로 맞춘 후 실제 UI 좌표를 사용한다.
- `simctl terminate` 후 새 프로세스로 시작하고 실제 ‘이어하기’ 타일을 눌러 디스크 저장을 복원한다. 시스템 메모리 압박 종료(Jetsam), 기기 잠금, 전화/시스템 시트와는 다른 시험이다.
- 명시적으로 고른 기술 조준 모드는 복귀 뒤 유지한다. 재개 버튼은 기술 사용/카드 적용으로 새지 않는다. 손가락을 누른 채 중단해 release가 유실되는 물리 과제는 이 시험에 없다.

## 채택한 결과

[첫6상태 실행](native-adopted/run.json)과 [연속 전투 재검사](native-continuous/run.json), [독립 원자료 검사·집계](summary.json)를 함께 채택한다. 첫 실행의 연속 복원 관측 실패는 [콘솔](native-adopted.log)에 보존하고, 통과한6상태만 집계한다. [연속 재검사 콘솔](native-continuous.log). CHOOSE/PLACE/AIM/READY/WAVE/기술 조준/연속 전투 **7상태129개 native 단언**과 저장한 원자료의 bank/skip/조준 모드35개 추가 단언을 분리한다.

같은 프로세스로 돌아오면 명시적 재개 전까지 정지를 유지한다. 카드/오브젝트/웨이브/기술 사용을 자동 변경하지 않으며, 재개 터치는 전장에 적용되지 않는다. 전투 중 중단은 마지막 쉬는 시간의 저장 해시를 덮어쓰지 않는다. 실제 프로세스 종료 후 새 PID에서 기존 선택지 또는 준비 상태, 웨이브/선택수/오브젝트 수와 보류 카드를 복원한다. 연속 진행은 제품의 기존 정책대로 READY 복원 뒤1초 후 전투를 재개한다. native 도구 반환 시점에는 이미 WAVE일 수 있으므로, 제품 이어하기 callback 직후의 READY를 관찰만 하는 signal listener로 기록한다.

in-app Logger에는 프로세스마다 양성 대조용 `BinduIOSQA logger probe` 경고가 있다. **경고0 주장이 아니다.** 기록된 runtime 오류·예상하지 못한 경고는0이다. `Logger._log_error` 관측 범위이며 기기 전체 시스템 로그, 모든 엔진 `_log_message`, native crash 수집의 완전성을 뜻하지 않는다.

[전체 회귀 로그](full-check.log), [exit0](full-check-exit.txt): 명세252·전달 상태86·parity345사례/4140표본·fuzz4·W4/8/12 복원→13·서버28개 통과. 서버 경고1개는 로그에 유지한다. 이전 일회성 아키텍처 감사의 기준 main43개 부채는 이 runtime 경계 검사와 구분한다.

대표 실제 화면: [AIM 복귀 정지](native-adopted/aim/returned.png), [새 프로세스 시작 화면](native-adopted/wave/restarted.png), [연속 진행 복원](native-continuous/continuous/restored.png).

## 빌드 장애와 재현

설치된 공식 iOS Simulator archive는 XCFramework plist에 ARM64를 표기했지만 실제 라이브러리는 x86_64였다. ARM64 link의 `_main` 실패와 x86 빌드 후 설치 거절은 제품 코드 결함으로 분류하지 않는다. [아키텍처 증거](bootstrap/architecture.txt), [실패 분류·수정·검증 경계](bootstrap/triage.json), [linker 실패 발췌·생략 경계](bootstrap/failure-digest.txt).

공식 버전의 iOS ZIP만 HTTP range로 내려받아 inner CRC와 SHA-256을 기록했다. 전체 TPZ SHA-256은 검증하지 않았다. [원본 출처/해시](bootstrap/template-source.json). 같은 엔진 소스에서 ARM64 debug Simulator 라이브러리를 직접 빌드해 debug slice와 그 plist만 바꿨다. release/device 항목은 보존한다. [실제 엔진 빌드 명령](bootstrap/arm64-build-command.txt), [빌드 exit0](bootstrap/arm64-engine-build-exit.txt), [템플릿/라이브러리 해시](bootstrap/reproduced-template.json).

정리된 `build_template.py`를 실행해 같은 템플릿 SHA를 재현했고, `prepare_app.py`로 새 앱을 export/build해 설치한 것이 첫6상태 cohort다. 연속 진행에는 제품 callback 직후 READY 관찰만 추가한 앱을 새로 빌드했다. [실제 import](bootstrap/adopted-import.log), [export](bootstrap/adopted-export.log), [Xcode build](bootstrap/adopted-xcode.log), [연속 관찰 앱 Xcode build](bootstrap/continuous-xcode.log). export는 원본 프로젝트 밖에 둔다. 템플릿 ZIP·엔진 checkout·앱 바이너리·DerivedData는 Git에 넣지 않는다.

```sh
python3 docs/qa/2026-11-09-battlefield-fixes/ios-runtime/fetch_template.py --output /tmp/bindu-ios-official-new
# 공식 Godot 소스의 위 SHA checkout과 SCons4.11.1 실행 파일을 준비한다.
python3 docs/qa/2026-11-09-battlefield-fixes/ios-runtime/build_template.py --source /tmp/godot-4.7.2 --scons /tmp/ios-build-venv/bin/scons --official-template /tmp/bindu-ios-official-new/ios.zip --output /tmp/bindu-ios-debug-sim-new.zip
python3 docs/qa/2026-11-09-battlefield-fixes/ios-runtime/prepare_app.py --workdir /tmp/bindu-ios-app-new --ios-template /tmp/bindu-ios-debug-sim-new.zip
# 별도 Simulator를 BinduUsabilityQA로 시작하는 이름으로 생성·부팅한다.
# UDID에는 이 시험용 Simulator만 지정한다. iOS26.5 runtime 설치가 필요하다.
xcrun simctl install "$QA_UDID" /tmp/bindu-ios-app-new/derived/Build/Products/Debug-iphonesimulator/BinduIOSQA.app
xcrun simctl launch "$QA_UDID" dev.bindu.usabilityqa.lifecycle
python3 docs/qa/2026-11-09-battlefield-fixes/ios-runtime/run_lifecycle.py --udid "$QA_UDID" --output /tmp/bindu-ios-lifecycle-new
python3 docs/qa/2026-11-09-battlefield-fixes/ios-runtime/summarize.py --run /tmp/bindu-ios-lifecycle-new --output /tmp/bindu-ios-lifecycle-summary-new.json
```

각 출력 폴더는 새 빈 경로를 요구한다. 실행 뒤 시험용 앱/Simulator만 정리한다. [채택 Simulator 정리 기록](cleanup.json). Python 도구의 문법 검사도 통과했다. `fetch_template.py`의 원래 다운로드를 실행했고 CLI 정리 후에는 문법 검사를 했으며 동일 네트워크 다운로드를 반복하지 않았다.

초기 `native-first`/`native-smoke`/`native-matrix`는 cold-start 좌표가 정렬되기 전이라 실패했다. `native-final`은6상태만 통과하고 연속 진행 fixture의 READY→WAVE 가정 오류로 중단됐다. 이 중간 실행은 전체7상태 통과 증거에 합산하지 않는다. `native-adopted`의 마지막 연속 진행은 READY 복원 후1초가 지나 WAVE가 된 상태를 기존 wait 조건이 놓쳤다. 실패를 보존하고 READY 전환 관찰을 추가한 단일 상태 재검사로 분리했다. 원자료는 publication manifest에 해시와 로컬 전용 여부로 보존한다. 최초 fractional 좌표·방향 오류와 수정 전 합성 held-input 시도도 채택 cohort에서 제외했다.

[Godot의 iOS Simulator/Compatibility 안내](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html), [Maestro의 기존 프로세스 foreground 옵션](https://docs.maestro.dev/reference/commands-available/launchapp), [방향 지정](https://docs.maestro.dev/reference/commands-available/setorientation).

실기기 iOS/Android, 손가락 가림/떨림·release 유실, 잠금·전화·Jetsam, 실제 release·WebRTC·인터넷·성능·사람 과제는 미검증이다. BF-47과 전체50개 목표는 partial/active를 유지한다.

## 상태별 원자료

- choose: [before](native-adopted/choose/before.json), [background](native-adopted/choose/background.json), [returned](native-adopted/choose/returned.json), [resumed](native-adopted/choose/resumed.json), [restarted](native-adopted/choose/restarted.json), [restored](native-adopted/choose/restored.json); [resume JUnit](native-adopted/choose/resume-junit.xml), [resume flow](native-adopted/choose/resume.yaml), [foreground JUnit](native-adopted/choose/foreground-junit.xml), [foreground flow](native-adopted/choose/foreground.yaml), [continue JUnit](native-adopted/choose/continue-junit.xml), [continue flow](native-adopted/choose/continue.yaml).
- place: [before](native-adopted/place/before.json), [background](native-adopted/place/background.json), [returned](native-adopted/place/returned.json), [resumed](native-adopted/place/resumed.json), [restarted](native-adopted/place/restarted.json), [restored](native-adopted/place/restored.json); [resume JUnit](native-adopted/place/resume-junit.xml), [resume flow](native-adopted/place/resume.yaml), [foreground JUnit](native-adopted/place/foreground-junit.xml), [foreground flow](native-adopted/place/foreground.yaml), [continue JUnit](native-adopted/place/continue-junit.xml), [continue flow](native-adopted/place/continue.yaml).
- aim: [before](native-adopted/aim/before.json), [background](native-adopted/aim/background.json), [returned](native-adopted/aim/returned.json), [resumed](native-adopted/aim/resumed.json), [restarted](native-adopted/aim/restarted.json), [restored](native-adopted/aim/restored.json); [resume JUnit](native-adopted/aim/resume-junit.xml), [resume flow](native-adopted/aim/resume.yaml), [foreground JUnit](native-adopted/aim/foreground-junit.xml), [foreground flow](native-adopted/aim/foreground.yaml), [continue JUnit](native-adopted/aim/continue-junit.xml), [continue flow](native-adopted/aim/continue.yaml).
- ready: [before](native-adopted/ready/before.json), [background](native-adopted/ready/background.json), [returned](native-adopted/ready/returned.json), [resumed](native-adopted/ready/resumed.json), [restarted](native-adopted/ready/restarted.json), [restored](native-adopted/ready/restored.json); [resume JUnit](native-adopted/ready/resume-junit.xml), [resume flow](native-adopted/ready/resume.yaml), [foreground JUnit](native-adopted/ready/foreground-junit.xml), [foreground flow](native-adopted/ready/foreground.yaml), [continue JUnit](native-adopted/ready/continue-junit.xml), [continue flow](native-adopted/ready/continue.yaml).
- wave: [before](native-adopted/wave/before.json), [background](native-adopted/wave/background.json), [returned](native-adopted/wave/returned.json), [resumed](native-adopted/wave/resumed.json), [restarted](native-adopted/wave/restarted.json), [restored](native-adopted/wave/restored.json); [resume JUnit](native-adopted/wave/resume-junit.xml), [resume flow](native-adopted/wave/resume.yaml), [foreground JUnit](native-adopted/wave/foreground-junit.xml), [foreground flow](native-adopted/wave/foreground.yaml), [continue JUnit](native-adopted/wave/continue-junit.xml), [continue flow](native-adopted/wave/continue.yaml).
- skill: [before](native-adopted/skill/before.json), [background](native-adopted/skill/background.json), [returned](native-adopted/skill/returned.json), [resumed](native-adopted/skill/resumed.json), [restarted](native-adopted/skill/restarted.json), [restored](native-adopted/skill/restored.json); [resume JUnit](native-adopted/skill/resume-junit.xml), [resume flow](native-adopted/skill/resume.yaml), [foreground JUnit](native-adopted/skill/foreground-junit.xml), [foreground flow](native-adopted/skill/foreground.yaml), [continue JUnit](native-adopted/skill/continue-junit.xml), [continue flow](native-adopted/skill/continue.yaml).
- continuous: [before](native-continuous/continuous/before.json), [background](native-continuous/continuous/background.json), [returned](native-continuous/continuous/returned.json), [resumed](native-continuous/continuous/resumed.json), [restarted](native-continuous/continuous/restarted.json), [restored](native-continuous/continuous/restored.json); [resume JUnit](native-continuous/continuous/resume-junit.xml), [resume flow](native-continuous/continuous/resume.yaml), [foreground JUnit](native-continuous/continuous/foreground-junit.xml), [foreground flow](native-continuous/continuous/foreground.yaml), [continue JUnit](native-continuous/continuous/continue-junit.xml), [continue flow](native-continuous/continuous/continue.yaml).
