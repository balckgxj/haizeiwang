<?php
// [haizei] GM 运营后台 —— 与游戏客户端共用 dzm.mapping 账号、与 DZM 服务端共用 TesterList.xml 白名单
require_once dirname(__FILE__) . '/lib.php';
?><!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>梦想海贼王 · GM 运营后台</title>
<style>
:root{--bg:#f5f6f8;--card:#fff;--line:#e3e6ec;--text:#1f2430;--muted:#6b7280;--brand:#2f6fed;--ok:#0f9d58;--warn:#d93025;--mono:Consolas,Monaco,monospace}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:14px/1.6 -apple-system,"Segoe UI","Microsoft YaHei",sans-serif}
.wrap{max-width:1080px;margin:0 auto;padding:24px 18px 60px}
header.top{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:20px}
header.top h1{font-size:20px;margin:0;font-weight:600}
header.top .sub{color:var(--muted);font-size:12px;margin-top:2px}
.badge{display:inline-block;padding:2px 9px;border-radius:20px;font-size:12px;border:1px solid var(--line);background:#fff}
.badge.on{color:var(--ok);border-color:#b7e4c8;background:#f0fbf4}
.badge.off{color:var(--warn);border-color:#f3c1bd;background:#fff5f4}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:20px;margin-bottom:16px;box-shadow:0 1px 2px rgba(20,30,60,.03)}
.card h2{font-size:15px;margin:0 0 4px;font-weight:600}
.card .hint{color:var(--muted);font-size:12px;margin:0 0 16px}
.row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
input,select,button{font:inherit;border:1px solid var(--line);border-radius:6px;padding:7px 11px;background:#fff;color:var(--text);outline:none}
input:focus,select:focus{border-color:var(--brand)}
button{cursor:pointer;background:var(--brand);border-color:var(--brand);color:#fff}
button:hover{filter:brightness(1.06)}
button.ghost{background:#fff;color:var(--text);border-color:var(--line)}
button.mini{padding:3px 9px;font-size:12px}
button.danger{background:#fff;color:var(--warn);border-color:#f3c1bd}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:9px 8px;border-bottom:1px solid var(--line);vertical-align:middle}
th{color:var(--muted);font-weight:500;font-size:12px}
td.code{font-family:var(--mono);font-size:12px}
.msg{margin-top:12px;padding:9px 12px;border-radius:6px;font-size:13px;display:none}
.msg.err{display:block;background:#fff2f1;color:var(--warn);border:1px solid #f3c1bd}
.msg.ok{display:block;background:#f0fbf4;color:var(--ok);border:1px solid #b7e4c8}
.muted{color:var(--muted)}
.codeblock{font-family:var(--mono);font-size:12px;background:#f7f8fa;border:1px solid var(--line);border-radius:6px;padding:10px;max-height:220px;overflow:auto;white-space:pre-wrap;word-break:break-all}
.login{max-width:400px;margin:90px auto 0}
.login .card{padding:28px}
.login label{display:block;font-size:12px;color:var(--muted);margin:12px 0 5px}
.login input{width:100%}
.login button{width:100%;margin-top:20px;padding:9px}
.hidden{display:none}
footer{color:var(--muted);font-size:12px;text-align:center;margin-top:28px}
</style>
</head>
<body>

<div id="loginView" class="login hidden">
  <div class="card">
    <h2>GM 运营后台登录</h2>
    <p class="hint">使用游戏账号密码登录；仅 GM 白名单内账号可进入。</p>
    <form onsubmit="return doLogin(event)">
      <label>账号（puid）</label><input id="lg_puid" autocomplete="username" autofocus />
      <label>密码</label><input id="lg_pwd" type="password" autocomplete="current-password" />
      <button type="submit">登 录</button>
    </form>
    <div id="loginMsg" class="msg"></div>
    <p class="hint" style="margin:16px 0 0">还没有账号？先在游戏的登录页用任意账号密码登录一次，服务端会自动注册。</p>
  </div>
</div>

<div id="mainView" class="wrap hidden">
  <header class="top">
    <div><h1>梦想海贼王 · GM 运营后台</h1><div class="sub">账号与 GM 权限与游戏客户端 / DZM 服务端实时共用</div></div>
    <div class="row"><span class="muted" id="who"></span><button class="ghost mini" onclick="doLogout()">退出</button></div>
  </header>

  <div class="card">
    <h2>服务状态</h2>
    <p class="hint">GM 指令通过 BackStage 协议直连游戏服务端；账号数据来自同一套 MySQL 表。</p>
    <div class="row" id="services"></div>
    <div id="globalMsg" class="msg"></div>
  </div>

  <div class="card">
    <h2>账号与 GM 权限</h2>
    <p class="hint">账号表 <span class="codeblock" style="display:inline;padding:2px 6px">dzm.mapping</span>：游戏登录页与本页面共用。改密码立即对游戏登录生效；设为 GM 会写入服务端白名单。</p>
    <table><thead><tr><th>账号 (puid)</th><th>角色名</th><th>gameid</th><th>密码</th><th>GM</th><th style="width:260px">操作</th></tr></thead><tbody id="accounts"></tbody></table>
  </div>

  <div class="card">
    <h2>GM 白名单（TesterList.xml）</h2>
    <p class="hint" id="wlPath"></p>
    <div class="row" id="whitelist"></div>
    <p class="hint" style="margin-top:12px">Java 服务端登录时读取此文件下发 GM 标记，GM 指令处理时再次校验；改完无需重启服务端。</p>
  </div>

  <div class="card">
    <h2>玩家数据（BackStage 协议）</h2>
    <p class="hint">与老项目 PHP 后台一致，经 25524 端口向 Java 服务端发 OPBackStage* 包。</p>
    <div class="row">
      <input id="q_name" placeholder="角色名，如 playerheigui" style="min-width:220px" />
      <button class="ghost" onclick="playerQuery()">查询玩家</button>
    </div>
    <div class="row" style="margin-top:12px">
      <input id="u_name" placeholder="角色名" style="min-width:180px" />
      <input id="u_field" placeholder="字段，如 goldcoins" style="min-width:170px" />
      <input id="u_value" placeholder="数值" style="width:110px" />
      <input id="u_value2" placeholder="数值2" style="width:110px" />
      <button class="ghost" onclick="playerUpdate()">修改</button>
    </div>
    <div class="codeblock" id="gmOut" style="margin-top:14px">（结果会显示在这里）</div>
  </div>

  <footer>Haizeiwang Win32 移植 · GM 后台 · 仅限本机调试环境使用</footer>
</div>

<script>
function $(id){return document.getElementById(id);}
function show(id,on){$(id).className=on?'':'hidden';}
function msg(id,text,ok){var e=$(id);e.className='msg '+(ok?'ok':'err');e.textContent=text;if(ok)setTimeout(function(){e.className='msg';},3500);}
function api(data,cb){
  var fd=new FormData();
  for(var k in data){if(data.hasOwnProperty(k))fd.append(k,data[k]);}
  var x=new XMLHttpRequest();
  x.open('POST','api.php',true);
  x.onreadystatechange=function(){
    if(x.readyState!==4)return;
    var r;try{r=JSON.parse(x.responseText);}catch(e){r={ok:false,error:'响应解析失败: '+x.responseText.slice(0,200)};}
    cb(r);
  };
  x.send(fd);
}
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}

function doLogin(e){
  e.preventDefault();
  api({action:'admin_login',puid:$('lg_puid').value,pwd:$('lg_pwd').value},function(r){
    if(!r.ok){msg('loginMsg',r.error||'登录失败',false);return;}
    msg('loginMsg',r.bootstrap?'首次初始化：已将当前账号设为 GM':'登录成功',true);
    setTimeout(loadState,300);
  });
  return false;
}
function doLogout(){api({action:'admin_logout'},function(){location.reload();});}

function refreshAccounts(list){
  var body=$('accounts');
  if(!list.length){body.innerHTML='<tr><td colspan="6" class="muted">暂无账号，请先在游戏登录页登录一次。</td></tr>';return;}
  var html='';
  for(var i=0;i<list.length;i++){
    var a=list[i];
    html+='<tr><td class="code">'+esc(a.puid)+'</td><td>'+esc(a.name)+'</td><td class="code">'+esc(a.gameid)+'</td>'
      +'<td>'+(a.has_pwd?'<span class="badge on">已设置</span>':'<span class="badge off">空</span>')+'</td>'
      +'<td>'+(a.is_gm?'<span class="badge on">GM</span>':'<span class="badge">普通</span>')+'</td>'
      +'<td><button class="mini ghost" onclick="setPwd(\''+esc(a.puid)+'\')">改密码</button> '
      +'<button class="mini '+(a.is_gm?'danger':'')+'" onclick="setGm(\''+esc(a.puid)+'\','+(a.is_gm?0:1)+')">'+(a.is_gm?'取消 GM':'设为 GM')+'</button></td></tr>';
  }
  body.innerHTML=html;
}
function setPwd(puid){
  var p=prompt('为账号 '+puid+' 设置新密码（明文存储，与服务端校验方式一致）：');
  if(p===null||p==='')return;
  api({action:'setpwd',puid:puid,pwd:p},function(r){msg('globalMsg',r.ok?'密码已更新':r.error,r.ok);if(r.ok)loadState();});
}
function setGm(puid,on){
  api({action:'setgm',puid:puid,on:on},function(r){msg('globalMsg',r.ok?'GM 权限已更新（服务端实时生效）':r.error,r.ok);if(r.ok)loadState();});
}
function playerQuery(){
  api({action:'player_query',name:$('q_name').value},function(r){
    $('gmOut').textContent=JSON.stringify(r,null,2);
  });
}
function playerUpdate(){
  api({action:'player_update',name:$('u_name').value,field:$('u_field').value,value:$('u_value').value,value2:$('u_value2').value||'0'},function(r){
    $('gmOut').textContent=JSON.stringify(r,null,2);
  });
}
function loadState(){
  api({action:'state'},function(r){
    if(r.need_login||!r.ok){show('loginView',true);show('mainView',false);return;}
    show('loginView',false);show('mainView',true);
    $('who').textContent='GM：'+r.admin;
    var s=r.services||{};
    $('services').innerHTML='<span class="badge '+(s.mysql?'on':'off')+'">MySQL '+(s.mysql?'已连接':'未启动')+'</span>'
      +'<span class="badge '+(s.server?'on':'off')+'">DZM 服务端 '+(s.server?'在线':'离线')+'</span>'
      +'<span class="badge">账号数 '+((r.accounts||[]).length)+'</span>'
      +'<span class="badge">GM 数 '+((r.whitelist||[]).length)+'</span>';
    $('wlPath').textContent='文件路径：'+(r.whitelist_path||'');
    refreshAccounts(r.accounts||[]);
    var wl=r.whitelist||[],h='';
    for(var i=0;i<wl.length;i++)h+='<span class="badge on code">'+esc(wl[i])+'</span>';
    $('whitelist').innerHTML=h||'<span class="muted">（白名单为空）</span>';
  });
}
loadState();
</script>
</body>
</html>
