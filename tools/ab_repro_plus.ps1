# 复现：主页点空位"+" -> 跳转阵容页 -> 截图观察（为点击船员格定位坐标）
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
    -ArgumentList @('/c', 'set HAIZEI_MENU_DIAG=1 && Haizeiwang.exe > ab_crash.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 7
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AT_LOGIN'; exit 1 }
$null = AB-Shot $c (Join-Path $out 'r0_home.png')

# 主页空位"+" (u=0.76 v=0.30)
AB-Click $c 0.76 0.30 | Out-Null
Start-Sleep -Seconds 3
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AFTER_PLUS'; exit 1 }
$null = AB-Shot $c (Join-Path $out 'r1_after_plus.png')
"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
