# 分别启动老/新客户端，量取窗口与客户区坐标，各截一张登录页
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
$newExe  = Join-Path $root 'build\Debug\Haizeiwang.exe'
$newCwd  = Join-Path $root 'build\Debug'
$null = New-Item -ItemType Directory -Path $out -Force

Write-Output '=== 0) DPI / 屏幕 ==='
$m = Get-ABMetrics
$m.GetEnumerator() | Sort-Object Name | ForEach-Object { "  $($_.Name) = $($_.Value)" }

function Probe([string]$tag, [string]$proc, [string]$exe, [string]$cwd) {
    Write-Output ""
    Write-Output "=== $tag) 启动 $proc ==="
    AB-Stop $proc
    if (-not (Test-Path $exe)) { Write-Output "  EXE_MISSING $exe"; return }
    # 老 exe 的 AllocConsole 会把 stdout 写到自己的控制台；新 exe 用 cmd 重定向拿 CCLOG
    if ($tag -like 'NEW*') {
        [System.IO.File]::WriteAllText('C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt', 'boot_probe')
        $null = Start-Process -FilePath 'cmd.exe' `
            -ArgumentList @('/c', 'Haizeiwang.exe > ab_new.log 2>&1') `
            -WorkingDirectory $cwd -WindowStyle Normal -PassThru
    } else {
        $null = Start-Process -FilePath $exe -WorkingDirectory $cwd -WindowStyle Normal -PassThru
    }
    $c = AB-Wait $proc 35
    if (-not $c) { Write-Output "  WINDOW_NOT_FOUND"; return }
    "  class  = $($c.Cls)"
    "  title  = $($c.Title)"
    "  pid    = $($c.Pid)  dpi = $($c.Dpi)"
    "  window = L$($c.WinL) T$($c.WinT) R$($c.WinR) B$($c.WinB)  ($($c.WinR-$c.WinL))x$($c.WinB-$c.WinT)"
    "  client = X$($c.X) Y$($c.Y)  $($c.W)x$($c.Height)"
    "  ratio  = $([math]::Round($c.W / [double]$c.Height, 4))"
    Start-Sleep -Seconds 3
    $p = Join-Path $out ("probe_{0}_login.png" -f $tag.ToLower())
    [void](AB-Shot $c $p)
    "  shot   = $p  $((Get-Item $p).Length) bytes"
    # 元数据落盘，供后续脚本读取
    $c | ConvertTo-Json -Compress | Out-File -Encoding utf8 (Join-Path $out ("probe_{0}_client.json" -f $tag.ToLower()))
}

Probe 'OLD' 'Game'        $oldExe $oldCwd
Probe 'NEW' 'Haizeiwang'  $newExe $newCwd

Write-Output ''
Write-Output '=== 3) 收尾（关闭两个客户端） ==='
AB-Stop 'Game'
AB-Stop 'Haizeiwang'
Write-Output 'DONE'
