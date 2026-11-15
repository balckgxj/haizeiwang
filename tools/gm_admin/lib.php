<?php
// [haizei] GM 后台公共库：账号、白名单、protobuf、BackStage 协议
// 兼容 PHP 5.6（系统自带 E:\Softwares\php-5.6.40\php.exe）。

function cfg() {
    static $c = null;
    if ($c === null) { $c = require dirname(__FILE__) . '/config.php'; }
    return $c;
}

function db() {
    static $link = null;
    if ($link !== null) { return $link; }
    $d = cfg();
    $d = $d['db'];
    $link = @new mysqli($d['host'], $d['user'], $d['pass'], $d['name'], $d['port']);
    if ($link->connect_errno) {
        json_out(array('ok' => false, 'error' => 'MySQL 连接失败: ' . $link->connect_error));
    }
    $link->set_charset($d['charset']);
    return $link;
}

function json_out($data) {
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function h($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

function arg($key, $default = '') {
    if (isset($_POST[$key])) { return is_string($_POST[$key]) ? trim($_POST[$key]) : $_POST[$key]; }
    if (isset($_GET[$key]))  { return is_string($_GET[$key])  ? trim($_GET[$key])  : $_GET[$key]; }
    return $default;
}

function sess_start() {
    $c = cfg();
    session_name($c['session_name']);
    if (session_id() === '') { @session_start(); }
}

function current_admin() {
    sess_start();
    return isset($_SESSION['puid']) ? $_SESSION['puid'] : '';
}

function require_admin() {
    $puid = current_admin();
    if ($puid === '') { json_out(array('ok' => false, 'error' => '未登录或会话已过期', 'need_login' => true)); }
    // 每次请求重新校验：GM 权限被撤销后立即失效
    if (!gm_has($puid)) { json_out(array('ok' => false, 'error' => '该账号的 GM 权限已被撤销', 'need_login' => true)); }
    return $puid;
}

// ---------- 账号：与游戏服务端共用 dzm.mapping ----------

function account_rows() {
    $r = db()->query('SELECT puid, name, passwd, gameid FROM mapping ORDER BY gameid ASC');
    if (!$r) { return array(); }
    $out = array();
    $wl = gm_whitelist_load();
    while ($row = $r->fetch_assoc()) {
        $row['is_gm'] = in_array($row['puid'], $wl, true) ? 1 : 0;
        $row['has_pwd'] = ($row['passwd'] === null || $row['passwd'] === '') ? 0 : 1;
        unset($row['passwd']);
        $out[] = $row;
    }
    return $out;
}

function account_check($puid, $pwd) {
    if ($puid === '' || $pwd === '') { return false; }
    $st = db()->prepare('SELECT passwd FROM mapping WHERE puid = ? LIMIT 1');
    if (!$st) { return false; }
    $st->bind_param('s', $puid);
    $st->execute();
    $st->bind_result($stored);
    $ok = $st->fetch();
    $st->close();
    if (!$ok || $stored === null) { return false; }
    return hash_equals((string)$stored, (string)$pwd);
}

function account_exists($puid) {
    $st = db()->prepare('SELECT 1 FROM mapping WHERE puid = ? LIMIT 1');
    $st->bind_param('s', $puid);
    $st->execute();
    $st->store_result();
    $n = $st->num_rows;
    $st->close();
    return $n > 0;
}

function account_setpwd($puid, $pwd) {
    if ($puid === '' || $pwd === '') { return array(false, '账号和密码不能为空'); }
    if (!account_exists($puid)) { return array(false, '账号不存在（请先在游戏登录页登录一次以自动注册）'); }
    $st = db()->prepare('UPDATE mapping SET passwd = ? WHERE puid = ?');
    $st->bind_param('ss', $pwd, $puid);
    $ok = $st->execute();
    $err = $st->error;
    $st->close();
    return $ok ? array(true, '') : array(false, $err);
}

// ---------- GM 白名单：与 Java 服务端共用 TesterList.xml ----------

function gm_whitelist_load() {
    $path = cfg();
    $path = $path['tester_list'];
    $raw = @file_get_contents($path);
    if ($raw === false) { return array(); }
    preg_match_all('/<Tester\s+puid="([^"]*)"/i', $raw, $m);
    $out = array();
    foreach ($m[1] as $p) {
        $p = html_entity_decode($p, ENT_QUOTES, 'UTF-8');
        if ($p !== '' && !in_array($p, $out, true)) { $out[] = $p; }
    }
    return $out;
}

function gm_whitelist_save($list) {
    $path = cfg();
    $path = $path['tester_list'];
    $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\r\n<root>\r\n";
    foreach ($list as $p) {
        $xml .= "\t<Tester puid=\"" . h($p) . "\"></Tester>\r\n";
    }
    $xml .= "</root>\r\n";
    if (@file_put_contents($path, $xml, LOCK_EX) === false) {
        return '无法写入白名单文件：' . $path;
    }
    return '';
}

function gm_has($puid) {
    return in_array($puid, gm_whitelist_load(), true);
}

function gm_set($puid, $on) {
    if ($puid === '') { return '账号不能为空'; }
    $list = gm_whitelist_load();
    $idx = array_search($puid, $list, true);
    if ($on) {
        if ($idx === false) { $list[] = $puid; }
    } else {
        if ($idx !== false) { array_splice($list, $idx, 1); }
    }
    return gm_whitelist_save($list);
}

// 首次初始化：白名单里没有任何一个有效游戏账号时，允许首个登录者自助成为 GM
function gm_bootstrap_needed() {
    $wl = gm_whitelist_load();
    foreach ($wl as $p) { if (account_exists($p)) { return false; } }
    return true;
}

// ---------- protobuf 2.5 极简编解码（BackStage 消息都是 varint / string） ----------

function pb_varint($v) {
    $v = (int)$v;
    $out = '';
    while (true) {
        $b = $v & 0x7f;
        $v = $v >> 7;
        if ($v > 0) { $out .= chr($b | 0x80); } else { $out .= chr($b); break; }
    }
    return $out;
}

function pb_int($field, $v)   { return pb_varint(($field << 3) | 0) . pb_varint($v); }
function pb_str($field, $str) {
    $str = (string)$str;
    return pb_varint(($field << 3) | 2) . pb_varint(strlen($str)) . $str;
}

function pb_decode($bytes) {
    $out = array();
    $len = strlen($bytes);
    $i = 0;
    while ($i < $len) {
        $tag = 0; $shift = 0;
        while ($i < $len) {
            $b = ord($bytes[$i++]);
            $tag |= ($b & 0x7f) << $shift;
            if (($b & 0x80) === 0) { break; }
            $shift += 7;
        }
        $field = $tag >> 3;
        $wire  = $tag & 7;
        if ($field <= 0) { break; }
        if ($wire === 0) {
            $v = 0; $shift = 0;
            while ($i < $len) {
                $b = ord($bytes[$i++]);
                $v |= ($b & 0x7f) << $shift;
                if (($b & 0x80) === 0) { break; }
                $shift += 7;
            }
            $out[$field] = $v;
        } elseif ($wire === 2) {
            $n = 0; $shift = 0;
            while ($i < $len) {
                $b = ord($bytes[$i++]);
                $n |= ($b & 0x7f) << $shift;
                if (($b & 0x80) === 0) { break; }
                $shift += 7;
            }
            $out[$field] = substr($bytes, $i, $n);
            $i += $n;
        } else { break; }
    }
    return $out;
}

// ---------- BackStage：直连 Java 服务端 25524（与老 PHP 后台同一协议） ----------

// 服务端 Decoder/Encoder 对包体每字节做 XOR 0xA5；老 PHP 后台源码漏了这步，
// 导致请求被当成畸形 protobuf 丢弃。这里按引擎真实协议补上。
function xor_a5($s) {
    $o = '';
    for ($i = 0; $i < strlen($s); $i++) { $o .= chr(ord($s[$i]) ^ 0xA5); }
    return $o;
}

// $legacy = true 表示 BackStage 系列包：老工程的 BackStage*Handler 会自己再 XOR
// 一次（请求解析前、响应写出前各一次），与 Encoder/Decoder 叠加后恰好抵消。
// 因此这类包请求发明文、收到也是明文；普通游戏包（如登录）则按单层 XOR。
function backstage_call($opcode, $body, $legacy = false) {
    $c = cfg();
    $c = $c['server'];
    $fp = @fsockopen($c['host'], $c['port'], $errno, $errstr, 3);
    if (!$fp) { return array('ok' => false, 'error' => '连接游戏服务端失败: ' . $errstr); }
    stream_set_timeout($fp, 5);
    // 请求包头：uint16 魔数 0x4346 + uint32 opcode + uint32 包体长度（Decoder 按包体长度读）
    $wire = $legacy ? $body : xor_a5($body);
    $packet = pack('nNN', 0x4346, $opcode, strlen($wire)) . $wire;
    fwrite($fp, $packet);
    $resp = '';
    for ($i = 0; $i < 20; $i++) {
        $chunk = fread($fp, 8192);
        if ($chunk === false || $chunk === '') { break; }
        $resp .= $chunk;
        if (strlen($resp) >= 10) {
            $h = unpack('Nlen', substr($resp, 6, 4));
            // 响应 Encoder 写的长度是「10 + 包体长度」，与请求语义不对称
            if (strlen($resp) >= (int)$h['len']) { break; }
        }
        if (strlen($resp) > 65536) { break; }
    }
    fclose($fp);
    if (strlen($resp) < 10) { return array('ok' => false, 'error' => '服务端无响应（请求可能被丢弃）', 'raw_hex' => bin2hex($resp)); }
    $hdr = unpack('nhead/Nopcode/Nlen', substr($resp, 0, 10));
    $bodyLen = (int)$hdr['len'] - 10; // Encoder: len = 10 + 包体长度
    $payload = ($bodyLen > 0) ? substr($resp, 10, $bodyLen) : substr($resp, 10);
    $plain = $legacy ? $payload : xor_a5($payload);
    return array(
        'ok'      => true,
        'opcode'  => $hdr['opcode'],
        'fields'  => pb_decode($plain),
        'raw_hex' => bin2hex($plain),
    );
}

function backstage_fetch_user($name) {
    $body = pb_int(1, 1) . pb_str(2, $name);
    return backstage_call(182, $body, true); // OPCODE_BACK_STAGE_FETCH_USER_INFO_C
}

function backstage_update_user($name, $field, $v1, $v2) {
    $body = pb_int(1, 1) . pb_str(2, $name) . pb_str(3, $field)
          . pb_int(4, (int)$v1) . pb_int(5, (int)$v2);
    return backstage_call(184, $body, true); // OPCODE_BACK_STAGE_UPDATE_USER_INFO_C
}

function port_up($host, $port) {
    $fp = @fsockopen($host, $port, $errno, $errstr, 1);
    if (!$fp) { return false; }
    fclose($fp);
    return true;
}
