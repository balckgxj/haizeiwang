# 带诊断启动新版，抓取 [SVDiag] setContainer 真实尺寸
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
[Environment]::SetEnvironmentVariable('HAIZEI_MENU_DIAG', '1', 'Process')
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'Haizeiwang.exe > ab_diag.log 2>&1') -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
"NEW {0}x{1} Dpi={2}" -f $c.W,$c.Height,$c.Dpi
Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'; $null = AB-Shot $c (Join-Path $out 'diag_home_splash.png')
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'diag_home.png') }
"HOME alive=$(AB-Alive 'Haizeiwang')"
# 抓诊断
$lg = Join-Path $dbg 'ab_diag.log'
if (Test-Path $lg) {
    (Get-Content $lg | Where-Object { $_ -match '\[SVDiag\]|force sized' } | Select-Object -First 40) -join "`n"
}
'DIAG_DONE'