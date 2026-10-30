# 처음 한 번: 비밀값·서명 키·게임 접속 설정을 만든다 (Windows).
#   powershell -ExecutionPolicy Bypass -File server\setup.ps1 https://bindu.anon-chat.kr -Tunnel
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [switch]$Tunnel  # Cloudflare Tunnel 뒤에서 실행 (포트를 열지 않음)
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
docker build -q -t bindu-server . | Out-Null
if ($LASTEXITCODE -ne 0) { throw "docker build 실패 (Docker Desktop이 켜져 있는지 확인)" }
$repo = (Resolve-Path "..").Path
$extra = @()
if ($Tunnel) { $extra += "--tunnel" }
docker run --rm -v "${repo}:/repo" -w /repo/server bindu-server python tools/setup.py $Url @extra
