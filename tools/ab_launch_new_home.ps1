# 启动新版 -> 登录 heigui/123456 -> 主城，抓取主城基准截图
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
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_new_home.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
"NEW client {0}x{1} @({2},{3}) Dpi={4} Title='{5}'" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi,$c.Title

Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'new_home_splash.png')
'SHOT_SPLASH'

# 进入游戏按钮（启动页）
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.50 0.79 | Out-Null }
Start-Sleep -Seconds 18
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'new_home_base.png') }
"NEW_HOME alive=$(AB-Alive 'Haizeiwang')"

# 日志验证
$lg = Join-Path $dbg 'game.log'
if (Test-Path $lg) {
    (Get-Content $lg -Tail 60 | Where-Object { $_ -match 'sever|Sever|enter game|Login|connect|Connect|CCB:Button|status' } | Select-Object -Last 12) -join "`n"
}
'DONE'
