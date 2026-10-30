# 집 PC 자동 배포: main에 server/ 변경이 올라오면 다시 빌드하고, 응답이 없으면 이전 api 이미지로 되돌린다.
#   손으로:   powershell -ExecutionPolicy Bypass -File server\deploy.ps1 [-Force]
#   자동:     server\install-autodeploy.ps1 (관리자) → 5분마다 이 파일 실행
#   기록:     server\deploy.log
param(
    [switch]$Force  # server/ 변경이 없어도 다시 빌드
)
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot
$log = Join-Path $PSScriptRoot "deploy.log"

function Log($msg) {
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Add-Content -Path $log -Value $line -Encoding UTF8
    Write-Host $line
}

function EnvValue($name, $default) {
    $f = Join-Path $PSScriptRoot ".env"
    if (Test-Path $f) {
        foreach ($l in Get-Content $f) {
            if ($l -match "^\s*$name\s*=\s*(.+?)\s*$") { return $Matches[1].Trim('"') }
        }
    }
    return $default
}

function Healthy($seconds) {
    $url = "http://127.0.0.1:{0}/health" -f (EnvValue "HTTP_PORT" "80")
    $until = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $until) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Seconds 3
    }
    return $false
}

# 같은 시간에 두 번 돌지 않게
$mutex = New-Object System.Threading.Mutex($false, "Global\BinduDeploy")
if (-not $mutex.WaitOne(0)) { exit 0 }
try {
    # 기록이 너무 커지면 뒤쪽만 남김
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 1MB) {
        Get-Content $log -Tail 2000 | Set-Content $log -Encoding UTF8
    }

    docker info *> $null
    if ($LASTEXITCODE -ne 0) { Log "Docker가 꺼져 있음, 건너뜀"; exit 1 }

    git fetch -q origin main
    if ($LASTEXITCODE -ne 0) { Log "git fetch 실패"; exit 1 }
    $old = (git rev-parse HEAD).Trim()
    $new = (git rev-parse origin/main).Trim()

    $serverChanged = $false
    if ($old -ne $new) {
        git diff --quiet $old $new -- .
        $serverChanged = ($LASTEXITCODE -ne 0)
        $caddyChanged = $false
        git diff --quiet $old $new -- Caddyfile
        $caddyChanged = ($LASTEXITCODE -ne 0)
        # fast-forward만. 이 폴더에 따로 커밋이 있거나 겹치는 수정이 있으면 손대지 않음
        git merge -q --ff-only origin/main
        if ($LASTEXITCODE -ne 0) { Log "fast-forward 불가 (이 폴더에 로컬 커밋·수정 있음), 건너뜀"; exit 1 }
    }
    if (-not $serverChanged -and -not $Force) { exit 0 }

    $short = $new.Substring(0, 7)
    Log "배포 시작 $($old.Substring(0, 7)) -> $short"

    # 지금 돌고 있는 api 이미지 기억
    $cid = (docker compose ps -q api) | Select-Object -First 1
    $prevImg = $null; $imgName = $null
    if ($cid) {
        $prevImg = (docker inspect -f "{{.Image}}" $cid).Trim()
        $imgName = (docker inspect -f "{{.Config.Image}}" $cid).Trim()
        docker tag $prevImg bindu-api:prev
    }

    docker compose up -d --build
    $ok = ($LASTEXITCODE -eq 0)
    if ($ok -and $caddyChanged) { docker compose restart caddy | Out-Null }
    if ($ok) { $ok = Healthy 90 }

    if ($ok) {
        Log "배포 성공 $short"
        docker image prune -f --filter "label=com.docker.compose.project=$(Split-Path $PSScriptRoot -Leaf)" | Out-Null
        exit 0
    }

    Log "배포 실패 $short (빌드 오류 또는 /health 응답 없음)"
    if (-not $prevImg) { Log "되돌릴 이전 이미지 없음"; exit 1 }
    docker tag $prevImg $imgName
    docker compose up -d --no-build api
    if (Healthy 60) { Log "이전 api 이미지로 되돌림 (코드 폴더는 $short 그대로, 다음 push 때 다시 시도)" }
    else { Log "되돌린 뒤에도 /health 응답 없음, 직접 확인 필요: docker compose logs api" }
    exit 1
}
finally {
    $mutex.ReleaseMutex()
}
