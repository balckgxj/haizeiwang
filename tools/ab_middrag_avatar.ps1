# 中途截图验证：主城头像行左拖，松手前抓"已滚动"状态，对比老/新版
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

function MidDrag([string]$proc, [string]$tag) {
    $c = Get-ABClient $proc; if(-not $c){"$tag LOST";return}
    AB-Click $c 0.125 0.932 | Out-Null; Start-Sleep -Milliseconds 1100   # 回首页
    $c = Get-ABClient $proc; if(-not $c){"$tag LOST2";return}
    $b = Join-Path $out ("middrag_${tag}_before.png"); $null = AB-Shot $c $b
    # 手动左拖：按下(0.75,0.25) -> 分步移动到(0.35,0.25) -> 中途截图 -> 松手
    $p1 = AB-Screen $c 0.75 0.25; $p2 = AB-Screen $c 0.35 0.25
    [void][AB]::SetCursorPos($p1[0],$p1[1]); Start-Sleep -Milliseconds 200
    [AB]::mouse_event([AB]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 120
    for ($i=1;$i -le 18;$i++){
        $nx=[int]($p1[0]+($p2[0]-$p1[0])*$i/18); $ny=[int]($p1[1]+($p2[1]-$p1[1])*$i/18)
        [void][AB]::SetCursorPos($nx,$ny); Start-Sleep -Milliseconds 35
    }
    Start-Sleep -Milliseconds 120
    $c = Get-ABClient $proc; if(-not $c){"$tag LOST3";return}
    $m = Join-Path $out ("middrag_${tag}_mid.png"); $null = AB-Shot $c $m
    [AB]::mouse_event([AB]::UP,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 300
    $c = Get-ABClient $proc; if(-not $c){"$tag LOST4";return}
    $a = Join-Path $out ("middrag_${tag}_after.png"); $null = AB-Shot $c $a
    "MIDDRAG $tag alive=$(AB-Alive $proc) -> $m"
}

# 老版（用户已开主城）
MidDrag 'Game' 'old'
# 新版（强制重启用最新构建）
AB-Stop 'Haizeiwang'; Start-Sleep -Milliseconds 700
$dbg = Join-Path $root 'build\Debug'
$null = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'Haizeiwang.exe > ab_middrag.log 2>&1') -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$cn = AB-Wait 'Haizeiwang' 45; if(-not $cn){'NEW_NO_WINDOW';exit 1}
Start-Sleep -Seconds 7
$cn = Get-ABClient 'Haizeiwang'; $null = AB-Shot $cn (Join-Path $out 'middrag_new_splash.png')
AB-Click $cn 0.50 0.79 | Out-Null; Start-Sleep -Seconds 16
MidDrag 'Haizeiwang' 'new'
'MIDDRAG_DONE'
