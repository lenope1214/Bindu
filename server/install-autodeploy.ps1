# 자동 배포 켜기: 5분마다 server\deploy.ps1 실행 (로그인하지 않아도 동작, 창 안 뜸).
#   관리자 PowerShell에서: powershell -ExecutionPolicy Bypass -File server\install-autodeploy.ps1
#   끄기: -Remove
param([switch]$Remove)
$ErrorActionPreference = "Stop"
$name = "BinduDeploy"

if ($Remove) {
    Unregister-ScheduledTask -TaskName $name -Confirm:$false
    Write-Host "자동 배포 끔"
    exit 0
}

$script = Join-Path $PSScriptRoot "deploy.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`"" `
    -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 20) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Force | Out-Null
Write-Host "자동 배포 켬: 5분마다 $script (기록: server\deploy.log)"
