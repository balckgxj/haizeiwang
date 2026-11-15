<?php
// [haizei] GM 后台 JSON 接口
require_once dirname(__FILE__) . '/lib.php';

sess_start();
$action = arg('action', 'state');

// ---- 给游戏客户端 / 脚本用的账号校验接口（凭账号密码，无需后台会话） ----
if ($action === 'auth') {
    $puid = arg('puid');
    $pwd  = arg('pwd');
    if (!account_check($puid, $pwd)) {
        json_out(array('ok' => false, 'error' => '账号或密码错误'));
    }
    json_out(array(
        'ok'    => true,
        'puid'  => $puid,
        'is_gm' => gm_has($puid) ? 1 : 0,
    ));
}

// ---- 后台登录 ----
if ($action === 'admin_login') {
    $puid = arg('puid');
    $pwd  = arg('pwd');
    if (!account_check($puid, $pwd)) {
        json_out(array('ok' => false, 'error' => '账号或密码错误（账号需先在游戏登录页注册）'));
    }
    $bootstrap = false;
    if (gm_bootstrap_needed()) {
        // 首次初始化：白名单里没有任何有效游戏账号，把首个登录者设为 GM，避免死锁
        $err = gm_set($puid, true);
        if ($err !== '') { json_out(array('ok' => false, 'error' => $err)); }
        $bootstrap = true;
    } elseif (!gm_has($puid)) {
        json_out(array('ok' => false, 'error' => '该账号不是 GM，无权进入后台'));
    }
    $_SESSION['puid'] = $puid;
    json_out(array('ok' => true, 'puid' => $puid, 'bootstrap' => $bootstrap));
}

if ($action === 'admin_logout') {
    $_SESSION = array();
    @session_destroy();
    json_out(array('ok' => true));
}

// ---- 以下接口均需后台登录 + GM 权限 ----
$me = require_admin();

switch ($action) {

case 'state':
    $allCfg = cfg();
    json_out(array(
        'ok'        => true,
        'admin'     => $me,
        'accounts'  => account_rows(),
        'whitelist' => gm_whitelist_load(),
        'services'  => array(
            'mysql'  => port_up('127.0.0.1', 3306),
            'server' => port_up('127.0.0.1', 25524),
        ),
        'whitelist_path' => $allCfg['tester_list'],
    ));

case 'setpwd':
    list($ok, $err) = account_setpwd(arg('puid'), arg('pwd'));
    json_out(array('ok' => $ok, 'error' => $err));

case 'setgm':
    $target = arg('puid');
    $on     = arg('on', '0') === '1';
    // [haizei] 自我保护：require_admin() 每次请求都重校验白名单，撤销自己会立刻
    // 让当前会话失效，之后再也无法通过后台把权限加回来（只能手改 XML）。
    // 明确禁止自撤，交给其他 GM 账号操作。
    if (!$on && $target === $me) {
        json_out(array('ok' => false, 'error' => '不能撤销自己的 GM 权限，请由其他 GM 账号操作'));
    }
    $err = gm_set($target, $on);
    json_out(array('ok' => $err === '', 'error' => $err));

case 'player_query':
    json_out(backstage_fetch_user(arg('name')));

case 'player_update':
    json_out(backstage_update_user(arg('name'), arg('field'), arg('value'), arg('value2', '0')));

default:
    json_out(array('ok' => false, 'error' => '未知操作: ' . $action));
}
