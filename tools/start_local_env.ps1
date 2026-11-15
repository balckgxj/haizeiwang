# Restore the local runtime after a machine reboot: MySQL 5.6 -> DZM server -> game client.
# Idempotent: each component is started only when its port/process is absent.
$ErrorActionPreference = "Continue"

# PowerShell 5.1's Start-Process builds a case-insensitive env dictionary; having both
# HTTPS_PROXY and https_proxy makes it throw "Item has already been added".
# Local DB/server/client never need a proxy, so drop both spellings for this process.
foreach ($n in @("http_proxy", "https_proxy", "all_proxy", "no_proxy",
                 "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")) {
    [Environment]::SetEnvironmentVariable($n, $null, "Process")
}

$mysqlDir = "E:\Softwares\mysql-5.6.51-winx64"
$mysqld   = Join-Path $mysqlDir "bin\mysqld.exe"
$myIni    = Join-Path $mysqlDir "my.ini"
$jdk      = "E:\Softwares\jdk8u512-b09\bin\java.exe"
$srvDir   = "E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\server\Code_Server\server"
$root     = "E:\PCGame\Haizeiwang"
$exe      = Join-Path $root "build\Debug\Haizeiwang.exe"
$logDir   = Join-Path $root "_tools"

function PortUp([int]$port) {
    $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    return ($null -ne $c)
}

function WaitPort([int]$port, [int]$seconds) {
    for ($i = 0; $i -lt $seconds; $i++) {
        if (PortUp $port) { return $true }
        Start-Sleep -Seconds 1
    }
    return (PortUp $port)
}

# --- 1. MySQL ---
if (PortUp 3306) {
    Write-Output "mysql   : already listening on 3306"
} else {
    $p = Start-Process -FilePath $mysqld -ArgumentList @("--defaults-file=`"$myIni`"") `
        -WorkingDirectory $mysqlDir -WindowStyle Hidden -PassThru `
        -RedirectStandardError (Join-Path $logDir "mysql_stderr.log")
    Write-Output ("mysql   : started pid={0}, waiting..." -f $p.Id)
    if (-not (WaitPort 3306 25)) { Write-Output "mysql   : FAILED to listen on 3306"; exit 1 }
    Write-Output "mysql   : ready on 3306"
}

# --- 2. DZM game server ---
if (PortUp 25524) {
    Write-Output "server  : already listening on 25524"
} else {
    $p = Start-Process -FilePath $jdk -ArgumentList @("-Dfile.encoding=UTF-8", "-jar", "DZM.jar") `
        -WorkingDirectory $srvDir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $srvDir "dzm_stdout.log") `
        -RedirectStandardError (Join-Path $srvDir "dzm_stderr.log")
    Write-Output ("server  : started pid={0}, waiting..." -f $p.Id)
    if (-not (WaitPort 25524 30)) { Write-Output "server  : FAILED to listen on 25524"; exit 1 }
    Write-Output "server  : ready on 25524"
}

# --- 3. Game client (only when explicitly requested) ---
if ($args -contains "-WithGame") {
    $running = Get-Process Haizeiwang -ErrorAction SilentlyContinue
    if ($running) {
        Write-Output ("client  : already running pid={0}" -f $running[0].Id)
    } else {
        Remove-Item (Join-Path $root "build\Debug\crash_stack.txt") -Force -ErrorAction SilentlyContinue
        $p = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru `
            -RedirectStandardOutput (Join-Path $logDir "verify_run.log") `
            -RedirectStandardError (Join-Path $logDir "verify_stderr.log")
        Write-Output ("client  : started pid={0}, waiting for window..." -f $p.Id)
        for ($i = 0; $i -lt 25; $i++) {
            Start-Sleep -Seconds 1
            $q = Get-Process Haizeiwang -ErrorAction SilentlyContinue
            if ($q -and $q.MainWindowHandle -ne 0) { break }
        }
        $q = Get-Process Haizeiwang -ErrorAction SilentlyContinue
        if ($q -and $q.MainWindowHandle -ne 0) {
            Write-Output ("client  : window ready hwnd={0}" -f $q.MainWindowHandle)
        } else {
            Write-Output "client  : FAILED to create a window"
        }
    }
}

Write-Output "--- final state ---"
Write-Output ("3306={0} 25524={1}" -f (PortUp 3306), (PortUp 25524))
Get-Process Haizeiwang, java, mysqld -ErrorAction SilentlyContinue |
    Select-Object ProcessName, Id, MainWindowHandle | Format-Table -AutoSize | Out-String
