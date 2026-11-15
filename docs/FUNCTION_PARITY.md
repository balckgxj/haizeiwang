# Haizeiwang 老 / 新工程功能逐项一致性核对报告

> 核对时间：2026-11-14　对象：cocos2d-x 2.1.3 原版 → 3.17.2 移植版（Win32 Debug）
> 目的：把「能不能跑」升级为「每一项操作是否与老工程一致」。

---

## 一、口径与判定标准

| 项 | 内容 |
|---|---|
| 老工程 | `E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\client\Game`（`Classes/` 416 文件、`proj.android/.../assets/` 1772 资源） |
| 新工程 | `E:\PCGame\Haizeiwang\client`（`Classes/` 418 文件、`Resources/` 1798 资源） |
| 功能项粒度 | 页面注册 / 按钮交互分支 / 页面跳转 / 界面资源(ccbi) / 协议 opcode / 成员函数 / 按钮回调函数体 |
| 「操作一致」定义 | 同一用户操作，两端的**页面跳转、发包、数据变更、界面文本、可见反馈**相同。纯 API 改名、内存优化、空指针加固、仅调试 flag 启用时不改变此项判定 |
| 方法 | ① 全量文件 diff（3712 行）② 功能点集合双向比对 ③ 回调函数体函数级比对 ④ diff hunk 自动分类（API / 行为 / 结构）⑤ 运行抽检 |

可复现工具（本轮新增）：

| 工具 | 作用 |
|---|---|
| `tools/audit_function_parity.py` | 六类功能点双向集合比对 + 全量 diff 导出（`--json` / `--diff`） |
| `tools/audit_page_parity.py` | 115 页逐页功能点、巡检结果、点击覆盖，产出 `parity_table.md` |
| `tools/audit_migration.py` | 既有：文件级覆盖与降级标记扫描 |
| `tools/patch/patch_parity_fixes.py` | 本轮一致性补丁（幂等） |
| `tools/verify_parity.ps1` / `verify_parity_wrongpwd.ps1` / `crop_parity.ps1` | 本轮运行抽检与截图裁剪 |

```bat
python tools\audit_function_parity.py --json --diff
python tools\audit_page_parity.py
python tools\patch\patch_parity_fixes.py
powershell -File tools\verify_parity.ps1
```

---

## 二、全局覆盖结论

| 维度 | 老工程 | 新工程 | 老有新无 | 判定 |
|---|---:|---:|---:|---|
| `Classes` 代码文件 | 416 | 418 | **0** | 新增 `LoginPage.cpp/.h`（账号密码登录页） |
| 完全相同文件 | — | 303 | — | 另 113 个有改动（多为 1~2 行 API 改名） |
| 页面注册 `REGISTER_PAGE` | 115 | 115 | **0** | ✅ 一一对应 |
| 按钮 / 交互分支 `itemName=="…"` | 250 | 250 | **0** | ✅ 一一对应 |
| 页面跳转目标 | 8 | 8 | **0** | ✅ |
| 界面资源 `.ccbi` 引用 | 202 | 202 | **0** | ✅ |
| 成员函数定义 | 2857 | 2871 | 2 | `copyWithZone→clone`、`draw→drawShader`（3.x 接口改名，等价） |
| 按钮回调函数体 | 193 | 193 | — | **190 个逐字一致**，3 个有意变更（见 §4.B） |
| 协议层 Protobuf | 240 文件 | 240 文件 | **0** | ✅ 内容全一致 |
| 协议处理 `PackageLogic.cpp` | 4234 行 | 4234 行 | — | ✅ **MD5 完全相同**（发包/回包逻辑零改动） |
| 资源文件 | 1772 | 1798 | **0** | 新增 26 = 23 张补齐散图 + 3 个本地调试配置 |
| Lua 脚本 `.el` | 90 | 90 | **0** | 两端一致（均为未接入的遗留脚手架） |
| 加密配置表 | 53 | 53 | **0** | 全部可解密，内容一致 |

> 逐页统计的另一口径：按页面文件组累加的按钮分支为 419（含跨页面复用同名分支），全局去重后为 250；两者不矛盾。

**代码差异分类**（`_tools/parity_full.diff`，318 个 hunk）：
`232` 个纯 API 改名（等价）、`74` 个结构性改动（新增校验 / 调试通道 / 稳定性加固）、`12` 个行为改写（逐项见 §4）。
另有 **仅 1 行**「老工程生效、新工程被注释停用」的功能代码：`LoadingFrame` 的密码错误提示，本轮已修回。

---

## 三、逐页功能对照表（115 页）

判据说明：「老→新无缺失」= 该页在老工程出现的页面名、按钮分支、跳转目标、ccbi、方法、功能字符串，在新工程全部存在；「新增项」= 新工程独有（调试通道 / 登录页 / 诊断日志 / 空位加号等），不算不一致。
「115 页巡检」取自 `_tools/page_audit_result.txt`；「真实点击」指本轮或上一轮通过主城按钮真实进入过（非 `goto:` 无上下文直开）。

| # | 页面 | 按钮分支 | ccbi | 方法 | 代码改动 | 老→新无缺失 | 新增项 | 115页巡检 | 真实点击 |
|---:|---|---:|---:|---:|---|---|---|---|---|
| 1 | `AboutPage` | 0 | 2 | 7 | 1 文件 | ✅ | — | ✅ | — |
| 2 | `ActivityPopPage` | 1 | 1 | 7 | — | ✅ | — | ✅ | — |
| 3 | `AdventurePage` | 0 | 2 | 37 | 1 文件 | ✅ | — | ✅ | ✅ |
| 4 | `AnnouncementPage` | 2 | 2 | 16 | — | ✅ | — | ✅ | — |
| 5 | `ArenaBuyChallengePage` | 3 | 1 | 4 | — | ✅ | — | ✅ | — |
| 6 | `ArenaPage` | 6 | 4 | 25 | 1 文件 | ✅ | — | ✅ | ✅ |
| 7 | `ArenaRewardAniPage` | 0 | 1 | 4 | — | ✅ | — | ✅ | — |
| 8 | `ArenaRewardPage` | 3 | 1 | 3 | — | ✅ | — | ✅ | — |
| 9 | `BuyPropInfoPage` | 3 | 1 | 6 | — | ✅ | — | ✅ | — |
| 10 | `BuyPropPopupPage` | 2 | 1 | 10 | — | ✅ | — | ✅ | — |
| 11 | `BuyPropsCountPage` | 7 | 1 | 8 | 1 文件 | ✅ | — | ✅ | — |
| 12 | `BuyPropsPage` | 8 | 3 | 12 | 1 文件 | ✅ | — | ✅ | — |
| 13 | `BuyStoneCountPage` | 7 | 1 | 8 | 1 文件 | ✅ | — | ✅ | — |
| 14 | `BuyStonePopupPage` | 6 | 2 | 13 | — | ✅ | — | ✅ | — |
| 15 | `BuyToolAlertPage` | 2 | 1 | 7 | — | ✅ | — | ✅ | — |
| 16 | `CDKeyInvitePage` | 4 | 1 | 9 | — | ✅ | — | ✅ | — |
| 17 | `CDKeyMsgPage` | 5 | 1 | 9 | — | ✅ | — | ✅ | — |
| 18 | `CareerPage` | 7 | 6 | 27 | 1 文件 | ✅ | — | ✅ | ✅ |
| 19 | `CareerQuickResultPage` | 2 | 2 | 9 | — | ✅ | — | ✅ | — |
| 20 | `CareerStoryPage` | 1 | 1 | 6 | 1 文件 | ✅ | — | ✅ | — |
| 21 | `ChangeNamePage` | 4 | 1 | 11 | 1 文件 | ✅ | — | ✅ | — |
| 22 | `ChatPage` | 2 | 1 | 15 | — | ✅ | — | ✅ | — |
| 23 | `ContinueLoginPage` | 3 | 2 | 23 | 1 文件 | ✅ | — | ✅ | — |
| 24 | `DiscipleChangePage` | 4 | 3 | 19 | 1 文件 | ✅ | — | ✅ | — |
| 25 | `DiscipleHandInfoPage` | 4 | 1 | 8 | — | ✅ | — | ✅ | — |
| 26 | `DiscipleInfoPage` | 4 | 1 | 6 | — | ✅ | — | ✅ | — |
| 27 | `DisciplePage` | 7 | 4 | 23 | 1 文件 | ✅ | — | ✅ | ✅ |
| 28 | `DiscipleRecruitPage` | 2 | 2 | 8 | — | ✅ | — | ✅ | — |
| 29 | `DiscipleUpgradePage` | 2 | 1 | 8 | 1 文件 | ✅ | — | ✅ | — |
| 30 | `DiscipleViewTeamInfoPage` | 4 | 1 | 8 | — | ✅ | — | ✅ | — |
| 31 | `EmbattlePage` | 4 | 2 | 13 | 1 文件 | ✅ | — | ✅ | — |
| 32 | `EquipChangePage` | 3 | 2 | 20 | 1 文件 | ✅ | — | ✅ | — |
| 33 | `EquipEnhanceAniPage` | 0 | 1 | 4 | — | ✅ | — | ✅ | — |
| 34 | `EquipEnhancePage` | 3 | 1 | 8 | 1 文件 | ✅ | — | ✅ | — |
| 35 | `EquipEnhanceResultPage` | 3 | 1 | 9 | 1 文件 | ✅ | — | ✅ | — |
| 36 | `EquipHandInfoPage` | 4 | 1 | 8 | — | ✅ | — | ✅ | — |
| 37 | `EquipInfoPage` | 5 | 3 | 12 | — | ✅ | — | ✅ | — |
| 38 | `EquipPage` | 9 | 5 | 26 | 1 文件 | ✅ | — | ✅ | ✅ |
| 39 | `EquipQuickEnhancePage` | 2 | 1 | 6 | — | ✅ | — | ✅ | — |
| 40 | `EquipSellPage` | 2 | 2 | 20 | 1 文件 | ✅ | — | ✅ | — |
| 41 | `EquipSurprisePage` | 4 | 1 | 6 | — | ✅ | — | ✅ | — |
| 42 | `FightEndPopupPage` | 2 | 1 | 7 | — | ✅ | — | ✅ | — |
| 43 | `FightEndRankPage` | 5 | 2 | 20 | 1 文件 | ✅ | — | ✅ | — |
| 44 | `FightGuidePage` | 3 | 3 | 9 | — | ✅ | — | ✅ | — |
| 45 | `FightPage` | 6 | 12 | 68 | 4 文件 | ✅ | — | ✅ | ✅ |
| 46 | `FortuneComeReward` | 2 | 1 | 6 | — | ✅ | — | ✅ | — |
| 47 | `FriendsDetailPopupPage` | 7 | 1 | 10 | — | ✅ | — | ✅ | — |
| 48 | `FriendsPage` | 11 | 2 | 29 | 1 文件 | ✅ | — | ✅ | — |
| 49 | `GiftPreviewPage` | 2 | 2 | 11 | — | ✅ | — | ✅ | — |
| 50 | `GoodsPopupPage` | 2 | 1 | 8 | — | ✅ | — | ✅ | — |
| 51 | `GuideBuyEquipPage` | 1 | 1 | 9 | — | ✅ | — | ✅ | — |
| 52 | `GuideBuyExpPage` | 1 | 1 | 9 | — | ✅ | — | ✅ | — |
| 53 | `GuideRechargePage` | 1 | 1 | 9 | — | ✅ | — | ✅ | — |
| 54 | `HandbookPage` | 4 | 2 | 28 | 1 文件 | ✅ | — | ✅ | ✅ |
| 55 | `HelpPage` | 0 | 2 | 7 | — | ✅ | — | ✅ | — |
| 56 | `LeaveMsgPage` | 5 | 1 | 10 | 1 文件 | ✅ | — | ✅ | — |
| 57 | `LoadingFrame` | 3 | 3 | 31 | 1 文件 | ✅ | 有 | ✅ | — |
| 58 | `MainFrame` | 9 | 1 | 27 | 2 文件 | ✅ | 有 | ✅ | — |
| 59 | `MainPage` | 20 | 2 | 11 | 1 文件 | ✅ | 有 | ✅ | ✅ |
| 60 | `MarketPage` | 10 | 1 | 12 | 1 文件 | ✅ | — | ✅ | — |
| 61 | `MemberPage` | 5 | 2 | 11 | 1 文件 | ✅ | — | ✅ | ✅ |
| 62 | `NewActivePromptPage` | 1 | 1 | 7 | — | ✅ | — | ✅ | — |
| 63 | `NewActivePromptToolPage` | 1 | 1 | 6 | — | ✅ | — | ✅ | — |
| 64 | `ObtainSkillBookPage` | 2 | 1 | 8 | — | ✅ | — | ✅ | — |
| 65 | `PackPreviewPage` | 2 | 2 | 20 | 1 文件 | ✅ | — | ✅ | — |
| 66 | `PackagePage` | 5 | 3 | 17 | 1 文件 | ✅ | — | ✅ | ✅ |
| 67 | `PlayerInfPage` | 1 | 1 | 9 | 2 文件 | ✅ | — | ✅ | — |
| 68 | `PlayerUpgradePage` | 0 | 1 | 5 | — | ✅ | — | ✅ | — |
| 69 | `PopUpSurprisePage` | 1 | 1 | 6 | — | ✅ | — | ✅ | — |
| 70 | `Popup1stPayTipPage` | 1 | 1 | 9 | 1 文件 | ✅ | — | ✅ | — |
| 71 | `PopupNotEnoughPage` | 3 | 1 | 8 | — | ✅ | — | ✅ | — |
| 72 | `PopupPage` | 4 | 1 | 10 | 1 文件 | ✅ | — | ✅ | — |
| 73 | `PropInfoPage` | 4 | 2 | 19 | 1 文件 | ✅ | — | ✅ | — |
| 74 | `PropUpPage` | 4 | 1 | 6 | — | ✅ | — | ✅ | — |
| 75 | `RechargePage` | 2 | 3 | 10 | 1 文件 | ✅ | — | ✅ | — |
| 76 | `SettingsPage` | 12 | 2 | 10 | 1 文件 | ✅ | — | ✅ | ✅ |
| 77 | `SkillBookLootPage` | 2 | 3 | 22 | 2 文件 | ✅ | — | ✅ | — |
| 78 | `SkillBookSurprisePage` | 1 | 1 | 7 | — | ✅ | — | ✅ | — |
| 79 | `SkillChangePage` | 3 | 2 | 20 | 1 文件 | ✅ | — | ✅ | — |
| 80 | `SkillHandInfoPage` | 3 | 1 | 8 | — | ✅ | — | ✅ | — |
| 81 | `SkillInfoPage` | 3 | 1 | 6 | — | ✅ | — | ✅ | — |
| 82 | `SkillPage` | 3 | 3 | 17 | 1 文件 | ✅ | — | ✅ | ✅ |
| 83 | `SkillSurprisePage` | 4 | 1 | 6 | — | ✅ | — | ✅ | — |
| 84 | `SkillUpChoosePage` | 3 | 2 | 20 | 1 文件 | ✅ | — | ✅ | — |
| 85 | `SkillUpgradePage` | 3 | 1 | 10 | 1 文件 | ✅ | — | ✅ | — |
| 86 | `SkillUpgradeResultPage` | 2 | 1 | 7 | 1 文件 | ✅ | — | ✅ | — |
| 87 | `SkillViewTeamInfoPage` | 3 | 1 | 8 | — | ✅ | — | ✅ | — |
| 88 | `SoulInfoPage` | 4 | 1 | 6 | — | ✅ | — | ✅ | — |
| 89 | `StoneInlaidPage` | 8 | 6 | 36 | 1 文件 | ✅ | — | ✅ | — |
| 90 | `StoneUpgradePage` | 6 | 1 | 19 | — | ✅ | — | ✅ | — |
| 91 | `SysMsgPage` | 12 | 2 | 19 | 1 文件 | ✅ | — | ✅ | — |
| 92 | `TeacherTeachResultPage` | 1 | 2 | 15 | 1 文件 | ✅ | 有 | ✅ | — |
| 93 | `TeamBuffPage` | 2 | 2 | 21 | — | ✅ | — | ✅ | — |
| 94 | `TeamBuffUpgradePage` | 3 | 2 | 27 | 1 文件 | ✅ | — | ✅ | — |
| 95 | `TeamPage` | 10 | 5 | 34 | 1 文件 | ✅ | — | ✅ | — |
| 96 | `TitleGetNewPage` | 2 | 1 | 7 | 1 文件 | ✅ | — | ✅ | — |
| 97 | `TitleInfoPage` | 1 | 1 | 6 | — | ✅ | — | ✅ | — |
| 98 | `TitleLVUpPage` | 2 | 1 | 6 | 1 文件 | ✅ | — | ✅ | — |
| 99 | `TitlePage` | 0 | 2 | 8 | 1 文件 | ✅ | — | ✅ | — |
| 100 | `TrainPage` | 6 | 1 | 9 | 1 文件 | ✅ | — | ✅ | — |
| 101 | `TrainResultPage` | 2 | 1 | 8 | 1 文件 | ✅ | — | ✅ | — |
| 102 | `TrainingBolusChoosePage` | 2 | 2 | 10 | 1 文件 | ✅ | — | ✅ | — |
| 103 | `TranExpChooseMemberPage` | 3 | 2 | 20 | 1 文件 | ✅ | — | ✅ | — |
| 104 | `TranExpPreviewPage` | 4 | 1 | 12 | 1 文件 | ✅ | — | ✅ | — |
| 105 | `TranExpResultPage` | 3 | 1 | 11 | 1 文件 | ✅ | — | ✅ | — |
| 106 | `TransferEXPPage` | 3 | 1 | 7 | 1 文件 | ✅ | — | ✅ | — |
| 107 | `VIPPrivilegePage` | 1 | 4 | 20 | — | ✅ | — | ✅ | — |
| 108 | `ViewListTeamPage` | 4 | 3 | 22 | — | ✅ | — | ✅ | — |
| 109 | `ViewTeamEquipInfoPage` | 4 | 3 | 13 | — | ✅ | — | ✅ | — |
| 110 | `ViewTeamPage` | 9 | 4 | 28 | 1 文件 | ✅ | — | ✅ | — |
| 111 | `WorldBossFight` | 0 | 1 | 6 | — | ✅ | — | ✅ | — |
| 112 | `WorldBossFightEnd` | 3 | 2 | 15 | 1 文件 | ✅ | — | ✅ | — |
| 113 | `WorldBossGiftPreviewPage` | 2 | 2 | 12 | — | ✅ | — | ✅ | — |
| 114 | `WorldBossJoinBattle` | 4 | 2 | 32 | 1 文件 | ✅ | — | ✅ | — |
| 115 | `WorldBossRankPage` | 2 | 2 | 14 | 1 文件 | ✅ | — | ✅ | — |

**汇总：115 / 115 页功能点无缺失，115 / 115 页运行巡检通过。**

---

## 四、差异逐项清单

### A. 本轮修复（老工程有、新工程迁移时丢失的行为）

| # | 位置 | 老工程行为 | 迁移后 | 本轮处置 |
|---|---|---|---|---|
| A1 | `AdventureContinuePage` / `AdventureInvitePage` / `LevelUpRewardPage` 的 `changeRewardStatus()` | 用 `CCTargetedTouchHandler::setSwallowsTouches(false)` 让滚动视图不吞触摸，内层奖励按钮可点 | 3 段共 37 行被整段删除，仅留「改由遮罩层处理」注释但无实现 | 按 3.x 等价接口补回 `ui::Widget::setSwallowTouches(false)`；幂等补丁 |
| A2 | `LevelUpRewardPage` | 同一段里还有 `levelUpContent->setBounceable(false)`（关闭回弹） | 一并删除 | 用兼容层 `CCScrollView::setBounceable(false)` 补回 |
| A3 | `InstructionManager.cpp` 4 处 | `CCApplication::purgeCachedData()` 在引导步骤切换时回收纹理 | 写成 `(void)0;`，纹理回收完全消失 | 改为 `Director::purgeCachedData()`。已核对 2.x `CCDirector::purgeCachedData()` 与 3.x 实现语义一致（FNT 缓存 + `removeUnusedTextures` + `purgeCachedEntries`） |
| A4 | `FightPage.cpp` | `CCApplication::purgeCachedData()` + `CCDirector::purgeCachedData()` 连续两次 | 第一处 `(void)0;` | 2.x 两次为同一清理，3.x 保留一次即可；改为等价说明注释 |
| A5 | `LoadingFrame.cpp` 登录 status 6 | 弹语言表 `@LoadingFrameSeversConnectionPasswordWrong`（「密码错误」） | 改硬编码 UTF-8 中文，且脱离多语言体系 | 改回 `Language::Get()->getString(...)`，文案与老工程一致 |

补丁后重新构建：**0 error C / 0 error LNK**（仅第三方 libtiff PDB 警告）。

### B. 有意变更（新流程，不构成不一致）

| # | 项 | 老 → 新 | 原因 |
|---|---|---|---|
| B1 | 登录 | 平台 SDK `lib91::login()` 原生弹框 + 自动重发 → 游戏内 `LoginPage` 账号密码页 + 提交后重发 | Win32 无 SDK；账号密码体系与 GM 打通的既定改造 |
| B2 | GM 权限 | `LeaveMsgPage` 里 `#ifdef _DEBUG` 无条件放行 → `BlackBoard::isGM`（服务端登录回包下发 + 服务端二次校验） | 白名单鉴权加固 |
| B3 | 更新检查 | 走远端 version.cfg → 本地模式读 `localSevers.json` 并跳过 | 本地联调必需 |
| B4 | 调试通道 | 无 → `MainFrame::_setupDebugPageKeys()`（数字键 / `goto:` `push:` `pop:` `back` `quit`） | 仅 `haizei_debug_pages.flag` / `haizei_debug_cmd.txt` 存在时启用，正常玩家不可达 |
| B5 | 主城阵容空位 | 无 → 空位显示「+」 | 第五轮 UI 修复 |
| B6 | Win32 生命周期 | 最小化暂停动画 → Win32 分支直接 `return` | 桌面端最小化不应改变游戏状态 |
| B7 | 稳定性加固 | — | `CareerStoryPage` / `BoundlessHolePage` / `BuyPropsCountPage` / `MemberPage` / `SkillChangePage` / `StoneInlaidPage` / `TeamBuffUpgradePage` / `TranExpChooseMemberPage` / `FightPage_roundState` 等加空指针与上下文保护；**正常数据路径行为不变**，仅避免 `goto:` 无上下文直开时崩溃 |
| B8 | `FightPage` 战斗数据 | 只调 `onReceivePacket()->fight()` 未填 `mBattleList` | 补齐数据填充，修复 `xtree(182)` 崩溃 |

### C. 等价适配（无操作差异，已核对实现）

| # | 项 | 2.x → 3.x | 等价依据 |
|---|---|---|---|
| C1 | `NumberChangeAction` | `copyWithZone(CCZone*)` → `clone()` / `reverse()` | 3.x `Ref::copy()` 会 `CC_ASSERT(false)`，clone 是规定替代 |
| C2 | `AsyncSprite` / `LoadingUnit` | `addImageAsync` + `callfuncO_selector` → lambda / `CC_CALLBACK_1` | 同一纹理异步加载回调 |
| C3 | `BoardCastLabel` 跑马灯 | `LabelTTF::setTextureRect` 滚动 → `ClippingNode` + `setPositionX` | 已实测主城无裁剪异常 |
| C4 | 单例 / 文件名 API | `CCDirector::sharedDirector()`、`CCFileUtils::sharedFileUtils()`、`CCUserDefault::sharedUserDefault()`、`particle_nodes/X.h` → `Director::getInstance()`、`2d/X.h` 等 | 纯改名 |
| C5 | `PopupPage` Lua 调用 | `CCScriptEngineManager::sharedManager()` → `ScriptEngineManager::getInstance()` + `CCLuaEngine*` | 两端 Lua 子系统都未接入游戏流程（死代码） |
| C6 | `CCBContainer::loadCcbiFile` | 2.x `CCBReader(library, assigner)` → 3.x 四参构造 + 注册 `CCScrollViewLoader` | 115 页可用性的关键适配 |
| C7 | 滚动菜单协作 | 老代码 26 处 `setScrollViewChild` 被注释 | 兼容层 `CCScrollView::setContainer()` 自动调 `_setChildMenu()`，引擎 `Menu::setScrollViewChild()` 已实现 2.x 语义（不吞触摸 + 视口命中限制），等价 |
| C8 | `AppDelegate` / `FightPage` 纹理回收去重 | 两次 `purgeCachedData` → 一次 | 同一清理调用两次无额外效果 |

### D. 已知残留（非阻断，未在本轮范围硬改）

| # | 项 | 影响 | 状态 |
|---|---|---|---|
| D1 | `SpriteShader::draw` → `drawShader` | 3.x `Node::draw` 为 `final`，自定义 shader 特效不生效 | 上一轮已定位；战斗卡片立绘相关 |
| D2 | `GamePrecedure` 的 `RenderTexture::keepBegin/keepEnd` 删除 | 2.x 扩展接口，3.x 无；影响 `gameSnapshot` 截图内容 | 仅截图特效 |
| D3 | `MainPage` 纹理阈值 `if(false)` | 3.x 无 `getTextrueTotalBytes()`，125MB 阈值回收关闭 | 仅内存占用 |
| D4 | 战斗卡片立绘 + 黑色小方块 | 视觉 | 上一轮遗留：`No file found` 已归零，黑块来自 ccbi 空 `spriteFile` 的 `displayFrame`；需专项查渲染链路 |
| D5 | `SoundManager::unloadEffect` | 两端**都是注释**（老工程本来就没启用） | 无差异 |

### E. 未能实跑触发的分支（两端一致，需特定业务条件）

| # | 项 | 原因 |
|---|---|---|
| E1 | 登录 status 6（密码错误）本地化提示 | 本地 DZM 服务端对错误密码仍返回 `showEnter`，不产生 status 6；已静态核对语言表 key 与调用链，未实跑触发 |
| E2 | `AdventureContinuePage` / `AdventureInvitePage` / `LevelUpRewardPage` 三个奖励弹窗 | **两端都没有 `REGISTER_PAGE`**，是业务流程里创建的子面板；调试通道 `goto:` / `push:` 对它们无效（`getPage` 返回空、静默 return）。本轮 A1/A2 补丁为静态等价恢复，未单独触发 |
| E3 | 成功突破路径、opcode 174 GM 白名单二次鉴权 | 需影子数据 / 白名单配置，沿用既有记录 |

---

## 五、运行抽检与证据边界

**构建**：`cmake --build build --config Debug --target Haizeiwang` → `BUILD_EXIT=0`，0 error C/LNK（`_tools/build_parity.log`）。

**本轮实跑**（`tools/verify_parity.ps1`，三服务 + 客户端同会话）：
- MySQL 3306 / Java 25524 / PHP 8080 全部 Listen；
- 客户端启动 → 登录 → **主城视觉确认**：玩家名「冥王」、VIP13、阵容 4 人 + 空位「+」、冒险/远航/决斗/船员/装备/奥义/修行/包裹/图鉴/设置按钮齐全，无黑块错位（`_tools/parity_02_main_city_crop.png`）；
- 3 个已注册页面滚动触摸回归 + 5 条主城真实点击路径（船员 / 冒险 / 远航 / 设置 / 图鉴）：**进程全程存活**；
- 日志：**0 断言、0 `xtree`、0 `connect server error`、0 `SendFailed`**，`FINAL_ALIVE=True`。

非阻断运行噪音：`ERROR: SpriteFrame nullptr` 18 次（ccbi 中空 `spriteFile` 的 `displayFrame`，非资源缺失）；`No file found` 4~5 条全部是引擎占位纹理名 `/__halfCircleImage`、`/__bodyImage`，两端行为相同。

**上一轮已交付证据**（见 `MIGRATION.md` §12、`MIGRATION_AUDIT.md` §12）：115 页逐页巡检 115/115、主城真实点击路径、远航→章节→关卡→战斗→结算链路，结算页「YOU WIN」+ 威 23 / 金币 560 / 船员经验条正常。

> **证据边界（须如实说明）**：本轮发现验证脚本的 `ToScreen()` 把 `GetWindowRect()` 的虚拟坐标与设计坐标直接相加，未统一乘 DPI 1.5；且不同 PowerShell 进程的 DPI awareness 不一致（同一窗口有时报 335×517、有时对应 502×720 物理像素），导致部分点击/拖动落点存在偏差。另外 `goto:` / `push:` 对未注册子面板无效（E2）。
> 因此本轮**只把「进程存活 + 0 断言 + 0 连接错误 + 视觉截图」计入运行结论**，逐按钮点击是否命中不作为功能一致性判据；功能一致性主要由 §2/§3 的静态逐项对照支撑。
> 后续若要做逐按钮自动化，建议：用 `MoveWindow` 把 GL 窗口固定到屏幕内，统一改用**全屏物理像素坐标**（从截图标定），并在每步点击后用日志中的 `load ccbi file:` 做闭环判据。

---

## 六、结论

1. **静态：老工程的每一项功能入口在新工程都有对应**。115 页面 / 250 按钮分支 / 8 跳转 / 202 ccbi / 240 协议文件 / 1772 资源 / 90 Lua 全部零缺失；193 个按钮回调体 190 个逐字一致，剩 3 个是 GM 白名单、API 改名、Lua 死代码。
2. **本轮把 5 类真实行为丢失补回**（滚动触摸、回弹、纹理回收、登录错误文案），构建通过，主链路实跑无崩溃。
3. **剩余差异全部归类和定位**：B 类为有意变更、C 类为等价适配、D 类为已知非阻断残留、E 类为无法实跑触发的分支；没有发现「点同一个按钮、两端结果不同」的未解释项。
4. 需要下一代处理的两件事：修验证工具的 DPI 坐标（§5 证据边界），以及 D1/D4 的战斗卡片渲染链路专项。

---

## 七、复现命令

```bat
:: 静态逐项对照
python tools\audit_function_parity.py --json --diff
python tools\audit_page_parity.py

:: 幂等补丁（已应用，重复执行会跳过）
python tools\patch\patch_parity_fixes.py

:: 构建（需先清代理变量，见 _tools/build_parity.log 对应命令）
cmake --build build --config Debug --target Haizeiwang --parallel 8

:: 运行抽检（服务会随脚本会话结束回收）
powershell -File tools\verify_parity.ps1
powershell -File tools\crop_parity.ps1

:: 本机启动游戏
powershell -File tools\start_local_env.ps1
powershell -File tools\gm_admin\start_gm_admin.ps1
build\Debug\Haizeiwang.exe
```


---

## 附录：同坐标真机 A/B 点击对照（后续轮次）

本报告是**静态功能入口对照**（115 页 / 250 按钮 / 193 回调体），结论为「代码层面无功能缺失」。
后续按用户要求分别运行老 `Game.exe` 与新 `Haizeiwang.exe`，用 DPI 正确的驱动
`tools/ab_lib.ps1` 对主城 20 个按钮跑同一组归一化坐标，发现静态对照看不出的运行期差异：

- 设计区 360×480 vs 320×480（`setFrameSize` 不一致）；
- Debug FPS 条遮挡底部功能栏；
- `CCScrollViewCompat` 的 `_touchArea` 与 3.x 触摸坐标系不匹配，锁死 ScrollView 内按钮。

修复后 **18/20 项逐项对齐**（画面 `diff` 与老版差 ±0.7），主城阵容头像 1 / 空位加号
2 项仍残留。完整方法、逐项表、根因、复现命令见 **`docs/AB_CLICK_PARITY.md`**。

> 静态「无缺失」不等于真机「操作一致」，两份报告需配套阅读。

