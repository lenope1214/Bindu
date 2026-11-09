# 정보 사용성 개선 검증

## 후속 통합 확인

아래 최초 독립 검사는 당시 소스의 역사다. 이후 공유 브랜치에서 [PC](../final-native/information-pc/run.log)·[폰](../final-native/information-phone/run.log) 각각20단언, 실패0·UI0·runtime ERROR0으로 다시 확인했다. 이 묶음은 협동 대기 표시의 마지막 수정과 실행 시점이 겹쳤으므로 개별 사본의 `field_view.gd` 해시를 확정하지 않는다. 해당 대기 표시는 별도 [실제 통신 검증](../multiplayer/gift/README.md)으로 확인한다.

BF-44는 합성 텍스트만 확인하던 초기 검사에 실제 Orb → `_record_leak` → `_log_wave` → 기록 읽기 연결을 추가했다. 통과 때 관찰된 저항·남은 보호막·굳셈·일시 면역과 실제 체력 손실이 읽기 UI에 도달하고, 오래된 네 칸 기록도 읽힌다. 상태 관찰을 누수 원인의 확정으로 해석하지 않는다. [직전 PC](leak-pc.log), [폰](leak-phone.log)과 최종 통합 로그에서 통과했다.

BF-43의 바람은 현재 실제 밀어내기·제어 역할로 설명한다. 비활성 순풍 강화가 적용되는 것처럼 설명하던 중간 구현을 독립 리뷰에서 제거했다. 아래 표의 최초 범위 개수 단언은 현재 지원 효과의 증거로 재사용하지 않는다.

기준 `e25b6eab5b4e64cca7ee5e0089d50e149588e9b9`에 정보 담당의 4개 제품 파일과 새 검사만 얹은 격리 사본에서 검증했다. 공유 브랜치의 다른 담당자 변경을 포함한 통합 결과는 아니다. 정확한 파일 해시는 [source-manifest.json](source-manifest.json)에 있다.

## 결과

- 수정 전 [before.log](before.log): `INFORMATION failures=6 ui=0`, 종료 코드 1. 기본 공격 예시 제어, 표 행 선택·포커스, 비교·지원·기술 조회 경로의 부재를 기록했다.
- 수정 후 [pc.log](pc.log), [phone.log](phone.log): PC 1280×720 100%·폰 모의 2556×1179 130%, 모두 `INFORMATION failures=0 ui=0`, 종료 코드 0.
- [PC 화면](pc/information-summary.png), [폰 화면](phone/information-summary.png): 기본 정보에서 공격 애니메이션보다 수치·조준 원칙·지원 역할이 먼저 보인다.
- OS 커서·개인 게임 저장·실서버를 사용하지 않은 VirtualInput native 실행. 각 실행은 tools/run.sh의 임시 사본 정리 후 종료했다. 출력에 도구 종료 ObjectDB 2개 경고가 남는다. 스크립트 오류는 없다.

## 항목별 구현과 증거

| 항목 | 구현 | 확인 |
|---|---|---|
| BF-21 | 기본 수치 우선, 공격 예시 기본 접힘·명시적 토글 API | 접힘/펼침 높이·위치 단언, native 캡처 |
| BF-25 | 대상별 가능 여부·변경·새 조합 비교 자료 | 유효/무효 대상과 빌드 미변경 단언. root의 실제 비교 UI 연결은 통합 확인 필요 |
| BF-27 | 오브젝트 기본 정보에 실제 조준 정책 표시 | native 캡처. 도움말·카드 문구는 다른 담당자 범위 |
| BF-28 | 거절 이유·다른 유효 대상 수를 클릭 전부터 표시, 긴 줄 접기 | 소스·native 정보 검사. 부모의 카드 들기 전체 검증에 포함 필요 |
| BF-39 | 조준 중 유효 대상 고리·면역 X, 실제 범위 기반 숫자 API | 면역 제외 예상 1개/면역 1개가 실제 Skill.use 결과와 일치 |
| BF-41 | DPS 표 행 클릭/터치/Enter/Space로 전장 선택, 포커스 표시 | 실제 GUI 클릭·터치에서 selected와 inspected 대상 일치 |
| BF-42 | 기본 공격 계산/초와 실측 DPS 이름·툴팁 구분 | 수치 라벨·표 헤더 변경 확인 |
| BF-43 | 피해 환산 없는 지원 범위 개수·제어 역할 표시 | 바람 범위 1개 단언. 다른 지원자의 더 센 바람에 의해 실제 적용되지 않을 수 있으므로 '지원 범위'로 표시 |
| BF-44 | 기록된 방향·종류·중앙 실제 손실과 인과 한계 제공 | 합성 누수 기록의 실제 손실/피해 구분 단언. 사용자의 개선 판단 성공률은 미측정 |
| BF-45 | 적 정보 명시적 고정·이동 후 유지·죽음/해제 정리 | API 단언. root/input owner의 전장 탭 연결은 최종 통합 검사 필요 |
| BF-48 | 고정된 적 정보는 손가락·움직이는 대상에서 분리 | 구현만. 실물 손가락 가림 검증 아님 |
| BF-50 | DPS 키보드 포커스·큰 터치 행·상단 정지 영역 회피 | local native 검사. 전체 접근성·실측 대비·모든 기기 검증 아님 |

## 공유 API

- `InfoPanel.set_preview_visible(bool)`, `preview_visible`, `summary_lines(Tower) -> PackedStringArray`, `targeting_summary(Tower) -> String`.
- `hud_system.card_comparisons(Dictionary) -> Array[Dictionary]`: tower/index/title/allowed/reason/changes/new_reactions.
- `hud_system.card_comparison_text(Dictionary)`, `support_summary(Tower)`, `leak_review_text()`는 String 반환.
- `field_view_system.pin_orb_at(Vector2) -> bool`, `clear_orb_pin()`, `pinned_orb() -> Orb`.
- `field_view_system.skill_aim_info(String, Vector2) -> Dictionary`: eligible/immune/count/immune_count/text. 조회만 수행하고 실제 효과는 변경하지 않는다.

BF-15 원진단 보정: 기존 코드도 드래그 도중 무효 대상에 빨간 고리를 표시했다. 구체적 거절 이유와 입력 담당자의 drag_preview 데이터가 보완 대상이며, 모든 사전 피드백이 없었다고 주장하면 안 된다.

## 재실행

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_information_check.gd /tmp/bindu-information-pc 1.0
RESOLUTION=2556x1179 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh ui battlefield_information_check.gd /tmp/bindu-information-phone 1.3 phone
```

이 명령은 현재 공유 소스를 검사한다. 위에 보존한 독립 결과는 source-manifest의 4개 파일만 기준 소스에 얹은 결과다. 전체 check·실기기·실통신·후반 부하·사람 대상 과제 시험은 부모의 통합 단계에서 따로 판단한다.
