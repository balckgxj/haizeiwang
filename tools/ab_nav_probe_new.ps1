# 探针：新版点击底部导航，确认各页面进入坐标，逐页截图
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force
$proc = 'Haizeiwang'

function Probe([string]$name, [double]$u, [double]$v) {
    $c = Get-ABClient $proc; if (-not $c) { "LOST $name"; return }
    $p = AB-Click $c $u $v | Out-Null
    Start-Sleep -Seconds 3
    $c = Get-ABClient $proc; if (-not $c) { "LOST2 $name"; return }
    $shot = Join-Path $out ("new_probe_$name.png")
    $null = AB-Shot $c $shot
    "PROBE $name @($u,$v) -> $shot alive=$(AB-Alive $proc)"
}
function Home() { Probe 'home' 0.10 0.95; Start-Sleep -Milliseconds 500 }

# 当前应在主城
Probe 'lineup' 0.25 0.95     # 阵容
Home
Probe 'adventure' 0.55 0.95  # 冒险
Home
Probe 'voyage' 0.40 0.95     # 远航
Home
Probe 'duel' 0.70 0.95       # 决斗
Home
'DONE_PROBE'
