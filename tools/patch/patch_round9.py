"""第九轮：收口剩余错误。"""
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

# 1) MainFrame：Vector 不能当 bool
p = os.path.join(D, "MainFrame.cpp")
t = load(p)
t2 = t.replace("if(mNodeFront && mNodeFront->getChildren() && mNodeFront->getChildren().size()>0)",
               "if(mNodeFront && !mNodeFront->getChildren().empty())")
save(p, t2)
log.append("MainFrame: %s" % (t != t2))

# 2) MainPage：3.x TextureCache 没有 getTextrueTotalBytes
p = os.path.join(D, "MainPage.cpp")
t = load(p)
t2 = t.replace("if (cocos2d::Director::getInstance()->getTextureCache()->getTextrueTotalBytes() > 125*1024*1024)",
               "if (false) // [migrate] 3.x TextureCache 无 getTextrueTotalBytes，纹理回收阈值先关闭")
save(p, t2)
log.append("MainPage: %s" % (t != t2))

# 3) LoadingUnit：addImageAsync 回调签名
p = os.path.join(D, "LoadingUnit.cpp")
t = load(p)
t2, n = re.subn(r"addImageAsync\(\s*([^,]+),\s*this,\s*callfuncO_selector\((\w+::\w+)\)\s*\)",
                r"addImageAsync(\1, CC_CALLBACK_1(\2, this), nullptr)", t, flags=re.S)
save(p, t2)
log.append("LoadingUnit addImageAsync: %d" % n)

# 4) libOS 的 MessageBox
p = os.path.join(B, "libOS\\win32\\libOS.cpp")
t = load(p)
t2 = t.replace('MessageBox(NULL, out, L"", MB_OK)', '::MessageBoxW(nullptr, out, L"", MB_OK)')
save(p, t2)
log.append("libOS MessageBox: %s" % (t != t2))

# 5) SpriteShader：3.x addObserver 是 4 参数 (target, SEL_CallFuncO, name, sender)
p = os.path.join(D, "SpriteShader.cpp")
t = load(p)
t2, n = re.subn(r"addObserver\(this,\s*EVNET_COME_TO_FOREGROUND,\s*CC_CALLBACK_1\((\w+::\w+),\s*this\)\);",
                r"addObserver(this, CC_CALLBACK_1(\1, this), EVNET_COME_TO_FOREGROUND, nullptr);", t)
save(p, t2)
log.append("SpriteShader addObserver: %d" % n)

# 6) CCScrollViewCompat：ui::ScrollView 没有 decelerationRate，自己记
h = load(os.path.join(C, "CCScrollViewCompat.h"))
if "_compatDeaccelRate" not in h:
    h = h.replace("    float _compatZoomScale = 1.0f;",
                  "    float _compatZoomScale = 1.0f;\n    float _compatDeaccelRate = 0.0f;")
    save(os.path.join(C, "CCScrollViewCompat.h"), h)
    log.append("CCScrollViewCompat.h: 增加 _compatDeaccelRate")

cpp = load(os.path.join(C, "CCScrollViewCompat.cpp"))
cpp = re.sub(r"void CCScrollView::setScrollDeaccelRate\(float fRate\)\s*\{.*?\n\}",
             "void CCScrollView::setScrollDeaccelRate(float fRate)\n{\n"
             "    // 3.x ui::ScrollView 没有 decelerationRate 接口，这里记录 2.x 的值并映射到惯性滚动开关\n"
             "    _compatDeaccelRate = fRate;\n"
             "    this->setInertiaScrollEnabled(fRate > 0.0f);\n}", cpp, flags=re.S)
cpp = re.sub(r"float CCScrollView::getScrollDeaccelRate\(\)\s*\{.*?\n\}",
             "float CCScrollView::getScrollDeaccelRate()\n{\n    return _compatDeaccelRate;\n}", cpp, flags=re.S)
save(os.path.join(C, "CCScrollViewCompat.cpp"), cpp)
log.append("CCScrollViewCompat.cpp: deceleration 映射")

for l in log:
    print(l)
