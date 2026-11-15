# 验证主页两个横向滑动控件（头像行 + 底部导航）松手后是否仍强制弹回。
# 用真正的"鼠标点住→按住拖动→松手"序列（SendMessage 客户端坐标）。
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
# 打开 3.x 滚动视图诊断：onTouchBegan/Moved/Ended 的 innerPos 轨迹
$env:HAIZEI_MENU_DIAG = '1'

$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 700
$psi = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'set HAIZEI_MENU_DIAG=1 && Haizeiwang.exe > ab_new_home.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
"NEW client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'v2_base.png')

# 进入游戏（启动页按钮）
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.50 0.79 | Out-Null }
Start-Sleep -Seconds 18
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'v2_home.png') }
'AT_HOME'

function FSize([string]$p){ if(Test-Path $p){ return (Get-Item $p).Length } return 0 }

# 真正的"点住→按住拖动→（松手前截图）→松手→（松手后截图）"
function Drag-MidShot($c, [double]$u1,[double]$v,[double]$u2,[string]$tag) {
    # 先点"回首页"确保停在主城主页（与历史可移动测试一致）
    AB-Click $c 0.125 0.932 | Out-Null; Start-Sleep -Milliseconds 1100
    $c = Get-ABClient 'Haizeiwang'; if(-not $c){"$tag LOST";return}
    $p1 = AB-Screen $c $u1 $v; $p2 = AB-Screen $c $u2 $v
    $null = AB-Shot $c (Join-Path $out ($tag + '_before.png'))
    # 点住
    [void][AB]::SetCursorPos($p1[0], $p1[1]); Start-Sleep -Milliseconds 200
    [AB]::mouse_event([AB]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 130
    # 按住拖动到终点（中途在 60% 处暂停截图，此时仍按住）
    $N = 20
    for ($i = 1; $i -le $N; $i++) {
        $nx = [int]($p1[0] + ($p2[0]-$p1[0])*$i/$N)
        $ny = [int]($p1[1] + ($p2[1]-$p1[1])*$i/$N)
        [void][AB]::SetCursorPos($nx,$ny); Start-Sleep -Milliseconds 32
        if ($i -eq [int]($N*0.6)) {
            Start-Sleep -Milliseconds 80
            $null = AB-Shot $c (Join-Path $out ($tag + '_mid.png'))   # 松手前（仍按住）
        }
    }
    Start-Sleep -Milliseconds 150
    $null = AB-Shot $c (Join-Path $out ($tag + '_midhold.png'))  # 拖到终点仍按住
    [AB]::mouse_event([AB]::UP,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 800
    $null = AB-Shot $c (Join-Path $out ($tag + '_after.png'))   # 松手后
    "  $tag BEFORE=$(FSize (Join-Path $out ($tag+'_before.png'))) MID=$(FSize (Join-Path $out ($tag+'_mid.png'))) MIDHOLD=$(FSize (Join-Path $out ($tag+'_midhold.png'))) AFTER=$(FSize (Join-Path $out ($tag+'_after.png')))"
}

# ===== 1) 头像行（顶部红框，v≈0.30）=====
$c = Get-ABClient 'Haizeiwang'
"== AVATAR ROW =="
Drag-MidShot $c 0.75 0.30 0.35 'av'

# ===== 2) 底部导航（底部红框，v≈0.94）=====
$c = Get-ABClient 'Haizeiwang'
"== BOTTOM NAV =="
Drag-MidShot $c 0.64 0.94 0.30 'nav'

'DONE'
