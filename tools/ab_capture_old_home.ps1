# 连接已运行的老 Game.exe（不重启），抓取主城截图确认状态
$ErrorActionPreference = 'Continue'
. 'E:\PCGame\Haizeiwang\tools\ab_lib.ps1'
$root = 'E:\PCGame\Haizeiwang'
$out  = Join-Path $root '_tools\ab'
$null = New-Item -ItemType Directory -Path $out -Force

$c = Get-ABClient 'Game'
if (-not $c) { 'OLD_NOT_FOUND'; exit 1 }
"OLD client {0}x{1} @({2},{3}) Dpi={4} Title='{5}'" -f $c.W,$c.Height,$c.X,$c.Y,$c.Dpi,$c.Title
$null = AB-Shot $c (Join-Path $out 'old_home_base.png')
'OLD_HOME_SHOT_OK -> ' + (Join-Path $out 'old_home_base.png')
