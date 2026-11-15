# ---------------------------------------------------------------------------
# A/B 滑动交互对照：两端用完全相同的归一化拖动序列
# 用法: & ab_scroll_ab.ps1 -Side old|new
#   前置：对应客户端已登录并停在主城
#   对每个可滑动区域：进页面 -> 截图 before -> 拖动 -> 截图 after -> 量化差异
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory=$true)][ValidateSet('old','new')][string]$Side
)
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'

$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root ("_tools\ab\scroll_$Side")
$null = New-Item -ItemType Directory -Path $out -Force
$proc = if ($Side -eq 'old') { 'Game' } else { 'Haizeiwang' }

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

# 纵向内容位移量：在中间列带（x 30%~70%）逐行比对，找使差异最小的上移行数（0..±240 源像素）
function VShift([string]$a, [string]$b) {
    if (-not (Test-Path $a) -or (-not (Test-Path $b))) { return 0 }
    $ia = [System.Drawing.Bitmap]::FromFile($a)
    $ib = [System.Drawing.Bitmap]::FromFile($b)
    $w = 40; $h = 240
    $sa = New-Object System.Drawing.Bitmap $w,$h
    $sb = New-Object System.Drawing.Bitmap $w,$h
    $ga = [System.Drawing.Graphics]::FromImage($sa); $gb = [System.Drawing.Graphics]::FromImage($sb)
    $ga.DrawImage($ia, 0,0,$w,$h); $gb.DrawImage($ib, 0,0,$w,$h)
    $best = 0; $bestScore = [double]::MaxValue
    for ($s = -120; $s -le 120; $s += 2) {
        $score = 0.0; $n = 0
        for ($y = 60; $y -lt 180; $y += 3) {
            $yy = $y + $s
            if ($yy -lt 0 -or $yy -ge $h) { continue }
            for ($x = 0; $x -lt $w; $x += 3) {
                $pa = $sa.GetPixel($x,$y); $pb = $sb.GetPixel($x,$yy)
                $score += [Math]::Abs([int]$pa.R-[int]$pb.R) + [Math]::Abs([int]$pa.G-[int]$pb.G) + [Math]::Abs([int]$pa.B-[int]$pb.B)
                $n++
            }
        }
        if ($n -gt 0) { $score /= $n; if ($score -lt $bestScore) { $bestScore = $score; $best = $s } }
    }
    $ga.Dispose(); $gb.Dispose(); $sa.Dispose(); $sb.Dispose(); $ia.Dispose(); $ib.Dispose()
    # s>0 表示 after 的内容相对 before 上移了 s 个源像素（手指上滑、内容上滚）
    return $best
}

$results = @()

function RunScroll([string]$name, [string]$enterBtn, [double]$u1,[double]$v1,[double]$u2,[double]$v2) {
    # 回主城
    $c = Get-ABClient $proc
    if (-not $c) { return }
    AB-Click $c 0.125 0.932 | Out-Null
    Start-Sleep -Milliseconds 1000
    # 进页面（若 enterBtn 为 $null 则说明本来就在主城）
    $c = Get-ABClient $proc
    if (-not $c) { return }
    if ($enterBtn) {
        AB-Click $c 0.5 $enterBtn | Out-Null
        Start-Sleep -Seconds 3
    } else {
        Start-Sleep -Milliseconds 600
    }
    $c = Get-ABClient $proc
    if (-not $c) { "LOST before $name"; return }
    $before = Join-Path $out ("${name}_a.png")
    $null = AB-Shot $c $before
    AB-Drag $c $u1 $v1 $u2 $v2 | Out-Null
    Start-Sleep -Seconds 2
    $c = Get-ABClient $proc
    if (-not $c) { "LOST after $name"; return }
    $after = Join-Path $out ("${name}_b.png")
    $null = AB-Shot $c $after
    $d = ImgDiff $before $after
    $sh = VShift $before $after
    $alive = AB-Alive $proc
    $script:results += [pscustomobject]@{ area=$name; diff=$d; vshift=$sh; alive=$alive }
    "{0,-16} diff={1,7} vshift={2,5} alive={3}" -f $name,$d,$sh,$alive
}

# 1) 主页：阵容头像行 横向拖动（向右滑出被裁掉的头像）
RunScroll 'main_avatar_h' $null 0.90 0.276 0.10 0.276
# 2) 阵容页：船员列表 纵向拖动
RunScroll 'member_v' 0.625 0.50 0.72 0.50 0.28
# 3) 冒险页：顶部活动子项 横向拖动
RunScroll 'adv_tabs_h' 0.427 0.90 0.155 0.10 0.155
# 4) 冒险页：活动内容 纵向拖动
RunScroll 'adv_v' 0.427 0.50 0.70 0.50 0.28
# 5) 远航页：关卡列表 纵向拖动
RunScroll 'voyage_list_v' 0.510 0.50 0.72 0.50 0.28
# 6) 远航页：章节 Tab 横向拖动
RunScroll 'voyage_tabs_h' 0.510 0.90 0.288 0.10 0.288

$results | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $out '_results.csv')
"DONE $Side -> $out"
