"""第八轮：清掉最后一批（56 个）编译错误。

1. CCStdC-win32.h 会 #undef MessageBox → 桥接层改用 ::MessageBoxW / ::MessageBoxA
2. CCTime::gettimeofdayCocos2d 需要返回 int
3. EVNET_COME_TO_FOREGROUND 在 3.x 是 string 型通知名
4. 无命名空间限定的 CCNode* 成员 → cocos2d::Node*
5. ContinueLoginPage：CardContent 的成员回调改成 this 上调用，参数仍传 mCardXxx
6. NumberChangeAction：copyWithZone → clone/reverse
7. SpriteShader：3.x 通知中心签名
8. SkillUpChoosePage：toString(size_t) 重载歧义
9. CCScrollViewCompat：setDirection 被我自己的同名函数遮蔽
"""
import io
import os
import re

D = r"E:\PCGame\Haizeiwang\client\Classes"
B = r"E:\PCGame\Haizeiwang\platform_bridge"
C = r"E:\PCGame\Haizeiwang\client\compat"

def load(p):
    return io.open(p, encoding="gbk", errors="surrogateescape", newline="").read()

def save(p, t):
    io.open(p, "w", encoding="gbk", errors="surrogateescape", newline="").write(t)

log = []

# ---------- 2) 桥接层 MessageBox ----------
for f in ["libPlatform\\win32\\libTB.cpp", "libPlatform\\win32\\lib91.cpp",
          "libPlatform\\win32\\libAG.cpp", "libPlatform\\win32\\libPP.cpp",
          "libOS\\win32\\libOS.cpp"]:
    p = os.path.join(B, f)
    if not os.path.exists(p):
        continue
    t = load(p)
    o = t
    t = t.replace("MessageBox(0,L", "::MessageBoxW(nullptr,L")
    t = t.replace("MessageBox(NULL,L", "::MessageBoxW(nullptr,L")
    t = t.replace("MessageBox(0, L", "::MessageBoxW(nullptr, L")
    t = t.replace("MessageBox(NULL, L", "::MessageBoxW(nullptr, L")
    if t != o:
        save(p, t)
        log.append("MessageBoxW -> %s x%d" % (f, o.count("MessageBox(")))

# ---------- 3) ContinueLoginPage ----------
p = os.path.join(D, "ContinueLoginPage.cpp")
t = load(p)
t, n = re.subn(r"\(this->(\w+)\)->CardContent::(\w+)\(haizeiNode\)",
               lambda m: "this->%s(this->%s)" % (m.group(2), m.group(1)), t)
save(p, t)
log.append("ContinueLoginPage CardContent 回调: %d" % n)

# ---------- 4) TitlePage.h / TrainingBolusChoosePage.h ----------
for f in ["TitlePage.h", "TrainingBolusChoosePage.h"]:
    p = os.path.join(D, f)
    t = load(p)
    o = t
    t = t.replace("\tCCNode* membersRootNode;", "\tcocos2d::Node* membersRootNode;")
    t = re.sub(r"^(\s*)CCNode\*", r"\1cocos2d::Node*", t, flags=re.M)
    t = re.sub(r"^(\s*)CCLayer\*", r"\1cocos2d::Layer*", t, flags=re.M)
    t = re.sub(r"^(\s*)CCSprite\*", r"\1cocos2d::Sprite*", t, flags=re.M)
    if t != o:
        save(p, t)
        log.append("unqualified CC* -> %s" % f)

# ---------- 7) SpriteShader ----------
p = os.path.join(D, "SpriteShader.cpp")
t = load(p)
t = t.replace("""        addObserver(this,
            callfuncO_selector(SpriteShader::listenBackToForeground),
            EVNET_COME_TO_FOREGROUND,
            NULL);""",
              """        addObserver(this, EVNET_COME_TO_FOREGROUND,
            CC_CALLBACK_1(SpriteShader::listenBackToForeground, this));""")
t, n = re.subn(r"addObserver\(this,\s*callfuncO_selector\((\w+::\w+)\),\s*(\w+),\s*NULL\);",
               r"addObserver(this, \2, CC_CALLBACK_1(\1, this));", t)
save(p, t)
log.append("SpriteShader 通知: %d" % n)

# ---------- 8) toString(size_t) ----------
p = os.path.join(D, "SkillUpChoosePage.cpp")
t = load(p)
t2, n = re.subn(r"StringConverter::toString\((\w+)\.size\(\)\)",
                r"StringConverter::toString((int)\1.size())", t)
save(p, t2)
log.append("toString(size_t): %d" % n)

# ---------- 9) CCScrollViewCompat setDirection ----------
p = os.path.join(C, "CCScrollViewCompat.cpp")
t = load(p)
t2 = t.replace("    this->setDirection(cocos2d::ui::ScrollView::Direction::BOTH);",
               "    cocos2d::ui::ScrollView::setDirection(cocos2d::ui::ScrollView::Direction::BOTH);")
save(p, t2)
log.append("CCScrollViewCompat setDirection: %s" % (t != t2))

for l in log:
    print(l)
