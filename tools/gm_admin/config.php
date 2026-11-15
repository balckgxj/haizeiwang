<?php
// [haizei] GM 后台配置
// 与本地游戏服务端共用同一套账号数据（dzm.mapping）与 GM 白名单（TesterList.xml）。
// 所有路径用正斜杠，避免 Windows 反斜杠转义问题。
return array(
    'db' => array(
        'host'    => '127.0.0.1',
        'port'    => 3306,
        'user'    => 'root',
        'pass'    => 'root',
        'name'    => 'dzm',
        'charset' => 'utf8',
    ),
    // Java 游戏服务端（DZM.jar），BackStage GM 协议与登录协议共用此端口
    'server' => array(
        'host' => '127.0.0.1',
        'port' => 25524,
    ),
    // 服务端 GM 白名单，PHP 后台与 Java 服务端读写同一文件
    'tester_list' => 'E:/BaiduNetdiskDownload/(SY-096)草M船Z/src/src/server/Code_Server/server/xml/TesterList.xml',
    'session_name' => 'HAIZEI_GM',
    // GM 后台只允许白名单内的账号登录（与游戏内 GM 权限同一份数据）
    'admin_requires_gm' => true,
);
