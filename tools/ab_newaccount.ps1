# 新号注册+建号全流程：登录 -> 开场剧情 -> 取名 -> 教学战
# 用法: powershell -ExecutionPolicy Bypass -File tools\ab_newaccount.ps1 [账号] [密码]
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}
$acct = if ($args.Count -ge 1) { $args[0] } else { '0202' }
$pass = if ($args.Count -ge 2) { $args[1] } else { '123456' }
$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools\ab\crash'

AB-Stop 'Haizeiwang'; Start-Sleep -Milliseconds 700
Remove-Item (Join-Path $dbg 'ab_flow.log') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $dbg 'crash_stack.txt') -Force -ErrorAction SilentlyContinue
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'set HAIZEI_MENU_DIAG=1 && Haizeiwang.exe > ab_flow.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$c = AB-Wait 'Haizeiwang' 45
if (-not $c) { 'NO_WINDOW'; exit 1 }
Start-Sleep -Seconds 12
function Shot([string]$name) {
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { "DIED_AT_$name"; return $false }
    AB-Shot $c (Join-Path $out "$name.png") | Out-Null
    return $true
}
if (-not (Shot 'na01_title')) { exit 1 }

# 启动页 -> 进入游戏
$null = AB-Click (Get-ABClient 'Haizeiwang') 0.5 0.79
Start-Sleep -Seconds 9
if (-not (Shot 'na02_login')) { exit 1 }

# 填账号(纯数字避开IME)/密码
$c = Get-ABClient 'Haizeiwang'
$null = AB-Click $c 0.5 0.36; Start-Sleep -Milliseconds 700
AB-Key '^a'; AB-Key '{DEL}'; Start-Sleep -Milliseconds 200
AB-Key $acct; Start-Sleep -Milliseconds 400
$null = AB-Click $c 0.5 0.48; Start-Sleep -Milliseconds 700
AB-Key $pass; Start-Sleep -Milliseconds 400
if (-not (Shot 'na03_filled')) { exit 1 }

# 登录
$c = Get-ABClient 'Haizeiwang'
$null = AB-Click $c 0.5 0.69
Start-Sleep -Seconds 12
if (-not (Shot 'na04_after_login')) { exit 1 }

# 开场剧情连点推进（每 3s 一次，共 60s）
for ($i = 1; $i -le 20; $i++) {
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { "DIED_AT_STORY_$i"; exit 1 }
    $null = AB-Click $c 0.5 0.5
    Start-Sleep -Seconds 3
    if ($i % 5 -eq 0) { Shot ("na05_story_{0:d2}" -f $i) | Out-Null }
}

# 取名页：随机 -> 确定
$c = Get-ABClient 'Haizeiwang'
if ($c) {
    Shot 'na06_naming' | Out-Null
    $null = AB-Click $c 0.77 0.38; Start-Sleep -Seconds 2
    if (-not (Shot 'na07_random')) { exit 1 }
    $c = Get-ABClient 'Haizeiwang'
    if ($c) {
        $null = AB-Click $c 0.5 0.61; Start-Sleep -Seconds 8
    }
}
# 教学战阶段观察 60s
for ($i = 1; $i -le 12; $i++) {
    $c = Get-ABClient 'Haizeiwang'
    if (-not $c) { "DIED_AT_TUTORIAL_$i"; exit 1 }
    if ($i -in 1,4,8,12) { Shot ("na08_tutorial_{0:d2}" -f $i) | Out-Null }
    Start-Sleep -Seconds 5
}
"ALIVE=$(AB-Alive 'Haizeiwang')"
'DONE'
