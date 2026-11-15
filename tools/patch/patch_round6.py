"""第六轮：最后一批机械修改。"""
import io
import os
import re

D = r"E:\PCGame\Haizeiwang\client\Classes"

def load(f):
    return io.open(os.path.join(D, f), encoding="gbk", errors="surrogateescape", newline="").read()

def save(f, t):
    io.open(os.path.join(D, f), "w", encoding="gbk", errors="surrogateescape", newline="").write(t)

log = []

# 1) Language.cpp 的 CCARRAY_FOREACH
t = load("Language.cpp")
if "CCARRAY_FOREACH(_root->getChildren(), pObj)" in t:
    t = t.replace("\tcocos2d::CCObject* pObj = NULL;\n", "")
    t = t.replace("\tcocos2d::CCObject* pObj = NULL;\r\n", "")
    t = t.replace("CCARRAY_FOREACH(_root->getChildren(), pObj)", "for (auto pObj : _root->getChildren())")
    save("Language.cpp", t)
    log.append("Language.cpp: CCARRAY_FOREACH -> range-for")

# 2) NumberChangeAction：2.x 的 copyWithZone / CCActionInterval / m_fDuration
h = load("NumberChangeAction.h")
h2 = h.replace("\tvirtual cocos2d::CCObject* copyWithZone(cocos2d::CCZone* pZone);",
               "\t// [migrate] 3.x 用 clone() 代替 copyWithZone")
h2 = h2.replace("virtual CCActionInterval* reverse(void);",
                "virtual cocos2d::CCActionInterval* reverse(void) const override;")
save("NumberChangeAction.h", h2)

c = load("NumberChangeAction.cpp")
c = c.replace("CCActionInterval* NumberChangeAction::reverse(void)", "NumberChangeAction* NumberChangeAction::reverse(void) const")
c = c.replace("m_fDuration", "_duration")
# 删掉 copyWithZone 的实现块
c = re.sub(r"(?s)cocos2d::CCObject\*\s*NumberChangeAction::copyWithZone\(.*?\n\}\n", "", c)
save("NumberChangeAction.cpp", c)
log.append("NumberChangeAction: copyWithZone/CCActorInterval/m_fDuration")

# 3) CallFuncN::create(CC_CALLBACK_1(...)) -> lambda（3.x 要 std::function<void(Node*)>）
pat = re.compile(r"cocos2d::CallFuncN::create\(CC_CALLBACK_1\((\w+::\w+),\s*([^()]+?)\)\)")
for f in os.listdir(D):
    if not f.endswith((".cpp", ".h")):
        continue
    t = load(f)
    t2, n = pat.subn(lambda m: "cocos2d::CallFuncN::create([=](cocos2d::Node* haizeiNode) "
                               "{ (%s)->%s(haizeiNode); })" % (m.group(2), m.group(1)), t)
    if n:
        save(f, t2)
        log.append("%s: CallFuncN lambda x%d" % (f, n))

# 4) RenderTexture 的 2.x 扩展接口
t = load("GamePrecedure.cpp")
for name in ("keepBegin", "keepEnd"):
    t = re.sub(r"^.*%s.*$" % name,
               "\t// [migrate] 2.x RenderTexture 扩展接口 %s，3.x 无" % name,
               t, flags=re.M)
save("GamePrecedure.cpp", t)
log.append("GamePrecedure.cpp: RenderTexture keepBegin/keepEnd")

for l in log:
    print(l)
