# 验证阵容页空槽加号居中：启动->登录->主页点空位->阵容页拖动槽位行露出空槽->截图
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab\crash'

AB-Stop 'Haizeiwang'; Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_center.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 7
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AT_LOGIN'; exit 1 }

# 主页第5格（空位）进阵容页
AB-Click $c 0.76 0.30 | Out-Null
Start-Sleep -Seconds 3
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AFTER_PLUS'; exit 1 }
$null = AB-Shot $c (Join-Path $out 't0_team.png')

# 拖动顶部槽位行向左，露出第5空槽（v=0.12）
AB-Drag $c 0.75 0.12 0.30 0.12 | Out-Null
Start-Sleep -Seconds 2
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AFTER_DRAG'; exit 1 }
$null = AB-Shot $c (Join-Path $out 't1_row_scrolled.png')

"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
