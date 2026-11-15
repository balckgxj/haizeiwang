# 密集扫描主城阵容头像行：找真实可点击位置 / 确认按钮是否挂载触摸
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$log  = Join-Path $dbg 'ab_head.log'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_head.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 40
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 6
$c = Get-ABClient 'Haizeiwang'
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
"IN_CITY {0}x{1}" -f $c.W,$c.Height

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

$hits = @()
$ys = @(0.22, 0.26, 0.30, 0.34)
$xs = @(0.10,0.15,0.20,0.25,0.30,0.35,0.40,0.45,0.50,0.55,0.60,0.65,0.70,0.75,0.80,0.85,0.90)
foreach ($v in $ys) {
  foreach ($u in $xs) {
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { 'WINDOW_LOST'; break }
    AB-Click $c 0.125 0.932 | Out-Null       # 回主城
    Start-Sleep -Milliseconds 500
    $len = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
    $c = Get-ABClient 'Haizeiwang'
    AB-Click $c $u $v | Out-Null
    Start-Sleep -Milliseconds 800
    $add = Since $len
    $sig = @($add | Where-Object { $_ -match 'Button pressed|onFrameButton|TeamPage|MSG_BOX|NeedUnlock|load ccbi file' } |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($sig.Count -gt 0) {
        $hits += "u=$u v=$v :: $($sig -join ' | ')"
        "HIT  u={0:0.00} v={1:0.00} :: {2}" -f $u,$v,($sig -join ' | ')
    }
  }
}
"TOTAL_HITS=$($hits.Count)"
$hits | Out-File -Encoding UTF8 (Join-Path $out 'head_scan_hits.txt')
'DONE'
