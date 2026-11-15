# 诊断：打开 HAIZEI_MENU_DIAG，观察点头像 / 点底部按钮时 Menu 的触摸链
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
[Environment]::SetEnvironmentVariable('HAIZEI_MENU_DIAG', '1', 'Process')
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$log  = Join-Path $dbg 'ab_diag.log'

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_diag.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 40
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 6
$c = Get-ABClient 'Haizeiwang'
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
'IN_CITY'

$mark = (Get-Item $log).Length
$c = Get-ABClient 'Haizeiwang'
AB-Click $c 0.171 0.278 | Out-Null       # 头像 1
Start-Sleep -Seconds 2
'=== 点头像后的诊断日志 ==='
$fs = [System.IO.File]::Open($log,'Open','Read','ReadWrite')
[void]$fs.Seek($mark,'Begin')
$sr = New-Object System.IO.StreamReader($fs); $t = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
@($t -split "`n") | Where-Object { $_ -match 'MenuDiag|SVDiag|Button pressed|onFrameButton|TeamPage' } |
    Select-Object -First 40

Start-Sleep -Milliseconds 500
$mark2 = (Get-Item $log).Length
$c = Get-ABClient 'Haizeiwang'
AB-Click $c 0.250 0.938 | Out-Null       # 底部「阵容」对照
Start-Sleep -Seconds 2
'=== 点底部按钮后的诊断日志（对照） ==='
$fs = [System.IO.File]::Open($log,'Open','Read','ReadWrite')
[void]$fs.Seek($mark2,'Begin')
$sr = New-Object System.IO.StreamReader($fs); $t = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
@($t -split "`n") | Where-Object { $_ -match 'MenuDiag|SVDiag|Button pressed' } | Select-Object -First 40

'=== 启动期 SVDiag（全部） ==='
Select-String -Path $log -Pattern '\[SVDiag\]' | Select-Object -First 12 | ForEach-Object { $_.Line }
'DONE'
