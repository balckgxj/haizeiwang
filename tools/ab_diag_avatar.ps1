# 诊断主页头像行：点击命中 + 横滑松手行为
# 依赖 ab_lib.ps1（归一化坐标 + 物理像素截图）
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
# 诊断开关
[Environment]::SetEnvironmentVariable('HAIZEI_MENU_DIAG', '1', 'Process')
[Environment]::SetEnvironmentVariable('HAIZEI_DUMP_AVATAR', '1', 'Process')

$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force
$log  = Join-Path $out 'ab_diag.log'

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$p = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', "set HAIZEI_MENU_DIAG=1&& set HAIZEI_DUMP_AVATAR=1&& Haizeiwang.exe > ab_diag.log 2>&1") `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
"NEW client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'diag_splash.png')
'SHOT_SPLASH'

# 进入游戏
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.50 0.79 | Out-Null }
Start-Sleep -Seconds 18
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'diag_home.png') }
"NEW_HOME alive=$(AB-Alive 'Haizeiwang')"

# 解析 [AvatarDump]
$lg = Join-Path $dbg 'ab_diag.log'
$dump = @()
if (Test-Path $lg) {
    foreach ($line in (Get-Content $lg)) {
        if ($line -match '\[AvatarDump\] idx=(\d+) worldRect=\(([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)\) contentSize=\(([-\d.]+),([-\d.]+)\)') {
            $idx = [int]$matches[1]
            $ox=[double]$matches[2]; $oy=[double]$matches[3]; $w=[double]$matches[4]; $h=[double]$matches[5]
            $dump += [pscustomobject]@{idx=$idx; cx=$ox+$w/2; cy=$oy+$h/2; w=$w; h=$h; ox=$ox; oy=$oy}
            "DUMP idx=$idx cx=$($ox+$w/2) cy=$($oy+$h/2) size=($w,$h)"
        }
    }
}
if ($dump.Count -eq 0) { 'NO_AVATAR_DUMP'; }
$dump | ConvertTo-Json | Out-File (Join-Path $out 'avatar_dump.json') -Encoding utf8

# ---- 点击头像 1 ----
$fb1 = $dump | Where-Object { $_.idx -eq 1 } | Select-Object -First 1
if ($fb1) {
    $u = $fb1.cx / 360.0
    $v = 1.0 - $fb1.cy / 480.0
    "CLICK_AVATAR1 u=$u v=$v"
    $c = Get-ABClient 'Haizeiwang'
    if ($c) { AB-Click $c $u $v | Out-Null }
    Start-Sleep -Seconds 2.5
    $c = Get-ABClient 'Haizeiwang'
    if ($c) { $null = AB-Shot $c (Join-Path $out 'diag_after_click.png') }
    'SHOT_AFTER_CLICK'
}

# ---- 横滑头像行（拖动不松手中途截图）----
$rowY = if ($fb1) { $fb1.cy } else { 240.0 }
$vRow = 1.0 - $rowY / 480.0
"SWIPE_ROW vRow=$vRow"
$c = Get-ABClient 'Haizeiwang'
if ($c) {
    $p1 = AB-Screen $c 0.55 $vRow
    $p2 = AB-Screen $c 0.15 $vRow
    [void][AB]::SetCursorPos($p1[0],$p1[1]); Start-Sleep -Milliseconds 220
    [AB]::mouse_event([AB]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 120
    for ($i = 1; $i -le 18; $i++) {
        $nx = [int]($p1[0] + ($p2[0]-$p1[0])*$i/18)
        $ny = [int]($p1[1] + ($p2[1]-$p1[1])*$i/18)
        [void][AB]::SetCursorPos($nx,$ny); Start-Sleep -Milliseconds 35
        if ($i -eq 9) { $null = AB-Shot $c (Join-Path $out 'diag_swipe_mid.png') }
    }
    Start-Sleep -Milliseconds 120
    $null = AB-Shot $c (Join-Path $out 'diag_swipe_before_release.png')
    [AB]::mouse_event([AB]::UP,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 700
    $null = AB-Shot $c (Join-Path $out 'diag_swipe_after.png')
    'SHOT_SWIPE_DONE'
}

# ---- 收集诊断日志 ----
if (Test-Path $lg) {
    $lines = Get-Content $lg
    $menu = $lines | Where-Object { $_ -match '\[MenuDiag\]' } | Select-Object -Last 40
    $sv   = $lines | Where-Object { $_ -match '\[SVDiag\]' } | Select-Object -Last 40
    "===== MENU DIAG (tail) ====="
    $menu -join "`n"
    "===== SV DIAG (tail) ====="
    $sv -join "`n"
}
'DONE'
