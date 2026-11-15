# -*- coding: utf-8 -*-
"""
功能一致性补丁（幂等）：把老工程有、新工程迁移时丢失的行为按 3.x 等价接口补回。

1) 3 处 `CCTargetedTouchHandler::setSwallowsTouches(false)`
   （AdventureContinuePage / AdventureInvitePage / LevelUpRewardPage）
   → 3.x `ui::Widget::setSwallowTouches(false)`。
2) LevelUpRewardPage 的 `setBounceable(false)` → 兼容层同名接口。
3) InstructionManager 4 处 `CCApplication::purgeCachedData()`（迁移时写成 `(void)0;`）
   → 3.x `Director::purgeCachedData()`（已核对 2.x/3.x 实现语义等价）。
4) FightPage 中重复的一次纹理回收调用 → 改为等价说明注释（2.x 两次调用等价）。
5) LoadingFrame 密码错误提示 → 走语言表 `@LoadingFrameSeversConnectionPasswordWrong`，
   与老工程文案/多语言行为一致。

注意：前 3 个文件含 GBK 字节，必须按 bytes 处理，不能用 UTF-8 文本读写。
用法：python tools/patch/patch_parity_fixes.py
"""
from __future__ import print_function

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLASSES = os.path.join(ROOT, "client", "Classes")


def load(rel):
    with open(os.path.join(CLASSES, rel), "rb") as f:
        return f.read()


def save(rel, data):
    with open(os.path.join(CLASSES, rel), "wb") as f:
        f.write(data)


def patch(rel, old, new, marker, count=1):
    p = os.path.join(CLASSES, rel)
    if not os.path.isfile(p):
        print("  [SKIP] %s (文件不存在)" % rel)
        return
    data = load(rel)
    if marker in data:
        print("  [SKIP] %s (已打过补丁)" % rel)
        return
    n = data.count(old)
    if n == 0:
        print("  [FAIL] %s (未找到目标片段)" % rel)
        sys.exit(1)
    data = data.replace(old, new, count)
    save(rel, data)
    print("  [OK]   %s (替换 %d 处，共匹配 %d 处)" % (rel, count, n))


# --- 1) 3 处滚动视图触摸语义 -------------------------------------------------
TOUCH_LINES = (
    b"\t// [parity] 2.x CCTargetedTouchHandler::setSwallowsTouches(false)\r\n"
    b"\t//  -> 3.x ui::Widget::setSwallowTouches(false); ScrollView does not swallow,\r\n"
    b"\t//     inner menus keep receiving touches (scene-graph priority dispatch).\r\n"
)

patch("AdventureContinuePage.cpp",
      b"\t//--end\r\n\tmembersRootNode = mContent->getContainer();",
      b"\t//--end\r\n" + TOUCH_LINES +
      b"\tif (mContent) { mContent->setSwallowTouches(false); }\r\n"
      b"\tmembersRootNode = mContent->getContainer();",
      b"[parity] 2.x CCTargetedTouchHandler")

patch("AdventureInvitePage.cpp",
      b"\t//--end\r\n\tmembersRootNode = mContent->getContainer();",
      b"\t//--end\r\n" + TOUCH_LINES +
      b"\tif (mContent) { mContent->setSwallowTouches(false); }\r\n"
      b"\tmembersRootNode = mContent->getContainer();",
      b"[parity] 2.x CCTargetedTouchHandler")

patch("LevelUpRewardPage.cpp",
      b"\t//--end\r\n\tmembersRootNode = levelUpContent->getContainer();",
      b"\t//--end\r\n" + TOUCH_LINES +
      b"\tif (levelUpContent)\r\n"
      b"\t{\r\n"
      b"\t\tlevelUpContent->setSwallowTouches(false);\r\n"
      b"\t\tlevelUpContent->setBounceable(false);\r\n"
      b"\t}\r\n"
      b"\tmembersRootNode = levelUpContent->getContainer();",
      b"[parity] 2.x CCTargetedTouchHandler")

# --- 2) 纹理回收 -------------------------------------------------------------
# 只替换字面量，保留原缩进与换行；替换后的调用串本身即幂等 marker
patch("InstructionManager.cpp",
      b"(void)0;",
      b"cocos2d::Director::getInstance()->purgeCachedData();",
      b"cocos2d::Director::getInstance()->purgeCachedData();",
      count=4)

patch("FightPage.cpp",
      b"        (void)0;\r\n\t\tcocos2d::Director::getInstance()->purgeCachedData();",
      b"        // [parity] 2.x CCApplication::purgeCachedData() + CCDirector::purgeCachedData()\r\n"
      b"        //  are the same cleanup; 3.x only needs the single call below.\r\n"
      b"\t\tcocos2d::Director::getInstance()->purgeCachedData();",
      b"[parity] 2.x CCApplication::purgeCachedData")

# --- 3) 登录错误提示走语言表 -------------------------------------------------
OLD_LOGIN = (b'\t\t\thaizei_showLoginUi("\\xE5\\xAF\\x86\\xE7\\xA0\\x81\\xE9\\x94\\x99'
             b'\\xE8\\xAF\\xAF\\xEF\\xBC\\x8C\\xE8\\xAF\\xB7\\xE9\\x87\\x8D\\xE6\\x96'
             b'\\xB0\\xE8\\xBE\\x93\\xE5\\x85\\xA5");')
NEW_LOGIN = (b'\t\t\t// [parity] use the same localized string as the 2.x build\r\n'
             b'\t\t\tstd::string out = Language::Get()->getString("@LoadingFrameSeversConnectionPasswordWrong");\r\n'
             b'\t\t\thaizei_showLoginUi(out.c_str());')
patch("LoadingFrame.cpp", OLD_LOGIN, NEW_LOGIN, b"[parity] use the same localized string")

print("完成。建议随后重新构建 Debug 并实跑回归。")
