# 完整复现闪退：启动 -> 登录 -> 主页点空位加号 -> 阵容页逐个点船员格 -> 抓崩溃点
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab\crash'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'; Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'set HAIZEI_MENU_DIAG=1 && set HAIZEI_CRASH_HUNT=1 && Haizeiwang.exe > ab_crash.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 7
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AT_LOGIN'; exit 1 }
$null = AB-Shot $c (Join-Path $out 'f0_home.png')

# 主页第5格（空位）
AB-Click $c 0.76 0.30 | Out-Null
Start-Sleep -Seconds 3
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AFTER_PLUS'; exit 1 }
$null = AB-Shot $c (Join-Path $out 'f1_team.png')

# 阵容页顶部图标行逐格点击：u = 0.17,0.32,0.47,0.61,0.76 / 右箭头 0.90  v = 0.12
$slots = @(@(0.17,'s1'), @(0.32,'s2'), @(0.47,'s3'), @(0.61,'s4'), @(0.76,'s5'), @(0.90,'arrow'))
foreach ($s in $slots) {
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { "CRASH_BEFORE $($s[1])"; break }
    AB-Click $c $s[0] 0.12 | Out-Null
    Start-Sleep -Seconds 2
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) {
        "CRASH_AFTER_CLICK $($s[1]) (u=$($s[0]))"
        break
    }
    $null = AB-Shot $c (Join-Path $out ("f_$($s[1]).png"))
    "OK $($s[1])"
}
"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
