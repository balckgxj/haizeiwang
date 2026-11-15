# ---------------------------------------------------------------------------
# A/B 主城逐按钮序列：两端用完全相同的归一化坐标点击，逐项留图
# 用法: & ab_run_sequence.ps1 -Side old   /  -Side new
#   old -> 进程名 Game       (老 Game.exe)
#   new -> 进程名 Haizeiwang (新 Haizeiwang.exe)
# 前置: 对应客户端已登录并停在主城
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory=$true)][ValidateSet('old','new')][string]$Side,
    [switch]$LegacyNewCoords
)
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'

$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root ("_tools\ab\seq_$Side")
$null = New-Item -ItemType Directory -Path $out -Force
$proc = if ($Side -eq 'old') { 'Game' } else { 'Haizeiwang' }
# [parity] 修复设计分辨率后两端设计区均为 360x480，「首页」位置一致。
# 修复前新版是 320x480，首页落在 (0.073,0.944)；可用 -LegacyNewCoords 复现旧行为。
$homeU = 0.125
$homeV = 0.932
if ($Side -eq 'new' -and $LegacyNewCoords) { $homeU = 0.073; $homeV = 0.944 }

# 缩略图差异：把两张图缩到 48x64，算平均绝对像素差（0..255）
function ImgDiff([string]$a, [string]$b) {
    if (-not (Test-Path $a) -or -not (Test-Path $b)) { return -1 }
    $ia = [System.Drawing.Bitmap]::FromFile($a)
    $ib = [System.Drawing.Bitmap]::FromFile($b)
    $sa = New-Object System.Drawing.Bitmap 48,64
    $sb = New-Object System.Drawing.Bitmap 48,64
    $ga = [System.Drawing.Graphics]::FromImage($sa)
    $gb = [System.Drawing.Graphics]::FromImage($sb)
    $ga.DrawImage($ia, 0, 0, 48, 64); $gb.DrawImage($ib, 0, 0, 48, 64)
    $sum = 0.0
    for ($y=0; $y -lt 64; $y++) {
        for ($x=0; $x -lt 48; $x++) {
            $pa = $sa.GetPixel($x,$y); $pb = $sb.GetPixel($x,$y)
            $sum += [Math]::Abs([int]$pa.R-[int]$pb.R) + [Math]::Abs([int]$pa.G-[int]$pb.G) + [Math]::Abs([int]$pa.B-[int]$pb.B)
        }
    }
    $ga.Dispose(); $gb.Dispose(); $sa.Dispose(); $sb.Dispose(); $ia.Dispose(); $ib.Dispose()
    return [Math]::Round($sum / (48*64*3), 2)
}

# 主城基准图（序列开始前）
$c = Get-ABClient $proc
if (-not $c) { "ABORT: no client $proc"; exit 1 }
$base = Join-Path $out '_00_city_base.png'
$null = AB-Shot $c $base
"{0}: client {1}x{2} @({3},{4}) Dpi={5}" -f $Side,$c.W,$c.Height,$c.X,$c.Y,$c.Dpi

# 名称 / u / v —— 归一化自老版 720x960 主城图；两端共用同一组坐标
$btns = @(
    @{ n='crew_big';      u=0.375; v=0.625 },   # 船员（已验证命中）
    @{ n='equip_big';     u=0.708; v=0.635 },   # 装备
    @{ n='aoyi_big';      u=0.354; v=0.714 },   # 奥义
    @{ n='xiuxing_big';   u=0.632; v=0.719 },   # 修行
    @{ n='adventure_big'; u=0.500; v=0.427 },   # 冒险
    @{ n='voyage_big';    u=0.264; v=0.510 },   # 远航
    @{ n='duel_big';      u=0.681; v=0.516 },   # 决斗
    @{ n='avatar1';       u=0.178; v=0.276 },   # 阵容头像 1
    @{ n='avatar_plus';   u=0.785; v=0.276 },   # 空位加号
    @{ n='bag_tab';       u=0.156; v=0.830 },   # 包裹
    @{ n='handbook_tab';  u=0.299; v=0.830 },   # 图鉴
    @{ n='chat_tab';      u=0.442; v=0.830 },   # 聊天
    @{ n='enmity_tab';    u=0.583; v=0.830 },   # 恩怨
    @{ n='letter_tab';    u=0.729; v=0.830 },   # 传书
    @{ n='settings_tab';  u=0.861; v=0.830 },   # 设置
    @{ n='nav_crew';      u=0.264; v=0.932 },   # 底部 阵容
    @{ n='nav_voyage';    u=0.403; v=0.932 },   # 底部 远航
    @{ n='nav_adventure'; u=0.542; v=0.932 },   # 底部 冒险
    @{ n='nav_duel';      u=0.681; v=0.932 },   # 底部 决斗
    @{ n='nav_shop';      u=0.819; v=0.932 }    # 底部 商店
)

$results = @()
$i = 0
foreach ($b in $btns) {
    $i++
    # 1) 回主城：底部「首页」。同时留一张 pre 图用于判断返回是否成功
    $c = Get-ABClient $proc
    if (-not $c) { "LOST at $($b.n)"; break }
    AB-Click $c $homeU $homeV | Out-Null
    Start-Sleep -Milliseconds 1100
    $c = Get-ABClient $proc
    $pre = Join-Path $out ("{0:00}_{1}_pre.png" -f $i,$b.n)
    if ($c) { $null = AB-Shot $c $pre }
    $backDiff = ImgDiff $base $pre

    # 2) 点目标
    $c = Get-ABClient $proc
    if (-not $c) { "LOST before click $($b.n)"; break }
    $p = AB-Click $c $b.u $b.v
    Start-Sleep -Seconds 3

    # 3) 截图
    $c = Get-ABClient $proc
    $shot = Join-Path $out ("{0:00}_{1}.png" -f $i,$b.n)
    if ($c) { $null = AB-Shot $c $shot }
    $d = ImgDiff $base $shot
    $alive = AB-Alive $proc
    $results += [pscustomobject]@{ n=$b.n; u=$b.u; v=$b.v; diff=$d; back_diff=$backDiff; alive=$alive; screen="$($p[0]),$($p[1])" }
    "{0,2}/{1} {2,-16} diff={3,7} back={4,7} alive={5}" -f $i,$btns.Count,$b.n,$d,$backDiff,$alive
}

$results | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $out '_results.csv')
"DONE $Side -> $out"
