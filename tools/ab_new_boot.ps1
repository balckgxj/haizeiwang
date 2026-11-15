# 启动新 Haizeiwang.exe -> 登录 heigui/123456 -> 主城 -> 跑 A/B 序列
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'
Start-Sleep -Milliseconds 800
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > ab_new.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 40
if (-not $c) { 'NEW_WINDOW_NOT_FOUND'; exit 1 }
"NEW client {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

# 观察启动流程
for ($i=0; $i -lt 4; $i++) {
    Start-Sleep -Seconds 3
    $cc = Get-ABClient 'Haizeiwang'
    if ($cc) { $null = AB-Shot $cc (Join-Path $out ("new_boot_{0}.png" -f $i)) }
}

# 登录表单（归一化坐标来自 verify_login_e2e.ps1）
$c = Get-ABClient 'Haizeiwang'
AB-Click $c 0.50 0.400 | Out-Null; AB-Key 'heigui'
AB-Click $c 0.50 0.483 | Out-Null; AB-Key '123456'
AB-Click $c 0.50 0.622 | Out-Null
'LOGIN_FORM_SENT'
Start-Sleep -Seconds 14
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'new_after_form.png') }

# 「进入游戏」按钮（启动页 v≈0.208），若已经进主城则此点击落在顶栏，无害
$c = Get-ABClient 'Haizeiwang'
if ($c) { AB-Click $c 0.50 0.208 | Out-Null }
Start-Sleep -Seconds 12
$c = Get-ABClient 'Haizeiwang'
if ($c) { $null = AB-Shot $c (Join-Path $out 'new_city.png') }
"NEW_ALIVE=$(AB-Alive 'Haizeiwang')"

# 直接在同一进程跑序列（服务/窗口都活着）
& (Join-Path $root 'tools\ab_run_sequence.ps1') -Side new
