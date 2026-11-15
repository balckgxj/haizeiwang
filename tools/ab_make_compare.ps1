# 三联对比图：老版基准 / 新版修复前 / 新版修复后
Add-Type -AssemblyName System.Drawing
$root = 'E:\PCGame\Haizeiwang\_tools\ab'
$srcs = @(
    @{ p = Join-Path $root 'seq_old_baseline.png';        t = 'OLD Game.exe (baseline)' },
    @{ p = Join-Path $root 'seq_new_mid_montage.png';      t = 'NEW mid: touch still broken' },
    @{ p = Join-Path $root 'seq_new_after_montage.png';   t = 'NEW final: 18/20 aligned' }
)
$ims = @()
foreach ($s in $srcs) {
    if (-not (Test-Path $s.p)) { "MISS $($s.p)"; exit 1 }
    $ims += [System.Drawing.Bitmap]::FromFile($s.p)
}
$w = 0; $h = 0
foreach ($im in $ims) { $w += $im.Width; $h = [Math]::Max($h, $im.Height) }
$lab = 34
$bmp = New-Object System.Drawing.Bitmap $w, ($h + $lab)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(18,18,22))
$font = New-Object System.Drawing.Font 'Consolas', 14, ([System.Drawing.FontStyle]::Bold)
$brush = [System.Drawing.Brushes]::White
$x = 0
for ($i = 0; $i -lt $ims.Count; $i++) {
    $g.DrawImage($ims[$i], $x, $lab)
    $g.DrawString($srcs[$i].t, $font, $brush, [single]($x + 10), [single]6)
    $x += $ims[$i].Width
}
$g.Dispose()
$out = Join-Path $root 'AB_COMPARE_3up.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"COMPARE $($bmp.Width)x$($bmp.Height) -> $out"
foreach ($im in $ims) { $im.Dispose() }
$bmp.Dispose()
