<?php
/**
 * 草帽船Z 本地 GM 面板（v2 —— BackStage 协议版）
 * 功能：查看/搜索全部账号，修改 等级/银两/元宝(系统+充值)/VIP/密码；300钻抽卡指定
 * 使用：http://127.0.0.1:8080/gm.php   登录密码：gm123456（可在下方修改）
 *
 * [v2 重要变更] 等级/元宝/银两/VIP 不再直写数据库！
 *   旧版直接 UPDATE player 表有两个致命问题：
 *   1) DZM 服务端把玩家实体缓存在内存并周期性持久化（CheckXml），直写 DB 会被
 *      内存旧数据覆盖 —— 这就是“GM 改完一直被重置”的根因；
 *   2) 若 player 行与 mapping 脱节（如误删账号后重新登录），直写 UPDATE 打不到行。
 *   v2 改走服务端原生 BackStage 通道（BackStageUpdateUserInfoHandler，协议 184）：
 *   服务端自己改内存+DB，在线玩家立即生效，离线玩家下次登录生效。
 *   另：账号列表的 <form> 移出 <tr>（HTML 合法结构 + 数组字段名），修复浏览器
 *   解析怪癖导致的跨行数据串写。
 *
 * 协议要点（源自服务端源码 BackStageUpdateUserInfoHandler/BackStageFetchUserInfoHandler）：
 *   帧 = 0x43 0x46 + int32(大端)opcode + int32(大端)body长度 + body
 *   BackStage 消息 body 为【裸 protobuf】——解码器和 handler 各 XOR 0xA5 一次，
 *   相互抵消，所以发送方不要再 XOR；响应体同样是裸的。
 *   fetch=182, update=184, 响应 opcode=994（OPCODE_HEARTBEATRET_S），
 *   Ret 字段：servertime=1 userid=2 name=3 registertime=4 lastlogin=5
 *             level=6 silvercoins=7 goldcoins=8
 *   请求字段：version=1(int, 必须为1) name=2(string)
 *             changeType=3(string) changeNum1=4(int) changeNum2=5(int)
 *   changeType: "level"=设到指定等级(经验自动对齐) "gold"=元宝增减(负数扣)
 *               "silver"=银两增减(负数扣) "recharge"=充值次数+1并升VIP(不可减)
 */

// ====== 配置 ======
$GM_PASSWORD   = 'gm123456';      // GM 面板登录密码
$DB_HOST       = '127.0.0.1';
$DB_USER       = 'root';
$DB_PASS       = 'root';
$DB_NAME       = 'dzm';
$BS_HOST       = '127.0.0.1';     // DZM 游戏服务端
$BS_PORT       = 25524;
$PAGE_SIZE     = 20;

// ====== 访问安全：GM 面板只允许本机与家里局域网访问 ======
// Tailscale(100.x) 与公网来源一律拒绝 —— 朋友只能玩游戏，碰不到 GM
$_gm_client_ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '';
$_gm_p = explode('.', $_gm_client_ip);
$_gm_allow = false;
if ($_gm_client_ip === '127.0.0.1' || $_gm_client_ip === '::1') {
    $_gm_allow = true;
} elseif (count($_gm_p) >= 2 && $_gm_p[0] === '192' && $_gm_p[1] === '168') {
    $_gm_allow = true;   // 家里局域网
}
if (!$_gm_allow) {
    http_response_code(403);
    die('Forbidden');
}

header('Content-Type: text/html; charset=utf-8');
error_reporting(E_ERROR | E_PARSE);

session_start();
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
    $db = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME);
    $db->set_charset('utf8');
} catch (Exception $e) {
    die('数据库连接失败: ' . $e->getMessage());
}

// ====== 登录 ======
$logged = isset($_SESSION['gm_ok']) && $_SESSION['gm_ok'] === true;
if (isset($_POST['do_login'])) {
    if ($_POST['password'] === $GM_PASSWORD) { $_SESSION['gm_ok'] = true; $logged = true; }
    else $login_err = 'GM 密码错误';
}
if (isset($_GET['logout'])) { session_destroy(); header('Location: gm.php'); exit; }
if (!$logged) {
    echo '<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GM 面板</title>
    <style>body{font-family:Microsoft YaHei;background:#1b2431;color:#cfe3ff;display:flex;justify-content:center;padding-top:120px}
    .box{background:#232f40;padding:30px 40px;border-radius:10px;box-shadow:0 4px 20px #000}
    input{padding:8px;border-radius:5px;border:1px solid #456;margin-top:10px}
    button{padding:8px 24px;background:#3d8ecf;color:#fff;border:0;border-radius:5px;cursor:pointer}
    .err{color:#ff8080}</style></head><body><div class="box"><h2>👑 GM 管理面板</h2>';
    if (isset($login_err)) echo "<div class='err'>$login_err</div>";
    echo '<form method="post"><input type="password" name="password" placeholder="GM 密码"><br>
    <button type="submit" name="do_login" value="1">登录</button></form></div></body></html>';
    exit;
}

// ====== protobuf 最小编解码（只覆盖本页用到的字段） ======
function pb_varint_enc($v) {
    $out = '';
    if ($v < 0) {
        // 负数按 64 位补码编码（int32 负数在 protobuf 中是 10 字节 varint）。
        // 注意不能用浮点数算 2^64（精度不够会把 -1 变成 0），全部用 64 位整数位运算：
        $lo = $v & 0xFFFFFFFF;         // 低 32 位
        $hi = ($v >> 32) & 0xFFFFFFFF; // 高 32 位
        for ($g = 0; $g < 10; $g++) {
            $b = 0;
            for ($k = 0; $k < 7; $k++) {
                $n = $g * 7 + $k;
                if ($n >= 64) break;
                $bit = ($n < 32) ? (($lo >> $n) & 1) : (($hi >> ($n - 32)) & 1);
                $b |= $bit << $k;
            }
            $out .= chr($g == 9 ? $b : ($b | 0x80));
        }
        return $out;
    }
    while (true) {
        $b = $v & 0x7F;
        $v = $v >> 7;
        if ($v > 0) $out .= chr($b | 0x80);
        else { $out .= chr($b); break; }
    }
    return $out;
}
function pb_int($field, $v) { return chr(($field << 3) | 0) . pb_varint_enc($v); }
function pb_str($field, $s) { return chr(($field << 3) | 2) . pb_varint_enc(strlen($s)) . $s; }
function pb_parse($bytes) {
    $res = array();
    $i = 0; $n = strlen($bytes);
    while ($i < $n) {
        $tag = 0; $shift = 0;
        while (true) {
            if ($i >= $n) return $res;
            $b = ord($bytes[$i++]);
            $tag |= ($b & 0x7F) << $shift; $shift += 7;
            if (!($b & 0x80)) break;
        }
        $field = $tag >> 3; $wire = $tag & 7;
        if ($wire == 0) {
            $v = 0; $shift = 0;
            while (true) {
                if ($i >= $n) return $res;
                $b = ord($bytes[$i++]);
                $v |= ($b & 0x7F) << $shift; $shift += 7;
                if ($shift >= 64) break;
                if (!($b & 0x80)) break;
            }
            $res[$field][] = $v;
        } elseif ($wire == 2) {
            $len = 0; $shift = 0;
            while (true) {
                if ($i >= $n) return $res;
                $b = ord($bytes[$i++]);
                $len |= ($b & 0x7F) << $shift; $shift += 7;
                if (!($b & 0x80)) break;
            }
            $res[$field][] = substr($bytes, $i, $len);
            $i += $len;
        } else {
            break; // 其它 wire type 本页用不到
        }
    }
    return $res;
}
function pb_val($parsed, $field, $default = 0) {
    return isset($parsed[$field]) ? $parsed[$field][0] : $default;
}

// ====== BackStage 通道 ======
define('BS_FETCH', 182);   // OPCODE_BACK_STAGE_FETCH_USER_INFO_C
define('BS_UPDATE', 184);  // OPCODE_BACK_STAGE_UPDATE_USER_INFO_C
define('BS_RET', 994);     // OPCODE_HEARTBEATRET_S（两个 handler 的回包都走它）

// 发一条 BackStage 消息并取回 Ret；失败返回 false
function bs_request($opcode, $pbBody) {
    global $BS_HOST, $BS_PORT;
    $sock = @fsockopen($BS_HOST, $BS_PORT, $errno, $errstr, 3);
    if (!$sock) return false;
    stream_set_timeout($sock, 3);
    $pkt = "\x43\x46" . pack('N', $opcode) . pack('N', strlen($pbBody)) . $pbBody;
    if (@fwrite($sock, $pkt) === false) { fclose($sock); return false; }
    $head = '';
    while (strlen($head) < 10) {
        $chunk = fread($sock, 10 - strlen($head));
        if ($chunk === '' || $chunk === false) { fclose($sock); return false; }
        $head .= $chunk;
    }
    $h = unpack('nhead/Nopcode/Nlen', $head);
    // 服务端 Encoder 的 len 是整包长(10+body)；按此取 body
    $bodyLen = $h['len'] - 10;
    if ($bodyLen < 0 || $bodyLen > 1048576) { fclose($sock); return false; }
    $body = '';
    while (strlen($body) < $bodyLen) {
        $chunk = fread($sock, $bodyLen - strlen($body));
        if ($chunk === '' || $chunk === false) { fclose($sock); return false; }
        $body .= $chunk;
    }
    fclose($sock);
    return pb_parse($body);
}

// 按角色名查实时数据（服务端内存优先，其次 DB）；返回 array(userid,level,silver,gold) 或 false
function bs_fetch_user($rolename) {
    $pb = pb_int(1, 1) . pb_str(2, $rolename);
    $ret = bs_request(BS_FETCH, $pb);
    if ($ret === false || !isset($ret[6])) return false;
    return array(
        'userid' => pb_val($ret, 2),
        'level'  => pb_val($ret, 6),
        'silver' => pb_val($ret, 7),
        'gold'   => pb_val($ret, 8), // sysgold + recharge 合计
    );
}

// 发送一条修改指令，返回成功与否
function bs_change($rolename, $changeType, $num1, $num2 = 0) {
    $pb = pb_int(1, 1) . pb_str(2, $rolename) . pb_str(3, $changeType)
        . pb_int(4, $num1) . pb_int(5, $num2);
    $ret = bs_request(BS_UPDATE, $pb);
    return ($ret !== false && isset($ret[6]));
}

// rechargenum → VIP 等级阈值（与服务端 RechargeHandler.getVipLevelByNum 一致）
$VIP_TABLE = array(13=>2000, 12=>1500, 11=>1200, 10=>1000, 9=>800, 8=>500, 7=>350, 6=>200, 5=>100, 4=>50, 3=>3, 2=>2, 1=>1);
function vip_need_rechargenum($targetVip) {
    global $VIP_TABLE;
    return isset($VIP_TABLE[$targetVip]) ? $VIP_TABLE[$targetVip] : null;
}

// ====== 保存修改（BackStage 通道） ======
$saved_msg = '';
if (isset($_POST['do_save'])) {
    foreach ($_POST['do_save'] as $gameid => $v) {
        $gameid = (int)$gameid;
        $row = $db->query("SELECT m.gameid, p.name AS rolename FROM mapping m LEFT JOIN player p ON p.id=m.gameid WHERE m.gameid=$gameid")->fetch_assoc();
        if (!$row || $row['rolename'] === null || $row['rolename'] === '') {
            $saved_msg .= "账号 #$gameid：找不到角色数据，跳过<br>";
            continue;
        }
        $rolename = $row['rolename'];
        $targetLevel  = (int)$_POST['level'][$gameid];
        $targetSilver = (int)$_POST['silvercoins'][$gameid];
        $targetSys    = (int)$_POST['sysgoldcoins'][$gameid];
        $targetRe     = (int)$_POST['rechargegoldcoins'][$gameid];
        $targetVip    = (int)$_POST['viplevel'][$gameid];

        $cur = bs_fetch_user($rolename);
        if ($cur === false) {
            $saved_msg .= "账号 #$gameid ($rolename)：连不上游戏服务端(25524)，本次未修改。请确认服务端已启动。<br>";
            continue;
        }
        if ((int)$cur['userid'] !== $gameid) {
            $saved_msg .= "账号 #$gameid ($rolename)：服务端按名字命中了别的账号(userid={$cur['userid']})，已跳过。角色名重复请改名后再用 GM。<br>";
            continue;
        }

        $msgs = array();
        // 1) 等级（服务端自动对齐经验）
        if ($targetLevel > 0 && $targetLevel !== (int)$cur['level']) {
            bs_change($rolename, 'level', $targetLevel);
            $msgs[] = "等级→{$targetLevel}";
        }
        // 2) VIP：走 recharge（充值次数），不可下调；补偿其附赠的元宝
        if ($targetVip > 0 && $targetVip != 0) {
            $need = vip_need_rechargenum($targetVip);
            $dbRow = $db->query("SELECT rechargenum FROM player WHERE id=$gameid")->fetch_assoc();
            $curNum = $dbRow ? (int)$dbRow['rechargenum'] : 0;
            if ($need !== null && $need > $curNum) {
                $delta = $need - $curNum;
                bs_change($rolename, 'recharge', $delta);
                // recharge 每次附赠 10 元宝，扣回去保持元宝数不受 VIP 调整影响
                $cur2 = bs_fetch_user($rolename);
                if ($cur2 !== false) bs_change($rolename, 'gold', (int)$cur['gold'] - (int)$cur2['gold']);
                $msgs[] = "VIP→{$targetVip}";
            } elseif ($need !== null && $need < $curNum) {
                $msgs[] = "VIP 保持（服务端通道不支持下调 VIP，当前充值次数已超目标档）";
            }
        }
        // 3) 元宝：目标=系统+充值 合计差值（负数会先扣系统元宝再扣充值元宝）
        $cur3 = bs_fetch_user($rolename);
        $targetGold = $targetSys + $targetRe;
        if ($targetGold !== (int)$cur3['gold']) {
            bs_change($rolename, 'gold', $targetGold - (int)$cur3['gold']);
            $msgs[] = "元宝→{$targetGold}";
        }
        // 4) 银两
        $cur4 = bs_fetch_user($rolename);
        if ($targetSilver !== (int)$cur4['silver']) {
            bs_change($rolename, 'silver', $targetSilver - (int)$cur4['silver']);
            $msgs[] = "银两→{$targetSilver}";
        }
        // 5) 最终实时值
        $fin = bs_fetch_user($rolename);
        if ($fin !== false) {
            $saved_msg .= "账号 #$gameid ($rolename) 已生效：等级{$fin['level']} 元宝{$fin['gold']} 银两{$fin['silver']}"
                        . ($msgs ? '（' . implode('，', $msgs) . '）' : '（无变化）') . "<br>";
        } else {
            $saved_msg .= "账号 #$gameid 已修改（" . implode('，', $msgs) . "）<br>";
        }
    }
}
// 重置密码（登录验证走 DB，无缓存问题，保持直写）
if (isset($_POST['do_resetpwd'])) {
    foreach ($_POST['do_resetpwd'] as $gameid => $v) {
        $gameid = (int)$gameid;
        $newpwd = isset($_POST['newpwd'][$gameid]) ? trim($_POST['newpwd'][$gameid]) : '';
        if ($newpwd !== '') {
            $stmt = $db->prepare("UPDATE mapping SET passwd=? WHERE gameid=?");
            $stmt->bind_param('si', $newpwd, $gameid);
            $stmt->execute(); $stmt->close();
            $stmt = $db->prepare("UPDATE player SET password=? WHERE id=?");
            $stmt->bind_param('si', $newpwd, $gameid);
            $stmt->execute(); $stmt->close();
            $saved_msg .= "账号 #$gameid 密码已重置为 {$newpwd}<br>";
        }
    }
}
// 删除账号（危险）—— 需玩家离线，否则服务端内存会重新落库
if (isset($_POST['do_delete'])) {
    foreach ($_POST['do_delete'] as $gameid => $v) {
        $gameid = (int)$gameid;
        foreach (array('player','mapping','bag','equip','skill','soul','battle','career','challenge','handbook','title','invitestatus','leaguamembers','teambuffer','sysmsginfo','rewards','stats','disciple','skillbook','worldboss','activityinfo','moment') as $t) {
            $col = in_array($t, array('player')) ? 'id' : ((in_array($t, array('mapping','playerfrom','leaguamembers','worldboss')) ? null : 'playerid'));
            if ($t === 'mapping') { $db->query("DELETE FROM mapping WHERE gameid=$gameid"); continue; }
            if ($t === 'player')  { $db->query("DELETE FROM player WHERE id=$gameid"); continue; }
            if ($col === null) continue;
            $db->query("DELETE FROM $t WHERE $col=$gameid");
        }
        $saved_msg .= "账号 #$gameid 已删除（务必保证该玩家已下线，否则服务端内存数据可能重新落库）<br>";
    }
}

// ====== 抽卡必得设置（300钻万里抽指定人物） ======
if (isset($_POST['do_pin_set'])) {
    $gameid = (int)$_POST['gameid'];
    $disc   = (int)$_POST['discipleid'];
    if ($gameid > 0 && $disc > 0) {
        load_disciples();
        $stmt = $db->prepare("INSERT INTO gmpin (playerid, discipleid) VALUES (?,?) ON DUPLICATE KEY UPDATE discipleid=?");
        $stmt->bind_param('iii', $gameid, $disc, $disc);
        $stmt->execute(); $stmt->close();
        $saved_msg = "账号 #{$gameid} 抽卡必得已设置为：{$GLOBALS['disciples'][$disc]['name']}（300钻万里抽必出，重新登录后生效）";
    } else {
        $saved_msg = "保存失败：请先在下拉框选择账号，并点击一个人物头像";
    }
}
if (isset($_POST['do_pin_clear'])) {
    $gameid = (int)$_POST['gameid'];
    $stmt = $db->prepare("DELETE FROM gmpin WHERE playerid=?");
    $stmt->bind_param('i', $gameid);
    $stmt->execute(); $stmt->close();
    $saved_msg = "账号 #{$gameid} 抽卡必得已取消，恢复随机";
}

// 解析弟子配置（Disciples.txt 为 GBK 编码）
$GLOBALS['disciples'] = array();
function load_disciples() {
    if (!empty($GLOBALS['disciples'])) return $GLOBALS['disciples'];
    $file = 'e:\BaiduNetdiskDownload\(SY-096)草M船Z\Debug_Alpha\Resources\Disciples.txt';
    $heads_dir = dirname(__FILE__) . DIRECTORY_SEPARATOR . 'heads';
    if (!file_exists($file)) return $GLOBALS['disciples'];
    foreach (file($file) as $ln) {
        $ln = trim($ln);
        if ($ln === '') continue;
        if (!mb_check_encoding($ln, 'UTF-8')) {
            $ln = mb_convert_encoding($ln, 'UTF-8', 'GBK');
        }
        $c = explode("\t", $ln);
        if (count($c) < 19 || trim($c[0]) === 'ID' || !ctype_digit(trim($c[0]))) continue;
        $head = basename(trim($c[18]));
        if ($head === '' || !file_exists($heads_dir . DIRECTORY_SEPARATOR . $head)) continue;
        $GLOBALS['disciples'][(int)trim($c[0])] = array(
            'id'      => (int)trim($c[0]),
            'name'    => trim($c[1]),
            'quality' => (int)trim($c[2]),
            'display' => (int)trim($c[17]),
            'head'    => $head,
        );
    }
    ksort($GLOBALS['disciples']);
    return $GLOBALS['disciples'];
}
load_disciples();

// 当前全部抽卡指定
$pins = array();
$res = $db->query("SELECT playerid, discipleid FROM gmpin");
while ($row = $res->fetch_assoc()) $pins[(int)$row['playerid']] = (int)$row['discipleid'];

// ====== 列表/搜索 ======
$search = isset($_GET['q']) ? trim($_GET['q']) : '';
$page   = isset($_GET['page']) ? max(1, (int)$_GET['page']) : 1;
$where  = '';
if ($search !== '') {
    $kw = $db->real_escape_string($search);
    $where = "WHERE m.puid LIKE '%$kw%' OR m.name LIKE '%$kw%' OR m.gameid=" . (int)$search;
}
$cnt = $db->query("SELECT COUNT(*) c FROM mapping m $where")->fetch_assoc()['c'];
$total_page = max(1, ceil($cnt / $PAGE_SIZE));
$page = min($page, $total_page);
$off = ($page - 1) * $PAGE_SIZE;

$sql = "SELECT m.gameid, m.puid, m.name AS accname, m.passwd,
        p.silvercoins, p.sysgoldcoins, p.rechargegoldcoins, p.level, p.viplevel, p.name AS rolename
        FROM mapping m LEFT JOIN player p ON p.id = m.gameid $where
        ORDER BY m.gameid DESC LIMIT $off, $PAGE_SIZE";
$rows = $db->query($sql);

function h($s){ return htmlspecialchars($s, ENT_QUOTES, 'UTF-8'); }
?>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1.2">
<title>草帽船Z GM 面板</title><style>
body{font-family:Microsoft YaHei;background:#1b2431;color:#cfe3ff;margin:0;padding:20px}
table{border-collapse:collapse;width:100%;background:#232f40;border-radius:8px}
th,td{padding:8px 10px;border-bottom:1px solid #2f3d52;text-align:center;font-size:13px}
th{background:#2a3850;color:#9fc5ff}
input{width:70px;padding:4px;background:#1b2431;color:#cfe3ff;border:1px solid #456;border-radius:4px;text-align:center}
input.wide{width:130px}
button{padding:4px 12px;background:#3d8ecf;color:#fff;border:0;border-radius:4px;cursor:pointer}
button.danger{background:#c0392b}
.search{margin-bottom:12px}
.msg{background:#204020;border:1px solid #3f8040;color:#a0e0a0;padding:8px 14px;border-radius:6px;margin-bottom:12px}
a{color:#7fbfff}
.pwd{color:#888}
/* ===== 本地版新增：手机访问适配 ===== */
.tblwrap{width:100%;overflow-x:auto;-webkit-overflow-scrolling:touch}
.tblwrap table{min-width:760px}
@media (max-width:768px){
  body{padding:10px}
  th,td{padding:6px 6px;font-size:12px;white-space:nowrap}
  input{width:52px;padding:6px 3px;font-size:14px}
  input.wide{width:100px}
  button{padding:8px 14px;font-size:14px}
  .dcard{width:72px !important}
  .dcard img{width:60px !important;height:60px !important}
  #dgrid{max-height:320px !important;padding:6px !important}
  h2{font-size:18px}
  h3{font-size:16px}
}
</style></head><body>
<h2>👑 草帽船Z GM 面板 &nbsp;<a href="?logout=1" style="font-size:13px">退出</a></h2>
<div style="color:#ffcc66;font-size:13px;margin-bottom:10px">
⚠ v2 版说明：等级/元宝/银两/VIP 通过游戏服务端 BackStage 通道修改，<b>在线玩家立即生效</b>，离线玩家下次登录生效，<b>不会再被服务端覆盖</b>。<br>
⚠ 删除账号仍是直删数据库：务必让该玩家先下线，否则会被服务端内存数据重新写回。
</div>
<?php if($saved_msg) echo "<div class='msg'>✔ $saved_msg</div>"; ?>

<div class="search">
<form method="get">
    <input type="text" name="q" class="wide" placeholder="账号/名字/ID" value="<?=h($search)?>">
    <button type="submit">搜索</button>
    <a href="gm.php">全部</a>
    &nbsp;共 <?= $cnt ?> 个账号
</form></div>

<div class="tblwrap">
<!-- [v2] 表单移出 <tr>：整个表共用一个 form，字段用 数组名[gameid]，
     修复浏览器把 <tr> 内 <form> 剥离导致的跨行/整行数据串写问题 -->
<form method="post" id="accform">
<table>
<tr><th>ID</th><th>账号</th><th>角色名</th><th>密码</th><th>抽卡指定</th><th>等级</th><th>VIP</th><th>银两</th><th>元宝(系统)</th><th>元宝(充值)</th><th>操作</th></tr>
<?php while($r = $rows->fetch_assoc()): $gid = (int)$r['gameid']; ?>
<tr>
  <td><?= $gid ?></td>
  <td><?= h($r['puid']) ?></td>
  <td><?= h($r['rolename']) ?></td>
  <td class="pwd"><?= h($r['passwd']) ?></td>
  <td><?php if (isset($pins[$gid]) && isset($GLOBALS['disciples'][$pins[$gid]])) {
          echo '<b style="color:#a0e0a0">'.h($GLOBALS['disciples'][$pins[$gid]]['name']).'</b>';
      } else { echo '<span style="color:#888">随机</span>'; } ?></td>
  <td><input name="level[<?= $gid ?>]" value="<?= (int)$r['level'] ?>"></td>
  <td><input name="viplevel[<?= $gid ?>]" value="<?= (int)$r['viplevel'] ?>"></td>
  <td><input name="silvercoins[<?= $gid ?>]" value="<?= (int)$r['silvercoins'] ?>"></td>
  <td><input name="sysgoldcoins[<?= $gid ?>]" value="<?= (int)$r['sysgoldcoins'] ?>"></td>
  <td><input name="rechargegoldcoins[<?= $gid ?>]" value="<?= (int)$r['rechargegoldcoins'] ?>"></td>
  <td>
    <button type="submit" name="do_save[<?= $gid ?>]" value="1">保存</button>
    <button type="submit" name="do_resetpwd[<?= $gid ?>]" value="1"
        onclick="var p=prompt('新密码:','123456'); if(!p) return false; document.getElementById('newpwd_<?= $gid ?>').value=p; return true;">
        改密</button>
    <input type="hidden" name="newpwd[<?= $gid ?>]" id="newpwd_<?= $gid ?>" value="">
    <button type="submit" name="do_delete[<?= $gid ?>]" value="1" class="danger"
        onclick="return confirm('确定删除账号 #<?= $gid ?> 的全部数据吗？请先让该玩家下线！')">删除</button>
  </td>
</tr>
<?php endwhile; ?>
</table>
</form>
</div>

<div style="margin-top:12px">
<?php for($i=1;$i<=$total_page;$i++): ?>
    <a href="?q=<?=urlencode($search)?>&page=<?=$i?>"><?= $i==$page ? "<b>[$i]</b>" : $i ?></a>
<?php endfor; ?>
</div>

<h3 style="margin-top:24px">🎯 抽卡必得（固定 300 钻万里抽指定人物）</h3>
<div style="color:#9fc5ff;font-size:13px;margin-bottom:8px">
说明：为某账号设置指定人物后，该账号每次 <b style="color:#ffcc66">300 钻万里抽</b> 必出该人物（已拥有则转为魂魄）。点头像选择，保存后玩家重新登录生效。取消指定后恢复随机。<br>
<span style="color:#ff9090">提示：请勿反复抽同一个已拥有的人物——大量重复转魂魄可能造成客户端界面异常。</span>
</div>
<form method="post" id="pinform">
<table style="width:auto;margin-bottom:12px"><tr>
<td style="border:0">
    <select name="gameid" id="pin_gameid" style="padding:6px;background:#1b2431;color:#cfe3ff;border:1px solid #456;border-radius:4px">
    <?php
    $allacc = $db->query("SELECT gameid, puid, name FROM mapping ORDER BY gameid");
    while ($a = $allacc->fetch_assoc()):
        $pinName = isset($pins[(int)$a['gameid']]) ? ('【当前：'.$GLOBALS['disciples'][$pins[(int)$a['gameid']]]['name'].'】') : '【未指定】';
    ?>
        <option value="<?= $a['gameid'] ?>"><?= "#{$a['gameid']} ".h($a['puid'])." (".h($a['name']).") ".$pinName ?></option>
    <?php endwhile; ?>
    </select>
    <input type="hidden" name="discipleid" id="discipleid" value="0">
    <span id="selname" style="color:#a0e0a0">未选择人物</span>
</td>
<td style="border:0">
    <button type="submit" name="do_pin_set" value="1" onclick="return document.getElementById('discipleid').value>0 || (alert('请先点击选择一个人物头像'),false)">保存指定</button>
    <button type="submit" name="do_pin_clear" value="1" class="danger">取消指定</button>
</td>
</tr></table>
<div style="margin-bottom:6px">
    品质筛选：<select id="qfilter" onchange="applyFilter()" style="padding:4px;background:#1b2431;color:#cfe3ff;border:1px solid #456">
        <option value="0">全部</option><option value="1">甲(1)</option><option value="2">乙(2)</option><option value="3">丙(3)</option><option value="4">丁(4)</option>
    </select>
    名字过滤：<input type="text" id="nfilter" oninput="applyFilter()" style="width:100px;padding:4px;background:#1b2431;color:#cfe3ff;border:1px solid #456;border-radius:4px">
    共 <?= count($GLOBALS['disciples']) ?> 个人物
</div>
<div id="dgrid" style="display:flex;flex-wrap:wrap;gap:6px;background:#232f40;padding:10px;border-radius:8px;max-height:420px;overflow-y:auto">
<?php foreach ($GLOBALS['disciples'] as $d): ?>
    <div class="dcard" data-q="<?= $d['quality'] ?>" data-n="<?= h($d['name']) ?>" data-id="<?= $d['id'] ?>"
         style="width:86px;text-align:center;cursor:pointer;border:2px solid transparent;border-radius:6px;padding:3px;background:#1b2431"
         onclick="pickDisciple(<?= $d['id'] ?>,'<?= h($d['name']) ?>',this)">
        <img src="heads/<?= h($d['head']) ?>" width="72" height="72" style="border-radius:4px" loading="lazy">
        <div style="font-size:11px;margin-top:2px"><?= h($d['name']) ?></div>
        <div style="font-size:10px;color:<?= $d['quality']==1?'#ff9090':($d['quality']==2?'#ffd070':($d['quality']==3?'#90c8ff':'#b0b0b0')) ?>">
            #<?= $d['id'] ?> · <?= $d['quality']==1?'甲':($d['quality']==2?'乙':($d['quality']==3?'丙':'丁')) ?>
        </div>
    </div>
<?php endforeach; ?>
</div>
</form>

<script>
var _selCard = null;
function pickDisciple(id, name, el) {
    document.getElementById('discipleid').value = id;
    document.getElementById('selname').innerHTML = '已选：' + name + ' (ID:' + id + ')';
    if (_selCard) _selCard.style.borderColor = 'transparent';
    _selCard = el; _selCard.style.borderColor = '#3dff70';
}
function applyFilter() {
    var q = document.getElementById('qfilter').value;
    var n = document.getElementById('nfilter').value.trim();
    var cards = document.querySelectorAll('.dcard');
    for (var i = 0; i < cards.length; i++) {
        var ok = true;
        if (q !== '0' && cards[i].getAttribute('data-q') !== q) ok = false;
        if (n !== '' && cards[i].getAttribute('data-n').indexOf(n) === -1) ok = false;
        cards[i].style.display = ok ? '' : 'none';
    }
}
</script>

</body></html>
