<?php
// 动态区服列表：根据访问者来源自动选择可达的服务器地址
// - Tailscale 网络 (100.64.0.0/10) -> 返回 Tailscale 地址
// - 家里局域网/本机 -> 返回局域网地址 192.168.1.2
header('Content-Type: application/json; charset=utf-8');

$ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1';

// Tailscale CGNAT 段: 100.64.0.0 - 100.127.255.255
$parts = explode('.', $ip);
$isTailscale = false;
if (count($parts) >= 2 && $parts[0] === '100') {
    $second = (int)$parts[1];
    if ($second >= 64 && $second <= 127) {
        $isTailscale = true;
    }
}

$host = $isTailscale ? '100.65.143.49' : '192.168.1.2';

echo '{
    "version": 1,
	"severVerson": "1.78.5",
	"updateAddress": "http://' . $host . ':8080/gameserver/dzm/1.8/update.php",
	"rootAddress": "http://' . $host . ':8080/gameserver/dzm/1.8/update.php",
    "defaultSeverID" : 1,
    "announcement":"http://' . $host . ':8080/gameserver/dzm/1.8/notice_ios.php",
    "updateByteSize":0,
	"updateMsg": "转盘刷新显示问题修复",
	"serverInUpdate": "，预计停服时间为3个小时左右，如有疑问请联系客服QQ：126367",
	"serverInGray": "龙吟好，预计停服时间为3个小时左右，如有疑问请联系客服QQ：12367",
	"inStoreUpdate":"http://127.0.0.1/download/91/index_ios.html",

    "severs" :
    [
		{"id":1, "name":"A1-TEST" , "address":"' . $host . '", "port":25524, "state":"new"}
    ]
}
';
