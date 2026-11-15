# Haizeiwang 迁移台账（2.1.3 → 3.17.2）

> 老工程保持原样未改动：`E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src`
> 新工程：`E:\PCGame\Haizeiwang`

---

## 一、当前状态（本次会话结束点）

| 项目 | 状态 |
|---|---|
| cocos2d-x 3.17.2 引擎 + external 预编译依赖 | ✅ 编译通过（Win32/x86，见下） |
| CMake 工程（Windows Win32 / VS2022） | ✅ 可配置、可增量编译 |
| 源码与资源拷贝（204 cpp / 120,200 行 / 1772 个资源文件） | ✅ |
| 兼容层（CCScrollView / CocosBuilder / Lua / 平台桥接） | ✅ |
| 自动迁移规则 | ✅ 302 处替换，覆盖 56 个文件 |
| `haizei_game` 游戏库 + 链接 | ✅ **0 错误，Haizeiwang.exe 已生成并可运行** |
| 运行验证 | ✅ 窗口启动、加载场景（ccbi+图集+音乐）正常渲染（已截图确认） |

架构说明：**必须编 Win32(x86)**。cocos2d-x 3.17 的 `external/*/prebuilt` 只有
win32 版（glew/zlib/curl/freetype/libpng… 都是 x86），编 x64 会出现大量
“引擎内部符号未解析”的假象。以后要 x64 需先用源码编这些第三方库。

运行方式：`E:\PCGame\Haizeiwang\build\Debug\Haizeiwang.exe`
（控制台窗口可看 CCLOG；正式版可改回 WIN32 子系统）。

一次增量编译约 15~30 秒（`build.bat`）。

---

## 二、已完成的工作

### 1. 工程结构

```
E:\PCGame\Haizeiwang
├─ engine\cocos2d-x              3.17.2（git cocos2d-x-3.17.2 + external v3-deps-158）
├─ client
│  ├─ Classes                    204 个 .cpp（业务逻辑原样，仅 API 适配）
│  ├─ Protobuf                   120 组 protobuf 2.5 生成代码
│  ├─ Resources                  美术/配置/音频，29.8MB
│  ├─ compat                     ★ 新增：2.x 兼容层
│  │  ├─ haizei_compat.h         由 /FI 强制包含，注入每个编译单元
│  │  ├─ cocos-ext.h             接管老代码的 #include "cocos-ext.h"
│  │  ├─ CCScrollViewCompat.*    用 ui::ScrollView 复刻 2.x CCScrollView
│  │  ├─ CCLuaEngine.h           阶段一 Lua 占位
│  │  ├─ CCLuaEngine/tolua* 系列  占位头
│  │  └─ revi/                   原工程的 CCReViScrollViewFacade
│  └─ CMakeLists.txt
├─ platform_bridge
│  ├─ libPlatform                libPlatform.h + 原 win32 实现（lib91/libAG/libPP/libTB）
│  └─ libOS                      原 win32 实现（libOS/inputBox/BulletinBoard）
├─ third_party                   protobuf 2.5 / jsoncpp 0.5.0 / tinyxml 1
├─ proj.win32\main.cpp           3.17 版入口
├─ tools
│  ├─ migrate\migrate.py         ★ 自动迁移工具（幂等，--check 可扫描残留）
│  ├─ migrate\group_errors.py    编译错误聚类分析
│  ├─ migrate\count_patterns.py  2.x 特征统计
│  └─ patch\*.py                 一次性定点补丁（每轮都有记录）
├─ build.bat                     一键构建
└─ docs\MIGRATION.md             本文件
```

### 2. 兼容层的关键设计

| 问题 | 方案 |
|---|---|
| 3.17 仍保留 `CCNode/CCSprite/CCLabelTTF/CCEGLView` 等 2.x 类型名（`deprecated/CCDeprecated.h`） | 直接复用，204 个文件的类型名不用改 |
| `cocos2d::extension::CCBReader` → 3.x 全局 `cocosbuilder::` 且去 `CC` 前缀 | `using namespace ::cocosbuilder` + `typedef NodeLoader CCNodeLoader` |
| `cocos2d::CCScrollView` → `ui::ScrollView`（接口完全不同） | `client/compat/CCScrollViewCompat.*` 复刻 2.x 接口：`create(Size,container)`、`setContentOffset(±animated)`、`min/maxContainerOffset`、`setViewSize`、`setDirection(kCCScrollViewDirection*)`、`setScrollDeaccelRate`、`CCScrollViewDelegate`（含 deaccelerate 回调） |
| `SEL_CCControlHandler` | `typedef Control::Handler SEL_CCControlHandler` |
| `CCMessageBox` / `kCCMenuHandlerPriority` / `kMaxLogLen` / `CCPointZero` / `ccp` | 补齐 |
| `CCTime` / `cc_timeval` / `gettimeofdayCocos2d` | 补齐 |
| Lua（`Gamelua.cpp` 4.6 万行 tolua 胶水） | 阶段一关闭：排除 `Gamelua.cpp`、`pb.cpp`，用 `CCLuaEngine.h` 占位（继承 `ScriptEngineProtocol`），11 个文件里的 2.x 调用通过 cast 兼容 |
| 30 个渠道 SDK | 直接复用原工程 `libPlatform` 的 win32 实现（含 lib91 的本地登录），PC 上可登录 |

### 3. 自动迁移规则（`tools/migrate/migrate.py`，幂等）

302 处替换，主要类别：

| 规则 | 次数 |
|---|---|
| `CCFileUtils::sharedFileUtils()` → `FileUtils::getInstance()` | 87 |
| `CCUserDefault::sharedUserDefault()` → `UserDefault::getInstance()` | 45 |
| `CCDirector::sharedDirector()` → `Director::getInstance()` | 44 |
| `CCTextureCache::sharedTextureCache()` → `Director::getInstance()->getTextureCache()` | 33 |
| `SimpleAudioEngine::sharedEngine()` → `SimpleAudioEngine::getInstance()` | 22 |
| `CCSpriteFrameCache::sharedSpriteFrameCache()` → `SpriteFrameCache::getInstance()` | 17 |
| 动作工厂 `CCMoveTo::actionWithDuration` → `MoveTo::create` 等 | 20+ |
| `CallFuncN::create` + `callfuncN_selector` → `CC_CALLBACK_1` / lambda | 14 |
| `isSingleReference()` → `getReferenceCount() == 1`、`Vector` 接口 | 12 |

### 4. 引擎补丁

1. `UIEditBoxImpl-win32.cpp`：`GWL_WNDPROC/GWL_USERDATA` → `GWLP_*`（Windows SDK 10 已删除旧宏）
2. `Node::draw` 是 `final`：原 `SpriteShader` 的 `draw()` 重写改名为 `drawShader()`（视觉效果后续用 `visit()` 或自定义 Command 恢复）
3. `cocosbuilder/CCNodeLoader.cpp`：ccbi 不带 spriteSheet 时先查图集（全名→去目录名）再退化成图片文件，恢复 2.x 行为；`CCBReader.cpp` 动画帧同样处理
4. `cocos/network/CMakeLists.txt`：不编译 `HttpClient/CCDownloader-curl`（拖 libcurl 依赖）
5. `extensions/CMakeLists.txt`：不编译 assets-manager（同上）

### 5. 定点补丁（无法机械替换的部分）

| 文件 | 处理 |
|---|---|
| `AdventureContinuePage/AdventureInvitePage/LevelUpRewardPage` | 删除 2.x `TouchDispatcher` 调整 CCScrollView 吃触摸的整段代码（3.x 由遮罩层/事件冒泡处理） |
| 9 个页面 | `menu->setScrollViewChild(...)`（2.x CCMenu 扩展）注释掉 |
| `BoardCastLabel` | 2.x 用 `LabelTTF::setTextureRect` 做跑马灯裁剪，3.x 无此接口 → 暂注释，待用 `ClippingNode` 重做 |
| `AsyncSprite` | `addImageAsync(path, this, selector)` → 3.x `(path, lambda, nullptr)` |
| `CCBLuaContainer/CCBScriptContainer` | `_searchChild(CCArray*)` → `Vector<Node*>` + range-for |
| `ContinueLoginPage` | 7 处 `CallFuncN::create` 改 lambda |

---

## 三、本次会话额外解决的关键问题（记录给后来人）

| 问题 | 根因 | 处理 |
|---|---|---|
| 链接期 200+ 引擎符号“未解析” | external 预编译库全是 x86，工程却编 x64 | 改成 `-A Win32` 重编（见第一节） |
| `MessageBox` 找不到标识符 | cocos2d 的 `CCStdC-win32.h` 里 `#undef MessageBox` | 桥接层改用 `::MessageBoxW/A` |
| `getFileData` 链接失败 → 配置表乱码、图集不加载 | 真正的实现（0xEF 0xFE + xor + zlib 解密）在 `client/Platform/GamePlatform.cpp`，但它没被编进工程 | 把 `Platform/*.cpp` 加进源码列表，适配 3.x 的 `ssize_t`；inflate 改用引擎 `ZipUtils` |
| ccbi 里 `mainScene/xxx.png` 找不到帧 | 2.x 的 `SpriteFrameCache` 有“去掉目录前缀再查”的兼容逻辑，3.x 删了；且 ccbi 不带 spriteSheet 时 2.x 先查图集 | 引擎补丁：`CCNodeLoader::parsePropTypeSpriteFrame` 先查图集（全名→去目录名）再退化为图片文件 |
| exe 依赖 `libcurl.dll`（还牵出 x86 版 libssl/libcrypto） | 引擎 `HttpClient/CCDownloader-curl/AssetsManager` + curl.h 的 dllimport 声明 | 引擎里排除这三个模块；`CURL_STATICLIB` + `compat_curl_stub.cpp` 桩实现（下载一律失败=“没有更新”）；做热更时接回 |
| `zconf.h` 找 `unistd.h` | MSVC 下不该触发 | `GamePlatform.cpp` 改用 `ZipUtils`，不再直接 include zlib |
| 入口 `APIENTRY/_tWinMain` 报错 | Win32 入口约定 | `main.cpp` 改为 console 子系统 `main()`（调试期还能看日志） |
| `AppDelegate` 断言 `getOpenGLView()==nullptr` | 2.x 的 CCEGLView 自建，3.x 要手动建 | `GLViewImpl::create("Haizeiwang")` + `setFrameSize(960,640)` + 设计分辨率逻辑保留原样 |

### 当前已知问题（下一步）

1. ~~CCB 回调没接上~~（已修，见第五节）
2. ~~大量帧找不到~~（已修，见第五节）
3. ~~"检查更新失败"卡死~~（已修，见第五节）

## 五、第二轮：绕过更新检查 + 修按钮回调 + 散图兼容（当前状态）

流程已跑通到：启动 → 加载场景（图集/音乐正常）→ **91 登录对话框（可输入账号密码）**。
丢帧日志从 60+ 条降到 1 条（引擎内部的 `cc_2x2_white_image`，无碍）。

| 问题 | 处理 |
|---|---|
| “检查更新失败”卡死 | `Resources` 里有 `version_win32.cfg`（指向线上更新地址），联网下载必失败 → `CS_FAILED`。在 `SeverConsts::start()` 加本地模式开关：`Resources/haizei_local_mode.flag` 存在即跳过联网检查，走 `_loadLocalSevers()` 读本地区服表（默认 127.0.0.1:25524，即 `server/xml/config.xml` 的端口；可用 `Resources/localSevers.json` 覆盖）。想走线上热更删掉 flag 文件即可 |
| 散图找不到（loadingScene/person/members 下大量裸 png 不在图集里） | 引擎补丁 `CCSpriteFrameCache::getSpriteFrameByName`：找不到帧时 ①去掉目录前缀再查 ②按文件名整张图建帧插入缓存（2.x 的“散图当帧”行为） |
| 按钮点击无效（Skipping selector 'onXXX'） | ① `CCBContainer` 创建 CCBReader 时漏传 selector resolver（3.x 构造参数顺序变了）→ 传 `(library, this, this)`；② 引擎补丁 `CCBSelectorResolver::onResolveCCBCCMenuItemSelectorWithSender` + `CCNodeLoader` 的回退调用（复刻老工程私改的 2.x 行为，菜单统一路由到 `CCBContainer::_menuItemClicked` → `onMenuItemAction`） |

## 七、服务端联调（已跑通主城）

**端到端已验证**：客户端自动登录 → 点"进入游戏" → 连 127.0.0.1:25524 →
登录包 → 服务器回全量玩家数据 → 加载 MainFrame/MainScene → **主城界面完整渲染**
（玩家栏/队员头像/冒险·远航·决斗·船员·装备·奥义·修行菜单，30FPS）。

服务端环境（本机已具备）：
| 组件 | 位置 | 说明 |
|---|---|---|
| JDK 8 | `E:\Softwares\jdk8u512-b09` | `java -Dfile.encoding=UTF-8 -jar DZM.jar`（在 Code_Server\server 下执行） |
| MySQL 5.6 | `E:\Softwares\mysql-5.6.51-winx64` | `mysqld --defaults-file=...\my.ini`；root/root；库 `dzm`（已建表，源 `dzm.sql`） |
| 服务端配置 | `Code_Server\server\xml\config.xml` | 监听 0.0.0.0:25524；`<Platform>lo</Platform>` → hibernate_lo_01.cfg.xml（jdbc:mysql://127.0.0.1:3306/dzm, root/root） |

客户端侧注意：
- `localSevers.json` / 内置本地服表指向 127.0.0.1:25524，与 config.xml 一致
- 自动登录账号：`C:\Users\24219\AppData\Local\Haizeiwang\localAccount.txt`
- MySQL 没起时服务端照样监听 25524，但登录无回包 → 客户端 10s 超时自动重连
（这就是"send packet 后 ReceiveTimeout"的原因，起 MySQL 即好）

## 八、第四轮：竖屏适配 + 子界面深挖（当前状态）

- **竖屏适配**：`AppDelegate` 窗口从 960x640 改为 480x720（竖屏比例），
  主城画面铺满窗口，无黑边
- **子界面验证**：主城点"船员" → `onJianghuPage` → `CareerPage.ccbi` 加载 →
  章节标签/关卡列表/星级完整渲染，协议收发正常

### 崩溃排查工具（重要基建）

`proj.win32/main.cpp` 注册了 `SetUnhandledExceptionFilter`：任何崩溃都会把
**函数名+偏移的调用栈**写到 `build/Debug/crash_stack.txt`（dbghelp + Debug PDB）。
以后再崩直接看这个文件，不用查 map 文件猜。

### 本轮修复的三个崩溃/问题

| 问题 | 根因 | 处理 |
|---|---|---|
| 点"船员"崩溃 1：`CareerPage::Enter` 里 `mNavContent` 空指针 | 引擎默认 `cocosbuilder::ScrollViewLoader` 创建的是 3.x 的 `extension::ScrollView`，业务代码 `dynamic_cast<CCScrollView*>`（compat 类）失败返回 null | 新增 `compat/CCScrollViewLoader`（复刻 2.x 版，创建 compat CCScrollView、处理 container/direction/clipsToBounds/bounces/scale 属性）；`CCBContainer::loadCcbiFile` 里先 `unregisterNodeLoader("CCScrollView")` 再注册（multimap 不先删会插到后面） |
| 崩溃 2：`~CCBAnimationManager` 析构时 `stopAllActions` 悬空指针 | `_rootNode` 是裸指针，页面换容器（`CCScrollView::setContainer`）时节点先于 manager 销毁 | 析构里去掉该调用（2.x 原版就没有；节点销毁时自身会清 action） |
| 崩溃 3：`getFrameNormalSpirte` 里 `CCSprite::create` 返回 null | 配置里图片路径（如 `mainScene/u_icobg02.png`）在磁盘上不存在，图在 `mainScene.plist` 图集里 | 引擎补丁 `Sprite::initWithFile`：文件加载失败时按帧名查图集（全名→去目录名），查到按帧初始化 |

### 遗留小问题（不挡进度）
- 18 条 `ERROR: SpriteFrame nullptr`：ccbi 空精灵，2.x 同样行为
- 部分文案显示 "Sample Text"/"@Name"：对应语言表 key 缺失或配置未填，属数据问题

## 六、第三轮：登录后丢图/崩溃修复（当前状态）

**已验证**：启动 → 加载场景 → 自动登录 → 进入游戏按钮 → 选服列表 → 点击进入游戏
→ `connect start!` → `send packet! opcode:1`（登录包正确序列化）→ 等待回包 →
超时 `ReceiveTimeout` → 自动重连。全程不崩，只差服务端。

本轮修复（都在引擎 cocosbuilder 里）：

| 问题 | 根因 | 处理 |
|---|---|---|
| 加载 Battle.ccbi 后**进程退出**（偶发） | `CCBReader::readKeyframe` 动画关键帧在 spriteSheet 为空时直接 `addImage`，找不到文件返回 null 后继续解引用 → 崩溃 | 先查图集（全名→去目录名）→ 再按散图文件加载 → 都失败打日志，不再解引用空指针 |
| 发登录包时空指针崩溃退出 | 包工厂靠静态初始化器注册（`GamePackets.cpp` 的 `AUTO_REGISITER_PACKET_FACTORY`），编在静态库里时链接器把整个 .obj 丢弃 → 工厂全没注册 | `GamePackets.cpp` 尾部加 `haizei_force_link_game_packets()` 空函数，`main()` 调用它强制链接 |
| 登录框每次都要手输账号密码 | lib91 本地版无记忆 | `lib91::login()` 支持自动登录（见上） |

遗留（无碍）：
- 18 条 `ERROR: SpriteFrame nullptr`：ccbi 里本来就没设图的空精灵，2.x 同样行为
- 控制台 `libpng warning: iCCP`：美术 png 的色彩配置文件警告，无碍

---

## 四、后续阶段（按优先级）

### 阶段一收尾（0.5~1 天）
1. 清掉上面 56 个错误 → 链接 → 启动
2. `AppDelegate` 改 3.x：`GLViewImpl::create("Haizeiwang")` + 设计分辨率策略
3. 用本地服务端（`server/Code_Server`）验证登录 → 主城

### 阶段二：Lua 回归 + 启动流程（3~5 天）
- `BUILD_LUA_LIBS=ON`，接回 `Gamelua.cpp` / `pb.cpp`，`CCLuaEngine::defaultEngine()` → 3.17 `LuaEngine`
- 加密 `.el` 脚本的解密加载（对照 `Gamelua.cpp` 的 tolua 注册表）

### 阶段三：分辨率与 PC 适配（2~3 周）
- 设计分辨率 320×480 → 750×1334（`FIXED_WIDTH` + 安全区）
- 1426 个 `.ccbi` 的绝对坐标分批校正（先写 `ccbi2json.py` 导出台账）
- 鼠标滚轮映射 `CCScrollView`、键盘快捷键、窗口缩放

### 阶段四：Android / iOS（2~3 周）
- Android：Gradle + CMake，`abiFilters arm64-v8a, armeabi-v7a`，targetSdk 34，AAB
- iOS：Xcode 15 工程，arm64
- 平台层收敛为 `IPlatform`（登录/支付/分享/推送/统计），替换 30 个渠道

### 阶段五：资源与数据（3~4 周）
- 1112 张 PNG 用 Real-ESRGAN 2x 高清化 + 重新打图集
- 数据表解密（`Classes/AES.cpp` 内有 key/iv）→ 明文 CSV/JSON + 新导出工具

---

## 五、常用命令

```bat
build.bat                 :: Debug 构建
build.bat Release         :: Release 构建
build.bat Debug clean     :: 清理重配

:: 重新跑自动迁移（幂等）
E:\Softwares\miniconda3\python.exe tools\migrate\migrate.py

:: 扫描仍残留的 2.x 特征
E:\Softwares\miniconda3\python.exe tools\migrate\migrate.py --check

:: 编译错误聚类
E:\Softwares\miniconda3\python.exe tools\migrate\group_errors.py
```

> 新增源文件（如 `LoginPage.cpp`）后必须重新 configure CMake（`file(GLOB ...)` 才会收集到），
> 且 `build.bat` 的生成器平台必须是 `-A Win32`（缓存实际为 Win32，写 x64 会报
> `generator platform does not match`）。构建前 `unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY`。

---

## 九、账号密码登录 + 老项目 GM 系统打通

需求：**取消 `localAccount.txt` 自动登录，改为游戏内账号密码登录，并与老项目 GM 体系打通**。
确认过的三个方向：GM 走 **PHP 运营后台**、登录界面是 **游戏内 Cocos 页**、权限由 **服务端白名单** 判定。

### 9.1 分层与数据流

```
游戏内 LoginPage (Cocos EditBox)
   └─ lib91_setLoginCredentials(account, password)
        ├─ s_loginSubmitted()  → 密码错误重试时 forceSentPacket()
        └─ _boardcastLoginResult(true) → LoadingFrame::onLogin → showEnter()
             └─ 点「进入游戏」→ OPLogin(opcode 1)
                  └─ LoginHandler.java 校验 dzm.mapping.passwd
                       ├─ 失败 status=6 → 客户端 LoginPage 重新显示「密码错误，请重新输入」
                       └─ 成功 status=1 + unknown field 4 (isGM)
                            └─ LoadingFrame 写入 BlackBoard::isGM
                                 └─ LeaveMsgPage 的 /add /to 等 GM 指令按此放行
```

PHP 后台与 Java 服务端**共用两份数据**：`dzm.mapping`（账号/密码）与
`xml/TesterList.xml`（GM 白名单）。后台改白名单 → 服务端 `GmWhitelist`（按 mtime 每秒最多
热加载一次）→ 下次登录回包的 field 4 立即变化。

### 9.2 关键文件

| 文件 | 作用 |
| --- | --- |
| `platform_bridge/libPlatform/include/lib91.h` | 新增 UI provider / credentials 接口 |
| `platform_bridge/libPlatform/win32/lib91.cpp` | 删除 `localAccount.txt` 与 Win32 原生登录框循环 |
| `client/Classes/LoginPage.{h,cpp}` | 游戏内登录页（EditBox / 记住密码 / 切换账号 / 错误提示） |
| `client/Classes/LoadingFrame.cpp` | 注册 provider、延迟显示登录页、读 field 4、status=6 重登 |
| `client/Classes/BlackBoard.h` | `bool isGM` |
| `client/Classes/LeaveMsgPage.cpp` | 取消 Debug 无条件放行，改判 `BlackBoard::isGM` |
| `tools/gm_admin/` | PHP 运营/GM 后台（`config.php` `lib.php` `api.php` `index.php`） |
| `tools/gm_admin/server_patch/` | Java 补丁源（`GmWhitelist` / `LoginHandler` / `PacketHandler`） |
| `tools/gm_admin/apply_server_patch.py` | 编译并把 4 个 class 注入 `DZM.jar`（自动备份 `.haizei_bak`） |

### 9.3 协议要点（踩过的坑）

- 包头 `uint16 0x4346` + `uint32 opcode` + `uint32 length` + body；body 每字节 XOR `0xA5`。
- **请求** length = body 长度；**响应** length = `10 + bodyLen`。
- `OPLoginRet.isGM` 不改用 protobuf 2.5 生成代码，而是用 `UnknownFieldSet` 追加
  **unknown field 4 (varint)**；客户端用 `logret->unknown_fields()` 读。
- `BackStage*` 系列（182/184）handler 内部又 XOR 一次，与 Decoder/Encoder 叠加后**抵消**，
  因此这类包实际按**明文**收发（`backstage_call(..., $legacy = true)`）。普通游戏包只做单层 XOR。
- GM 指令 `OPCODE_UPDATE_USERINFO_BY_GM_C = 174` 在 `PacketHandler` 中除
  `DZM.canUseGmTools == 1` 外，追加 `GmWhitelist.isGm(session.puid)` 二次校验。

### 9.4 启动方式

```powershell
# 1) MySQL(dzm) + Java 服务端（patched DZM.jar，监听 127.0.0.1:25524）
tools\start_local_env.ps1
# 2) PHP GM 后台（http://127.0.0.1:8080）
tools\gm_admin\start_gm_admin.ps1
# 3) 客户端
build\Debug\Haizeiwang.exe
```

首次进后台用**游戏账号密码**登录；白名单里没有任何有效游戏账号时，首个登录者自动成为 GM
（bootstrap，避免死锁）。默认测试账号 `heigui / 123456`。

### 9.5 端到端实测结论（本轮）

| 验证项 | 证据 | 结果 |
| --- | --- | --- |
| 登录页渲染 / 中文 | `_tools/crew_wrongpwd_crop.png` | 通过 |
| 记住密码自动提交 | `[lib91] credentials submitted for account: heigui` | 通过 |
| 点击进入游戏 → 发 OPLogin | `send packet! opcode:1 message:puid: "heigui" ...` | 通过 |
| 服务端 GM 标记下发 | `[haizei] server GM flag = 1` | 通过 |
| 密码错误重登 | `status: 6` → 再次 `[LoginPage] shown` + 橙色「密码错误，请重新输入」 | 通过 |
| 切换账号 | 点击后 `UserDefault` 三个 `haizei_login_*` 键清空、`[ ] 记住密码`、提示「已清空账号，请输入新的账号密码」 | 通过 |
| 后台开关 GM → 服务端生效 | `setgm on=0` → `field4=0`；恢复 → `field4=1` | 通过 |
| BackStage 玩家查询 | `opcode:994` 正常返回 | 通过 |

**修复的后台缺陷**：`require_admin()` 每次请求重校验白名单，原本「撤销自己的 GM」会立刻让
当前会话失效且无法自行恢复。已在 `api.php?action=setgm` 禁止自撤，返回
「不能撤销自己的 GM 权限，请由其他 GM 账号操作」。

---

## 十、船员觉醒 / 船员突破功能核查

### 10.1 船员突破：**存在且链路完整**

- 文案：`chinese.lang` 的 `@MemBreakThrough`=「船员突破」、`@MemBTNote`、
  `@SoulNotEnough`、`@DiscipleAlreadyUpgradeMaxLevel`。
- 页面：`DiscipleUpgradePage`（`REGISTER_PAGE`），加载 `MemberBreakThrough.ccbi`，
  按钮 `onBreakThrough` / `onQuit`。115 页巡检中 `DiscipleUpgradePage ok`。
- 协议：`OPCODE_UPGRADE_DISCIPLE_C = 17` → 服务端 `UpgradeDiscipleHandler` →
  `OPCODE_UPGRADE_DISCIPLERET_S = 18` → 客户端 `OPUpgradeDiscipleHandle`
  （`PackageLogic.cpp:1421`）更新 `upgradelevel` / `potentiality` / `soulcount`
  并派发 `MSG_MAINFRAME_REFRESH` 刷新页面。
- 上限一致：客户端 `MAX_DISCIPLE_UPGRADE_LEVEL = 10`，服务端 `>= 10` 拒绝。
- 服务端按品质计算消耗与潜力增量（quality 1~4 → 45/30/15/5 起始影子数、75/60/45/30 潜力）。

**实跑证据**（`tools/verify_crew_breakthrough.ps1`，真实点击进入）：
```
[debug] cmd -> goto:DiscipleUpgradePage
load ccbi file: MemberBreakThrough.ccbi
CCB:Button pressed! ccb:MemberBreakThrough.ccbi, func:onBreakThrough, tag:0
send packet! opcode:17 message:id: 0
received packet! opcode:999 message: errorid: 18 errmsg: "disciple not exist"
load ccbi file: MessageBox.ccbi
```
未选船员时发 `id:0`，服务端按 `disciple not exist` 正确拒绝，客户端弹提示、取消等待，
全程无崩溃。页面截图 `_tools/crew_03_page_crop.png` 显示标题、潜力、层次、影子数量、
「退出 / 突破」按钮齐全。

> 说明：成功突破（真正 +1 层次）需要账号持有对应影子并走「船员 → 影子 → 选择 → 突破」
> 父流程；本轮验证的是入口、渲染、按钮、协议收发、服务端校验与客户端回包处理全链路。

### 10.2 船员觉醒：**本工程不存在该模块**

在客户端源码/资源/语言文件、服务端 Java/XML/proto、PHP GM 后台、老项目源码中全量检索
`觉醒 / awaken / awake / juexing`，**零命中**（唯一 `awake` 命中是 Box2D 的 `b2Body::SetAwake`，
与玩法无关）。服务端 `Disciple` 实体只有 `upgradelevel`（突破等级）、`potentiality`、
`trainstatus` 等字段，没有觉醒等级/状态。

该版本已有的船员成长系统是：**突破、培养、传承、修行、装备、奥义**，没有独立「觉醒」。
另有两个**未被任何 `loadCcbiFile` 引用**的孤立资源 `SoulBreak.ccbi` / `SoulBreakC.ccbi`，
内部是 `SoulInfo` 弹窗 + `onBreak` 按钮 + 技能信息（`@GivenSkill`、`mSkillPic`），
属于旧版影子/奥义弹窗遗留，**不是觉醒功能，也未接入**。

### 10.3 顺带发现的非阻断问题

- `[CCBVar] MISS 'mEnterButton' in LoadingFrame.ccbi (have 15 vars)`：ccbi 变量名不匹配，
  但「进入游戏」按钮本身可见可点，实测 `func:onEnter` 正常触发。
- `DiscipleUpgradePage::refreshPage` 用 `dynamic_cast<CCLabelTTF*>` 取 `mPlayerName`，
  3.x 下类型不匹配导致判空跳过，玩家名显示 ccbi 占位 `NameName`（同类问题在
  `PlayerInfPage` 已改为 `CCLabelBMFont`）。
- 若干 `ERROR: SpriteFrame nullptr` / 缺失散图（`mainScene/u_icobg02.png` 等），
  属第八节已记录的既有资源缺口，不阻断。

## 十一、第五轮：UI 专项修复（ScrollView 语义 + shader + 字体类型）

用户实测报出 5 项 UI 问题，逐一修复，全部根因集中在 2.x→3.x 迁移差异：

### 11.1 纵向滑动窗口系统性缺陷（问题 1/2/4/5 的共同根因）

`CCScrollViewCompat` 对 2.x `CCScrollView` 的语义复刻存在 4 处错误，导致**所有**
使用纵向滚动的页面（冒险活动、阵容、背包、手册、好友、设置等）内容偏移错位、
顶部起始位置不对、显示不全、不能拖动：

1. **`contentOffset` 取反错误**：2.x 的 `contentOffset` 就是 container 的 position
   **原值**（不取反）；compat 版在 `applyOffset` 里 `-offset` 导致内容位置镜像。
2. **`setContainer` 锚点错误**：2.x 会把 container 锚点强制设为 (0,0) 再挂载；
   compat 版未设置，锚点 (0.5,0.5) 时偏移计算全错。
3. **`setContentSize` 语义错误**：2.x 设置的是**内容大小**（决定可滚动范围），
   compat 版误设为视口大小，导致滚动边界退化为 0。
4. **scissor 裁剪 + Menu 协作缺失**：2.x 依赖 `m_bScrollViewChild`（menu 不吞触摸、
   限制在视口内命中）配合 scissor 实现裁剪内拖动；未移植则滚动区里的菜单按钮
   要么吞掉拖动手势（不能滑），要么触摸越界（隔壁船员装备区被误触/遮挡）。

修复（`client/compat/CCScrollViewCompat.h/.cpp` 全面重写）：
- `setContainer` 设锚点 (0,0)、挂进 innerContainer；
- `applyOffset` 用原值 `setPosition`，`getContentOffset` 返回原值；
- `min/maxContainerOffset` 复刻 2.x 原版边界计算，`setContentSize` 设内容大小；
- 新增 `_setChildMenu`（桥接 `CCMenu::setScrollViewChild(true)`）、
  `forceRecaculateChildren`、`setScrollDeaccelRate`、
  `scrollViewDidDeaccelerateStop` 回调。

配套修复：
- `engine/.../CCMenu.h/.cpp`：移植 2.x 协作——新增 `_scrollViewChild/_touchArea/
  _touchStartWorldPos/_menuTouchListener` 成员；`onTouchBegan` 在 scrollViewChild
  模式下限制视口命中且不吞触摸；`onTouchEnded` 位移 <20px 才激活按钮（滑动不误触）。
- 11 个页面恢复 `menu->setScrollViewChild(true)`（Adventure/Career/FightEnd/Friends/
  Handbook/Member/Main/PackPreview/Settings/SkillBookLoot/TeamBuffUpgrade，共 23 处）。
- `client/compat/revi/CCReViScrollViewFacade.cpp`：长列表回收复用依赖
  `getContainer()->getPosition()`，compat 下恒为 (0,0)，改用
  `getContentOffset/setContentOffset`（4 处）——修复「更换船员」列表
  回收后条目缺失/错位。
- 修正 `CareerPage.cpp` / `SettingsPage.cpp` 两处 `dynamic_cast<CCMenu*>`
  误作用到 `getParent()` 结果的写法。

### 11.2 首页阵容问题（问题 1 专项）

- 点击上阵人物跳阵容页：`MainPage` 已有 `func:onCellTouch` 路由，随 compat 修复生效。
- 未上阵空位加号：`MainPage.cpp` 为「已解锁未上阵」空位叠加
  `CCLabelBMFont::create("+", "Lang/heiOutline24.fnt")`，点击跳新增上阵流程。

### 11.3 远航战斗棕方块 + 结算无奖励（问题 3）

- **根因**：3.x `GLProgram` 在所有 shader 源码前注入 `COCOS2D_SHADER_UNIFORMS`
  （含 `uniform sampler2D CC_Texture0;`），而 `client/Resources/fightcard.sha`
  自声明了同一 uniform → 编译重定义失败 → 战斗层整体回退为棕色方块。
  **修复**：删除 `.sha` 中自声明的 `CC_Texture0`（保留 varying）。
- 结算页玩家名/敌人名：`FightPage.cpp`、`FightEndRankPage.cpp`、
  `WorldBossFightEnd.cpp`、`WorldBossJoinBattle.cpp` 中 ccbi 创建的
  `CCLabelTTF` 在 3.x 实际是 `cocos2d::Label`，`dynamic_cast<CCLabelTTF*>`
  恒失败 → 统一改 `CCLabelBMFont`（mPlayerName/mEnemyName/nameBM）。
- `battle.plist` 部分 frame 名带 `battle/` 前缀问题由引擎侧查找补丁兼容。

### 11.4 实跑验证结果（已收尾）

经用户确认后重启 MySQL 3306 / Java 25524 / PHP 8080，Debug 重新构建 0 error，完成两轮实跑：

- **无上下文巡检**：`tools/verify_ui_final.ps1` — 登录→主城→11 页 `goto:` + 逐页纵向拖动，
  25 张截图，11/11 进程存活、0 断言、0 连接错误。证据 `_tools/final_*.png`。
- **真实点击路径**：`tools/verify_clickpath.ps1`、`tools/verify_fight_real.ps1` — 从主城按设计坐标
  真实点击船员 / 冒险 / 远航 / 装备 / 设置，日志分别命中 `MembersContent.ccbi`、`opcode:110`、
  `CareerChapterButton.ccbi`、`EquipmentContentStoneItem.ccbi`、`func:onSettings`，0 崩溃。
  证据 `_tools/cp_*_crop.png`、`_tools/cp2_*_crop.png`。

| 用户报告 | 真实路径复核结论 |
| --- | --- |
| 1 首页点人物跳阵容 / 空位加号 / 阵容显示不全 | 主城空位「+」已显示；真实船员页 4 条条目完整、顶栏名字「冥王」正确 → **通过** |
| 2 阵容不能切换船员 / 更换列表缺人 / 装备区被遮挡 | 员工条目齐全、传承/培养按钮可见；装备页可正常进入 → **通过** |
| 3 远航战斗无立绘 / 结算无奖励 | 结算页「YOU WIN」+ 威 23 / 金币 560 / 船员经验条完整 → **结算通过**；战斗卡片立绘仍为棕色占位 → **部分未结（12.3）** |
| 4 冒险活动图片显示不全 / 不能滑动 | 活动页图片/文案完整，章节页关卡列表与立绘完整 → **通过** |
| 5 纵向滑动窗口顶部起始位置错 | 手册页网格从顶部正确起始；图鉴页拖动前后画面确有变化 → **通过** |

> **方法论（重要）**：`goto:` 直开是**无上下文**的，会产生 `NameName` 占位顶栏、空木质面板、
> 演示战斗数据和空结算页——这些都是假象，不是 UI 回归。功能验收必须以主城真实点击路径为准。
> 之前 115 页审计只验证「不崩溃」，不等于「功能正常」。

## 十二、本轮收尾：实跑 + 资源补齐 + 类型契约

### 12.1 修复清单

| # | 问题 | 修复 | 验证 |
| --- | --- | --- | --- |
| 1 | 28 处 `dynamic_cast<CCLabelTTF*>(ccbVar)` 恒为 null，玩家名显示 `NameName` 占位 | `tools/patch/patch_ccb_labelttf.py`（幂等）统一改 `CCLabelBMFont*`；3.x 的 `LabelTTFLoader` 创建的其实是 `cocos2d::Label`，兼容层已把 `CCLabelBMFont` typedef 到 `Label` | 突破页/主城顶栏显示真实名「冥王」 |
| 2 | `start_gm_admin.ps1` 启动 PHP 后台报 `Item has already been added: http_proxy` | 启动前清理 8 个大小写代理变量（与 `start_local_env.ps1` 同款处理） | 8080 正常 Listen |
| 3 | 构建报 `MSB6001 CL.exe 命令行开关无效`（同一代理冲突） | 构建前清代理变量；改用直接调用 `cmake --build`，不再经 `cmd.exe` | `_tools/build_final.log` BUILD_EXIT=0 |
| 4 | 调试通道连续写 `back` 不生效（`lastCmd` 去重） | 验证脚本每次先写唯一 `boot:N` 哨兵刷新 `lastCmd`，再写 `back` | 7 个探测点均正确回主城 |
| 5 | 运行期 23 个 `No file found at *.png`（含文档记录多年的 3 张源头缺图） | `tools/patch/export_missing_frames.ps1`：从日志自动收集缺失名，在 56 个 `Imagesetfile/*.plist` 中按同名 frame 从图集裁出，导出到 `client/Resources` 与 `build/Debug/Resources` | 18 张导出 + 5 张跳过（已存在），`.png` 缺失归零 |

> 注：`export_missing_frames.ps1` 按 frame 名全局索引，同名 frame 取扫描顺序最后一个图集；
> `mainScene/u_icoqy*.png` 等小图标可能来自 hxf/nd/yc 等多个图集，视觉上可接受。

### 12.2 验证工具链（本轮新增）

- `tools/verify_ui_final.ps1`：一体化启三服务 → 登录 → 11 页 goto + 拖动 → 截图 + 日志取证。
- `tools/verify_clickpath.ps1`：主城真实点击探测（含坐标换算与页面命中日志）。
- `tools/verify_fight_real.ps1`：远航→章节→关卡→战斗→结算真实链路 + 图鉴拖动。
- `_tools/crop_main.ps1`、`_tools/crop_clickpath.ps1`：按 GLFW 虚拟 rect × DPI 1.5 裁剪客户区，
  用于精确量取设计坐标（换算：`dx=(cropX-11)/1.5`、`dy=480-cropY/1.5`）。
- 关键约束：**后台服务与 GUI 点击必须在同一次 `.ps1` 执行内完成**，否则 `Start-Process`
  子进程随工具会话结束被回收；`Add-Type` 必须写在脚本文件内，PowerShell 内联会被安全策略拦截。

### 12.3 仍存在的残留（非阻断，下一轮专项）

| 现象 | 已排除 / 已定位 | 建议 |
| --- | --- | --- |
| 战斗卡片为棕色占位、无船员/对手立绘 | 已排除资源缺失（`.png` 缺失归零、275 张 `person/poster_char_*.png` 齐全）、已排除 shader 编译失败（日志无 `CC_Texture0` 报错）、已排除子 ccbi 路径问题（`Battle.ccbi` 内嵌 `BattleHead.ccb` 由 `parsePropTypeCCBFile` 自动补 `.ccbi` 正常加载） | 专项排查 `FightCardSprite` / `SpriteShader` 的 3.x 渲染路径：`initWithTexture` 重写签名是否仍生效、`drawShader()` 是否被 3.x QuadCommand 取代、以及子 CCBFile 的 `mPoster/mOwn1` 变量是否并入父容器 |
| 战斗页若干黑色小方块 | 34 条 `ERROR: SpriteFrame nullptr`，来自 ccbi 中 `spriteFile` 为空串的 `displayFrame` 属性（非资源缺失） | 在 `CCSpriteLoader::onHandlePropTypeSpriteFrame` 的空帧分支隐藏精灵，或在 `CCNodeLoader::parsePropTypeSpriteFrame` 返回 1×1 透明帧 |
| `s_slsa` / `s_slga` 缺 ccbi、`/` 开头的 `__halfCircleImage` / `__bodyImage` 占位名 | 文档第八节已记录，运行期已被空节点保护接住 | 保持观察 |
| 成功突破路径（需影子数据）、opcode 174 GM 白名单二次鉴权 | 本轮未单独实测 | 需构造影子数据后走 GM 后台复核 |

## 十三、老 / 新工程功能逐项一致性核对（新增）

完整报告见 **`docs/FUNCTION_PARITY.md`**（含 115 页逐页对照表）。本节只留索引与结论。

**核对口径**：以「页面注册 / 按钮交互分支 / 页面跳转 / ccbi 资源 / 协议 opcode / 成员函数 /
按钮回调函数体」为功能项，对老工程 `client/Game/Classes`(416 文件) 与新工程
`client/Classes`(418 文件) 做双向集合比对 + 全量 diff(3712 行) + 函数体级比对 + 运行抽检。

| 维度 | 老 | 新 | 老有新无 |
| --- | ---: | ---: | ---: |
| 页面注册 | 115 | 115 | 0 |
| 按钮 / 交互分支 | 250 | 250 | 0 |
| 页面跳转目标 | 8 | 8 | 0 |
| ccbi 资源引用 | 202 | 202 | 0 |
| 资源文件 | 1772 | 1798 | 0（新增 26 = 23 张补齐散图 + 3 个调试配置） |
| Protobuf 协议文件 | 240 | 240 | 0（内容全一致） |

- 按钮回调函数体 **193 个中 190 个逐字一致**，另 3 个是 GM 白名单改造、API 改名、Lua 死代码。
- `PackageLogic.cpp` 4234 行两端 **MD5 完全相同** —— 发包 / 回包逻辑零改动。
- 全量 diff 的 318 个 hunk：232 纯 API 改名、74 结构改动、12 行为改写（逐项见报告 §4）。
- **115 / 115 页功能点无缺失，115 / 115 页运行巡检通过。**

**本轮据此补回 5 类真实行为丢失**（幂等脚本 `tools/patch/patch_parity_fixes.py`）：

1. `AdventureContinuePage` / `AdventureInvitePage` / `LevelUpRewardPage` 三段被删的
   `CCTargetedTouchHandler::setSwallowsTouches(false)` → 3.x `setSwallowTouches(false)`；
2. `LevelUpRewardPage` 的 `setBounceable(false)` 回弹设置；
3. `InstructionManager` 4 处被写成 `(void)0;` 的纹理回收 → `Director::purgeCachedData()`
   （已核对 2.x/3.x 实现语义一致）；
4. `FightPage` 重复回收调用的等价说明；
5. `LoadingFrame` 密码错误提示改回语言表 `@LoadingFrameSeversConnectionPasswordWrong`。

构建 `BUILD_EXIT=0`（`_tools/build_parity.log`），实跑主链路 0 断言 / 0 连接错误。

**新增的本轮教训（验证工具缺陷，非游戏缺陷）**：`verify_*.ps1` 的 `ToScreen()` 把
`GetWindowRect()` 返回的坐标与设计坐标直接相加，未统一处理 DPI 1.5，且不同 PowerShell
进程 DPI awareness 不一致，点击落点可能偏移；另 `goto:` / `push:` 对**未 `REGISTER_PAGE`
的子面板**（3 个奖励弹窗）无效（`getPage` 返回空并静默 return）。因此本轮运行证据只采用
「进程存活 + 0 断言 + 日志 + 视觉截图」，逐按钮点击命中不作为一致性判据。
后续做自动化请用 `MoveWindow` 固定窗口 + 全屏物理像素坐标 + 每步日志闭环判据。

---

## 十四、老 / 新客户端逐按钮 A/B 实跑对照（后续轮次）

用户反馈「运行两个版本还是很多地方操作不对劲」，按用户给的两个可执行文件
（`启动游戏.bat` / `build\Debug\Haizeiwang.exe`）分别真机运行，用 DPI 正确的新驱动
`tools/ab_lib.ps1` 对主城 20 个按钮跑**同一组归一化坐标**，逐项留图对比。
完整报告见 **`docs/AB_CLICK_PARITY.md`**。

**结论：20 项中 18 项已逐项对齐（`diff` 与老版吻合到 ±0.7），2 项残留。**

修掉的 3 个根因：

1. `AppDelegate.cpp` 的 `setFrameSize(480,720)` 与老版 `main.cpp` 的 `(480,640)` 不一致，
   导致设计区 320×480 vs 老版 360×480，横向少 40 个设计像素 → 改回 `(480,640)`；
2. Debug `setDisplayStats(true)` 的 FPS 统计条盖住主城底部功能栏（老版 Release 无）→ 关闭；
3. 移植时 `CCScrollViewCompat::_setChildMenu` 给 ScrollView 内 CCMenu 塞了一个与
   3.x `touch->getLocation()` 不同坐标系的 `_touchArea`，`containsPoint` 恒 false，
   把底部 5 个导航按钮全部锁死 → `CCMenu::onTouchBegan` 移除该阻断，
   对齐老版 2.x「业务代码从不调用 setTouchArea」的实际语义；
   同时给 `CCScrollViewCompat::init()` 补 `setSwallowTouches(false)` 恢复协同分发。

另有语义对齐：`MainPage::_refreshBattle` 中 `setContainer()` 之后多余的
`members->setContentSize(size)` 已注释（3.x 会把它当视口重排）。

**残留 2 项**：主城阵容头像 1 / 空位加号点击无响应（老版分别打开船员详情与解锁提示）。
68 点密集扫描确认不是坐标问题，定位到 `framedButton.ccbi` 动态创建的
`CCMenuItemImage` 在 `ui::ScrollView` innerContainer 变换下 `getItemForTouch` 不命中；
需改引擎命中链，未硬改。替代路径（船员大按钮 → 列表 → 详情）两端一致。
详见 `AB_CLICK_PARITY.md` §6。

> 口径提醒：第十三节是静态功能入口对照，第十四节是同坐标真机点击对照，
> 二者粒度不同、互不替代；静态对照看不出设计分辨率与触摸分发这类运行期差异。
