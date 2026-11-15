# 聚焦对比：底部「商店」按钮同一坐标点击，老版 / 修复前 / 修复后
Add-Type -AssemblyName System.Drawing
$root = 'E:\PCGame\Haizeiwang\_tools\ab'
$srcs = @(
    @{ p = Join-Path $root 'seq_old\20_nav_shop.png';                   t = 'OLD: shop page' },
    @{ p = Join-Path $root 'seq_new_resolution_fixed\20_nav_shop.png';  t = 'NEW before: no response (city)' },
    @{ p = Join-Path $root 'seq_new\20_nav_shop.png';                   t = 'NEW after: shop page' }
)
$ims = @()
foreach ($s in $srcs) {
    if (-not (Test-Path $s.p)) { "MISS $($s.p)"; exit 1 }
    $ims += [System.Drawing.Bitmap]::FromFile($s.p)
}
$cw = 360; $ch = 480; $lab = 34
$bmp = New-Object System.Drawing.Bitmap ($cw * 3), ($ch + $lab)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(18,18,22))
$font = New-Object System.Drawing.Font 'Consolas', 12, ([System.Drawing.FontStyle]::Bold)
for ($i = 0; $i -lt 3; $i++) {
    $x = $i * $cw
    $g.DrawImage($ims[$i], (New-Object System.Drawing.Rectangle $x,$lab,$cw,$ch))
    $g.DrawString($srcs[$i].t, $font, [System.Drawing.Brushes]::White, [single]($x+8), [single]8)
}
$g.Dispose()
$out = Join-Path $root 'AB_FOCUS_nav_shop.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"FOCUS $($bmp.Width)x$($bmp.Height) -> $out"
foreach ($im in $ims) { $im.Dispose() }
$bmp.Dispose()
