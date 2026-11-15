"""检查 cocos2d-x 3.17.2 引擎里是否存在我们需要的替代符号。"""
import os
import re
import sys

ENGINE = r"E:\PCGame\Haizeiwang\engine\cocos2d-x"
SCAN_DIRS = [os.path.join(ENGINE, "cocos"), os.path.join(ENGINE, "extensions")]

# 待验证的 2.x -> 3.x 目标符号
TARGETS = [
    "LabelTTF", "LabelBMFont", "Label", "Sprite", "SpriteFrameCache", "TextureCache",
    "Layer", "LayerColor", "Scene", "Node", "Director", "MenuItem", "MenuItemImage",
    "MenuItemSprite", "MenuItemLabel", "MenuItemToggle", "Menu", "ScrollView",
    "TableView", "TableViewCell", "Scale9Sprite", "EditBox", "ControlButton",
    "Control", "NotificationCenter", "__NotificationCenter", "UserDefault", "FileUtils",
    "Scheduler", "SimpleAudioEngine", "Animation", "AnimationCache", "Animate",
    "CallFunc", "CallFuncN", "Sequence", "Spawn", "MoveTo", "MoveBy", "ScaleTo",
    "RotateBy", "FadeIn", "FadeOut", "TintTo", "Blink", "DelayTime", "RepeatForever",
    "EaseIn", "EaseOut", "ProgressTo", "SkewTo", "JumpBy", "BezierTo", "OrbitCamera",
    "SpriteBatchNode", "ParticleSystemQuad", "CCBReader", "NodeLoaderLibrary",
    "GLView", "Vector", "Map", "String", "Point", "Size", "Rect", "Color3B",
]

MACROS = [
    "menu_selector", "CC_SCHEDULE_SELECTOR", "schedule_selector", "ccp", "ccc3",
    "CCPoint", "CCSize", "CCRect", "CCLabelTTF", "CCSprite", "CCDirector", "CCNode",
    "CCLayer", "CCScene", "CCMenu", "CCArray", "CCString", "CCDictionary",
    "CCLOG", "CCAssert", "CC_SAFE_RELEASE", "CC_SAFE_DELETE", "CCARRAY_FOREACH",
    "CC_SYNTHESIZE", "USING_NS_CC", "NS_CC_BEGIN", "CocosDenshion", "CCFileUtils",
    "CCUserDefault", "CCEGLView", "SimpleAudioEngine",
]

def collect_text():
    buf = []
    for root in SCAN_DIRS:
        for dirpath, _, files in os.walk(root):
            for f in files:
                if f.endswith((".h", ".cpp", ".hpp", ".inl")):
                    p = os.path.join(dirpath, f)
                    try:
                        with open(p, "r", encoding="utf-8", errors="ignore") as fh:
                            buf.append(fh.read())
                    except OSError:
                        pass
    return "\n".join(buf)

def main():
    text = collect_text()
    print("engine text chars = %d" % len(text))
    print("\n== classes ==")
    for t in TARGETS:
        found = re.search(r"\b(class|struct)\s+" + re.escape(t) + r"\b", text) is not None
        print(("  OK    " if found else "  MISS  ") + t)
    print("\n== macros / free functions ==")
    for m in MACROS:
        found = re.search(r"#\s*define\s+" + re.escape(m) + r"\b", text) is not None
        if not found:
            found = re.search(r"\btypedef\b[^;\n]*\b" + re.escape(m) + r"\b", text) is not None
        print(("  OK    " if found else "  MISS  ") + m)

if __name__ == "__main__":
    sys.exit(main())
