# 빈두 브랜치 골라 실행 (Windows). Bindu_branch_run.bat 을 더블클릭하면 이 스크립트가 열린다.
# GitHub 브랜치 목록 창에서 하나를 고르면 그 브랜치 최신본을 전용 사본
# (%LOCALAPPDATA%\Bindu-branches\<브랜치>)에 받아 빌드 없이 실행한다. 다른 폴더는 건드리지 않음.
# Godot 위치가 다르면: 이 파일 옆 godot_path.txt 에 Godot exe 경로 한 줄, 또는 환경 변수 GODOT
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference = "Continue"
$Repo = if ($env:BINDU_REPO) { $env:BINDU_REPO } else { "https://github.com/lenope1214/Bindu.git" }
$Cache = Join-Path $env:LOCALAPPDATA "Bindu-branches"
New-Item -ItemType Directory -Force -Path $Cache | Out-Null

function Fail($msg) {
    [System.Windows.Forms.MessageBox]::Show($msg, "빈두 실행기", "OK", "Error") | Out-Null
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "git이 없어요. https://git-scm.com 에서 설치해 주세요." }

function Find-Godot {
    $side = Join-Path $PSScriptRoot "godot_path.txt"
    if (Test-Path $side) { $p = (Get-Content $side -TotalCount 1).Trim('" '); if ($p -and (Test-Path $p)) { return $p } }
    if ($env:GODOT -and (Test-Path $env:GODOT)) { return $env:GODOT }
    foreach ($n in @("godot", "godot4")) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    $dirs = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:LOCALAPPDATA\Programs", "C:\Godot", "D:\Godot", "D:\tools\Godot", "$env:LOCALAPPDATA\Godot", "$env:LOCALAPPDATA\Programs\Godot", "C:\Program Files", "C:\Program Files\Godot", "$env:USERPROFILE\scoop\apps\godot\current", "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine")
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { continue }
        # 게임 창용은 콘솔이 아닌 버전
        $f = Get-ChildItem -Path $d -Filter "Godot*.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '_console\.exe$' } | Sort-Object Name -Descending | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

$lines = & git ls-remote --heads $Repo 2>$null
$branches = @($lines | ForEach-Object { ($_ -split "refs/heads/", 2)[1] } | Where-Object { $_ } | Sort-Object)
if ($branches.Count -eq 0) { Fail "브랜치 목록을 받지 못했어요. 인터넷 연결을 확인해 주세요." }
$branches = @($branches | Where-Object { $_ -eq "main" }) + @($branches | Where-Object { $_ -ne "main" })
$lastFile = Join-Path $Cache ".last"
$last = if (Test-Path $lastFile) { (Get-Content $lastFile -TotalCount 1) } else { "main" }

$form = New-Object System.Windows.Forms.Form
$form.Text = "빈두 실행기"
$form.Size = New-Object System.Drawing.Size(420, 480)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Malgun Gothic", 10)
$label = New-Object System.Windows.Forms.Label
$label.Text = "실행할 브랜치를 고르세요 (두 번 누르면 바로 실행)"
$label.SetBounds(12, 10, 380, 24)
$list = New-Object System.Windows.Forms.ListBox
$list.SetBounds(12, 38, 380, 340)
$branches | ForEach-Object { [void]$list.Items.Add($_) }
$i = $list.Items.IndexOf($last); $list.SelectedIndex = if ($i -ge 0) { $i } else { 0 }
$ok = New-Object System.Windows.Forms.Button
$ok.Text = "실행"; $ok.SetBounds(212, 390, 85, 32); $ok.DialogResult = "OK"
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = "취소"; $cancel.SetBounds(307, 390, 85, 32); $cancel.DialogResult = "Cancel"
$list.Add_DoubleClick({ $form.DialogResult = "OK"; $form.Close() })
$form.AcceptButton = $ok; $form.CancelButton = $cancel
$form.Controls.AddRange(@($label, $list, $ok, $cancel))
if ($form.ShowDialog() -ne "OK" -or -not $list.SelectedItem) { exit 0 }
$branch = [string]$list.SelectedItem
Set-Content -Path $lastFile -Value $branch

$dir = Join-Path $Cache ($branch -replace '[\\/:*?"<>|]', '_')
if (-not (Test-Path (Join-Path $dir ".git"))) {
    Write-Host "$branch 받는 중 (처음 한 번): $dir"
    & git clone --depth 1 --branch $branch $Repo $dir
    if ($LASTEXITCODE -ne 0) { Fail "$branch 를 받지 못했어요." }
} else {
    & git -C $dir fetch --depth 1 origin $branch
    if ($LASTEXITCODE -eq 0) {
        # 전용 사본이라 강제로 맞춰도 됨 (.godot 임포트 캐시는 gitignore라 유지)
        & git -C $dir checkout -qf -B $branch FETCH_HEAD
        & git -C $dir reset -q --hard FETCH_HEAD
        & git -C $dir clean -qfd
    } else {
        Write-Host "새로 받지 못해 마지막으로 받은 $branch 로 실행합니다." -ForegroundColor Yellow
    }
}
Write-Host ("실행: $branch " + (& git -C $dir log -1 --format="%h %s"))

$godot = Find-Godot
if (-not $godot) { Fail "Godot을 찾지 못했어요. 이 파일 옆에 godot_path.txt 를 만들고 Godot exe 경로를 한 줄 적어 주세요." }
Write-Host "Godot: $godot"
& $godot --headless --path $dir --import 2>&1 | Out-Null
Start-Process -FilePath $godot -ArgumentList @("--path", "`"$dir`"")
