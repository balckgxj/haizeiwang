# 一体化滑动 A/B：老 Game.exe(已在主城) + 新 Haizeiwang.exe(本脚本启动并登录)
# 对每个可滑动区域：进页面 -> before -> 拖动 -> after -> 量化位移；两端逐一对照
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab\scroll'
$null = New-Item -ItemType Directory -Path $out -Force

# ---- 启动新版 ----
AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'Haizeiwang.exe > ab_scroll_full.log 2>&1') -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$cn = AB-Wait 'Haizeiwang' 45
if (-not $cn) { 'NEW_NO_WINDOW'; exit 1 }
"NEW {0}x{1} @({2},{3}) Dpi={4}" -f $cn.W,$cn.Height,$cn.X,$cn.Y,$cn.Dpi
Start-Sleep -Seconds 7
$cn = Get-ABClient 'Haizeiwang'; $null = AB-Shot $cn (Join-Path $out 'new_00_splash.png')
AB-Click $cn 0.50 0.79 | Out-Null
Start-Sleep -Seconds 16
$cn = Get-ABClient 'Haizeiwang'
if ($cn) { $null = AB-Shot $cn (Join-Path $out 'new_01_home.png') }
"NEW_HOME alive=$(AB-Alive 'Haizeiwang')"

# ---- 指标 ----
function ImgDiff([string]$a, [string]$b) {
    if (-not (Test-Path $a) -or -not (Test-Path $b)) { return -1 }
    $ia = [System.Drawing.Bitmap]::FromFile($a); $ib = [System.Drawing.Bitmap]::FromFile($b)
    $w=48;$h=64; $sa=New-Object System.Drawing.Bitmap $w,$h; $sb=New-Object System.Drawing.Bitmap $w,$h
    $ga=[System.Drawing.Graphics]::FromImage($sa); $gb=[System.Drawing.Graphics]::FromImage($sb)
    $ga.DrawImage($ia,0,0,$w,$h); $gb.DrawImage($ib,0,0,$w,$h)
    $sum=0.0
    for($y=0;$y -lt $h;$y++){for($x=0;$x -lt $w;$x++){$pa=$sa.GetPixel($x,$y);$pb=$sb.GetPixel($x,$y);$sum+=[Math]::Abs([int]$pa.R-[int]$pb.R)+[Math]::Abs([int]$pa.G-[int]$pb.G)+[Math]::Abs([int]$pa.B-[int]$pb.B)}}
    $ga.Dispose();$gb.Dispose();$sa.Dispose();$sb.Dispose();$ia.Dispose();$ib.Dispose()
    return [Math]::Round($sum/($w*$h*3),2)
}
# 垂直位移：找使 before/after 在中间列带最匹配的上移行数（>0 表示内容上滚）
function VShift([string]$a,[string]$b){
    if(-not(Test-Path $a)-or -not(Test-Path $b)){return 0}
    $ia=[System.Drawing.Bitmap]::FromFile($a);$ib=[System.Drawing.Bitmap]::FromFile($b)
    $w=40;$h=360;$sa=New-Object System.Drawing.Bitmap $w,$h;$sb=New-Object System.Drawing.Bitmap $w,$h
    $ga=[System.Drawing.Graphics]::FromImage($sa);$gb=[System.Drawing.Graphics]::FromImage($sb)
    $ga.DrawImage($ia,0,0,$w,$h);$gb.DrawImage($ib,0,0,$w,$h)
    $best=0;$bs=[double]::MaxValue
    for($s=-150;$s -le 150;$s+=2){$sc=0.0;$nn=0
        for($y=60;$y -lt 300;$y+=3){$yy=$y+$s;if($yy -lt 0 -or $yy -ge $h){continue}
            for($x=0;$x -lt $w;$x+=3){$pa=$sa.GetPixel($x,$y);$pb=$sb.GetPixel($x,$yy);$sc+=[Math]::Abs([int]$pa.R-[int]$pb.R)+[Math]::Abs([int]$pa.G-[int]$pb.G)+[Math]::Abs([int]$pa.B-[int]$pb.B);$nn++}}
        if($nn -gt 0){$sc/=$nn;if($sc -lt $bs){$bs=$sc;$best=$s}}}
    $ga.Dispose();$gb.Dispose();$sa.Dispose();$sb.Dispose();$ia.Dispose();$ib.Dispose()
    return $best
}
# 水平位移：左右拖动后内容的横向移动（>0 表示内容左移，露出右侧）
function HShift([string]$a,[string]$b){
    if(-not(Test-Path $a)-or -not(Test-Path $b)){return 0}
    $ia=[System.Drawing.Bitmap]::FromFile($a);$ib=[System.Drawing.Bitmap]::FromFile($b)
    $w=480;$h=60;$sa=New-Object System.Drawing.Bitmap $w,$h;$sb=New-Object System.Drawing.Bitmap $w,$h
    $ga=[System.Drawing.Graphics]::FromImage($sa);$gb=[System.Drawing.Graphics]::FromImage($sb)
    $ga.DrawImage($ia,0,0,$w,$h);$gb.DrawImage($ib,0,0,$w,$h)
    $best=0;$bs=[double]::MaxValue
    for($s=-150;$s -le 150;$s+=2){$sc=0.0;$nn=0
        for($x=60;$x -lt 420;$x+=3){$xx=$x+$s;if($xx -lt 0 -or $xx -ge $w){continue}
            for($y=0;$y -lt $h;$y+=3){$pa=$sa.GetPixel($x,$y);$pb=$sb.GetPixel($xx,$y);$sc+=[Math]::Abs([int]$pa.R-[int]$pb.R)+[Math]::Abs([int]$pa.G-[int]$pb.G)+[Math]::Abs([int]$pa.B-[int]$pb.B);$nn++}}
        if($nn -gt 0){$sc/=$nn;if($sc -lt $bs){$bs=$sc;$best=$s}}}
    $ga.Dispose();$gb.Dispose();$sa.Dispose();$sb.Dispose();$ia.Dispose();$ib.Dispose()
    return $best
}

$rows = @()

function RunArea([string]$side, [string]$proc, [hashtable]$nav, [array]$tests) {
    $c = Get-ABClient $proc; if(-not $c){"[$side] LOST before area $($nav.name)"; return}
    # 回首页
    AB-Click $c 0.125 0.932 | Out-Null; Start-Sleep -Milliseconds 1100
    if ($nav.u -ne $null) {
        $c = Get-ABClient $proc; if(-not $c){"[$side] LOST nav $($nav.name)"; return}
        AB-Click $c $nav.u $nav.v | Out-Null; Start-Sleep -Seconds 3
    } else { Start-Sleep -Milliseconds 600 }
    foreach ($t in $tests) {
        $c = Get-ABClient $proc; if(-not $c){"[$side] LOST test $($t.name)"; return}
        $before = Join-Path $out ("${side}_$($nav.tag)_$($t.name)_a.png")
        $null = AB-Shot $c $before
        AB-Drag $c $t.u1 $t.v1 $t.u2 $t.v2 | Out-Null
        Start-Sleep -Seconds 2
        $c = Get-ABClient $proc; if(-not $c){"[$side] LOST after $($t.name) alive=$(AB-Alive $proc)"; return}
        $after = Join-Path $out ("${side}_$($nav.tag)_$($t.name)_b.png")
        $null = AB-Shot $c $after
        $d = ImgDiff $before $after
        $sh = if ($t.dir -eq 'v') { VShift $before $after } else { HShift $before $after }
        $rows += [pscustomobject]@{ side=$side; area=$nav.tag; test=$t.name; dir=$t.dir; diff=$d; shift=$sh; alive=(AB-Alive $proc) }
        "{0,-4} {1,-9} {2,-9} dir={3} diff={4,7} shift={5,5} alive={6}" -f $side,$nav.tag,$t.name,$t.dir,$d,$sh,(AB-Alive $proc)
    }
}

# 区域定义：nav.tag / nav.u,v(进入坐标,$null=主城) / tests(名称,方向,拖动端点)
$homeNav = @{ tag='home'; u=$null; v=$null }
$lineupNav= @{ tag='lineup'; u=0.264; v=0.932 }
$advNav  = @{ tag='adv'; u=0.542; v=0.932 }
$voyNav  = @{ tag='voy'; u=0.403; v=0.932 }

# 主页头像行（横向）
$homeTests = @( @{ name='avatar_h'; dir='h'; u1=0.85; v1=0.25; u2=0.20; v2=0.25 } )
# 阵容：顶部头像行横滑 + 下方列表纵滑
$lineupTests = @(
    @{ name='row_h';  dir='h'; u1=0.85; v1=0.15; u2=0.20; v2=0.15 },
    @{ name='list_v'; dir='v'; u1=0.50; v1=0.78; u2=0.50; v2=0.35 }
)
# 冒险：顶部子项标签横滑 + 主体内容纵滑
$advTests = @(
    @{ name='tabs_h';    dir='h'; u1=0.85; v1=0.15; u2=0.20; v2=0.15 },
    @{ name='content_v'; dir='v'; u1=0.50; v1=0.60; u2=0.50; v2=0.30 }
)
# 远航/闯关：章节Tab横滑 + 关卡列表纵滑
$voyTests = @(
    @{ name='tabs_h';  dir='h'; u1=0.85; v1=0.23; u2=0.20; v2=0.23 },
    @{ name='list_v';  dir='v'; u1=0.50; v1=0.60; u2=0.50; v2=0.30 }
)

# 先老后新（老版稳定，新版同会话内）
"===== OLD ====="
RunArea 'old' 'Game' $homeNav $homeTests
RunArea 'old' 'Game' $lineupNav $lineupTests
RunArea 'old' 'Game' $advNav $advTests
RunArea 'old' 'Game' $voyNav $voyTests
"===== NEW ====="
RunArea 'new' 'Haizeiwang' $homeNav $homeTests
RunArea 'new' 'Haizeiwang' $lineupNav $lineupTests
RunArea 'new' 'Haizeiwang' $advNav $advTests
RunArea 'new' 'Haizeiwang' $voyNav $voyTests

$rows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $out '_results.csv')
"FINAL old=$(AB-Alive 'Game') new=$(AB-Alive 'Haizeiwang')"
'SCROLL_FULL_DONE'
