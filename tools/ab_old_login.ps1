# 一体化：启网关(0.0.0.0) -> 启动老 Game.exe -> 观察启动 -> 按 heigui/123456 登录 -> 截图
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
$php     = 'E:\Softwares\php-5.6.40\php.exe'
$gmDir   = Join-Path $root 'tools\gm_admin'
$gameLog = Join-Path $oldCwd 'game.log'
$null = New-Item -ItemType Directory -Path $out -Force

# --- 1) 网关 ---  
if (-not (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)) {
    $null = Start-Process -FilePath $php `
        -ArgumentList @('-S','0.0.0.0:8080','-t',"`"$gmDir`"") `
        -WorkingDirectory $gmDir -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
}
$listen = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
Write-Output ("GW: {0}" -f $(if ($listen) { $listen[0].LocalAddress } else { 'DOWN' }))
foreach ($h in @('127.0.0.1','192.168.1.3')) {
    try {
        $r = Invoke-WebRequest -Uri "http://$h:8080/gameserver/dzm/1.8/servers_list.php" -UseBasicParsing -TimeoutSec 4
        Write-Output ("  {0} -> {1}" -f $h, $r.StatusCode)
    } catch { Write-Output ("  {0} -> FAIL {1}" -f $h, $_.Exception.Message) }
}

# --- 2) 老客户端 ---  
$beforeLog = (Get-Item $gameLog).Length
AB-Stop 'Game'
$null = Start-Process -FilePath $oldExe -WorkingDirectory $oldCwd -WindowStyle Normal -PassThru
$c = AB-Wait 'Game' 30
if (-not $c) { Write-Output 'OLD_WINDOW_NOT_FOUND'; exit 1 }
Write-Output ("OLD client {0}x{1} @({2},{3})" -f $c.W,$c.Height,$c.X,$c.Y)
for ($i = 0; $i -lt 6; $i++) {
    Start-Sleep -Seconds 4
    $c2 = Get-ABClient 'Game'
    if ($c2) { [void](AB-Shot $c2 (Join-Path $out ("old_boot_{0}.png" -f $i))) }
}
Write-Output '=== game.log 新增尾部 ==='
$fs = [System.IO.File]::Open($gameLog,'Open','Read','ReadWrite'); [void]$fs.Seek($beforeLog,'Begin')
$sr = New-Object System.IO.StreamReader($fs); $t = $sr.ReadToEnd(); $sr.Dispose()
($t -split "`n") | Select-Object -Last 20

# --- 3) 登录（归一化坐标，来自 verify_login_e2e.ps1） ---  
$c3 = Get-ABClient 'Game'
if ($c3) {
    AB-Click $c3 0.50 0.400 | Out-Null; AB-Key 'heigui'
    AB-Click $c3 0.50 0.483 | Out-Null; AB-Key '123456'
    AB-Click $c3 0.50 0.622 | Out-Null
    Write-Output 'LOGIN_FORM_SENT'
    Start-Sleep -Seconds 16
    $c4 = Get-ABClient 'Game'
    if ($c4) { [void](AB-Shot $c4 (Join-Path $out 'old_after_login.png')) }
    Write-Output ("OLD_ALIVE={0}" -f (AB-Alive 'Game'))
}
AB-Stop 'Game'
Write-Output 'DONE'
