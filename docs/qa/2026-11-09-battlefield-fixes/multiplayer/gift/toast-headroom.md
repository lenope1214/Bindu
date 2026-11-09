# Toast 여유 검토

최신 pending PC/폰3조건 캡처는 **각17장·합계34장**이다(race6 + reverse6 + ACKloss5). 전부 기존 UI checker에서0건이다. 요청/거절 toast와 협동 버튼 겹침이 있었던 이전 PNG와 구분하며 대표 최신 PNG도 직접 확인했다.

`frame.gd`는 `toast_top = max(HUD 하단+36, mp_bar 하단+8, mp_act 하단+8, 안내 하단)`을 구하고, 카드에 닿으면 `max(toast_top, cardPanelTop - toastHeight - 4)`로 재배치한다. 따라서 `toast_top + toastHeight + 4 > cardPanelTop`이면 두 영역 사이에 수직 여유가 없다는 소스 반례는 성립한다. 현재 실행에서 이 반례를 관측했다는 뜻은 아니다.

현재 도구는 PNG와 UI checker 결과를 저장하며 각 toast의 `Control.position/size`, panel top, lowerbound는 저장하지 않았다. **이 34장의 정확한 부등식 여유 수치를 소급 집계할 근거는 없다.** 이미지의 보이는 글자 bbox는 Label 전체 높이와 같지 않고, native stretch/폰 safe area/130% 변환도 있어 픽셀 간격을 Control 여유로 제시하지 않는다. 새 native 실행 없이 가능한 결론은 관측된34장 UI 겹침0까지다.

향후 이 조건을 별도 검증할 때는 같은 draw 직후 `toast.get_rect`, card panel rect, 각 blocker rect, `ui_root.scale`, toast 표시/alpha/줄 수를 함께 기록해야 한다. DPS/inspector 때문에 폭이 줄어 긴 toast가 여러 줄이 되거나 상단 안내가 늘어나는 조건을 포함한다. 여유가 음수인 경우의 위치/대기 정책을 먼저 정하고 사용자 메시지를 지우는 방식으로 검사만 통과시키지 않는다.
