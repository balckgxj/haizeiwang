# 启动老版 Game.exe，等待主城，抓主页截图（含头像行放大）
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root '_tools\ab\crash'
$oldExe = 'E:\BaiduNetdiskDownload\(SY-096)草M船Z\Debug_Alpha\Resources\Game.exe'
$oldDir = Split-Path $oldExe

$c = Get-ABClient 'Game'
if (-not $c) {
    Start-Process -FilePath $oldExe -WorkingDirectory $oldDir | Out-Null
    $c = AB-Wait 'Game' 40
    if (-not $c) { 'OLD_NO_WINDOW'; exit 1 }
    Start-Sleep -Seconds 6
}
"OLD {0}x{1} @({2},{3})" -f $c.W,$c.Height,$c.X,$c.Y
$null = AB-Shot $c (Join-Path $out 'old_s0.png')

# 可能需要点"进入游戏"
AB-Click $c 0.50 0.79 | Out-Null
for ($i=1; $i -le 5; $i++) {
    Start-Sleep -Seconds 4
    $cc = Get-ABClient 'Game'
    if ($cc) { $null = AB-Shot $cc (Join-Path $out ("old_s{0}.png" -f $i)) }
}
"ALIVE=$(AB-Alive 'Game')"
'DONE'
