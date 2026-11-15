# 诊断老 exe 是否真的发出了区服表请求
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root '_tools\ab'
$oldRoot = 'E:\BaiduNetdiskDownload\(SY-096)草M船Z'
$oldExe  = Join-Path $oldRoot 'src\src\client\Release.win32\Game.exe'
$oldCwd  = Join-Path $oldRoot 'Debug_Alpha\Resources'
$access  = Join-Path $root 'tools\gm_admin\gameserver\dzm\1.8\access.log'
$gameLog = Join-Path $oldCwd 'game.log'

$beforeAcc = if (Test-Path $access) { (Get-Item $access).Length } else { 0 }
$beforeLog = (Get-Item $gameLog).Length

AB-Stop 'Game'
$null = Start-Process -FilePath $oldExe -WorkingDirectory $oldCwd -WindowStyle Normal -PassThru
$c = AB-Wait 'Game' 30
if (-not $c) { Write-Output 'WINDOW_NOT_FOUND'; exit 1 }
Write-Output ("client {0}x{1} @({2},{3})" -f $c.W,$c.Height,$c.X,$c.Y)
Start-Sleep -Seconds 22
$c2 = Get-ABClient 'Game'
if ($c2) { [void](AB-Shot $c2 (Join-Path $out 'diag_old_22s.png')) }

Write-Output '=== 区服表接口新增访问 ==='
if (Test-Path $access) {
    $fs = [System.IO.File]::Open($access,'Open','Read','ReadWrite'); [void]$fs.Seek($beforeAcc,'Begin')
    $sr = New-Object System.IO.StreamReader($fs); Write-Output $sr.ReadToEnd(); $sr.Dispose()
} else { Write-Output '(no access.log)' }

Write-Output '=== game.log 新增尾部 ==='
$fs2 = [System.IO.File]::Open($gameLog,'Open','Read','ReadWrite'); [void]$fs2.Seek($beforeLog,'Begin')
$sr2 = New-Object System.IO.StreamReader($fs2)
$t = $sr2.ReadToEnd(); $sr2.Dispose()
($t -split "`n") | Select-Object -Last 25

AB-Stop 'Game'
Write-Output 'DONE'
