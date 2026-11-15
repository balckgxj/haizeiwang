# 启动老 Game.exe -> 登录 -> 截主城头像行（用于空位加号渲染对照），保持进程运行
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root    = 'E:\PCGame\Haizeiwang'
$out     = Join-Path $root '_tools\ab'
$oldRoot = 'E:\BaiduNetdiskDownload\(SY-096)草M船Z'
$oldExe  = Join-Path $oldRoot 'src\src\client\Release.win32\Game.exe'
$oldCwd  = Join-Path $oldRoot 'Debug_Alpha\Resources'
$null = New-Item -ItemType Directory -Path $out -Force

if (Get-ABClient 'Game') { AB-Stop 'Game'; Start-Sleep -Milliseconds 800 }
$null = Start-Process -FilePath $oldExe -WorkingDirectory $oldCwd -WindowStyle Normal -PassThru
$c = AB-Wait 'Game' 30
if (-not $c) { 'OLD_WINDOW_NOT_FOUND'; exit 1 }
Start-Sleep -Seconds 8
$c = Get-ABClient 'Game'
AB-Click $c 0.50 0.400 | Out-Null; AB-Key 'heigui'
AB-Click $c 0.50 0.483 | Out-Null; AB-Key '123456'
AB-Click $c 0.50 0.622 | Out-Null
'LOGIN_FORM_SENT'
Start-Sleep -Seconds 16
$c = Get-ABClient 'Game'
if ($c) {
    [void](AB-Shot $c (Join-Path $out 'old_home_avatar.png'))
    "OLD_ALIVE={0} shot=old_home_avatar.png ({1} bytes)" -f (AB-Alive 'Game'), (Get-Item (Join-Path $out 'old_home_avatar.png')).Length
} else { 'OLD_DEAD' }
