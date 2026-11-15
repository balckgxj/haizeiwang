# 老 / 新客户端逐按钮 A/B 实跑对照

> 目标：按用户给的两个可执行文件，**分别真机运行**，用完全相同的归一化坐标逐个点击主城功能按钮，
> 核对「同一个点击在两端是否得到同一个结果」，并修复不一致项。
>
> - 老：`E:\BaiduNetdiskDownload\(SY-096)草M船Z\启动游戏.bat`
>   （实际客户端 `src\src\client\Release.win32\Game.exe`，工作目录 `Debug_Alpha\Resources`）
> - 新：`E:\PCGame\Haizeiwang\build\Debug\Haizeiwang.exe`
>
> 结论：**20 项中 18 项已与老版逐项对齐，2 项（阵容头像点击）仍残留，定位见 §6。**

---

## 1. 方法与证据边界

上一轮 `docs/FUNCTION_PARITY.md` 的实跑结论只采用「进程存活 + 0 断言」，因为旧脚本 `ToScreen()`
混用了 DPI 虚拟/物理坐标。本轮先修工具，再谈功能：

`tools/ab_lib.ps1` 统一为物理像素坐标系：

1. 调用 `SetProcessDPIAware()`，让脚本进程与截图坐标系一致；
2. `GetClientRect` + `ClientToScreen` 精确取客户区屏幕矩形（不含标题栏）；
3. 点击 / 拖动 / 截图全部使用客户区**归一化坐标** `u,v ∈ [0,1]`，两端窗口尺寸不同也能对齐；
4. 每项点击后按「首页」回主城，并留一张 `*_pre.png`；用 48×64 缩略图平均绝对像素差
   （`diff`）量化画面变化，`back_diff` 用来确认是否真的回到了主城（本轮两端全部为 0）。

`tools/ab_run_sequence.ps1` 定义 20 个按钮的**同一组坐标**，两端各跑一遍：
`tools/ab_new_full.ps1` 把「启动新版 → 进入游戏 → 主城 → 序列」放在同一次会话里
（服务 / 客户端会随工具会话结束被回收，必须同会话），老版则直接接上已在主城的运行实例。

**验证过驱动精度**：在老版点 `(0.375,0.625)` 命中「船员」页（白胡子 / 雷利 / 香克斯 / 龙 4 条），
再点 `(0.125,0.932)` 干净回到主城。见 `_tools/ab/pc_01_crew.png`、`pc_02_back.png`。

日志判据：`CCB:Button pressed! ccb:..., func:...`。命中按钮必有这条日志，
「点了没反应」据此与「坐标偏了」区分。

---

## 2. 启动环境的两个前提（否则老版卡在「检查更新」）

用户手动运行能进游戏，脚本启动却卡住，根因是网关根目录不同：

| | 用户 `启动游戏.bat` | 本轮脚本最初用的 |
|---|---|---|
| HTTP 网关根 | `E:\softwares\hzw_web`（完整老版接口） | `tools\gm_admin`（只挂了 2 个 php） |
| 监听 | `0.0.0.0:8080` | 原为 `127.0.0.1:8080` |
| 区服表 | `gameserver/dzm/1.8/servers_list.php` 指向 `192.168.1.3:8080` | 不可用 |

`start_gm_admin.ps1` 已改为监听 `0.0.0.0`；老版区服表 / 更新接口已挂到
`tools/gm_admin/gameserver/dzm/1.8/`（**未改动老项目任何文件**）。
本轮最终的 A/B 对照直接使用用户已启动、已在主城的老版实例（账号「冥王」Lv21）。

### 坐标体系实测

| | 老 Game.exe | 新 Haizeiwang.exe（修复前） | 新（修复后） |
|---|---|---|---|
| DPI 感知 | 96（系统虚拟化 1.5×） | 144（原生） | 144 |
| 客户区物理像素 | 720 × 960 | 480 × 720 | 480 × 640 |
| frame | 480 × 640 | 480 × 720 | **480 × 640** |
| 推算设计区 | **360 × 480** | **320 × 480** | **360 × 480** |

两端 `AppDelegate.cpp` 的 designSize 算法完全一样（`CCSizeMake(320,480)` 后按
`asp = height/width` 调整），差异只来自 `setFrameSize`。老 `main.cpp` 是 `(480,640)`
→ `designSize.width = 480/(640/480) = 360`；新误用 `(480,720)` → `320`。
**新版横向少了 40 个设计像素（11%）**，这是「很多地方操作不对劲」的主因。

---

## 3. 逐项结果（20 项，`diff` = 相对主城基准的画面差异）

| # | 按钮（归一化坐标） | 老版 | 新版·修复前 | 新版·最终 | 结论 |
|---:|---|---:|---:|---:|---|
| 1 | 船员 `(0.375,0.625)` | 50.62 | 57.31 | 50.77 | ✅ 对齐 |
| 2 | 装备 `(0.708,0.635)` | 51.35 | 58.51 | 52.10 | ✅ 对齐 |
| 3 | 奥义 `(0.354,0.714)` | 50.27 | 57.00 | 50.71 | ✅ 对齐 |
| 4 | 修行 `(0.632,0.719)` | 54.35 | 61.95 | 54.99 | ✅ 对齐 |
| 5 | 冒险 `(0.500,0.427)` | 46.77 | 52.82 | 46.67 | ✅ 对齐 |
| 6 | 远航 `(0.264,0.510)` | 47.50 | 53.92 | 47.94 | ✅ 对齐 |
| 7 | 决斗 `(0.681,0.516)` | 49.46 | 56.38 | 49.88 | ✅ 对齐 |
| 8 | 阵容头像 1 `(0.178,0.276)` | 46.52 | 0 | **0** | ⚠️ 残留 |
| 9 | 空位加号 `(0.785,0.276)` | 46.87 | 0 | **0** | ⚠️ 残留 |
| 10 | 包裹 `(0.156,0.830)` | 41.73 | 47.50 | 42.17 | ✅ 对齐 |
| 11 | 图鉴 `(0.299,0.830)` | 49.07 | 55.46 | 49.40 | ✅ 对齐 |
| 12 | 聊天 `(0.442,0.830)` | 56.57 | 64.19 | 56.84 | ✅ 对齐 |
| 13 | 恩怨 `(0.583,0.830)` | 44.32 | 50.22 | 44.57 | ✅ 对齐 |
| 14 | 传书 `(0.729,0.830)` | 46.45 | 52.46 | 46.62 | ✅ 对齐 |
| 15 | 设置 `(0.861,0.830)` | 50.77 | 57.54 | 51.11 | ✅ 对齐 |
| 16 | 底部·阵容 `(0.264,0.932)` | 46.87 | **0** | 46.40 | ✅ 已修复 |
| 17 | 底部·远航 `(0.403,0.932)` | 47.45 | **0** | 47.91 | ✅ 已修复 |
| 18 | 底部·冒险 `(0.542,0.932)` | 46.77 | **0** | 46.67 | ✅ 已修复 |
| 19 | 底部·决斗 `(0.681,0.932)` | 49.46 | **0** | 49.88 | ✅ 已修复 |
| 20 | 底部·商店 `(0.819,0.932)` | 37.99 | **0** | 38.31 | ✅ 已修复 |

> 「修复前」= 设计分辨率未修、只成功进主城那一轮（`_tools/ab/seq_new_full_run.log`）。
> 修复后 18 项的 `diff` 与老版**逐项吻合到 ±0.7 以内**，不只是「页面打开了」，
> 连画面内容都一致；两端总览见 `_tools/ab/AB_COMPARE_3up.png`。
> 20/20 项全程 `back_diff=0`、`alive=True`、0 断言 / 0 连接错误。

老版 20 项的页面依次为：船员列表 / 装备 / 奥义 / 修行 / 冒险活动 / 远航章节 / 决斗排名 /
船员详情 / 加号面板 / 背包 / 图鉴网格 / 聊天 / 恩怨 / 传书 / 设置 / 底部阵容·远航·冒险·决斗·商店。

---

## 4. 根因与修复

### 4.1 设计分辨率不等（影响全部 20 项的布局）

`client/Classes/AppDelegate.cpp`：`glview->setFrameSize(480, 720)` → **`(480, 640)`**，
与老版 `proj.win32/main.cpp` 的 `CCEGLView::setFrameSize(480, 640)` 一致，
设计区回到 360×480。修复后 13 个原本能响应的页面 `diff` 由 52–64 收敛到与老版 41–57 逐项吻合。

### 4.2 Debug FPS 统计条遮挡底部

同文件 `setDisplayStats(true)` → **`false`**。老版是 Release 客户端不显示，
新版 Debug 的 `GL verts / GL calls / 30.0` 半透明文字盖住了主城底部功能栏。

### 4.3 ScrollView 内 CCMenu 被 `_touchArea` 锁死（底部 5 项无响应）

`tools/ab_new_scan.ps1` 坐标扫描：底部栏只有 `onButton1`（首页）、`onBottomL/R`（翻页箭头）
能触发，中间 5 个图标按钮**连一条 `Button pressed` 都没有**；头像行同样。

`tools/ab_diag_head.ps1` 加受 `HAIZEI_MENU_DIAG` 控制的诊断日志，实测：

```
[MenuDiag] pos=(62,346) area=(80,730,580,128)   ← 触摸点 vs 缓存视口，坐标系不同量级
[SVDiag] _setChildMenu rect=(99,884,456,120) viewSize=(456,120) contentSize=(518,130)
```

- 移植时新增的 `CCScrollViewCompat::_setChildMenu` 在 `setContainer()` 阶段把
  `getViewRect()` 缓存成 `_touchArea`，`Menu::onTouchBegan` 用它做 `containsPoint` 硬拦截；
- 该矩形与 3.x `touch->getLocation()` 不是同一坐标系，`containsPoint` 恒 false；
- **老版 2.x 业务代码从不调用 `setTouchArea`**（`CCMenu` 的 `mTouchArea` 构造里未初始化），
  实际等于没有视口限制，命中完全交给 `itemForTouch`。

`engine/cocos2d-x/cocos/2d/CCMenu.cpp`：`onTouchBegan` 移除 `_touchArea` 阻断，
只保留老版真正在用的位移阈值起点（`_touchStartWorldPos`）。底部 5 项随即恢复。

配套：`client/compat/CCScrollViewCompat.cpp::init()` 加 `setSwallowTouches(false)`，
对齐 2.x「CCMenu 以 -128 优先级先收且不吞、ScrollView 随后也能收到拖动」的协同分发。

### 4.4 其它语义对齐（未引入回归）

- `client/Classes/MainPage.cpp`：`members->setContainer(node)` 之后的
  `members->setContentSize(size)` 注释掉。2.x `CCScrollView` 继承 `CCLayer`，该调用只记内容尺寸、
  不改视口；3.x `ui::ScrollView` 会拿它当视口重排 innerContainer。
- `CCMenu.h/.cpp` 的 `setTouchArea(area, provider)` 接口与 `CCScrollViewCompat` 的
  `[SVDiag]` / `[MenuDiag]` 日志保留：接口当前不参与命中判断，日志默认静默，
  供后续排查 ScrollView 内控件用（设置环境变量 `HAIZEI_MENU_DIAG=1` 开启）。

全部 4 轮构建 `BUILD_EXIT=0`（`_tools/build_ab_fix{,2,3,4,5,diag}.log`），仅第三方 PDB 警告。

---

## 5. 与既有报告的关系

`docs/FUNCTION_PARITY.md` 是**静态入口逐项对照**（115 页 / 250 按钮 / 193 回调体），
结论是「代码层面无功能缺失」。本轮是**同坐标真机点击对照**，两者粒度不同、互补：
静态看不出「设计分辨率差 40 像素」和「ScrollView 内按钮收不到触摸」这类运行期差异——
这正是本轮发现并修掉的两类问题。

---

## 6. 残留 2 项（阵容头像 1 / 空位加号）—— ✅ 已修复（2026-11-14 晚）

### 6.0 最终根因（两层叠加）

1. **命中层（已修）**：`Menu::getItemForTouch` 的 `isScreenPointInRect` +
   `getWorldToNodeTransform` 命中数学实际正确（CHAIN 诊断确认链路含页面 0.5 缩放，
   `hit=1`）。早期"2× 坐标错位"结论是把 parent-space 的 `getBoundingBox()`
   误读成世界坐标所致。
2. **回调层（真正根因，已修）**：3.x 上游
   `cocosbuilder::NodeLoader::parsePropTypeBlock` 保留 `if(!isJSControlled())`
   守卫；而老工程私改版（老 `extensions/CCBReader/CCNodeLoader.cpp:760`）
   **注释掉了该判断**——无论 ccbi 的 jsControlled 标志是什么，都走 C++ selector
   解析。framedButton.ccbi、TeamPage 成员格等 ccbi 头部 `jsControlled=1`，
   3.x 端因此静默 `return nullptr` → `MenuItem::_callback` 为 NULL →
   `activate()` 空转（无任何日志）。全量 274 个 BLOCK 属性中 59 个中招：
   `onFrameButton`×17（主页头像/空位/锁定格）、`onFrame1-6`（阵容页）、
   `onShowDetail1-4`、`onJoinBattle`、`onShowRank`、`onSkillCenter`、
   `getRewardBtn`、`onPieceBook` 等。

### 6.0.1 修复与验证

- 修复：`engine/.../cocosbuilder/CCNodeLoader.cpp::parsePropTypeBlock` 去掉
  jsControlled 分支（对齐老版：始终解析，解析失败才落回回调数组兜底；
  `parsePropTypeBlockCCControl` 老版保留守卫 → 不动）。
- 顺带修复主页空位视觉：删除 `[haizei]` 添加的白色 "+" 文本（老版无此元素）。
  蓝色 "+" 当轮误判为"已居中"，实际未居中，根因与修复见 §6.2。
- 实跑验证（`tools/ab_click_test.ps1`）：
  - 头像 1 点击 → 进入 TeamPage【雷利】阵容页（452360 字节 ≠ 主城基准）✓
  - 空位加号点击 → 进入【香克斯】船员信息/更换船员流程（391026 字节）✓
  - 滑动回归：头像行拖动后停留（AFTER≠BEFORE）、底部导航硬停 + delegate 吸附 ✓
- 诊断手段（env 门控，保留）：`HAIZEI_MENU_DIAG=1` 输出
  `[MenuDiag] begin/TEST/CHAIN/onTouchEnded/activate` 与
  `[CCBDiag] prop/BLOCK apply/parsePropTypeBlock/setCallback`，
  可直接看到 59 个 `BLOCK apply ... blockData=00000000` 的未绑定项。

历史定位过程（已被上面修正，仅留档）：早期怀疑 `getItemForTouch` 相机/裁剪变换
不一致、`u_icobg02.png` 缺失等，均被逐层诊断排除。

---

### 6.1 附加发现：商店页顶栏玩家名（非按键差异）

`_tools/ab/AB_FOCUS_nav_shop.png` 三联图里，老版与修复后新版都正确进入商店页，
但新版顶栏玩家名显示 `NameName`，老版显示「冥王」。这是**显示内容差异，不是按键行为差异**：

- 两端 `UsrInfoBanner.ccbi` / `TopBanner.ccbi` 二进制一致，都含 `NameName` 默认文本；
- 两端业务代码都没有专门刷新 `UsrInfoBanner` 的分支（老版靠主城顶栏复用，
  新版商店页用了独立副本）；
- 上一轮已把 28 处 `CCLabelTTF*` 类型契约修成 `CCLabelBMFont*`，主城 / 突破页显示正常，
  商店页这个独立副本仍走默认值。

未在本轮硬改：需要在页面加载链路补一次 `mPlayerName` 刷新，属于显示逻辑，
与「点击是否一致」无关，改动会扩大回归面。已记录为待办。

---

### 6.2 二轮修复（2026-11-14 深夜）：空位加号未居中 + 阵容页点击闪退

#### 6.2.1 蓝色加号未居中（用户实测纠正）

**根因（引擎层，两层叠加）**：

1. 老版魔改 `CCSpriteFrameCache::spriteFrameByName`（老
   `cocos2dx/sprite_nodes/CCSpriteFrameCache.cpp:419`）会**先剥掉目录前缀**再查帧
   （`mainScene/u_+2.png` → `u_+2.png`），而 `Imagesetfile/mainScene.plist` 图集
   帧名均无目录前缀。
2. 老版 `CCSprite::setTexture(const char*)`（老 CCSprite.cpp:1135）**先查
   SpriteFrameCache**：命中即 `setDisplayFrame`，用图集帧的
   offset/originalSize 布局——`u_+2.png` 是 40×42 字形垫在 84×84 原始画布上
   （offset {1,-1}），锚点 (0,0) 的槽位精灵因此把加号画在画布中心 → 居中。
   3.x `Sprite::setTexture(filename)` 没有帧查找路径，直接按整张散图加载：
   新版 Resources 的独立 `mainScene/u_+2.png` 只有 40×42（画布被裁），
   contentSize 被改为 40×42 → 锚点 (0,0) 下加号整体左下偏移约 22px
   （实测偏移设计坐标 (-21.8, +21)，老版基准为 (+1.0, -0.5) 居中）。

**修复**：`engine/cocos2d-x/cocos/2d/CCSprite.cpp::Sprite::setTexture(const std::string&)`
对齐 2.x 语义：先 `getSpriteFrameByName`（新引擎该方法已带剥目录 + 散图回退）命中
则 `setSpriteFrame`；未命中才走散图加载；加载失败保持原样（2.x pTexture==NULL 直接返回）。

**验证**（`_tools/ab/old_home_base.png` vs `_tools/ab/crash/v_home.png`，像素测量）：
加号中心设计坐标 X=567.0（两端一致），相对槽框垂直偏移 +0.5px（老）vs +0.0px（新），
字形尺寸 34×35 vs 33×34 —— 像素级对齐。

#### 6.2.2 阵容页点击船员格闪退（use-after-free）

**现象**：主页空位加号/槽位跳转阵容页后，点击其他船员格闪退（复现率 100%）。

**根因链**：

1. `TeamPage` 点击格 → `PersonIconContent::onFrameButton`（WIN32 DEBUG）先调
   `GamePrecedure::gameSnapshot()`。
2. 老版 `gameSnapshot` 用私改扩展 `RenderTexture::keepBegin()/keepEnd()`
   （= begin(WithClear) + **立即渲染到纹理**）。迁移时 3.x 无此接口，begin/end
   被注释掉，`visit()` 的全部渲染命令**直接滞留主渲染器队列**；后恢复
   `beginWithClear/end` 仍不够——3.x `RenderTexture::end()`（CCRenderTexture.cpp:839）
   只是把"执行捕获" CustomCommand 入队 + popGroup，同样**不立即渲染**。
3. 随后 `TeamPage::refreshPersonPage` 的
   `setNormalImage/setSelectedImage`（奥义/武器/防具/饰品共 6 处）按 3.x
   `MenuItemSprite::setNormalImage` 语义 `addChild(新)+removeChild(旧, cleanup=true)`
   释放 12 张旧贴图 Sprite（`u_icobg02.png` 槽位框图）。
4. 主渲染阶段处理队列中 gameSnapshot 留下的悬空命令：
   `TrianglesCommand` 的顶点指针已随 Sprite 释放（MSVC 调试堆 0xCD/0xDD 填充），
   `Renderer::drawBatchedTriangles` memcpy 读已释放内存 →
   访问违例 0xC0000005（转储确认：VCRUNTIME140D memcpy，
   读 0xFFFFFFFFCDCDCDCD；渲染器 "Unknown commands in renderQueue"×N，
   cmd 指针与 [SpriteFree] 日志逐一吻合）。

**修复**：`client/Classes/GamePrecedure.cpp::gameSnapshot` 在 `in_texture->end()`
后补 `Director::getInstance()->getRenderer()->render()`，与老版 keepEnd 的
"立即渲染到纹理并清空队列"语义对齐（saveToFile 的捕获命令也随之当场执行）。

**验证**（`tools/ab_crash_full.ps1`，修复前 s2 必崩）：主页点空位 → 阵容页 →
依次点击 5 个船员格 + 右箭头，全部 OK、进程存活；连续两轮构建验证通过。

**取证工具沉淀**（可复用）：
- `HAIZEI_CRASH_HUNT=1` → `Sprite::~Sprite` 输出 `[SpriteFree] sprite/triCmd/file`；
- `Renderer::processRenderCommand` 未知命令分支输出 `cmd=%p type=%d`；
- WER LocalDumps（HKCU）抓全量转储 + `tools/pdbsym/pdbsym.exe`（DIA/DbgHelp 解析 PDB）。

---

## 7. 复现

```powershell
# 1) 按用户方式启动老版（会拉起 MySQL/Java/PHP，PHP 根为 E:\softwares\hzw_web）
& "E:\BaiduNetdiskDownload\(SY-096)草M船Z\启动游戏.bat"
# 用 heigui / 123456 登录到主城后保持运行

# 2) 老版 20 项基准（接上已运行实例）
powershell -File tools\ab_run_sequence.ps1 -Side old

# 3) 新版：同会话启动 + 登录 + 同坐标序列
powershell -File tools\ab_new_full.ps1

# 4) 生成总览 / 三联对比
powershell -File tools\ab_montage.ps1   -Dir _tools\ab\seq_old
powershell -File tools\ab_montage.ps1   -Dir _tools\ab\seq_new
powershell -File tools\ab_make_compare.ps1

# 5) 单项定位
powershell -File tools\ab_head_scan.ps1     # 头像行 68 点扫描
powershell -File tools\ab_diag_head.ps1     # 触摸链诊断（需 HAIZEI_MENU_DIAG=1）
```

证据目录 `_tools/ab/`：
`seq_old/`（老版基准 20 项）、`seq_new/`（最终 20 项）、
`seq_new_before_fix/`、`seq_new_resolution_fixed/`、`seq_new_nav_fixed/`（各阶段留档）、
`AB_COMPARE_3up.png`（三联对比）、`scan_results.csv`、`head_scan_hits.txt`、
`seq_*_run.log`、`build_ab_fix*.log`。

> 老版窗口在本轮结束时仍在运行（用户手动启动的实例），未强制关闭。
> 三服务随脚本会话结束会被回收；自行开新版请先 `tools\start_local_env.ps1`
> 再 `tools\gm_admin\start_gm_admin.ps1`，最后启动 `build\Debug\Haizeiwang.exe`。

### 6.3 阵容页蓝加号未居中（initWithFile 路径，✅ 已修复）

- 现象：阵容页顶部船员空槽的蓝加号（u_+2.png）整体偏向槽框左下约 11~12px；
  两侧装备槽（u_+1.png）正常。老版全部居中。
- 根因：这些空槽走 `Sprite::initWithFile`（PersonIconContent::refreshContent →
  `frame->initWithFile(getTeamDefaultPic())`，即 `mainScene/u_+2.png`）。
  上一轮只把 `setTexture(filename)` 修成"帧缓存优先"，`initWithFile` 没改：
  新版 Resources 里 u_+2.png 散图存在、但画布被导出工具裁成 40×42（老版图集帧
  是 40×42 字形垫在 84×84 画布、offset(1,-1) 居中）→ addImage 成功走散图路径
  → contentSize 40×42、锚点(0,0) → 左下偏移。装备槽 u_+1.png 散图缺失，
  恰好落进此前"文件缺失才查帧"的回退 → 图集 97×101 全幅 → 居中。
- 修复：`engine/.../2d/CCSprite.cpp::initWithFile` 改为**帧缓存优先**
  （getSpriteFrameByName + 剥目录前缀回退，与 setTexture 修复同语义）；
  未命中帧再走散图路径。图集帧自带 offset/originalSize，渲染即完整画布，
  与 2.x 视觉等价；`Sprite::create(filename)` 同步受益。
- 验证（480×640 实跑截图 t1_row_scrolled.png）：拖动槽位行露出空槽，
  槽框中心 (170.5,78.5) vs 加号中心 (169.5~171,77.5)，偏移 ≤1px；
  装备槽无回归；主页加号 (566.2,264.8) vs 老版基线 X=567.0，≤1px；
  s1~s5+箭头逐格点击回归通过、进程存活。

### 6.4 打斗技能特效失效 + 施法卡牌错乱（✅ 已修复 2026-11-15 凌晨）

- 现象：放技能时无任何特效演出（无技能名卷轴、无特效图），
  施法者卡牌错位堆叠（顶部中央"败"字卡堆叠、我方卡消失、敌方上移）。
- 取证：`HAIZEI_MENU_DIAG=1` + [SkillDiag] 桩（FightTaskSkillBig::onLoad /
  FightTaskSkillBigSingle::onStart）抓到：
  `[CCBContainer] failed to load ccbi (missing or invalid): s_slga / s_slsa`
  → skillNode 是空容器（sz=0、mAssailant/mDefender 全 NULL）。
- 根因（两层）：
  1. 技能表里 `SkillItem.ccbFile` 存的是**无 .ccbi 后缀**的文件名
     （如 `s_slga`），普通页面代码传的都是带后缀名；
  2. 迁移时 `CCBContainer::loadCcbiFile` 额外加了一层
     `fullPathForFilename(filename)` 预处理——对无后缀名返回空串，
     `CCBReader::readNodeGraphFromFile("")` 首行 `strlen==0` 就静默
     返回 nullptr。2.x 语义是把原始文件名交给 reader，由 reader
     内部补 `.ccbi` 后缀再搜路径，所以老版能加载。
     特效节点为空后，卡片被 addChild 到空容器上，坐标换算全错 → 错乱。
- 修复：`client/Classes/CCBContainer.cpp::loadCcbiFile` 先补齐
  `.ccbi` 后缀（<5 字符防御）再交给 reader，对齐 2.x 行为。
- 验证（ab_fight_seq.ps1 时序截图）：`s_slga` 加载成功
  sz=(738,1152)、mAssailant/mDefender ok；t12 群体技「龙卷风」演出完整
  （技能名卷轴+暗场+敌方 4 卡 -50 伤害）；t16 刀光特效；t20 单体技
  「瓦正拳」演出（斗气+拳气弹+防守方卡牌正常）；t28 FIGHT 转场；
  无卡牌堆叠错乱。诊断桩已清理，重建后 ab_crash_full.ps1 回归通过。
