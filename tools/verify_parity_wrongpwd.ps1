# [haizei] 功能一致性专项：密码错误分支的本地化提示
# 复用 tools/verify_login_e2e.ps1 的 -WrongPassword 路径（比例坐标已验证），
# 三服务 + 客户端必须在同一次会话内拉起，否则后台进程会被会话回收。
$ErrorActionPreference = 'Continue'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}

$root    = 'E:\PCGame\Haizeiwang'
$out     = Join-Path $root '_tools'
$mysqlDir = 'E:\Softwares\mysql-5.6.51-winx64'
$jdk     = 'E:\Softwares\jdk8u512-b09\bin\java.exe'
$srvDir  = 'E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\server\Code_Server\server'
$php     = 'E:\Softwares\php-5.6.40\php.exe'
$gmDir   = Join-Path $root 'tools\gm_admin'

function PortUp([int]$port) {
    return ($null -ne (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue))
}
function WaitPort([int]$port, [int]$sec) {
    for ($i = 0; $i -lt $sec; $i++) { if (PortUp $port) { return $true }; Start-Sleep -Seconds 1 }
    return (PortUp $port)
}

Write-Output '=== 1) 拉起本地服务 ==='
if (-not (PortUp 3306)) {
    $null = Start-Process -FilePath (Join-Path $mysqlDir 'bin\mysqld.exe') `
        -ArgumentList @("--defaults-file=`"$(Join-Path $mysqlDir 'my.ini')`"") `
        -WorkingDirectory $mysqlDir -WindowStyle Hidden -PassThru `
        -RedirectStandardError (Join-Path $out 'mysql_stderr.log')
}
Write-Output ("mysql 3306 : {0}" -f (WaitPort 3306 25))
if (-not (PortUp 25524)) {
    $null = Start-Process -FilePath $jdk -ArgumentList @('-Dfile.encoding=UTF-8','-jar','DZM.jar') `
        -WorkingDirectory $srvDir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $srvDir 'dzm_stdout.log') `
        -RedirectStandardError (Join-Path $srvDir 'dzm_stderr.log')
}
Write-Output ("server 25524 : {0}" -f (WaitPort 25524 30))
if (-not (PortUp 8080)) {
    $null = Start-Process -FilePath $php -ArgumentList @('-S','127.0.0.1:8080','-t',"`"$gmDir`"") `
        -WorkingDirectory $gmDir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $out 'gm_admin_stdout.log') `
        -RedirectStandardError (Join-Path $out 'gm_admin_stderr.log')
}
Write-Output ("gm_admin 8080 : {0}" -f (WaitPort 8080 15))
if (-not ((PortUp 3306) -and (PortUp 25524) -and (PortUp 8080))) {
    Write-Output 'SERVICES_NOT_READY'; exit 1
}

Write-Output '=== 2) 错误密码登录（status 6 分支） ==='
& (Join-Path $root 'tools\verify_login_e2e.ps1') -WrongPassword 2>&1 |
    Tee-Object -FilePath (Join-Path $out 'parity_wrongpwd_run.log')

# 保留本次证据，避免被后续验证覆盖
foreach ($src in @('login_e2e_after.png','login_e2e_before.png')) {
    $p = Join-Path $out $src
    if (Test-Path $p) {
        Copy-Item -LiteralPath $p -Destination (Join-Path $out ("parity_wrongpwd_" + $src)) -Force
    }
}
Write-Output '=== DONE ==='
