# 观察两端启动流程：每 3 秒截一张客户区图，共 12 张，确定登录页稳定时机
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

function Flow([string]$tag, [string]$proc, [string]$exe, [string]$cwd) {
    AB-Stop $proc
    if ($tag -eq 'new') {
        [System.IO.File]::WriteAllText('C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt', 'boot_flow')
        $null = Start-Process -FilePath 'cmd.exe' `
            -ArgumentList @('/c', 'Haizeiwang.exe > ab_flow_new.log 2>&1') `
            -WorkingDirectory $cwd -WindowStyle Normal -PassThru
    } else {
        $null = Start-Process -FilePath $exe -WorkingDirectory $cwd -WindowStyle Normal -PassThru
    }
    $c = AB-Wait $proc 35
    if (-not $c) { Write-Output "$tag WINDOW_NOT_FOUND"; return }
    Write-Output ("{0} client {1}x{2} @({3},{4}) dpi={5}" -f $tag,$c.W,$c.Height,$c.X,$c.Y,$c.Dpi)
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 3
        $c2 = Get-ABClient $proc
        if (-not $c2) { Write-Output "$tag WINDOW_LOST at $($i*3+3)s"; break }
        $p = Join-Path $out ("flow_{0}_{1:D2}.png" -f $tag, $i)
        [void](AB-Shot $c2 $p)
        Write-Output ("{0} t={1,2}s  {2}" -f $tag, ($i*3+3), (Split-Path -Leaf $p))
    }
    AB-Stop $proc
}

Flow 'old' 'Game'       $oldExe $oldCwd
Flow 'new' 'Haizeiwang' $newExe $newCwd
Write-Output 'DONE'
