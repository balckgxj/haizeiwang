"""
cocos2d-x 2.1.3 -> 3.17.2 源码自动迁移工具（只改新工程 E:\\PCGame\\Haizeiwang）

用法:
    python migrate.py            # 应用规则
    python migrate.py --check    # 只扫描剩余 2.x 特征，不修改
    python migrate.py --dry      # 打印将要发生的变化

规则分两类:
    A. 引擎单例 / 静态工厂改名（语义确定，可安全批量替换）
    B. 无法确定语义的，只在 --check 中列出，交人工处理
"""
import os
import re
import sys
import json
from collections import Counter, OrderedDict

ROOT = r"E:\PCGame\Haizeiwang"
TARGET_DIRS = [os.path.join(ROOT, "client", "Classes"),
               os.path.join(ROOT, "client", "Platform")]
LOG = os.path.join(ROOT, "tools", "migrate", "migrate_report.json")

# ---------------------------------------------------------------------------
# A 类规则: (名称, 正则, 替换)
# ---------------------------------------------------------------------------
RULES = [
    # ---- 单例 ----
    ("app_instance",      r"CCApplication::sharedApplication\(\)",
                          r"cocos2d::Application::getInstance()"),
    ("director",          r"CCDirector::sharedDirector\(\)",
                          r"cocos2d::Director::getInstance()"),
    ("fileutils",         r"CCFileUtils::sharedFileUtils\(\)",
                          r"cocos2d::FileUtils::getInstance()"),
    ("userdefault",       r"CCUserDefault::sharedUserDefault\(\)",
                          r"cocos2d::UserDefault::getInstance()"),
    ("texturecache",      r"CCTextureCache::sharedTextureCache\(\)",
                          r"cocos2d::Director::getInstance()->getTextureCache()"),
    ("spriteframecache",  r"CCSpriteFrameCache::sharedSpriteFrameCache\(\)",
                          r"cocos2d::SpriteFrameCache::getInstance()"),
    ("animationcache",    r"CCAnimationCache::sharedAnimationCache\(\)",
                          r"cocos2d::AnimationCache::getInstance()"),
    ("notifycenter",      r"CCNotificationCenter::sharedNotificationCenter\(\)",
                          r"cocos2d::__NotificationCenter::getInstance()"),
    ("scheduler",         r"CCScheduler::sharedScheduler\(\)",
                          r"cocos2d::Director::getInstance()->getScheduler()"),
    ("scriptengine",      r"CCScriptEngineManager::sharedManager\(\)",
                          r"cocos2d::ScriptEngineManager::getInstance()"),
    ("glview",            r"CCEGLView::sharedOpenGLView\(\)",
                          r"cocos2d::Director::getInstance()->getOpenGLView()"),
    ("audio",             r"SimpleAudioEngine::sharedEngine\(\)",
                          r"SimpleAudioEngine::getInstance()"),

    # ---- 精灵 ----
    ("sprite_file",       r"\bCCSprite::spriteWithFile\(",
                          r"cocos2d::Sprite::create("),
    ("sprite_fn",         r"\bCCSprite::spriteWithSpriteFrameName\(",
                          r"cocos2d::Sprite::createWithSpriteFrameName("),
    ("sprite_frame",      r"\bCCSprite::spriteWithSpriteFrame\(",
                          r"cocos2d::Sprite::createWithSpriteFrame("),
    ("sprite_tex",        r"\bCCSprite::spriteWithTexture\(",
                          r"cocos2d::Sprite::createWithTexture("),
    ("sprite_node",       r"\bCCSprite::node\(\)", r"cocos2d::Sprite::create()"),

    # ---- 文本 ----
    ("lblttf",            r"\bCCLabelTTF::labelWithString\(",
                          r"cocos2d::LabelTTF::create("),
    ("lblbmfont",         r"\bCCLabelBMFont::labelWithString\(",
                          r"cocos2d::LabelBMFont::create("),

    # ---- 菜单项 ----
    ("mi_image",          r"\bCCMenuItemImage::itemWithNormalImage\(",
                          r"cocos2d::MenuItemImage::create("),
    ("mi_sprite",         r"\bCCMenuItemSprite::itemWithNormalSprite\(",
                          r"cocos2d::MenuItemSprite::create("),
    ("mi_toggle",         r"\bCCMenuItemToggle::itemWithTarget\(",
                          r"cocos2d::MenuItemToggle::createWithTarget("),

    # ---- 节点/场景 ----
    ("node_node",         r"\bCCNode::node\(\)",  r"cocos2d::Node::create()"),
    ("scene_node",        r"\bCCScene::node\(\)", r"cocos2d::Scene::create()"),
    ("layer_node",        r"\bCCLayer::node\(\)", r"cocos2d::Layer::create()"),
    ("menu_node",         r"\bCCMenu::node\(\)",  r"cocos2d::Menu::create()"),
    ("colorlayer",        r"\bCCLayerColor::colorLayerWithColor\(",
                          r"cocos2d::LayerColor::create("),

    # ---- 资源 ----
    ("frame_tex",         r"\bCCSpriteFrame::frameWithTexture\(",
                          r"cocos2d::SpriteFrame::createWithTexture("),
    ("anim_frames",       r"\bCCAnimation::animationWithFrames\(",
                          r"cocos2d::Animation::createWithSpriteFrames("),
    ("animate",           r"\bCCAnimate::actionWithAnimation\(",
                          r"cocos2d::Animate::create("),

    # ---- 动作工厂 ----
    ("actions",           r"\bCC(MoveTo|MoveBy|ScaleTo|ScaleBy|RotateTo|RotateBy|SkewTo|SkewBy|"
                          r"JumpTo|JumpBy|BezierTo|BezierBy|Blink|DelayTime|FadeIn|FadeOut|FadeTo|"
                          r"TintTo|TintBy|Sequence|Spawn|Repeat|RepeatForever|EaseIn|EaseOut|"
                          r"EaseInOut|EaseSineIn|EaseSineOut|EaseBackIn|EaseBackOut|ProgressTo|"
                          r"ProgressFromTo|Hide|Show|ToggleVisibility|Place|FlipX|FlipY|OrbitCamera|"
                          r"CardinalSplineTo|CardinalSplineBy|CatmullRomTo|CatmullRomBy)::"
                          r"(actionWithDuration|actionWithAction|actions|actionWithSize|actionOneTwo)\(",
                          r"cocos2d::\1::create("),
    ("callfunc",          r"\bCCCallFunc::actionWithTarget\(", r"cocos2d::CallFunc::create("),
    ("callfuncn",         r"\bCCCallFuncN::actionWithTarget\(", r"cocos2d::CallFuncN::create("),

    # ---- 老代码里的错误写法 / 与 3.x typedef 冲突的前向声明 ----
    # GamePrecedure.cpp 等文件里写成 cocos2d::cocos2d::Xxx
    ("double_ns",         r"\bcocos2d::cocos2d::", r"cocos2d::"),
    # 3.x 的 ScriptEngineProtocol 没有 2.x 的 executeEvent / executeGlobalFunctionByName
    ("scriptengine_cast", r"ScriptEngineManager::getInstance\(\)->getScriptEngine\(\)->executeEvent\(",
                          r"((cocos2d::CCLuaEngine*)cocos2d::ScriptEngineManager::getInstance()->getScriptEngine())->executeEvent("),
    ("scriptengine_cast2", r"ScriptEngineManager::getInstance\(\)->getScriptEngine\(\)->executeGlobalFunctionByName\(",
                           r"((cocos2d::CCLuaEngine*)cocos2d::ScriptEngineManager::getInstance()->getScriptEngine())->executeGlobalFunctionByName("),
    # 2.x 的扩展头路径已不存在，统一改成 cocos2d.h
    ("inc_pointext",      r'#include\s*"support/CCPointExtension\.h"', r'#include "cocos2d.h"'),
    ("inc_particle",      r'#include\s*"particle_nodes/CCParticleSystemQuad\.h"', r'#include "2d/CCParticleSystemQuad.h"'),

    # ---- 回调：2.x 的 selector 宏 → 3.x 的 CC_CALLBACK_n ----
    ("callfuncN",         r"CallFuncN::create\(\s*this\s*,\s*callfuncN_selector\((\w+::\w+)\)\s*\)",
                          r"cocos2d::CallFuncN::create(CC_CALLBACK_1(\1, this))"),
    ("callfunc0",         r"CallFunc::create\(\s*this\s*,\s*callfunc_selector\((\w+::\w+)\)\s*\)",
                          r"cocos2d::CallFunc::create(CC_CALLBACK_0(\1, this))"),

    # ---- 容器接口 ----
    ("vec_count",         r"->getChildren\(\)->count\(\)", r"->getChildren().size()"),
    ("vec_count2",        r"(childern|children)->count\(\)", r"\1.size()"),
    ("single_ref",        r"->isSingleReference\(\)", r"->getReferenceCount() == 1"),

    # 3.x 的 CCDeprecated.h 用 typedef 定义了 CCNode/CCSprite，
    # 老文件里的 namespace cocos2d { class CCNode; } 前向声明会与之冲突 → 删掉
    ("fwd_decl",          r"(?s)namespace\s+cocos2d\s*\{[^{}]*?\bclass\s+CC\w+\s*;[^{}]*?\}\s*;?",
                          r"// [migrate] removed forward declaration conflicting with 3.x typedef"),
]

# B 类：需要人工确认的特征
CHECK_PATTERNS = OrderedDict([
    ("CCScale9Sprite",          r"CCScale9Sprite"),
    ("CCControlButton",         r"CCControlButton"),
    ("CCTableView",             r"CCTableView"),
    ("setHandlerPriority",      r"->setHandlerPriority\("),
    ("CCArray 旧接口",            r"->objectAtIndex\(|->count\(\)|CCARRAY_FOREACH"),
    ("CCDictionary 旧接口",       r"->objectForKey\(|->setObject\("),
    ("CCFileUtils 读文件",        r"->getFileData\(|->getFileDataFromZip\("),
    ("CCUserDefault 旧接口",      r"setBoolForKey|getBoolForKey|setIntegerForKey|getIntegerForKey"),
    ("CCEditBox",               r"CCEditBox"),
    ("ScheduleSelector",        r"scheduleSelector\(|unscheduleSelector\("),
    ("CCBReader",               r"CCBReader"),
    ("Lua",                     r"CCLuaEngine|CCScriptEngineManager|tolua|lua_State"),
    ("libOS",                   r"libOS\.h"),
    ("lib91/libPlatform",       r"lib91\.h|libPlatform\.h"),
    ("Curl",                    r"curl/curl\.h|CurlDownload"),
    ("pthread",                 r"pthread"),
])


def iter_files():
    for d in TARGET_DIRS:
        for f in sorted(os.listdir(d)):
            if f.endswith((".cpp", ".h", ".cc")):
                yield os.path.join(d, f)


def apply_rules(dry=False):
    report = Counter()
    per_file = {}
    hits_total = 0
    for p in iter_files():
        with open(p, "r", encoding="gbk", errors="surrogateescape", newline="") as fh:
            text = fh.read()
        orig = text
        file_hits = Counter()
        for name, pat, repl in RULES:
            text, n = re.subn(pat, repl, text)
            if n:
                file_hits[name] += n
                hits_total += n
        if text != orig:
            report.update(file_hits)
            per_file[os.path.relpath(p, ROOT)] = dict(file_hits)
            if not dry:
                with open(p, "w", encoding="gbk", errors="surrogateescape", newline="") as fh:
                    fh.write(text)
    return hits_total, report, per_file


def check_remaining():
    res = {}
    for p in iter_files():
        with open(p, "r", encoding="gbk", errors="surrogateescape") as fh:
            lines = fh.readlines()
        for i, line in enumerate(lines, 1):
            for name, pat in CHECK_PATTERNS.items():
                if re.search(pat, line):
                    res.setdefault(name, []).append(
                        "%s:%d: %s" % (os.path.basename(p), i, line.strip()[:160]))
    return res


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "--check":
        res = check_remaining()
        for k, v in res.items():
            print("\n== %s (%d) ==" % (k, len(v)))
            for line in v[:6]:
                print("   " + line)
            if len(v) > 6:
                print("   ...")
        return

    total, report, per_file = apply_rules(dry=(mode == "--dry"))
    print("替换总数: %d" % total)
    for k, v in report.most_common():
        print("  %-22s %d" % (k, v))
    print("涉及文件: %d" % len(per_file))
    with open(LOG, "w", encoding="utf-8") as fh:
        json.dump({"total": total, "rules": dict(report), "files": per_file},
                  fh, ensure_ascii=False, indent=1)
    print("报告: " + LOG)


if __name__ == "__main__":
    main()
