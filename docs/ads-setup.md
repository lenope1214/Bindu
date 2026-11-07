# 광고(1.1) 남은 설정

코드(브랜치 `ads-1.1`)는 끝났고, 폰 빌드에 광고를 실제로 붙이려면 아래가 남았다. 끝나면 줄을 지운다.
기획: 결과 화면에서만, 보상형 [광고 보고 한 번 더] + 결과 화면 배너(처음 3판 없음). 기능 명세 ADS-01~04.

## 사용자가 할 일

1. AdMob 계정(https://admob.google.com)에서 앱 2개(Android `kr.chat.anon.bindu`, iOS `kr.chat.anon.bindu`) 등록 → **App ID** 2개.
2. 앱마다 광고 단위 2개: 보상형(이름 예: revive), 배너(result_banner) → **광고 단위 id** 4개.
3. AdMob 개인정보 및 메시지에서 유럽 규정(GDPR) 메시지 만들기 (동의 창 문구, 무료).
4. App Store Connect 앱 개인정보·Play 데이터 보안·광고 신고는 1.1 배포하는 날 바꾼다(아래 표).

## Mac에서 할 일 (편집기 필요)

1. Godot 편집기로 프로젝트 열기 → 프로젝트 설정 → 플러그인에서 AdMob 켜기.
2. 프로젝트 → 도구 → AdMob Manager → Android·iOS 각각 Download & Install (네이티브 라이브러리를 `addons/admob/android`, `addons/admob/ios`에 받음).
3. 프로젝트 설정 `admob/...`에 App ID 2개 넣기. 중개(mediation) 항목은 모두 끔.
4. `scripts/ads.gd`의 `UNITS`에 광고 단위 id 4개 넣기 (비어 있으면 배포 빌드는 광고가 꺼진다).
5. Android: 내보내기 프리셋은 이미 Gradle 빌드. AD_ID 권한이 들어가는지 확인.
6. iOS: Info.plist에 `GADApplicationIdentifier`·`SKAdNetworkItems`가 들어가는지 확인. ATT 문구(`NSUserTrackingUsageDescription`)는 넣지 않는다(맞춤형 광고를 쓰지 않음).
7. 테스트: 디버그 빌드는 구글 테스트 광고가 나온다. TestFlight·Play 내부 테스트로 결과 화면 두 가지(배너·한 번 더)를 확인.

## 1.1 배포 때 같이 바꿀 신고·글

| 항목 | 바꿀 내용 |
| --- | --- |
| App Store 앱 개인정보 | Google AdMob이 모으는 항목(기기 ID, 제품 상호작용, 광고 데이터, 대략 위치, 진단)을 '제3자 광고' 목적으로 추가. 추적은 '아니오' 유지 |
| 심사 메모 `store/ios/review_notes.txt` | "No ads" 문장 → 결과 화면 광고 설명, 녹화에 광고 위치·보상·닫기 포함 |
| Play 앱 콘텐츠 | 광고 포함 예, 광고 ID 사용 예, 데이터 보안에 광고 목적 공유 추가 |
| `server/app/privacy.md` | 광고(AdMob)에 넘어가는 정보·맞춤형 아님·동의 철회 방법 |
| `store/android/store_listing.md`, `server/app/home.md`, `store/listing.json` | "광고와 결제가 없는" 문구 고치기 |
