# macOS 자체 업데이터

Godot의 `Updater`가 기존 `/v1/boot`의 `bindu-release|macos|버전|URL|SHA-256|크기` RSA 서명을 검증한다. HTTPS ZIP 다운로드·해시·크기 검사가 끝나면 보조 프로그램을 앱 밖의 같은 볼륨 임시 폴더에 복사해 실행한다. Sparkle이나 관리자 권한 서비스는 사용하지 않는다.

1. `prepare`: ZIP 해시 재검증 → 시스템 libarchive로 안전하게 해제 → 실행 권한·내부 심볼릭 링크 보존 → 번들 ID/버전/코드 서명/Developer ID Team ID 검증. 외부 경로·하드 링크·특수 파일·과도한 크기는 거부한다.
2. `install`: 설치 폴더의 파일 잠금 → 준비 완료 확인 → 기존 앱 종료 대기(최대 30초) → 원래 앱 inode 재확인 → 코드 서명 재검증 → `renamex_np(RENAME_SWAP)`으로 번들을 원자적으로 교환한다.
3. 검증된 새 번들의 실행 파일을 `posix_spawn`으로 실행한다. LaunchServices의 이전 번들 정보 캐시나 동기 시작 대기에 의존하지 않는다. 실행 중인 파일을 덮어쓰지 않는다.
4. 새 앱은 초기화 후 `MacUpdater.acknowledge()`로 일회성 토큰과 버전·대상 경로를 확인해 시작을 알린다. 보조 프로그램은 최대 45초 대기한다.
5. 확인 성공 시 이전 앱과 임시 ZIP·helper를 정리한다. 새 앱 종료·확인 누락이면 새 프로세스를 종료하고 번들을 다시 교환해 이전 앱을 실행한다. 오류는 `user://macos-update-result.json`으로 이전 앱에 전달한다.

상태 폴더는 앱 옆 `.bindu-update-<난수>`이며 준비 단계에서 권한을 0700으로 제한한다. `.bindu-update.lock`은 동시 교체를 막는 빈 잠금 파일로 남긴다. 실패 시 상태 폴더는 진단·복구용으로 남긴다. 원자적 교환 이후 시작 확인 전의 이전 앱은 그 안의 `unpacked/Bindu.app`이다. 복구 후 설치 앱이 정상임을 확인한 상태에서 실패 폴더를 삭제할 수 있다. 시스템 강제 종료·디스크 손상까지 자동 복구했다고 가정하지 않는다.

빌드: 저장소 루트의 `./build_macos.command`. libarchive 헤더는 빌드 시에만 필요하고 실행 시 시스템 libarchive를 사용한다. 배포 앱·helper는 마지막에 함께 서명해야 한다. Developer ID로 배포할 때는 동일 Team ID를 유지한다. 기본 ad-hoc 빌드는 로컬 QA용이며 공증한 배포본과 구분한다.

```sh
python3 native/macos/tests/test_updater.py
python3 tools/macos_update_smoke.py
```

모든 시험 앱·상태·저장 데이터는 별도 경로를 사용한다. 운영 서버 등록과 실사용 게임 저장은 변경하지 않는다.
