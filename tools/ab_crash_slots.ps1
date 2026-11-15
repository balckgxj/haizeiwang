# 复现闪退：在已打开的阵容页上逐个点击船员格子，检测进程是否崩溃
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
$out = 'E:\PCGame\Haizeiwang\_tools\ab\crash'

$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'NOT_RUNNING'; exit 1 }
"CLIENT {0}x{1} @({2},{3})" -f $c.W,$c.Height,$c.X,$c.Y
$null = AB-Shot $c (Join-Path $out 'c0_before.png')

# 阵容页顶部图标行：u = 0.17,0.32,0.47,0.61,0.76  v = 0.12
$slots = @(@(0.17,'s1'), @(0.32,'s2'), @(0.47,'s3'), @(0.61,'s4'), @(0.76,'s5'))
foreach ($s in $slots) {
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { "DIED_BEFORE $($s[1])"; break }
    AB-Click $c $s[0] 0.12 | Out-Null
    Start-Sleep -Seconds 2
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) {
        "CRASH_AFTER_CLICK $($s[1]) (u=$($s[0]))"
        break
    }
    $null = AB-Shot $c (Join-Path $out ("c_$($s[1]).png"))
    "OK $($s[1])"
}
"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
