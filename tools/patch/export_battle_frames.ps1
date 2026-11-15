# [haizei] 幂等：把 battle.plist 图集里的 5 个 frame 导出成散图，补齐 battle/ 目录。
#
# 背景：运行期日志（真实战斗链路）报
#   fullPathForFilename: No file found at battle/b_bgr02.png / b_qa.png /
#   b_bgb02.png / b_qb.png / b_qd.png
# 这些 ccbi/代码是按「散图路径」加载的，但老工程资源 dump 里 battle/ 只有 4 张，
# 这 5 张只存在于 Imagesetfile/battle.plist 图集（同名 frame，无 battle/ 前缀），
# 表现为战斗页若干黑色小方块。这里按 plist 的 frame rect 从 battle.png 裁出补齐。
Add-Type -AssemblyName System.Drawing

$root = 'E:\PCGame\Haizeiwang'
$atlasPath = Join-Path $root 'client\Resources\Imagesetfile\battle.png'
$targets = @(
    (Join-Path $root 'client\Resources\battle'),
    (Join-Path $root 'build\Debug\Resources\battle')
)
# frame / sourceSize 均取自 battle.plist（format 2，rotated=false）
$frames = @(
    @{ n = 'b_bgr02.png'; x = 1252; y = 1454; w = 93; h = 30 },
    @{ n = 'b_qa.png';    x =  920; y = 1376; w = 35; h = 34 },
    @{ n = 'b_bgb02.png'; x = 1252; y = 1490; w = 93; h = 30 },
    @{ n = 'b_qb.png';    x =  920; y = 1334; w = 35; h = 36 },
    @{ n = 'b_qd.png';    x =  920; y = 1416; w = 34; h = 35 }
)

foreach ($d in $targets) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$atlas = [System.Drawing.Bitmap]::FromFile($atlasPath)
Write-Output ("ATLAS: {0}x{1}" -f $atlas.Width, $atlas.Height)
foreach ($f in $frames) {
    $rect = New-Object System.Drawing.Rectangle $f.x, $f.y, $f.w, $f.h
    $crop = $atlas.Clone($rect, $atlas.PixelFormat)
    foreach ($d in $targets) {
        $crop.Save((Join-Path $d $f.n), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    Write-Output ("EXPORT {0} <- ({1},{2},{3},{4})" -f $f.n, $f.x, $f.y, $f.w, $f.h)
    $crop.Dispose()
}
$atlas.Dispose()
Write-Output '[OK] battle frames exported'
