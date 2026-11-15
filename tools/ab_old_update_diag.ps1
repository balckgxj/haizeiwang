# 诊断老版「正在检查更新」卡点：监控 TCP 连接 + 临时文件 + 画面演进
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root '_tools\ab'
$oldDir = 'E:\BaiduNetdiskDownload\(SY-096)草M船Z\Debug_Alpha\Resources'
$wpath = "$env:LOCALAPPDATA\Game"

AB-Stop 'Game'
Start-Sleep -Milliseconds 800
$log1 = Join-Path $oldDir 'game.log'
if (Test-Path $log1) { $before = (Get-Item $log1).Length } else { $before = 0 }
"game.log before=$before"

$p = Start-Process -FilePath (Join-Path $oldDir 'Game.exe') -WorkingDirectory $oldDir -PassThru
"started pid=$($p.Id)"

for ($i = 0; $i -lt 8; $i++) {
    Start-Sleep -Seconds 6
    $conns = @(Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue |
        Where-Object { $_.RemotePort -eq 8080 -or $_.RemotePort -eq 25524 })
    $connStr = ($conns | ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort)=$($_.State)" }) -join ','
    $files = @(Get-ChildItem $wpath -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'UserDefault*' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 4 |
        ForEach-Object { "$($_.Name)($($_.Length))" }) -join ','
    $c = Get-ABClient 'Game'
    $shot = Join-Path $out ("diag2_{0:00}.png" -f $i)
    if ($c) { $null = AB-Shot $c $shot }
    "t={0,2}s alive={1} conns=[{2}] files=[{3}]" -f (($i+1)*6), (AB-Alive 'Game'), $connStr, $files
}

"=== game.log 新增段 ==="
if (Test-Path $log1) {
    $fs = [System.IO.File]::Open($log1,'Open','Read','ReadWrite')
    [void]$fs.Seek($before,'Begin')
    $sr = New-Object System.IO.StreamReader($fs)
    $t = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
    ($t -split "`n" | Where-Object { $_ -match 'sever|Sever|download|Download|curl|version|crc|fail|error|CS_' } | Select-Object -Last 40) -join "`n"
}
'DONE'
