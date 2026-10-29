# Bindu Windows(.exe) 빌드 스크립트 (Windows용)
#
# 사용법:  build_windows.bat 더블클릭              → 프로젝트 폴더에 Bindu.exe, Bindu.zip (릴리스)
#          powershell -ExecutionPolicy Bypass -File build_windows.ps1 -DebugBuild   → 디버그 빌드
#          $env:GODOT = "D:\Godot\Godot_v4.7.2-stable_win64.exe" 로 Godot 실행 파일 직접 지정
#
# 처음 실행 시 Godot 버전에 맞는 export 템플릿이 없으면 내려받아 설치한다(약 1GB).
param([switch]$DebugBuild)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # 진행 표시줄이 있으면 다운로드가 매우 느려짐
Set-Location -Path $PSScriptRoot
$ProjectDir = $PSScriptRoot
$Preset = "Windows Desktop"
$Out = "build\windows\Bindu.exe"
$Mode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }

# 0) 실행 중인 Bindu.exe가 있으면 종료 (파일이 잠겨 덮어쓰기·압축이 실패하는 것을 막음)
Get-Process -Name "Bindu" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "실행 중인 Bindu.exe(PID $($_.Id))를 종료합니다."
    $_ | Stop-Process -Force
}
Start-Sleep -Milliseconds 500

# 파일이 잠겨 있으면(백신 검사 등) 잠시 기다렸다가 다시 시도
function Retry([scriptblock]$Action, [string]$What) {
    for ($i = 1; $i -le 10; $i++) {
        try { & $Action; return }
        catch {
            if ($i -eq 10) { throw "$What 실패: $($_.Exception.Message)" }
            Write-Host "$What 대기 중... ($i/10) 다른 프로그램이 파일을 쓰고 있어요"
            Start-Sleep -Seconds 2
        }
    }
}

# 1) Godot 실행 파일 찾기 (콘솔 버전 우선: 빌드 로그가 이 창에 보임)
function Find-Godot {
    if ($env:GODOT -and (Test-Path $env:GODOT)) { return $env:GODOT }
    foreach ($n in @("godot", "godot4")) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    $dirs = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:LOCALAPPDATA\Programs", "C:\Godot", "D:\Godot", "C:\Program Files", "C:\Program Files\Godot", "$env:USERPROFILE\scoop\apps\godot\current", "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine")
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { continue }
        $f = Get-ChildItem -Path $d -Filter "Godot*_console.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $f) { $f = Get-ChildItem -Path $d -Filter "Godot*.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1 }
        if ($f) { return $f.FullName }
    }
    return $null
}
$Godot = Find-Godot
# 창 버전(Godot_vX.exe)은 출력이 안 보이므로 옆에 콘솔 버전이 있으면 그것을 쓴다
if ($Godot -and $Godot -notmatch '_console\.exe$') {
    $console = $Godot -replace '\.exe$', '_console.exe'
    if (Test-Path $console) { $Godot = $console }
}
if (-not $Godot) {
    Write-Host "Godot을 찾지 못했어요. 예: `$env:GODOT = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe' 로 지정한 뒤 다시 실행하세요." -ForegroundColor Red
    exit 1
}

# 2) 버전 확인 (예: 4.7.2.stable.official.abc123 → 템플릿 폴더 4.7.2.stable, 태그 4.7.2-stable)
# Godot은 경고를 stderr로 내보내므로, Godot을 부르는 동안에는 오류로 멈추지 않게 한다
$ErrorActionPreference = "Continue"
$RawVer = "$(& $Godot --version | Select-Object -Last 1)".Trim()
$ErrorActionPreference = "Stop"
if (-not $RawVer) {
    Write-Host "Godot 버전을 읽지 못했어요. 콘솔 버전(Godot_v..._console.exe)을 `$env:GODOT 로 지정해 주세요." -ForegroundColor Red
    exit 1
}
$parts = $RawVer.Split(".")
if ($parts[2] -match '^\d+$') { $TplVer = "$($parts[0]).$($parts[1]).$($parts[2]).$($parts[3])" } else { $TplVer = "$($parts[0]).$($parts[1]).$($parts[2])" }
$Tag = $TplVer.Substring(0, $TplVer.LastIndexOf(".")) + "-" + $TplVer.Substring($TplVer.LastIndexOf(".") + 1)
Write-Host "Godot: $Godot ($RawVer)"

# 3) export 템플릿 확인/설치
$TplDir = Join-Path $env:APPDATA "Godot\export_templates\$TplVer"
if (-not (Test-Path (Join-Path $TplDir "windows_release_x86_64.exe"))) {
    Write-Host "export 템플릿($TplVer)이 없어 내려받습니다..."
    $Url = "https://github.com/godotengine/godot/releases/download/$Tag/Godot_v${Tag}_export_templates.tpz"
    $Tmp = Join-Path $env:TEMP ("bindu_tpl_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $Tmp | Out-Null
    try {
        Invoke-WebRequest -Uri $Url -OutFile "$Tmp\templates.zip" -UseBasicParsing
        Expand-Archive -Path "$Tmp\templates.zip" -DestinationPath $Tmp
        New-Item -ItemType Directory -Path $TplDir -Force | Out-Null
        Copy-Item -Path "$Tmp\templates\*" -Destination $TplDir -Recurse -Force
        Write-Host "템플릿 설치 완료: $TplDir"
    } catch {
        Write-Host "템플릿 다운로드 실패: $Url`nGodot 에디터 > 편집기 > 내보내기 템플릿 관리에서 설치해도 됩니다." -ForegroundColor Red
        exit 1
    } finally { Remove-Item -Path $Tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# 4) 빌드
New-Item -ItemType Directory -Path (Split-Path $Out) -Force | Out-Null
# 리소스 임포트·스크립트 목록 갱신 (새 스크립트가 추가돼도 바로 실행되도록 매번)
$ErrorActionPreference = "Continue"
& $Godot --headless --path $ProjectDir --import *> $null
& $Godot --headless --path $ProjectDir $Mode $Preset $Out
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Out)) {
    Write-Host "빌드 실패: $Out 이 만들어지지 않았어요. 위 로그를 확인해 주세요." -ForegroundColor Red
    exit 1
}

# 5) 결과물을 프로젝트 폴더로 옮기기 (디버그 빌드의 콘솔용 exe 포함)
$Built = @()
foreach ($f in Get-ChildItem -Path (Split-Path $Out) -Filter "*.exe") {
    $dest = Join-Path $ProjectDir $f.Name
    Retry { Move-Item -Path $f.FullName -Destination $dest -Force } "$($f.Name) 옮기기"
    $Built += $dest
}
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue

# 6) 배포용 zip (exe와 같은 폴더에 Bindu.zip)
Retry {
    if (Test-Path "Bindu.zip") { Remove-Item "Bindu.zip" -Force }
    Compress-Archive -Path $Built -DestinationPath "Bindu.zip" -Force
} "Bindu.zip 만들기"
$exeMB = [math]::Round((Get-Item "Bindu.exe").Length / 1MB, 1)
$zipMB = [math]::Round((Get-Item "Bindu.zip").Length / 1MB, 1)
Write-Host "완료: $ProjectDir\Bindu.exe ($exeMB MB)" -ForegroundColor Green
Write-Host "      $ProjectDir\Bindu.zip ($zipMB MB)" -ForegroundColor Green
