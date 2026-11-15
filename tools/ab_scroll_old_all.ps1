# 一体化：启动老 Game.exe -> 等登录页 -> 若需登录则输入 heigui/123456 -> 主城 -> 滑动 A/B 序列
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root '_tools\ab'
$oldDir = 'E:\BaiduNetdiskDownload\(SY-096)草M船Z\Debug_Alpha\Resources'

AB-Stop 'Game'
Start-Sleep -Milliseconds 800
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Game.exe > ab_old_scroll.log 2>&1') `
    -WorkingDirectory $oldDir -WindowStyle Normal -PassThru
$c = AB-Wait 'Game' 40
if (-not $c) { 'NO_WINDOW'; exit 1 }
"client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi
Start-Sleep -Seconds 8
$c = Get-ABClient 'Game'
if ($c) { $null = AB-Shot $c (Join-Path $out 'scroll_old_boot.png') }
'BOOT_SHOT_OK'

# 老版：先尝试「进入游戏」（启动页），再输入账号密码
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.79 | Out-Null }
Start-Sleep -Seconds 6
$c = Get-ABClient 'Game'
if ($c) { $null = AB-Shot $c (Join-Path $out 'scroll_old_step2.png') }
'S T E P 2'

# 账号
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.40 | Out-Null }
Start-Sleep -Milliseconds 500
AB-Key 'heigui'
Start-Sleep -Milliseconds 500
# 密码
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.483 | Out-Null }
Start-Sleep -Milliseconds 500
AB-Key '123456'
Start-Sleep -Milliseconds 500
# 登录
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.622 | Out-Null }
Start-Sleep -Seconds 12
$c = Get-ABClient 'Game'
if ($c) { $null = AB-Shot $c (Join-Path $out 'scroll_old_city.png') }
"CITY_SHOT alive=$(AB-Alive 'Game')"

& (Join-Path $root 'tools\ab_scroll_ab.ps1') -Side old
"FINAL_ALIVE=$(AB-Alive 'Game')"
'DONE'
