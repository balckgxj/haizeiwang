# -*- coding: utf-8 -*-
"""Restore the marquee ticker (MoveBoardCastLabel) on cocos2d-x 3.17.

Old 2.x code used LabelTTF::setTextureRect(Rect(x,0,w,h)) to slide the
visible texture window. 3.x Label/CCLabelTTF has no such API, so the
migration deleted those calls and left the ticker frozen and unclipped.

This patch restores equivalent behaviour with a ClippingNode:
  - one stencil rectangle (mRect) is the visible window at mPosition
  - each label is a child of that clipper, positioned at (-mStartX, 0)
  - update() increments mStartX and moves the label left each frame

Idempotent: re-running is a no-op. Files are read/written as GBK with
surrogateescape and newline='' because the sources contain legacy Chinese
comments and a MIX of CRLF/LF line endings (a plain text open would silently
rewrite every newline).
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HDR = os.path.join(ROOT, "client", "Classes", "BoardCastLabel.h")
CPP = os.path.join(ROOT, "client", "Classes", "BoardCastLabel.cpp")
ENC = "gbk"
IOERR = "surrogateescape"


def read_text(path):
    # universal newlines: CRLF -> LF so the rules below can match with \n
    with open(path, "r", encoding=ENC, errors=IOERR) as f:
        return f.read()


def write_text(path, s):
    # the file is overwhelmingly CRLF (287 CRLF vs 9 stray LF);
    # normalise all line endings to CRLF on the way back
    with open(path, "w", encoding=ENC, errors=IOERR, newline="") as f:
        f.write(s.replace("\r\n", "\n").replace("\n", "\r\n"))


def apply(text, old, new, label):
    n = text.count(old)
    if n == 1:
        return text.replace(old, new, 1), "applied"
    if n == 0:
        return text, "already" if new in text else "MISSING"
    return text, "AMBIGUOUS(%d)" % n


def patch_pair(path, rules):
    s = read_text(path)
    if "HAIZEI_BOARDCAST_CLIP" in s:
        print("[skip] %s already patched" % os.path.basename(path))
        return True
    ok = True
    for old, new, label in rules:
        s, st = apply(s, old, new, label)
        print("  %-28s %s" % (label, st))
        if st not in ("applied", "already"):
            ok = False
    if ok:
        s = s.replace("HAIZEI_BOARDCAST_CLIP_MARK", "HAIZEI_BOARDCAST_CLIP", 1)
        write_text(path, s)
    return ok


hdr_rules = [
    (
        "\tCCRect mRect;\n",
        "\tCCRect mRect;\n"
        "\tcocos2d::ClippingNode* mClipper;  // HAIZEI_BOARDCAST_CLIP_MARK 3.x marquee clipper\n",
        "header: add mClipper",
    ),
]

MIG = "// [migrate] 2.x \u63a5\u53e3\u5728 3.x \u5df2\u79fb\u9664\uff08LabelTTF::setTextureRect\uff09\uff0c\u5f85\u7528 ClippingNode \u91cd\u505a"

cpp_rules = [
    (
        '#include "BoardCastLabel.h"\n',
        '#include "BoardCastLabel.h"\n'
        '#include "2d/CCClippingNode.h"\n'
        '#include "2d/CCDrawNode.h"\n',
        "include clipper headers",
    ),
    (
        "MoveBoardCastLabel::MoveBoardCastLabel()\n{\n\tmLabelFirst = NULL;\n",
        "MoveBoardCastLabel::MoveBoardCastLabel()\n{\n\tmLabelFirst = NULL;\n\tmClipper = NULL;\n",
        "ctor: init mClipper",
    ),
    (
        "   initFirstLabel();\n   initSecondLabel();\n",
        "   // HAIZEI_BOARDCAST_CLIP_MARK: 3.x has no LabelTTF::setTextureRect;\n"
        "   // use one ClippingNode as the scrolling window instead.\n"
        "   if (!mClipper)\n"
        "   {\n"
        "       mClipper = cocos2d::ClippingNode::create();\n"
        "       cocos2d::DrawNode* stencil = cocos2d::DrawNode::create();\n"
        "       cocos2d::Vec2 poly[4] = {\n"
        "           cocos2d::Vec2(0, 0),\n"
        "           cocos2d::Vec2(mRect.size.width, 0),\n"
        "           cocos2d::Vec2(mRect.size.width, mRect.size.height),\n"
        "           cocos2d::Vec2(0, mRect.size.height)\n"
        "       };\n"
        "       stencil->drawPolygon(poly, 4, cocos2d::Color4F::WHITE, 0, cocos2d::Color4F::WHITE);\n"
        "       mClipper->setStencil(stencil);\n"
        "       addChild(mClipper);\n"
        "   }\n"
        "   mClipper->setPosition(mPosition);\n"
        "   initFirstLabel();\n"
        "   initSecondLabel();\n",
        "initStr: create clipper",
    ),
    (
        "\tmPosition.y -= (mRect.size.height+2) ;\n"
        "\t\t" + MIG + "\n"
        "\tmLabelFirst->setPosition(mPosition);\n"
        "\taddChild(mLabelFirst);\n",
        "\tmPosition.y -= (mRect.size.height+2) ;\n"
        "\tmClipper->setPosition(mPosition);\n"
        "\tmLabelFirst->setPosition(cocos2d::Vec2(-mStartFirstX, 0));\n"
        "\tmClipper->addChild(mLabelFirst);\n",
        "initFirstLabel: clip + offset",
    ),
    (
        "\t\t" + MIG + "\n"
        "\tmLabelSecond->setPosition(mPosition);\n"
        "\tmLabelSecond->setVisible(false);\n"
        "\taddChild(mLabelSecond);\n",
        "\tmLabelSecond->setPosition(cocos2d::Vec2(-mStartSecondX, 0));\n"
        "\tmLabelSecond->setVisible(false);\n"
        "\tmClipper->addChild(mLabelSecond);\n",
        "initSecondLabel: clip + offset",
    ),
    (
        "\t\t" + MIG + "\n"
        "\tmLabelFirst->setDimensions(mDimensionsFirst);\n",
        "\tmLabelFirst->setDimensions(mDimensionsFirst);\n"
        "\tmLabelFirst->setPositionX(-mStartFirstX);\n",
        "changeFirstLabel: reset x",
    ),
    (
        "\t\t" + MIG + "\n"
        "\tmLabelSecond->setDimensions(mDimensionsSecond);\n",
        "\tmLabelSecond->setDimensions(mDimensionsSecond);\n"
        "\tmLabelSecond->setPositionX(-mStartSecondX);\n",
        "changeSecondLabel: reset x",
    ),
    (
        "\t\t" + MIG + "\n"
        "\t\tif(mDimensionsFirst.width-mStartFirstX <=mRect.size.width)\n",
        "\tmStartFirstX++;\n"
        "\tmLabelFirst->setPositionX(-mStartFirstX);\n"
        "\t\tif(mDimensionsFirst.width-mStartFirstX <=mRect.size.width)\n",
        "update: scroll first label",
    ),
    (
        "\t\t" + MIG + "\n"
        "\t\tif(mDimensionsSecond.width-mStartSecondX<=mRect.size.width)\n",
        "\tmStartSecondX++;\n"
        "\tmLabelSecond->setPositionX(-mStartSecondX);\n"
        "\t\tif(mDimensionsSecond.width-mStartSecondX<=mRect.size.width)\n",
        "update: scroll second label",
    ),
]


def main():
    print("== BoardCastLabel.h ==")
    a = patch_pair(HDR, hdr_rules)
    print("== BoardCastLabel.cpp ==")
    b = patch_pair(CPP, cpp_rules)
    if not (a and b):
        print("\nFAILED: some rules did not match exactly; files left unchanged where unsafe.")
        return 1
    print("\nDone. Rebuild with: env -u https_proxy -u http_proxy cmd //c build.bat")
    return 0


if __name__ == "__main__":
    sys.exit(main())
