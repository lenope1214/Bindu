# iOS 심사 남은 작업

App Store iOS 1.0 심사(가이드라인 2.1 정보 요청, 2026-11-01)와 2026-11-03 전수 점검에서 나온 남은 일. 끝나면 줄을 지운다.

## 코드에 반영된 것

- 닉네임 거르기·리더보드/멀티 방 신고·차단·관리 신고 탭, 설정 [내 온라인 데이터 지우기] (ONLINE-06)
- 폰·태블릿의 [새 버전] 버튼은 App Store·Google Play 주소일 때만 보임 (서버에 `ios` 릴리스로 zip·TestFlight 주소를 등록해도 열지 않음)
- iOS plist: `ITSAppUsesNonExemptEncryption=NO`, `NSLocalNetworkUsageDescription`(멀티플레이) — `export_presets.cfg` iOS `application/additional_plist_content`
- 개인정보처리방침(`server/app/privacy.md`): 멀티플레이(Cloudflare 중개·TURN, P2P IP), 아동 문구를 연령 등급 9+와 맞춤

## 남은 일 (App Store Connect·기기, 사용자)

1. **앱 개인정보 항목 고치기 (위험 높음)**: 지금 답은 0.5.1 기준(계정 없음, 신원에 연결 안 됨). 다음으로 바꾼다. 모두 목적 "앱 기능"(플레이 기록·진단은 "분석"도), **신원에 연결됨: 예**, 추적: 아니요.
   - Identifiers: User ID(익명 계정 id), Device ID(게임이 만든 무작위 id)
   - User Content: Gameplay Content(진행·이어하던 판), Other User Content(닉네임·투표 의견·신고)
   - Usage Data: Product Interaction(플레이 기록·카드 선택)
   - Diagnostics: Crash Data, Other Diagnostic Data(오류 기록·OS 버전)
2. **스크린샷 다시 찍기 (위험 높음)**: 지금 것은 16:9 검은 여백·PC 키 안내가 보임(2.3.3). 실제 iPhone 6.9"(2868x1320 가로)·iPad 13" 화면으로 판 중·카드 선택·리더보드 등.
3. **새 빌드로 심사 (위험 높음)**: 위 코드가 들어간 빌드를 TestFlight에 올리고 iOS 1.0 심사 빌드를 바꾼다.
4. **화면 녹화 + Notes**: 새 빌드로 녹화해 첨부하고 Notes 영어 본문을 붙여 다시 제출. 순서·본문은 프로젝트 파일 `bindu-appreview/review_notes.md`.
5. **iPad 확인 (중간)**: 내보내기가 iPhone+iPad(`targeted_device_family=2`)라 iPad에서도 심사함. TestFlight로 iPad에서 한 판·설정·리더보드·멀티 방 확인. 자신 없으면 iPhone만(`=0`)으로.
6. **연령 등급 설문 (중간)**: 사용자 생성 콘텐츠 예(닉네임), 멀티플레이로 다른 사용자와 상호작용이 생김 → 해당 질문이 있으면 예. 채팅·메시지 아니요, 시뮬레이션 도박 아니요(주사위·동전 카드는 돈·베팅 없음).
7. **신고 처리**: Notes에 "24시간 안에 처리"라고 적음 → 관리 화면 신고 탭을 매일 확인.
8. **ITMS-91053 메일 확인 (낮음)**: 업로드 뒤 개인정보 매니페스트 관련 메일이 오면 Godot iOS 내보내기 `privacy/*` 설정을 채운다.
9. **EU 거래자 선택, 한국 GRAC 등급 칸**: 출시 전 (`store/listing.json` submission.ios).

## 결정할 것 (낮음)

- "(시험)" 표시(맵 규칙·모드·이번 판 흐름 등)가 2.2(시험판 금지)로 보일 여지. "(새 기능)"으로 바꾸거나 iOS에서 숨길지.
- 게임 안 패치노트·멀티 방 그림의 Android·Windows 언급(2.3.10). 지적되면 iOS에서 플랫폼 줄을 거른다.
