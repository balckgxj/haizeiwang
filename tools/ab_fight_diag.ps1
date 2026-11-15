# 打斗位置错乱取证：启动->登录->goto:FightPage 演示战斗->截图+读 FightDiag 日志
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab\crash'
$cmdFile = 'C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt'

AB-Stop 'Haizeiwang'; Start-Sleep -Milliseconds 700
if (Test-Path $cmdFile) { Remove-Item $cmdFile -Force }
Remove-Item (Join-Path $dbg 'ab_fight.log') -Force -ErrorAction SilentlyContinue
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'set HAIZEI_MENU_DIAG=1 && Haizeiwang.exe > ab_fight.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 7
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AT_LOGIN'; exit 1 }

# 跳演示战斗
[System.IO.File]::WriteAllText($cmdFile, 'goto:FightPage', (New-Object System.Text.UTF8Encoding($false)))
Start-Sleep -Seconds 5
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_AT_GOTO'; exit 1 }
$null = AB-Shot $c (Join-Path $out 'bf_t5s.png')
Start-Sleep -Seconds 6
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'DIED_LATER'; exit 1 }
$null = AB-Shot $c (Join-Path $out 'bf_t11s.png')
"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
