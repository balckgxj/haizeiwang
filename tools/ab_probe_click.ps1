# 验证 A/B 驱动在老版主城上的点击精度：点「船员」-> 截图 -> 点「首页」-> 截图
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
$out = 'E:\PCGame\Haizeiwang\_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

$c = Get-ABClient 'Game'
if (-not $c) { 'NO_OLD_CLIENT'; exit 1 }
"OLD W=$($c.W) H=$($c.Height) @($($c.X),$($c.Y)) Dpi=$($c.Dpi)"

$null = AB-Shot $c (Join-Path $out 'pc_00_city.png')

# 中部「船员」按钮：老版 720x960 图上约 (270, 600)
$p = AB-Click $c 0.375 0.625
"CLICK crew -> screen ($($p[0]),$($p[1]))"
Start-Sleep -Seconds 3
$c = Get-ABClient 'Game'
if ($c) { $null = AB-Shot $c (Join-Path $out 'pc_01_crew.png') }

# 底部「首页」返回
$p = AB-Click $c 0.125 0.932
"CLICK home -> screen ($($p[0]),$($p[1]))"
Start-Sleep -Seconds 2
$c = Get-ABClient 'Game'
if ($c) { $null = AB-Shot $c (Join-Path $out 'pc_02_back.png') }

"ALIVE=$(AB-Alive 'Game')"
"DONE"
