# AccessKit 전달 직전과 native AX 결과의 분리

**I-17의 원인은 미확정이다.** 같은 진단 엔진·제품70개 소스에서 시작 버튼과 조상의 아래 필드는 같지만 native 발견 결과는 0개와 1개로 갈렸다. [전체 비교](engine-comparison.json), [엔진 소스·빌드·제한](engine-provenance.json).

## 관찰한 경계

Godot 소스 `ed1daf0bf001b61586d9930840f2f1394092c079`를 별도 디렉터리에 아카이브했다. [패치](engine-trace.patch)는 `_accessibility_build_tree_update` 안에서 `accesskit_tree_update_push_node`로 소유권을 넘기기 **직전** 노드를 읽어 출력한다. 제품 동작·접근성 갱신 방식은 수정하지 않았다. 패치는 깨끗한 원본에 `git apply --check --unidiff-zero`가 통과하며 관련 엔진 소스9개 중8개는 그대로다. 나머지 하나가 이 로그 추가다.

노드 로그는 전송의 수락이나 AccessKit 내부 트리까지 관찰한 것이 아니다. JSON 생성·출력이 시간에 영향을 줄 수 있다. 실제 증상이 같은 실행에서 재현됐다는 점과 이 한계를 함께 남긴다. 소스가 같아도 설치된 stock 실행 파일과 같은 바이너리라고 부르지 않는다.

| 같은 editor 진단 빌드 | 시작 버튼 전달 직전 | 조회 완료 때의 native AX |
|---|---|---|
| READY 경계 | `hidden=false`, 창에서 도달 가능. 조상4개 모두 숨김/clipping 없음 | 시작 버튼0개. 반복 조회5회에서도 누락 |
| READY 경계 + 실제 Tab 정보창 열기 | 위 선택 필드와 조상 선택 필드 동일 | 시작 버튼1개 |

비교한 버튼 필드는 role·name·extra·hidden·clips_children·bounds·children다. 조상은 role·name·extra·hidden·clips_children·bounds다. 다른 프로세스의 ID·시간은 비교에서 제외했다. 정보창 subtree가 의도적으로 달라지므로 전체 트리나 모든 속성이 같다는 주장도 아니다.

원본 로그를 각 native 조회 완료 handshake까지 순서대로 재구성했다. 해당 시점에서 빠진 자식 참조·여러 부모 참조·루트의 자식 역참조는 모두0이다. WAVE에서는 같은 시작 버튼의 `hidden=true` 전달과 native 부재가 일치했다. 따라서 시작 버튼의 갱신을 전혀 받지 않았거나 전달 직전의 숨김/조상 clipping만으로 실패를 설명할 수 없다. 실제 전달, 소비 트리, 필터/캐시, macOS 노출 사이의 원인은 아직 분리하지 못했다.

- [누락 실행](engine-ready-04/run.json), [누락 AX](engine-ready-04/ready-ax.json), [전달 요약](engine-ready-04/outgoing-summary.json), [전달 기록 전체](engine-ready-04/outgoing-nodes.jsonl).
- [정보창 대조 실행](engine-inspector-01/run.json), [대조 AX](engine-inspector-01/ready-ax.json), [전달 요약](engine-inspector-01/outgoing-summary.json), [전달 기록 전체](engine-inspector-01/outgoing-nodes.jsonl).
- [재구성 코드](extract_engine.py), [실행 코드](run.py). 각 요약은 원본 native.log의 경로·바이트·SHA-256과 입력 행 번호를 보존한다. 원본 로그도 로컬에 보존한다.

누락 실행은 관찰 모드이므로 프로세스 exit0이 접근성 통과를 의미하지 않는다. `sentinel_mismatches`의 실패1개를 그대로 남겼다. 정보창 대조는 `--require-fresh`에서 두 상태 모두 통과했다. 두 실행 모두 소유 프로세스 종료·임시 프로젝트·고유 저장 제거를 확인했다. 종료의 기존 ObjectDB 경고도 원본에 남긴다.

## 진단 환경 실패는 제품 표본에서 제외

처음 축소한 template 빌드는 [경로 override 차단](engine-ready-01/run.json), [QA 상속 스크립트 로딩](engine-ready-02/run.json), [SubViewport.disable_3d 미지원](engine-ready-03/run.json)으로 각각 실행이 막혔다. 세 실행 모두 유효한 제품 비교에서 제외했다. 마지막 경우는 게임 미리보기가 2D에서도 해당 3D 비활성화 속성을 사용하는데 빌드에서 그 API를 없앤 차이다.

최종 빌드는 전체 모듈·3D API를 포함한 editor이며 실제 렌더링은 기존과 같은 OpenGL Compatibility다. 빌드에서 Metal/Vulkan backend는 생략했고 최적화도 다르다. 의존성은 Godot의 AccessKit C SDK 0.22.3 설치 스크립트로 받았다. 실제 헤더·정적 라이브러리 SHA와 모든 빌드 로그의 경로·크기·SHA는 provenance에 있다. native 실행 전에 같은 진단 엔진으로 QA 상속 스크립트4개도 parse 검사했다.

```sh
# 같은 revision의 별도 소스에서 git apply --unidiff-zero engine-trace.patch 적용 및 SDK 설치 후:
scons platform=macos target=editor arch=arm64 debug_symbols=no optimize=none vulkan=no metal=no disable_3d=no modules_enabled_by_default=yes accesskit=yes -j8

BINDU_AX_TRACE=1 python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/run.py --journey ready-only --native-engine /path/to/godot.macos.editor.arm64 --output /tmp/bindu-engine-ready-new
python3 docs/qa/2026-11-09-battlefield-fixes/accessibility-visibility/extract_engine.py /tmp/bindu-engine-ready-new
```

사용자 동작의 복귀 실패는 [stock 엔진 두 실행](journeys.md)에서 별도로 관찰했다. 이 진단 빌드의 READY 경계 비교를 실제 사용자 전체 과제·VoiceOver 성공으로 바꾸지 않는다. 네 번째 추측 제품 수정은 준비하지 않았다.
