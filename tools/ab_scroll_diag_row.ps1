# 聚焦诊断：新版主页头像行，从不同起点横向拖动，开 MenuDiag 看触摸归属
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

# 强制重启用新构建
AB-Stop 'Haizeiwang'; Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'Haizeiwang.exe > ab_rowdiag.log 2>&1') -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45; if (-not $c){'NO_WINDOW';exit 1}
Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'; $null = AB-Shot $c (Join-Path $out 'rowdiag_splash.png')
AB-Click $c 0.50 0.79 | Out-Null; Start-Sleep -Seconds 16
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'rowdiag_home.png') }
"HOME alive=$(AB-Alive 'Haizeiwang')"

function TryDrag([string]$name,[double]$u1,[double]$v1,[double]$u2,[double]$v2){
    $c = Get-ABClient 'Haizeiwang'; if(-not $c){"$name LOST";return}
    $b = Join-Path $out ("rowdiag_${name}_a.png"); $null = AB-Shot $c $b
    AB-Drag $c $u1 $v1 $u2 $v2 | Out-Null
    Start-Sleep -Seconds 2
    $c = Get-ABClient 'Haizeiwang'; if(-not $c){"$name LOST2";return}
    $a = Join-Path $out ("rowdiag_${name}_b.png"); $null = AB-Shot $c $a
    "TRY $name alive=$(AB-Alive 'Haizeiwang')"
}
# 头像行在 v≈0.25；头像间缝隙、头像上、最左空白
TryDrag 'onBtn'    0.30 0.25 0.10 0.25
TryDrag 'gap'      0.50 0.25 0.30 0.25
TryDrag 'leftEdge' 0.12 0.25 0.32 0.25

# 抓 MenuDiag
$lg = Join-Path $dbg 'ab_rowdiag.log'
if (Test-Path $lg) { (Get-Content $lg | Where-Object { $_ -match '\[MenuDiag\]' } | Select-Object -Last 30) -join "`n" }
'ROWDIAG_DONE'
