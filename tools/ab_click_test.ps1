# 主页头像行点击验证：头像1 + 空位"+"是否响应（是否弹出详情/解锁提示）
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$env:HAIZEI_MENU_DIAG = '1'
$env:HAIZEI_DUMP_AVATAR = '1'
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

AB-Stop 'Haizeiwang'; Start-Sleep -Milliseconds 700
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'set HAIZEI_MENU_DIAG=1 && set HAIZEI_DUMP_AVATAR=1 && Haizeiwang.exe > ab_click.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 7
$c = Get-ABClient 'Haizeiwang'
AB-Click $c 0.50 0.79 | Out-Null
Start-Sleep -Seconds 18
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'clk_home.png')

# 头像1（最左立绘卡，u≈0.13 v≈0.30）
AB-Click $c 0.13 0.30 | Out-Null
Start-Sleep -Seconds 2
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'clk_avatar1.png')
"AVATAR1 {0}" -f (Get-Item (Join-Path $out 'clk_avatar1.png')).Length

# 关掉可能弹出的面板（点空白返回），再点空位"+"（u≈0.76 v≈0.30）
AB-Click $c 0.05 0.06 | Out-Null
Start-Sleep -Milliseconds 900
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'clk_back.png')
AB-Click $c 0.76 0.30 | Out-Null
Start-Sleep -Seconds 2
$c = Get-ABClient 'Haizeiwang'
$null = AB-Shot $c (Join-Path $out 'clk_plus.png')
"PLUS {0}" -f (Get-Item (Join-Path $out 'clk_plus.png')).Length
'DONE'
