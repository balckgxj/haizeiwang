# 打斗位移时序取证：进演示战斗后连续截图
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

[System.IO.File]::WriteAllText($cmdFile, 'goto:FightPage', (New-Object System.Text.UTF8Encoding($false)))
Start-Sleep -Seconds 4
for ($t = 4; $t -le 36; $t += 4) {
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { "DIED_AT_t$t"; break }
    $null = AB-Shot $c (Join-Path $out ("seq_t{0:d2}.png" -f $t))
    Start-Sleep -Seconds 4
}
"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
