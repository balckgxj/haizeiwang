# 扫描新版主城底部栏/头像行的真实可点击区域（同会话内启动+登录+扫描）
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$log  = Join-Path $dbg 'ab_scan.log'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_scan.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 40
if (-not $c) { 'NO_WINDOW'; exit 1 }
"client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi
Start-Sleep -Seconds 6
$c = Get-ABClient 'Haizeiwang'
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
$base = Join-Path $out 'scan_base.png'
$null = AB-Shot $c $base
'IN_CITY'

function Since([long]$from) {
    if (-not (Test-Path $log)) { return @() }
    $fs = [System.IO.File]::Open($log,'Open','Read','ReadWrite')
    try {
        [void]$fs.Seek($from,'Begin')
        $sr = New-Object System.IO.StreamReader($fs)
        $t = $sr.ReadToEnd(); $sr.Dispose()
        return @($t -split "`n")
    } finally { $fs.Dispose() }
}

# 标签 / u / v
$pts = @(
    @{ n='head1_own';  u=0.171; v=0.278 },
    @{ n='head1_old';  u=0.178; v=0.276 },
    @{ n='head2';      u=0.300; v=0.278 },
    @{ n='head3';      u=0.440; v=0.278 },
    @{ n='head4';      u=0.580; v=0.278 },
    @{ n='plus_own';   u=0.792; v=0.278 },
    @{ n='plus_old';   u=0.785; v=0.276 },
    @{ n='nav1_home';  u=0.125; v=0.938 },
    @{ n='nav2_own';   u=0.250; v=0.938 },
    @{ n='nav2_old';   u=0.264; v=0.932 },
    @{ n='nav3_own';   u=0.375; v=0.938 },
    @{ n='nav3_old';   u=0.403; v=0.932 },
    @{ n='nav4_own';   u=0.521; v=0.938 },
    @{ n='nav4_old';   u=0.542; v=0.932 },
    @{ n='nav5_own';   u=0.656; v=0.938 },
    @{ n='nav5_old';   u=0.681; v=0.932 },
    @{ n='nav6_own';   u=0.802; v=0.938 },
    @{ n='nav6_old';   u=0.819; v=0.932 },
    @{ n='nav7_arrow'; u=0.917; v=0.938 },
    @{ n='nav2_hi';    u=0.250; v=0.905 },
    @{ n='nav2_lo';    u=0.250; v=0.965 }
)

$rows = @()
foreach ($p in $pts) {
    # 回主城
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { 'WINDOW_LOST'; break }
    AB-Click $c 0.125 0.932 | Out-Null
    Start-Sleep -Milliseconds 900
    $len = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
    $c = Get-ABClient 'Haizeiwang'
    AB-Click $c $p.u $p.v | Out-Null
    Start-Sleep -Seconds 2
    $add = Since $len
    $press = @($add | Where-Object { $_ -match 'Button pressed' } |
        ForEach-Object { ($_ -replace '.*func:','func:') -replace ',\s*tag:.*','' })
    $ccbi = @($add | Where-Object { $_ -match 'load ccbi file' } |
        ForEach-Object { ($_ -split 'file:')[-1].Trim() } | Select-Object -Unique)
    $shot = Join-Path $out ("scan_{0}.png" -f $p.n)
    $c = Get-ABClient 'Haizeiwang'
    if ($c) { $null = AB-Shot $c $shot }
    $rows += [pscustomobject]@{
        n=$p.n; u=$p.u; v=$p.v
        pressed=($press -join '|'); ccbi=($ccbi -join '|')
    }
    "{0,-14} u={1:0.000} v={2:0.000} :: {3} :: {4}" -f $p.n,$p.u,$p.v,($press -join '|'),($ccbi -join '|')
}
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $out 'scan_results.csv')
'DONE'
