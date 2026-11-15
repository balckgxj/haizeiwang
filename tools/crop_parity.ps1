# [haizei] 功能一致性实跑截图裁剪
# 窗口坐标每次启动都不同，直接从最新的 verify_parity_run*.log 里读，避免硬编码错位。
Add-Type -AssemblyName System.Drawing
$out = 'E:\PCGame\Haizeiwang\_tools'

$run = Get-ChildItem (Join-Path $out 'verify_parity_run*.log') |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $run) { Write-Output 'NO_RUN_LOG'; exit 1 }
$txt = Get-Content $run.FullName -Raw
$ma = [regex]::Match($txt, 'client A win L=(\d+) T=(\d+)')
$mb = [regex]::Match($txt, 'client B win L=(\d+) T=(\d+)')
if (-not ($ma.Success -and $mb.Success)) { Write-Output 'WINDOW_RECT_NOT_FOUND'; exit 1 }
$al = [int]$ma.Groups[1].Value; $at = [int]$ma.Groups[2].Value
$bl = [int]$mb.Groups[1].Value; $bt = [int]$mb.Groups[2].Value
Write-Output "run=$($run.Name)  A=($al,$at)  B=($bl,$bt)"

function Crop([string]$name, [int]$L, [int]$T) {
    $p = Join-Path $out $name
    if (-not (Test-Path $p)) { Write-Output "MISS $name"; return }
    $im = [System.Drawing.Bitmap]::FromFile($p)
    $x = [int]($L * 1.5); $y = [int]($T * 1.5); $w = 502; $h = 720
    if (($x + $w) -gt $im.Width -or ($y + $h) -gt $im.Height) {
        Write-Output "OUT_OF_RANGE $name full=$($im.Width)x$($im.Height) crop=$x,$y,$w,$h"
        $im.Dispose(); return
    }
    $rect = New-Object System.Drawing.Rectangle $x, $y, $w, $h
    $c = $im.Clone($rect, $im.PixelFormat)
    $dst = Join-Path $out ($name -replace '\.png$', '_crop.png')
    $c.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "OK $(Split-Path -Leaf $dst)"
    $c.Dispose(); $im.Dispose()
}

Crop 'parity_01_wrong_password.png' $al $at
$pages = @('11_MemberPage', '12_AdventurePage', '13_HandbookPage')
$bnames = @('parity_02_main_city.png',
            'parity_2_crew.png', 'parity_2_adventure.png', 'parity_2_voyage.png',
            'parity_2_settings.png', 'parity_2_handbook.png')
foreach ($k in $pages) {
    $bnames += "parity_${k}_a.png"
    $bnames += "parity_${k}_b.png"
}
foreach ($n in $bnames) { Crop $n $bl $bt }

Write-Output '--- 拖动前后是否不同 ---'
foreach ($k in $pages) {
    $a = Join-Path $out "parity_${k}_a.png"
    $b = Join-Path $out "parity_${k}_b.png"
    if ((Test-Path $a) -and (Test-Path $b)) {
        $same = (Get-FileHash $a -Algorithm MD5).Hash -eq (Get-FileHash $b -Algorithm MD5).Hash
        Write-Output "$k : $(if ($same) { 'SAME' } else { 'DIFF' })"
    }
}
