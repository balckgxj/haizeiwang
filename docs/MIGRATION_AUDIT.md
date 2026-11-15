# Haizeiwang 升级移植完整性审计报告

> 审计时间：2026-11-13 ~ 11-14（持续更新）
> 老工程（只读）：`E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src`（cocos2d-x 2.1.3）
> 新工程：`E:\PCGame\Haizeiwang`（cocos2d-x 3.17.2 + CMake / Win32）
> 迁移台账：`docs/MIGRATION.md`；本文件只做「完整性核对 + 缺口登记 + 修复记录」。

---

## 一、结论摘要（最终）

| 维度 | 结论 |
|---|---|
| **文件资产覆盖** | ✅ **100%**。源码 416、协议 240、资源 1772 个文件全部到位，无遗漏 |
| **资源内容一致性** | ✅ 1772 个资源文件 MD5 与老工程逐个一致（只多 3 个本地调试用的新文件） |
| **代码改动面** | 416 个业务源文件中 341 个原样未改，75 个做了 API 适配 |
| **编译链接** | ✅ Win32/x86 Debug **0 错误**，exe 已生成（含两轮修复后仍 0 错误） |
| **运行闭环** | ✅ 登录 → 主城 → **115 / 115 个注册页面逐页直开实测，0 崩溃、0 断言**（`_tools/page_audit_result.txt`）；Debug 构建 0 错误 |
| **Lua 子系统** | ⓘ **老工程里就是死代码**（`CCBLuaContainer` 从未实例化），新工程未接 Lua **不是回归**；125 个 C++ 页面自身处理逻辑，不依赖 Lua |
| **功能完整性** | ✅ **核心玩法完整可玩 + 全页面运行稳定**。剩余均为次要降级项（视觉/触摸细微差别/内存报告）与多端目标，无阻断性功能缺失 |

一句话：**资产 100% 搬全、代码 100% 编通、115 个页面逐页实测零崩溃**；两类「编译通过 ≠ 移植完成」陷阱（752 处 `CCLabelBMFont` 类型契约，以及只在运行时暴露的 2.x/3.x API、生命周期与上下文状态差异）已系统收敛，详见**第八节**。

---

## 二、审计方法与可复现工具

| 工具 | 作用 |
|---|---|
| `tools/audit_migration.py` | 按相对路径 + basename 双向对比两工程，输出缺失/新增/内容变更清单，扫描降级标记；`--json` 导出 |
| `tools/decrypt_el.py` | 按老工程 `Cocos2dxLuaLoader.cpp` 算法导出 90 个 `.el` 为明文 Lua |
| `tools/patch/patch_labelbmfont.py` | P0 修复：752 处 `CCLabelBMFont` 类型契约幂等补丁 |
| `tools/patch/patch_boardcast_clip.py` | P1 修复：跑马灯 `ClippingNode` 裁剪 + 滚动位移回补 |
| `tools/start_local_env.ps1` | 一键拉起本地环境（MySQL 3306 + DZM 服务端 25524 + 客户端），重启后复用 |
| `tools/verify_pages.ps1` | 附着式巡检：进主城后发 1~9 键逐页截图、监测 `crash_stack.txt` |
| `tools/audit_all_pages.ps1` | **全 115 页逐页核对**：调试通道 `goto:<Page>` + 逐页截图 + 多判据崩溃检测，输出 `_tools/page_audit_result.txt` |
| `tools/audit_recheck.ps1` | 定向复检此前崩溃的 15 个页面，验证修复是否生效 |
| `tools/capture_one.ps1` | 单页冷启动复现：dump `crash_stack.txt` 前 12 行 + 日志中的断言行 |
| `tools/capture_fight.ps1` | 进程退出时间线（逐秒 alive）+ `verify_run.log` 末尾，用于定位无 crash_stack 的退出 |
| `tools/repro_seq.ps1` | 按给定页面**序列**依次 `goto:`，复现「连续切换累积 BlackBoard 状态」才出现的崩溃 |

```bat
E:\Softwares\miniconda3\python.exe tools\audit_migration.py
E:\Softwares\miniconda3\python.exe tools\decrypt_el.py
powershell -File tools\audit_all_pages.ps1
powershell -File tools\repro_seq.ps1 -seq StoneInlaidPage,StoneUpgradePage -wait 2
```

审计快照：`_tools/audit_result.json`；明文脚本：`tools/lua_plain/`（含 `_index.json`）。

**运行时调试通道**：`MainFrame::_setupDebugPageKeys` 每 0.2 s 轮询
`C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt`，支持
`goto:<Page>` / `push:` / `pop:` / `back` / `quit`。这是无 UI 自动化依赖、逐页直开 115 个注册页面的关键。

**崩溃必须多判据检测**（本轮踩过的坑，见第八节）：进程存活 + CRT 断言弹窗（**多标题**）+
日志新增内容中的 `Assertion failed` / `xtree(\d+)` / `abort() has been called`（按字节偏移归属到当前页）+
`crash_stack.txt` 的 mtime。只查 "Microsoft Visual C++ Runtime Library" 弹窗会漏掉 Debug CRT 断言。

---

## 三、文件级覆盖明细

| 资产组 | 老工程 | 新工程 | 完全一致 | 内容有改动 | 缺失 |
|---|---:|---:|---:|---:|---:|
| `Classes`（204 cpp + 212 h） | 416 | 416 | 341 | 75 | **0** |
| `Protobuf`（120 cc + 120 h） | 240 | 240 | 240 | 0 | **0** |
| `Platform` | 2 | 2 | 1 | 1 | **0** |
| `Resources` | 1,772 | 1,775 | 1,772 | 0 | **0** |

资源构成：1112 PNG / 338 ccbi / 96 mp3 / 90 `.el` / 56 plist / 47 txt / 16 cfg / 8 fnt / 2 lang。
新工程多出的 3 个文件均为本地调试新增：`haizei_local_mode.flag`、`localSevers.json`、`cc_2x2_white_image`。

**数据资产可解密性（实测）**
- 53 个加密配置表（`0xEF 0xFE` + `youaiABC` 异或 + zlib）全部解密成功，0 失败。
- 90 个 `.el` 脚本（无异或头，同密钥）全部解密成功，共 **27,373 行明文 Lua**，已导出。
- 结论：配置与脚本资产完好。

**页面注册**：115 个 `REGISTER_PAGE`，全部在编（`/WHOLEARCHIVE` 保证静态注册器不被链接器丢弃）。
另有 **125 个 C++ `*Page.cpp`** 类，构成实际可玩内容的全部界面（含本次验证的 9 个主页面）。

---

## 四、完整性缺口清单（按优先级）

### P0 — 阻断核心玩法（已修复并复验 ✅）

| # | 问题 | 根因 | 影响 | 处理 | 状态 |
|---|---|---|---|---|---|
| 1 | **`CCLabelBMFont` 类型契约错配** | 引擎 `CCDeprecated.h` 把 2.x `CCLabelBMFont` 映射成 3.x 的 `LabelBMFont`（继承 `SpriteBatchNode`），但 3.17 CocosBuilder `LabelBMFontLoader` 实际创建的是 `cocos2d::Label` | **752 处** `dynamic_cast<CCLabelBMFont*>` 在 **76 个文件** 全返回 `nullptr`：动态文本不刷新、页面空指针崩溃（`crash_stack.txt` 记录 `SkillBookPage::refreshContent`，冒险/技能书页必崩） | 兼容层 `typedef Label CCLabelBMFont`；20 处旧式创建改接 `createLabelBMFontCompat()` | ✅ 0 错误构建，9 页复验文字正常、无崩溃 |

> 这是最关键的「编译通过 ≠ 移植完成」陷阱：不影响编译/启动/主城截图，但任何代码写文本的页面都是坏的。

### P1 — 已回补 / 重新定性的项

| # | 项 | 重新定性 | 证据 / 处理 |
|---|---|---|---|
| 1 | **Lua 子系统未接入** | ⓘ **非缺口（死代码）**。老工程 `CCBLuaContainer` 同样只被自身引用、从未实例化；`Gamelua.cpp`(57k 行 tolua) / `pb.cpp` / 90 个 `.el` 在两端都是遗留脚手架，从未进入游戏流程 | 125 个 C++ 页面按钮走 `CCBContainer::onMenuItemAction`（`executeGlobalFunctionByName` 桩返回 0 时回退 C++ 处理），完全不依赖 Lua |
| 2 | **跑马灯裁剪失效** | 🔧 **已修复** | `BoardCastLabel.cpp` 原 6 处 `LabelTTF::setTextureRect` 被注释 → 改用 `ClippingNode` 裁剪 + 恢复 `mStartFirstX` 滚动位移（幂等补丁 `patch_boardcast_clip.py`）。主城验证无崩溃 |
| 3 | **滚动菜单 `setScrollViewChild`** | ⚠️ **非阻断**。2.x 自定义 CCMenu 扩展（让滚动容器内菜单项触摸正确），3.x 由 `ui::ScrollView` 事件冒泡处理 | 26 处被注释；`CareerPage` 等带此标记的页面已验证可加载、不崩；仅触摸细微差别 |
| 4 | **TouchDispatcher 段删除** | ⚠️ **非阻断** | 3 处（AdventureContinue/Invite、LevelUpReward）；注释说明改由遮罩层处理 |
| 5 | **纹理回收阈值关闭** | ⚠️ **非阻断（内存优化）** | `AppDelegate`/`MainPage` 共 5 处 `purgeCachedData`/字节阈值在 3.x 接口迁移；仅影响内存回收强度 |
| 6 | **RenderTexture keepBegin/keepEnd** | ⚠️ **轻微视觉** | `GamePrecedure.cpp` 2 处 2.x 扩展接口，3.x 无；影响特定截图/特效，不崩 |
| 7 | **SpriteShader 视觉特效** | ⚠️ **轻微视觉** | 3.x `Node::draw` 为 `final`，`drawShader()` 无处调用；自定义 shader 精灵效果不生效 |
| 8 | **音效卸载 / 纹理预加载注释** | ⚠️ **轻微（音效内存/首屏加载）** | `SoundManager::unloadEffect` 等几处；不阻断流程 |

### P1b — 真实存在的资源缺口（预存于老工程，非移植引入）

| # | 缺失文件 | 引用面 | 性质 |
|---|---|---|---|
| 1 | `mainScene/u_icobg02.png` | 被 **70+ 个 ccbi** 引用（各类弹窗/面板背景） | 老工程资源 dump 本身就缺（新旧都不存在）；仅背景图缺失，不崩 |
| 2 | `mainScene/u_icobg06.png` | 同上（AdventureNavButton 等） | 同上 |
| 3 | `mainScene/u_lock.png` | 锁图标 | 同上 |

> 这 3 张图在源资源里就不存在（文件审计已确认 1772 资源新旧 100% 一致 ⇒ 源头即缺）。属「数据源不完整」，若要补齐需从原始 APK 中提取。当前表现：少数面板背景/锁图标显示为缺图占位，**不影响功能**。

### P2 — 多端与长期目标（移植方案阶段三~五，未启动）

| # | 缺口 | 现状 |
|---|---|---|
| 1 | 目标平台 | 仅 Win32/x86（external 预编译库只有 x86）。x64/Android(arm64)/iOS(arm64) 未建 |
| 2 | 平台层 | `platform_bridge` 只接 win32；30 个渠道未收敛为 `IPlatform` |
| 3 | 分辨率 | 窗口 480×720 竖屏，但 338 个 `.ccbi` 仍 320×480 绝对坐标；无安全区/滚轮/键盘适配 |
| 4 | 服务端 | 老工程 `server/`（8847 文件）未迁入；当前直接跑老目录的 JDK8 + MySQL5.6 |

### 已知非阻断运行噪音
- 18 条 `ERROR: SpriteFrame nullptr`（ccbi 空精灵，2.x 同样行为）
- `No file found at mainScene/u_ico*.png` / `u_lock.png`（见 P1b，预存缺图）
- `libpng warning: iCCP`（美术 PNG 色彩配置，无害）
- 部分文案 `Sample Text` / `@Name`（语言表 key 缺失，数据问题）
- `libpng`/`vc140.pdb` 链接警告（第三方预编译库，无害）

---

## 五、本轮已完成的修复与产出（累计）

1. **P0-1 类型契约修复** ✅
   - `client/compat/haizei_compat.h`：把 `CCLabelBMFont` 对齐到 `cocos2d::Label`，提供 `cocos2d::createLabelBMFontCompat(text, fnt, width)`。
   - `tools/patch/patch_labelbmfont.py`：6 文件 20 处旧式创建改接新工厂（幂等）。
   - 构建 0 错误；**9 个主页面复验：文字正常渲染、无 `crash_stack.txt`**（原崩溃点技能书页 `SkillContent.ccbi` 正常加载）。
2. **P1-2 跑马灯回补** ✅
   - `tools/patch/patch_boardcast_clip.py`：用 `ClippingNode` 重做裁剪 + 恢复横向滚动位移（幂等，备份至 `_tools/backup/`）。
   - 构建 0 错误；主城复验无崩溃。
3. **审计/抢救工具链**：`audit_migration.py`、`decrypt_el.py`、本地环境脚本、巡检脚本。
4. **本报告**与日常记忆。

### 与引擎的关系
3.17.2 引擎共打 10 个文件补丁（195 行增 / 39 行删），集中在 `CCSprite` / `CCSpriteFrameCache` / `cocosbuilder`(4) / `UIEditBoxImpl-win32` / `CCCommon-win32` / `network|extensions CMakeLists`。`git -C engine/cocos2d-x diff` 可审阅，升级引擎版本时需重移植。

---

## 六、逐步完成路线（建议顺序，已推进至 ①）

| 阶段 | 内容 | 状态 |
|---|---|---|
| **① 稳定性收敛** | P0-1 修复 + 9 主页面巡检（登录/主城/冒险/竞技/决斗/船员/装备/奥义/修行/设置/背包/图鉴） | ✅ 完成：9 页无崩溃、文字正常 |
| **② 降级点回补** | 跑马灯裁剪（已完成）；逐项确认滚动菜单/触摸/特效无可见缺陷 | 🔶 跑马灯已修；其余为非阻断项，按需 |
| **③ P1b 缺图补齐**（可选） | 从原始 APK 提取 `u_icobg02/06`、`u_lock` 三张图放入 `client/Resources/mainScene/` | ⬜ 待定（数据源问题） |
| **④ 多端**（长周期） | x64 第三方库重编 → Android(arm64) → iOS；`IPlatform` 收敛渠道 | ⬜ 未启动 |
| **⑤ 适配与资源** | 设计分辨率升级 + 安全区 + 滚轮/键盘；PNG 高清化 | ⬜ 未启动 |

> 与初版评估不同：**Lua 子系统不再列为必须项**——它两端都是死代码，不接也不影响任何可玩页面。
> 真正影响「可玩性」的阻断项（P0）已清零，当前工程已具备完整可玩的核心循环。

---

## 七、复现命令

```bat
:: 完整性审计（只读）
E:\Softwares\miniconda3\python.exe tools\audit_migration.py --json _tools\audit_result.json

:: 构建（需先清掉小写代理变量，否则 MSBuild 的 CL.exe 启动失败）
env -u https_proxy -u http_proxy cmd //c build.bat

:: 拉起本地环境（MySQL + DZM 服务端 + 客户端）
powershell -File tools\start_local_env.ps1 -WithGame

:: 附着式页面巡检（需客户端已在跑）
powershell -File tools\verify_pages.ps1

:: 全 115 页逐页核对（自启本地环境，约 5 分钟，结果写 _tools\page_audit_result.txt）
powershell -File tools\audit_all_pages.ps1

:: 顺序复现「累积状态」才出现的崩溃
powershell -File tools\repro_seq.ps1 -fromList _tools\page_list.txt -untilPage TranExpChooseMemberPage -wait 2
```

---

## 八、运行时逐页核对（115 页）与本轮稳定性收敛

> 目标：回答「每一项功能是否都正常」——不只看编译，而是**真的把 115 个注册页面逐个打开**。

### 8.1 方法与验收口径

- 通道：`MainFrame::_setupDebugPageKeys` 每 0.2 s 轮询
  `%LOCALAPPDATA%\Haizeiwang\haizei_debug_cmd.txt`，执行 `goto:<PageName>`。
- 工具：`tools/audit_all_pages.ps1` 自启 MySQL/DZM 服务端 → 启动客户端 → 进主城 →
  按 `_tools/page_list.txt` 逐页 `goto`（间隔 2 s）→ 截图 + 崩溃检测；结果写
  `_tools/page_audit_result.txt`。
- **四判据任一命中即判失败**：
  1. 进程退出（`$g.HasExited`）；
  2. CRT 断言/abort 模态框（**多标题**匹配，含 `Microsoft Visual C++ Debug Library`）；
  3. **本次 `goto` 之后新增日志**里出现 `Assertion failed` / `xtree(N)` / `abort() has been called`
     （按文件字节偏移归属到当前页，避免跨页误判）；
  4. `crash_stack.txt` 的 mtime 变新。
- 命中时自动备份崩溃栈到 `_tools/crash_NNN_<Page>.txt`（否则重启游戏会覆盖证据）。
- 「进程静默退出且**零崩溃证据**」视为环境性，重启后重测一次；真实崩溃绝不重试。

### 8.2 逐轮收敛（最终 115/115）

| 轮次 | 结果 | 关键发现 |
|---|---|---|
| 首轮（修复前） | 100 / 115 | 15 页崩溃：`AboutPage`、`FightPage`、`TeacherTeachResultPage`、`NewActivePromptPage`、`NewActivePromptToolPage`、`MemberPage`、`PlayerInfPage`、`SkillChangePage`、`StoneInlaidPage`、`DiscipleRecruitPage`、`TeamBuffUpgradePage`、`TitleGetNewPage`、`TitleLVUpPage`、`TranExpPreviewPage`、`WorldBossRankPage` |
| 修复 A（系统性根因 + 上下文 guard） | 113 / 115 | 原 15 页全部转 `ok`；新暴露 `FortuneComeReward`(046)、`StoneUpgradePage`(090) —— 修复减少了重启，累积状态路径改变 |
| 修复 B（FightPage / Exit 野指针 / `copy()`） | 114 / 115 | 046/090 转 `ok`；`TranExpChooseMemberPage`(103) 出现，实为 `TeacherTeachResultPage::Exit` 延迟崩溃误归属 |
| 修复 C（Win32 后台生命周期） | 114 / 115 | 崩溃页漂移到 `PropInfoPage`(073)，仍为无证据静默退出 ⇒ 定位到与时间/最小化相关的进程退出 |
| **最终验收** | **115 / 115，0 崩溃** | 无静默退出、无重测触发，`_tools/page_audit_result.txt` 全 `ok` |

### 8.3 崩溃根因分类与修复（运行时缺陷）

| # | 根因 | 表现 / 崩溃栈 | 修复 |
|---|---|---|---|
| 1 | **ccbi 缺失/解析失败返回空节点** | `Language::updateNode(nullptr)` 访问违例（3 页）；`TeachResultPage.ccbi` 资源本身在新旧工程都不存在 | `CCBContainer::loadCcbiFile` 空文件名/空节点保护 + `Language::updateNode` 判空 |
| 2 | **CCBAnimationManager 序列 id = -1** | `CCASSERT(nSeqId != -1)` 直接 abort（FightPage、DiscipleRecruitPage） | 引擎改为「找不到序列则跳过并告警」，不再断言 |
| 3 | **`CCLabelTTF` 类型契约错配** | `PlayerInfPage::refreshPage` 中 `mName` 为 `LabelTTF*`，而 ccbi 节点是 `Label` ⇒ `dynamic_cast` 返回 null | 成员与 cast 改为 `CCLabelBMFont*`（与 P0-1 同类） |
| 4 | **上下文依赖页无数据时空指针** | `Equip::stoneNum` 空 `mEquipInfo`、`getWorldBossInfoByID` 空、`getUserBattleInfo` 空等（7 页） | `Enter` 改为**数据有效性**校验（仅判 `==0` 不够：BlackBoard 是单例，跨 `goto` 会残留旧的非 0 值） |
| 5 | **`Enter` 提前 return 导致 `Exit` 解引用未初始化节点** | `StoneInlaidPage::Exit`→`clearAllItem`（`mPageInlay` 野指针）、`TeacherTeachResultPage::Exit`（`mDisciplesPosNode` 空） | 构造函数显式置空所有节点指针 + `clearAllItem`/`addItem` 判空；同时加固 `SkillChangePage`、`TeamBuffUpgradePage`、`TranExpChooseMemberPage` |
| 6 | **2.x 废弃 API 在 3.x 触发断言** | `move->copy()->autorelease()` → `Ref::copy()` 里 `CC_ASSERT(false)` 且返回 `nullptr`（`FightTasks.cpp` 2 处、`FightPage_finalRound.cpp` 1 处） | 改为 `move->clone()`（3.x `clone()` 返回 autorelease 对象，`ActionEase::initWithAction` 会 retain） |
| 7 | **演示战斗分支未同步填充容器** | `goto:FightPage` 走 `//temp code` 生成假数据并 `fight()`，但 `mBattleList` 为空 ⇒ `FightPage_roundState` 里 `find(i)->second` 解引用 `end()`，触发 `xtree(182) : Assertion failed` | `FightPage::Enter` 让演示/正常战斗共用同一套 `mBattleList` 初始化；`FightPage_roundState` 再加 `end()` 防御 |
| 8 | **Win32 误用移动端「切后台」生命周期** | 窗口最小化触发 `applicationDidEnterBackground`；老逻辑断线/停动画，且 Debug 版带「跨天 / 同小时超 1 分钟 / 有待发包即 `exit(0)`」测试代码 ⇒ 长时运行随机静默退出 | `AppDelegate` 在 `CC_PLATFORM_WIN32` 下跳过整条后台/前台生命周期（两端对称），移动端行为不变 |

另有 `MemberPage` 的 `getCharacter(entity->id)`（headless 下角色数据未加载返回空）加判空跳过。

### 8.4 两个「检测假阴性 / 误归属」教训

1. **abort 弹窗标题不唯一**：Debug CRT 断言框标题是 `Microsoft Visual C++ Debug Library`，
   而旧脚本只查 `Microsoft Visual C++ Runtime Library`；且断言写 stderr、**不生成 `crash_stack.txt`**。
   若只看进程存活 + 单一弹窗标题，会把「断言 abort」漏判成正常。现已加入日志偏移断言检测。
2. **延迟崩溃会记到下一页头上**：`FightPage` 打开后约 5 s 才触发断言退出，
   巡检在 2 s 时判 `ok`，下一页 `FortuneComeReward` 才看到 `alive=False`，
   且其 `lastccbi` 仍是上一页的 `s_curtain.ccbi`。定位这类问题必须用
   `capture_fight.ps1`（逐秒 alive + 日志末尾）与 `repro_seq.ps1`（页面序列复现）。

### 8.5 结论与残留非阻断噪音

**115 / 115 页面逐页实测零崩溃**，`build\Debug\Haizeiwang.exe` Debug 构建 0 错误，
`_tools/page_audit_result.txt` 全部 `ok`。运行时仍有以下**非阻断**噪音（不影响流程、不崩溃）：

- `SpriteShader`/`fightcard.sha` 在 3.x 下 fragment shader 编译失败（`CC_Texture0` 重复声明），
  对应第四节 P1-7 的自定义 shader 视觉降级。
- 演示战斗路径引用不存在的资源：`battle/b_qa.png`、`s_slga`、`s_slsa` 等 ccbi；
  已被 `loadCcbiFile` 的空节点保护接住，仅打印告警。
- `mainScene/u_icobg02/06`、`u_lock` 三张图（第四节 P1b，源头即缺）与
  `TeachResultPage.ccbi`（新旧工程均无）。
- 18 条 `ERROR: SpriteFrame nullptr`、`libpng iCCP`、`Sample Text` 等既有噪音。

> 说明：逐页巡检验证的是「每个注册页面可加载、可渲染、切换不崩溃」。
> 依赖**父流程上下文**（如某件具体装备、某场具体战斗数据）的页面，在缺少真实数据时按
> 设计走安全返回；这类页面由第 8.3 节 #4 的数据有效性 guard 保证「无数据也不崩」。

---

## 九、账号密码登录 + GM 体系端到端复核（本轮新增）

第 8 节的 115 页巡检建立在早期 `localAccount.txt` 自动登录之上；本轮按需求把登录改成
**游戏内 Cocos 账号密码页**并打通老项目 GM 体系后，重新做了真实交互复核（不是只跑 `goto:`）。

| 复核项 | 手段 / 证据 | 结论 |
| --- | --- | --- |
| 登录页渲染、中文、记住密码、切换账号 | `tools/probe_game_window.ps1`、截图 | 通过 |
| 凭据提交 → 发登录包 | `[lib91] credentials submitted` + `send packet! opcode:1` | 通过 |
| 服务端 GM 标记写入客户端 | `[haizei] server GM flag = 1`（`BlackBoard::isGM`） | 通过 |
| 密码错误回到登录页 | `status: 6` → 再次 `[LoginPage] shown` + 橙色错误提示 | 通过 |
| 切换账号 | `UserDefault` 的 `haizei_login_*` 清空、取消勾选、提示「已清空账号」 | 通过 |
| PHP 后台开关 GM 联动服务端 | `setgm` → 模拟登录回包 `field4: 0 → 1` | 通过 |
| 后台自撤死锁 | 修复前 `need_login:true` 无法恢复；修复后明确拒绝且不改白名单 | 已修复 |
| BackStage 玩家查询 | `opcode:994` 正常返回 | 通过 |

新增/复用的验证工具：`tools/probe_game_window.ps1`（Unicode 窗口枚举 + 全屏截图）、
`tools/game_interact.ps1`、`tools/verify_crew_breakthrough.ps1`（启动→登录→goto→点击一条龙）、
`tools/crop_shot.ps1`、`_tools/verify_login_gm.php`（模拟登录读 field 4）。

**两个自动化经验**（写在这里避免重复踩坑）：

1. **DPI 150%**：`GetWindowRect` / `SetCursorPos` 是虚拟坐标，
   `CopyFromScreen` 抓到的是物理像素；GLFW 每次启动窗口位置还会变（曾出现
   `(25,25)` / `(101,101)` / `(177,177)`）。所以点击坐标必须
   **从当前窗口 rect 动态换算**：客户区虚拟原点 `(r.L, r.T+30)`，之后
   `screen = (L + designX, T + 30 + (480 - designY))`，设计分辨率 320x480 与虚拟客户区 1:1。
2. **进程生命周期**：`Start-Process cmd /c Haizeiwang.exe` 起的进程会随 PowerShell 会话结束
   被回收，因此「启动 + 点击 + 截图 + 读日志」必须在**同一次脚本执行**内完成。
3. PowerShell 命令行里直接 `Add-Type` 会被安全策略拦截，要放在 `.ps1` 文件里执行。

详细设计、协议 XOR 细节、启动命令与文件清单见 `docs/MIGRATION.md` 第九节。

---

## 十、船员觉醒 / 船员突破专项核查（本轮新增）

### 结论

- **船员突破：存在且完整**。页面 `DiscipleUpgradePage` + `MemberBreakThrough.ccbi`；
  协议 `17 → 18`；服务端 `UpgradeDiscipleHandler` 校验船员存在、影子存在、
  突破上限 10、影子数量足够，扣影子、加潜力、回包；客户端回包更新数据并刷新页面。
  真实点击验证：`func:onBreakThrough` → `send packet! opcode:17` →
  `errorid: 18 errmsg: "disciple not exist"` → `MessageBox.ccbi`，无崩溃。
- **船员觉醒：本工程不存在**。客户端/服务端/PHP 后台/老项目源码全量检索
  `觉醒|awaken|awake|juexing` 零命中（仅 Box2D `SetAwake` 无关命中）；
  服务端 `Disciple` 实体无觉醒字段。该版本的船员成长线是
  **突破 / 培养 / 传承 / 修行 / 装备 / 奥义**。
  `SoulBreak.ccbi`、`SoulBreakC.ccbi` 是未接入的旧版影子信息弹窗，不是觉醒。

### 本轮发现的非阻断缺陷（尚未修，记录在案）

| 现象 | 影响 |
| --- | --- |
| `[CCBVar] MISS 'mEnterButton' in LoadingFrame.ccbi` | 仅变量名不匹配，按钮实际可见可点，`func:onEnter` 正常 |
| `DiscipleUpgradePage::refreshPage` 用 `CCLabelTTF*` 取 `mPlayerName` | 3.x 类型不匹配被判空跳过，玩家名显示占位 `NameName` |
| `Soul: SoulInfo not find 0` / `SoulBreak*.ccbi` 无引用 | headless 直开无上下文时的安全返回 + 孤立旧资源 |

> 这三处都不影响「突破功能存在且可用」的结论；如需彻底清理，建议把
> `mPlayerName` 改为 `CCLabelBMFont*`（参照 `PlayerInfPage` 的同类修复），
> 并确认 `LoadingFrame.ccbi` 里进入按钮的真实变量名。

## 十一、第五轮 UI 专项修复审计（本轮新增）

用户实测 5 项 UI 问题 → 全部定位为迁移缺陷并修复（详见 MIGRATION.md 第十一节）：

| # | 用户报告 | 根因 | 修复 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | 首页点人物跳阵容/空位加号/阵容拖动/右侧显示不全 | compat 偏移+锚点+内容大小 3 处语义错；MainPage 空位无入口 | CCScrollViewCompat 重写；空位叠 `+` BMFont | 已实跑验证 ✅ |
| 2 | 阵容页不能切换船员/更换列表缺人/装备区被遮挡 | menu 未协作 scrollView（吞触摸）+ ReVi 回收依赖 container position | CCMenu 移植协作 + 23 处 setScrollViewChild + ReVi Facade 改用 offset | 已实跑验证 ✅ |
| 3 | 远航战斗无船员/对手图、结算无奖励 | fightcard.sha 重定义 CC_Texture0 编译失败；CCLabelTTF dynamic_cast 失败 | 删自声明 uniform；4 处改 CCLabelBMFont | 已实跑验证 ✅ |
| 4 | 冒险活动图片显示不全、不能滑动 | 同 #1/#2 compat 缺陷 | 同上 | 已实跑验证 ✅ |
| 5 | 所有纵向滑动窗口顶部起始位置错 | `applyOffset` 取反 contentOffset | 恢复 2.x 原值语义 | 已实跑验证 ✅ |

构建：第二轮 `build.bat Debug` 通过（`_tools/build_ui_fix2.log`，`[OK] Haizeiwang.exe`，无 error C/LNK）；
本轮收尾再次构建通过（`_tools/build_final.log`，BUILD_EXIT=0，仅第三方 `LNK4099` PDB 警告）。

**实跑回归已完成（原阻塞项已解除）**：经用户确认重启 MySQL / Java / PHP 三服务，
在同一次 `.ps1` 会话内完成「启服务 → 登录 → 点击 → 截图 → 日志取证」。
`tools/verify_ui_final.ps1` 跑 11 页 goto（11/11 存活、0 断言、0 连接错误），
`tools/verify_clickpath.ps1` + `verify_fight_real.ps1` 从主城真实点击进入船员 / 冒险 /
远航 / 装备 / 设置并走完章节→战斗→结算链路。逐项结论见 `MIGRATION.md` 第 11.4 节。

> **审计口径修正**：`goto:` 无上下文直开只验证「不崩溃」，会产生 `NameName` 占位顶栏、
> 空面板与演示战斗数据。此前第八节 115/115 的结论是稳定性结论，**不是功能正确性结论**；
> 本轮以真实点击路径补齐了功能验收，两者不可互相替代。

## 十二、本轮收尾审计（实跑 + 资源补齐）

| 项 | 结果 |
| --- | --- |
| 28 处 `CCLabelTTF*` → `CCLabelBMFont*` 类型契约 | 已修（幂等脚本 `tools/patch/patch_ccb_labelttf.py`），真实页面顶栏显示「冥王」 |
| 运行期 23 个 `No file found at *.png` | 全部在图集中找到同名 frame；`export_missing_frames.ps1` 导出 18 张 + 跳过 5 张，`.png` 缺失归零（含长期记录的 `u_icobg02/06`、`u_lock`） |
| PHP 后台 / 构建 / 调试通道三处工具链缺陷 | 已修（代理变量清理、`cmake --build`、`back` 去重哨兵），详见 `MIGRATION.md` 12.1 |
| 结算奖励 | 真实链路显示「YOU WIN」+ 威 23 / 金币 560 / 船员经验条，问题 3 的「结算无奖励」不成立 |
| 战斗卡片立绘 / 黑色小方块 | **残留、非阻断**，已排除资源缺失与 shader 编译失败，定位与建议见 `MIGRATION.md` 12.3 |
| 成功突破路径、opcode 174 GM 二次鉴权 | 本轮未单独实测，保持记录 |

证据目录：`_tools/final_*.png`（11 页巡检）、`_tools/cp_*_crop.png`、`_tools/cp2_*_crop.png`
（真实点击/战斗/结算）、`_tools/pre_fix_*.png`（补齐散图前对比）、
`build/Debug/verify_{final,click,fight}.log`、`_tools/verify_*_run.log`。

## 十三、功能逐项一致性专项审计（本轮新增）

**独立报告：`docs/FUNCTION_PARITY.md`**（含 115 页逐页对照表），本节为审计摘要。

| 审计项 | 结果 |
| --- | --- |
| 方法 | `tools/audit_function_parity.py`（六类功能点双向集合 + 3712 行全量 diff）、`tools/audit_page_parity.py`（115 页逐页）、回调体函数级比对、diff hunk 自动分类 |
| 文件覆盖 | 老 416 / 新 418（+`LoginPage.cpp/.h`），仅老 0；303 完全一致、113 有改动 |
| 功能点 | 页面 115/115、按钮分支 250/250、跳转 8/8、ccbi 202/202 全部零缺失；资源 1772→1798 零缺失 |
| 协议 | Protobuf 240 文件内容全一致；`PackageLogic.cpp` 4234 行两端 MD5 相同 |
| 回调体 | 193 个中 190 逐字一致；3 个差异均有意（GM 白名单 / API 改名 / Lua 死代码） |
| hunk 分类 | 232 API 等价 / 74 结构（校验、加固、调试通道）/ 12 行为改写 |
| 被停用的老功能代码 | 仅 1 行（登录密码错误提示），本轮已修回 |
| 逐页结论 | **115/115 页老→新无功能缺失，115/115 页运行巡检通过** |

**本轮修复**（`tools/patch/patch_parity_fixes.py`，幂等）：3 处滚动视图「不吞触摸」、
`LevelUpRewardPage` 回弹设置、`InstructionManager` 4 处纹理回收、`FightPage` 重复回收去重、
密码错误提示本地化。构建 0 error C/LNK。

**差异定性**：有意变更 8 类（登录页 / GM 白名单 / 本地更新模式 / 调试通道 / 空位加号 /
Win32 生命周期 / 稳定性加固 / 战斗数据补齐）、等价适配 8 类、已知残留 5 类
（SpriteShader、RenderTexture、纹理阈值、战斗卡片立绘与黑块、两端都注释的 unloadEffect）、
无法实跑触发 3 类（status 6、三个未注册奖励子面板、GM 二次鉴权）。

> **审计口径再修正（重要）**：此前第八节 115/115 是「逐页不崩溃」，第十二节真实点击路径是
> 「关键链路功能验收」，本轮第十三节是「全量功能入口一一对照」。三者粒度不同、互不替代。
> 另发现验证脚本 `ToScreen()` 存在 DPI 虚拟/物理坐标混用，且 `goto:`/`push:` 对未注册子面板
> 静默失效；本轮已把该工具缺陷写入报告 §5「证据边界」，运行结论未依赖逐按钮命中判定。

---

## 十四、A/B 真机点击审计（补充修正上一节的证据边界）

上一节承认旧驱动 `ToScreen()` 的 DPI 缺陷并声明「逐按钮点击命中不作为一致性判据」。
本轮用 `tools/ab_lib.ps1`（`SetProcessDPIAware` + `GetClientRect` + `ClientToScreen`，
全物理像素 + 归一化坐标）重做，并用日志 `CCB:Button pressed!` 作闭环判据，
因此**逐按钮命中现在可以作为判据**。详见 `docs/AB_CLICK_PARITY.md`。

| 审计项 | 结论 |
|---|---|
| 老版 20 项基准 | 20/20 有响应，每次 `back_diff=0` 干净回主城 |
| 新版修复前 | 13 项响应（画面与老版偏差 6–8），7 项 `diff=0` |
| 新版最终 | **18/20 逐项对齐**（`diff` 差 ±0.7），2 项残留 |
| 构建 | 5 轮 `BUILD_EXIT=0`，仅第三方 PDB 警告 |
| 实跑稳定性 | 20/20 全程 `alive=True`，0 断言 / 0 连接错误 |

修复项：`AppDelegate.cpp` frame 720→640、关闭 Debug FPS、
`CCMenu::onTouchBegan` 移除 `_touchArea` 阻断、`CCScrollViewCompat::init()`
补 `setSwallowTouches(false)`、`MainPage` 多余 `setContentSize` 注释。

**新增已知残留 1 项**（合并计为 2 个按钮）：主城阵容头像 1 / 空位加号点击无响应，
68 点密集扫描 `TOTAL_HITS=0`，定位到 `framedButton.ccbi` 动态菜单项在
`ui::ScrollView` innerContainer 下的 `getItemForTouch` 不命中，属引擎命中链问题，
不在本轮安全修复范围内。替代操作路径两端一致。

审计口径现已扩展为四层：逐页不崩溃 / 关键链路功能验收 / 全量功能入口静态对照 /
**同坐标真机点击 A/B 对照**。前三层「无缺失」不等于第四层「操作一致」。
