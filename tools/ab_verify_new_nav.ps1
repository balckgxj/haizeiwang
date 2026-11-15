# 一次性脚本：启动新版 -> 登录 -> 立即点底部导航阵容 -> 检查存活（验证进程被回收假设）
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'Haizeiwang.exe > ab_verify.log 2>&1') -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
"NEW {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi
Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'; $null = AB-Shot $c (Join-Path $out 'verify_splash.png')
AB-Click $c 0.50 0.79 | Out-Null   # 进入游戏
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'verify_home.png') }
"HOME alive=$(AB-Alive 'Haizeiwang')"

# 立即点底部导航：阵容 (u=0.264 v=0.932, 与上一轮工作序列一致)
$c = Get-ABClient 'Haizeiwang'
$p = AB-Click $c 0.264 0.932 | Out-Null
Start-Sleep -Seconds 3
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'verify_lineup.png') }
"AFTER nav_crew alive=$(AB-Alive 'Haizeiwang') shot=verify_lineup.png"

# 再点冒险
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.125 0.932 | Out-Null; Start-Sleep -Milliseconds 1100 }  # 回首页
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.542 0.932 | Out-Null; Start-Sleep -Seconds 3 }
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'verify_adventure.png') }
"AFTER nav_adventure alive=$(AB-Alive 'Haizeiwang')"

# 再点远航
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.125 0.932 | Out-Null; Start-Sleep -Milliseconds 1100 }
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.403 0.932 | Out-Null; Start-Sleep -Seconds 3 }
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'verify_voyage.png') }
"AFTER nav_voyage alive=$(AB-Alive 'Haizeiwang')"
'VERIFY_DONE'
