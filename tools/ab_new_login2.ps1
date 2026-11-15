# 新版：从启动页点「进入游戏」(v=0.79) -> 观察后续流程 -> 必要时输入账号密码 -> 主城
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
$out = 'E:\PCGame\Haizeiwang\_tools\ab'
$c = Get-ABClient 'Haizeiwang'
if (-not $c) { 'NO_NEW_CLIENT'; exit 1 }
"NEW {0}x{1} @({2},{3}) Dpi={4}" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi

$p = AB-Click $c 0.50 0.79
"CLICK enter-game -> ($($p[0]),$($p[1]))"
for ($i=0; $i -lt 8; $i++) {
    Start-Sleep -Seconds 2
    $cc = Get-ABClient 'Haizeiwang'
    if ($cc) { $null = AB-Shot $cc (Join-Path $out ("lg_{0}.png" -f $i)) }
}
'--- observed 16s ---'

# 若出现登录表单，补输入
$c = Get-ABClient 'Haizeiwang'
if ($c) {
    AB-Click $c 0.50 0.400 | Out-Null; AB-Key 'heigui'
    AB-Click $c 0.50 0.483 | Out-Null; AB-Key '123456'
    AB-Click $c 0.50 0.622 | Out-Null
    'FORM_SENT'
    Start-Sleep -Seconds 14
    $c = Get-ABClient 'Haizeiwang'
    if ($c) { $null = AB-Shot $c (Join-Path $out 'lg_after_form.png') }
}
"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
