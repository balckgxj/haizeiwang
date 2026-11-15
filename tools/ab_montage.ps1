param([Parameter(Mandatory=$true)][string]$Dir, [string]$Out)
Add-Type -AssemblyName System.Drawing
$files = @(Get-ChildItem -Path $Dir -Filter '*.png' |
    Where-Object { $_.Name -notlike '*_pre.png' -and $_.Name -notlike '_00_*' } |
    Sort-Object Name)
if ($files.Count -eq 0) { "NO SHOTS in $Dir"; exit 1 }
$cols = 5; $rows = [Math]::Ceiling($files.Count / $cols)
$cw = 216; $ch = 288; $lab = 24
$bmp = New-Object System.Drawing.Bitmap ($cols*$cw), ($rows*($ch+$lab))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(24,24,28))
$font = New-Object System.Drawing.Font 'Consolas', 11
$brush = [System.Drawing.Brushes]::White
for ($i=0; $i -lt $files.Count; $i++) {
    $src = [System.Drawing.Bitmap]::FromFile($files[$i].FullName)
    $x = ($i % $cols) * $cw; $y = [Math]::Floor($i / $cols) * ($ch+$lab)
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle $x,$y,$cw,$ch))
    $g.DrawString($files[$i].BaseName, $font, $brush, [single]($x+4), [single]($y+$ch+3))
    $src.Dispose()
}
$g.Dispose()
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $Dir) ((Split-Path -Leaf $Dir)+'_montage.png') }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"MONTAGE $($files.Count) shots -> $Out"
