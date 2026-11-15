# 一体化观察：启动新版 -> 点「进入游戏」(v=0.79) -> 每 2s 截图 -> 打印日志关键行
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$log  = Join-Path $dbg 'ab_obs.log'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_obs.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 40
if (-not $c) { 'NO_WINDOW'; exit 1 }
"client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

for ($i=0; $i -lt 3; $i++) {
    Start-Sleep -Seconds 2
    $cc = Get-ABClient 'Haizeiwang'
    if ($cc) { $null = AB-Shot $cc (Join-Path $out ("obs_{0:00}_boot.png" -f $i)) }
}
$c = Get-ABClient 'Haizeiwang'
$p = AB-Click $c 0.50 0.79
"CLICK enter-game ($($p[0]),$($p[1]))"

for ($i=0; $i -lt 12; $i++) {
    Start-Sleep -Seconds 2
    $cc = Get-ABClient 'Haizeiwang'
    if ($cc) { $null = AB-Shot $cc (Join-Path $out ("obs_{0:00}_after.png" -f $i)) }
    else { "WINDOW_LOST at $i"; break }
}
"ALIVE=$(AB-Alive 'Haizeiwang')"
'=== 日志关键行 ==='
if (Test-Path $log) {
    Select-String -Path $log -Pattern 'MainFrame|Announcement|LoginPage|showEnter|preEnterMainMenu|status:|load ccbi file|Button pressed|ERROR' |
        Select-Object -Last 35 | ForEach-Object { $_.Line }
}
'DONE'
