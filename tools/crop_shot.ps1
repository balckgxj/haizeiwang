# 按指定矩形裁剪截图，便于精确读取控件坐标
param(
    [string]$In  = 'probe_full.png',
    [string]$Out = 'crop.png',
    [int]$X = 0, [int]$Y = 0, [int]$W = 400, [int]$H = 600
)
Add-Type -AssemblyName System.Drawing
$root = 'E:\PCGame\Haizeiwang\_tools'
$src = [System.Drawing.Image]::FromFile((Join-Path $root $In))
Write-Output "SOURCE: $($src.Width)x$($src.Height)"
$rect = New-Object System.Drawing.Rectangle $X, $Y, $W, $H
$crop = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $W, $H), $rect, 'Pixel')
$dst = Join-Path $root $Out
$crop.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $crop.Dispose(); $src.Dispose()
Write-Output "CROP: $dst ($W x $H at $X,$Y)"
