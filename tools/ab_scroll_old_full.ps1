# 非沙箱一体化：启动老 Game.exe -> 登录 heigui/123456 -> 主城 -> 6 项滑动对照
# 用法（必须以非沙箱权限执行）：& ab_scroll_old_full.ps1
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
$null = Start-Process -FilePath (Join-Path $oldDir 'Game.exe') -WorkingDirectory $oldDir -PassThru
$c = AB-Wait 'Game' 40
if (-not $c) { 'NO_WINDOW'; exit 1 }
"client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

# 等检查更新结束：轮询画面，出现「进入游戏」/登录页时停止
$prev = ''
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 4
    $c = Get-ABClient 'Game'
    if (-not $c) { 'WINDOW_LOST'; break }
    $shot = Join-Path $out ("olboot_{0:00}.png" -f $i)
    $null = AB-Shot $c $shot
    $h = (Get-FileHash $shot -Algorithm MD5).Hash
    "t={0,2}s hash={1}" -f (($i+1)*4), $h.Substring(0,8)
    if ($prev -and $h -ne $prev -and $i -ge 1) { "PAGE_CHANGED at t=$(($i+1)*4)"; break }
    $prev = $h
}

# 进入游戏（启动页按钮）
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.79 | Out-Null }
Start-Sleep -Seconds 5
$c = Get-ABClient 'Game'
if ($c) { $null = AB-Shot $c (Join-Path $out 'ol_login.png') }

# 若出现账号密码页：输入
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.40 | Out-Null }
Start-Sleep -Milliseconds 400
AB-Key 'heigui'
Start-Sleep -Milliseconds 400
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.483 | Out-Null }
Start-Sleep -Milliseconds 400
AB-Key '123456'
Start-Sleep -Milliseconds 400
$c = Get-ABClient 'Game'
if ($c) { AB-Click $c 0.50 0.622 | Out-Null }
Start-Sleep -Seconds 10
$c = Get-ABClient 'Game'
if ($c) { $null = AB-Shot $c (Join-Path $out 'ol_city.png') }
"CITY alive=$(AB-Alive 'Game')"

"=== game.log 更新相关 ==="
$lg = Join-Path $oldDir 'game.log'
if (Test-Path $lg) {
    (Get-Content $lg -Tail 400 | Where-Object { $_ -match 'sever|Sever|download|Download|curl|version|CS_|enter game|Login' } | Select-Object -Last 25) -join "`n"
}

& (Join-Path $root 'tools\ab_scroll_ab.ps1') -Side old
"FINAL_ALIVE=$(AB-Alive 'Game')"
'DONE'
