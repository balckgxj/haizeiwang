# 验证主页两个横向滑动控件（头像行 + 底部导航）松手后是否仍强制弹回。
# 设计分辨率 360x480，归一化坐标 u,v∈[0,1]。
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_new_home.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
"NEW client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'bn_splash.png')

# 进入游戏（启动页按钮）
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.50 0.79 | Out-Null }
Start-Sleep -Seconds 18
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'bn_home_base.png') }
'AT_HOME'

# 先点底部"首页"确保停在主城主页（与已验证脚本一致）
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.125 0.932 | Out-Null; Start-Sleep -Seconds 3 }
'AT_HOME_TAB'

# ---- 通用：带中途截图的横向拖动 ----
function DragH-MidShot($c, [double]$u1,[double]$v,[double]$u2,[string]$tag) {
    $p1 = AB-Screen $c $u1 $v; $p2 = AB-Screen $c $u2 $v
    [void][AB]::SetCursorPos($p1[0], $p1[1]); Start-Sleep -Milliseconds 200
    [AB]::mouse_event([AB]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 120
    $N = 16
    for ($i = 1; $i -le $N; $i++) {
        $nx = [int]($p1[0] + ($p2[0]-$p1[0])*$i/$N)
        $ny = [int]($p1[1] + ($p2[1]-$p1[1])*$i/$N)
        [void][AB]::SetCursorPos($nx,$ny); Start-Sleep -Milliseconds 32
        if ($i -eq [int]($N/2)) {
            Start-Sleep -Milliseconds 80
            $null = AB-Shot $c (Join-Path $out ($tag + '_mid.png'))
        }
    }
    Start-Sleep -Milliseconds 120
    [AB]::mouse_event([AB]::UP,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 500
    $null = AB-Shot $c (Join-Path $out ($tag + '_after.png'))
}

function FSize([string]$p){ if(Test-Path $p){ return (Get-Item $p).Length } return 0 }

# ===== 1) 头像行（顶部红框）=====
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'av_before.png')
"AV_BEFORE=$(FSize (Join-Path $out 'av_before.png'))"
# 与已验证脚本一致：按(0.75,0.25) -> 拖到(0.35,0.25)
DragH-MidShot $c 0.75 0.25 0.35 'av'
"AV_MID=$(FSize (Join-Path $out 'av_mid.png'))  AV_AFTER=$(FSize (Join-Path $out 'av_after.png'))"

# ===== 2) 底部导航（底部红框）=====
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'nav_before.png')
"NAV_BEFORE=$(FSize (Join-Path $out 'nav_before.png'))"
# 底部导航 v≈0.955（实际标签在 0.95-0.98 之间）
DragH-MidShot $c 0.62 0.955 0.30 'nav'
"NAV_MID=$(FSize (Join-Path $out 'nav_mid.png'))  NAV_AFTER=$(FSize (Join-Path $out 'nav_after.png'))"

'DONE'
