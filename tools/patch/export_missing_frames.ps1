# [haizei] 通用·幂等：把运行期报「No file found at xxx.png」的散图从
# Imagesetfile/*.plist 图集里裁出来，补到 client/Resources 与 build/Debug/Resources。
#
# 根因：老工程一批 ccbi / 代码按带目录前缀的散图路径加载（battle/b_qa.png、
# mainScene/u_lock.png ...），而资源 dump 里只保留了图集版本（同名 frame，无前缀），
# 于是运行期 fullPathForFilename 失败 -> 页面上出现黑色/空方块。
#
# 用法：powershell -File tools\patch\export_missing_frames.ps1 [-Force]
#   默认跳过已存在的目标文件；-Force 覆盖。
param([switch]$Force)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Continue'
$root = 'E:\PCGame\Haizeiwang'

# ---- 1) 从历次实跑日志收集缺失的散图名 ----
$logFiles = @('verify_fight.log', 'verify_final.log', 'verify_click.log', 'verify_run.log')
$missing = @{}
foreach ($lf in $logFiles) {
    $p = Join-Path $root "build\Debug\$lf"
    if (-not (Test-Path $p)) { continue }
    $txt = Get-Content -LiteralPath $p -Raw
    foreach ($m in [regex]::Matches($txt, 'No file found at ([^\s\.][^\s]*\.png)')) {
        $v = $m.Groups[1].Value
        if ($v -notmatch '^/') { $missing[$v] = $true }
    }
}
Write-Output ("MISSING PATHS: {0}" -f $missing.Count)

# ---- 2) 建立 frame 名 -> 图集裁剪参数 的索引 ----
$frames = @{}
$plistDir = Join-Path $root 'client\Resources\Imagesetfile'
foreach ($pl in Get-ChildItem -LiteralPath $plistDir -Filter '*.plist') {
    $text = Get-Content -LiteralPath $pl.FullName -Raw
    $texName = $pl.BaseName + '.png'
    $tm = [regex]::Match($text, '(?s)<key>textureFileName</key>\s*<string>([^<]+)</string>')
    if ($tm.Success) { $texName = $tm.Groups[1].Value }
    $atlasPath = Join-Path $plistDir $texName
    if (-not (Test-Path $atlasPath)) { continue }
    foreach ($fm in [regex]::Matches($text, '(?s)<key>([^<]+\.png)</key>\s*<dict>(.*?)</dict>')) {
        $name = $fm.Groups[1].Value
        $body = $fm.Groups[2].Value
        $rm = [regex]::Match($body, '<key>frame</key>\s*<string>\{\{(\d+),(\d+)\},\{(\d+),(\d+)\}\}</string>')
        if (-not $rm.Success) { continue }
        $frames[$name] = @{
            atlas = $atlasPath
            x = [int]$rm.Groups[1].Value; y = [int]$rm.Groups[2].Value
            w = [int]$rm.Groups[3].Value; h = [int]$rm.Groups[4].Value
            rotated = [bool][regex]::IsMatch($body, '<key>rotated</key>\s*<true\s*/>')
        }
    }
}
Write-Output ("ATLAS FRAMES INDEXED: {0}" -f $frames.Count)

# ---- 3) 逐个导出 ----
$ok = 0; $skip = 0; $noFrame = 0
$atlasCache = @{}
foreach ($path in ($missing.Keys | Sort-Object)) {
    $leaf = [System.IO.Path]::GetFileName($path)
    if (-not $frames.ContainsKey($leaf)) {
        Write-Output ("NO_FRAME  {0}" -f $path)
        $noFrame++
        continue
    }
    $f = $frames[$leaf]
    $rel = $path -replace '/', '\'
    $dsts = @((Join-Path $root "client\Resources\$rel"),
              (Join-Path $root "build\Debug\Resources\$rel"))
    $todo = @($dsts | Where-Object { $Force -or -not (Test-Path $_) })
    if ($todo.Count -eq 0) { $skip++; continue }

    if (-not $atlasCache.ContainsKey($f.atlas)) {
        $atlasCache[$f.atlas] = [System.Drawing.Bitmap]::FromFile($f.atlas)
    }
    $atlas = $atlasCache[$f.atlas]
    if (($f.x + $f.w) -gt $atlas.Width -or ($f.y + $f.h) -gt $atlas.Height) {
        Write-Output ("BAD_RECT  {0} ({1},{2},{3},{4})" -f $path, $f.x, $f.y, $f.w, $f.h)
        continue
    }
    $rect = New-Object System.Drawing.Rectangle $f.x, $f.y, $f.w, $f.h
    $crop = $atlas.Clone($rect, $atlas.PixelFormat)
    if ($f.rotated) { $crop.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    foreach ($d in $todo) {
        $dir = Split-Path -Parent $d
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $crop.Save($d, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    Write-Output ("EXPORT    {0} <- {1} ({2},{3},{4},{5}) rot={6}" -f `
        $path, (Split-Path -Leaf $f.atlas), $f.x, $f.y, $f.w, $f.h, $f.rotated)
    $crop.Dispose()
    $ok++
}
foreach ($b in $atlasCache.Values) { $b.Dispose() }
Write-Output ("[OK] exported={0} skipped={1} noframe={2}" -f $ok, $skip, $noFrame)
