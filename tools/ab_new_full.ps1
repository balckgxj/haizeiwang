# 一体化（避免工具会话结束回收进程）：启动新版 -> 进入游戏 -> 主城 -> 20 项 A/B 序列
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_full.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 40
if (-not $c) { 'NO_WINDOW'; exit 1 }
"client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

Start-Sleep -Seconds 6
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'full_00_splash.png')
$p = AB-Click $c 0.50 0.79
"CLICK enter-game ($($p[0]),$($p[1]))"
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'full_01_city.png') }
"AFTER_ENTER alive=$(AB-Alive 'Haizeiwang')"

& (Join-Path $root 'tools\ab_run_sequence.ps1') -Side new
"FINAL_ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
