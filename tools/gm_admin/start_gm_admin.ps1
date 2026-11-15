# [haizei] 启动 GM 运营后台（PHP 5.6 内置服务器）
# 依赖：MySQL 3306 与 DZM 服务端 25524（可用 tools\start_local_env.ps1 拉起）
# 用法：powershell -File tools\gm_admin\start_gm_admin.ps1
$ErrorActionPreference = "Stop"

# PowerShell 5.1's Start-Process builds a case-insensitive env dictionary; having both
# http_proxy and HTTP_PROXY makes it throw "Item has already been added".
# The local GM backend never needs a proxy, so drop both spellings for this process.
foreach ($n in @("http_proxy", "https_proxy", "all_proxy", "no_proxy",
                 "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")) {
    [Environment]::SetEnvironmentVariable($n, $null, "Process")
}

$root = Split-Path -Parent $PSScriptRoot          # tools\
$proj = Split-Path -Parent $root                  # 项目根
$dir  = $PSScriptRoot
$php  = "E:\Softwares\php-5.6.40\php.exe"
$port = 8080
$logDir = Join-Path $proj "_tools"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

if (-not (Test-Path $php)) { Write-Output "PHP_NOT_FOUND: $php"; exit 1 }

$listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listening) {
    Write-Output "gm_admin: already listening on $port -> http://127.0.0.1:$port/"
    exit 0
}

# [ab-parity] 老版 version_win32.cfg 的区服表返回 updateAddress/announcement 指向
# 192.168.1.3:8080（本机 LAN IP）。若只监听 127.0.0.1，老 Game.exe 的后续请求会
# 连不上并永远停在「正在检查更新」。与老 启动游戏.bat 一致改为 0.0.0.0。
$p = Start-Process -FilePath $php `
    -ArgumentList @("-S", "0.0.0.0:$port", "-t", "`"$dir`"") `
    -WorkingDirectory $dir -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $logDir "gm_admin_stdout.log") `
    -RedirectStandardError  (Join-Path $logDir "gm_admin_stderr.log")

for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { break }
}

if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
    Write-Output ("gm_admin: started pid={0} -> http://127.0.0.1:{1}/" -f $p.Id, $port)
    Write-Output "账号：游戏账号密码（首次登录者自动初始化为 GM）"
} else {
    Write-Output "gm_admin: FAILED to listen on $port, see _tools\gm_admin_stderr.log"
    exit 1
}
