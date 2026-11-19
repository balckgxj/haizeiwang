<?php
// 动态区服列表：按访问来源自动选择可达地址（本地 / 局域网 / Tailscale 通用）
//  - Tailscale (100.64.0.0/10) -> 100.65.143.49  (远程手机/电脑经 Tailscale 接入)
//  - 本机回环 (127.0.0.1 / ::1) -> 127.0.0.1      (本地 PC 客户端)
//  - 局域网 (192.168./10./172.16-31.) -> 192.168.1.2 (同网段设备)
// 游戏服 DZM 绑定 0.0.0.0:25524，网关监听 0.0.0.0:8080，三个来源均可达。
header('Content-Type: application/json; charset=utf-8');

$ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1';

function ipIsTailscale($ip) {
    if (strpos($ip, '.') === false) return false;
    $p = explode('.', $ip);
    return count($p) >= 2 && $p[0] === '100' && (int)$p[1] >= 64 && (int)$p[1] <= 127;
}
function ipIsLoopback($ip) {
    return $ip === '127.0.0.1' || $ip === '::1';
}
function ipIsLan($ip) {
    return strpos($ip, '192.168.') === 0
        || strpos($ip, '10.') === 0
        || preg_match('/^172\.(1[6-9]|2\d|3[01])\./', $ip) === 1;
}

if (ipIsTailscale($ip)) {
    $host = '100.65.143.49';
} elseif (ipIsLoopback($ip)) {
    $host = '127.0.0.1';
} elseif (ipIsLan($ip)) {
    $host = '192.168.1.2';
} else {
    // 未知来源默认回环，保证本机始终可用
    $host = '127.0.0.1';
}

echo '{
    "version": 1,
	"severVerson": "1.78.5",
	"updateAddress": "http://' . $host . ':8080/gameserver/dzm/1.8/update.php",
	"rootAddress": "http://' . $host . ':8080/gameserver/dzm/1.8/update.php",
    "defaultSeverID" : 1,
    "announcement":"http://' . $host . ':8080/gameserver/dzm/1.8/notice_ios.php",
	"updateByteSize":0,
	"updateMsg": "转盘刷新显示问题修复",
	"serverInUpdate": "",
	"serverInGray": "",
	"inStoreUpdate":"http://127.0.0.1/download/91/index_ios.html",

	"severs" :
	[
		{"id":1, "name":"A1-TEST" , "address":"' . $host . '", "port":25524, "state":"new"}
	]
}
';
