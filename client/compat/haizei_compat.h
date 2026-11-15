#pragma once
// ---------------------------------------------------------------------------
//  Haizeiwang 2.1.3 -> 3.17.2 兼容层
//
//  通过 CMake 的 /FI（强制包含）注入到每个编译单元，
//  这样 204 个老源文件不需要逐个改 include / 类型名。
// ---------------------------------------------------------------------------

#include "cocos-ext.h"
#include "CCLuaEngine.h"   // 阶段一的 Lua 占位实现（含 CCLuaEngine / ScriptEngineManager）

// ---------------------------------------------------------------------------
// 1.5) CCLabelBMFont 类型对齐（关键）
//
// 引擎 CCDeprecated.h 把 2.x 的 CCLabelBMFont 映射成 3.x 的 LabelBMFont
// （继承 SpriteBatchNode），但 3.17 的 CocosBuilder 里 LabelBMFontLoader
// 实际创建的是 cocos2d::Label（见 CCB_VIRTUAL_NEW_AUTORELEASE_CREATECCNODE_METHOD）。
// 老工程有 752 处 dynamic_cast<CCLabelBMFont*>(ccbVar)，映射不一致会全部返回
// nullptr —— 表现为文本不刷新、冒险/技能书等页面直接空指针崩溃。
// 这里把名字对齐到 Label，让所有 dynamic_cast 生效。
// ---------------------------------------------------------------------------
#include "2d/CCLabel.h"
#ifdef CCLabelBMFont
#undef CCLabelBMFont
#endif
namespace cocos2d {
    typedef Label CCLabelBMFont;

    // 2.x: LabelBMFont::create(text, fntFile, width)
    // 3.x: Label::createWithBMFont(fntFile, text, alignment, maxLineWidth)
    // 老工程有 20 处用旧签名创建逐字标签（ScrollNumCard 等），由此函数承接。
    inline Label* createLabelBMFontCompat(const char* text, const char* fntFile, float width = 0.0f)
    {
        Label* label = Label::createWithBMFont(fntFile, text);
        if (label && width > 0.0f)
        {
            label->setMaxLineWidth(width);
        }
        return label;
    }
}

// ---------------------------------------------------------------------------
// 1) CocosBuilder
//    2.x: cocos2d::extension::CCBReader / CCNodeLoader ...
//    3.x: 全局命名空间 cocosbuilder::，且类名去掉了 CC 前缀
// ---------------------------------------------------------------------------
#include "cocosbuilder/CCBReader.h"
#include "cocosbuilder/CCNodeLoader.h"
#include "cocosbuilder/CCNodeLoaderLibrary.h"
#include "cocosbuilder/CCBSelectorResolver.h"
#include "cocosbuilder/CCBMemberVariableAssigner.h"
#include "extensions/GUI/CCControlExtension/CCControl.h"

namespace cocos2d {
namespace extension {
using namespace ::cocosbuilder;

// 3.x 去掉了 CC 前缀
typedef ::cocosbuilder::NodeLoader        CCNodeLoader;
typedef ::cocosbuilder::NodeLoaderLibrary CCNodeLoaderLibrary;

// 2.x 的 SEL_CCControlHandler，3.x 换成了 Control::Handler
typedef Control::Handler SEL_CCControlHandler;
typedef ControlButton    CCControlButton;
typedef Control          CCControl;
typedef ui::Scale9Sprite CCScale9Sprite;
}
using extension::CCControlButton;
using extension::CCControl;
using extension::CCScale9Sprite;
using extension::TableView;
using extension::TableViewCell;
using extension::TableViewDataSource;
using extension::TableViewDelegate;
using ui::Scale9Sprite;
typedef extension::TableView CCTableView;
typedef extension::TableViewCell CCTableViewCell;
typedef extension::TableViewDataSource CCTableViewDataSource;
typedef extension::TableViewDelegate CCTableViewDelegate;
}

// 2.x 的工厂函数
inline cocos2d::extension::NodeLoaderLibrary* newDefaultCCNodeLoaderLibrary()
{
    return cocos2d::extension::NodeLoaderLibrary::newDefaultNodeLoaderLibrary();
}

// ---------------------------------------------------------------------------
// 2) 2.x 的全局函数/常量
// ---------------------------------------------------------------------------
#include "platform/CCCommon.h"

namespace cocos2d {
inline void CCMessageBox(const char* msg, const char* title)
{
#if defined(_WIN32)
    // 注意：cocos2d 的 CCStdC-win32.h 里 #undef MessageBox，只能用 MessageBoxA
    ::MessageBoxA(nullptr, msg, title, MB_OK);
#else
    // iOS/Mac：无 Win32 对话框，落日志（后续可接 UIAlertView）
    printf("[MessageBox] %s: %s\n", title ? title : "", msg ? msg : "");
#endif
}

// 2.x 的计时接口，3.x 已移除
struct cc_timeval
{
    long tv_sec;
    long tv_usec;
};
inline int gettimeofdayCocos2d(cc_timeval* tp, void*)
{
    if (tp)
    {
        tp->tv_sec = (long)time(nullptr);
        tp->tv_usec = 0;
    }
    return 0;
}
}
using cocos2d::CCMessageBox;
using cocos2d::cc_timeval;
using cocos2d::gettimeofdayCocos2d;

#ifndef kCCMenuHandlerPriority
#define kCCMenuHandlerPriority (-128)
#endif

// 2.x CCCommon.h 里的常量，3.x 删了
#ifndef kMaxLogLen
#define kMaxLogLen 16
#endif
// 3.x 的通知中心按字符串名注册（2.x 的常量名拼写是 EVNET，这里保留原拼写）
namespace cocos2d {
static const std::string EVNET_COME_TO_FOREGROUND = "haizei_come_to_foreground";
}
using cocos2d::EVNET_COME_TO_FOREGROUND;

// 2.x 的 CCTime（只有 gettime 在用）
#include <ctime>
namespace cocos2d {
class CCTime
{
public:
    static float gettime()
    {
        return (float)clock() / (float)CLOCKS_PER_SEC;
    }
    static int gettimeofdayCocos2d(struct cc_timeval* tp, void*)
    {
        if (tp)
        {
            tp->tv_sec = (long)time(nullptr);
            tp->tv_usec = 0;
        }
        return 0;
    }
    static void timersubCocos2d(struct cc_timeval* start, struct cc_timeval* end, struct cc_timeval* result)
    {
        if (!start || !end || !result)
        {
            return;
        }
        result->tv_sec = end->tv_sec - start->tv_sec;
        result->tv_usec = end->tv_usec - start->tv_usec;
        if (result->tv_usec < 0)
        {
            result->tv_usec += 1000000;
            result->tv_sec -= 1;
        }
    }
};
}
using cocos2d::CCTime;

// lib91 等平台桥接代码直接用 Win32 的 MessageBox
#if defined(_WIN32) && !defined(HAIZEI_WINDOWS_H)
#define HAIZEI_WINDOWS_H
#include <windows.h>
#endif

// ---------------------------------------------------------------------------
// 3) 非 MSVC（iOS/Clang）的 MSVC CRT 兼容映射
//    老代码是 VS2010 年代写的，下面的函数在 Clang/libc++ 里名字不同
// ---------------------------------------------------------------------------
#if !defined(_MSC_VER)
#include <strings.h>
#include <unistd.h>
#include <string.h>

#ifndef _stricmp
#define _stricmp strcasecmp
#endif
#ifndef stricmp
#define stricmp strcasecmp
#endif
#ifndef _strnicmp
#define _strnicmp strncasecmp
#endif
#ifndef strnicmp
#define strnicmp strncasecmp
#endif
#ifndef _snprintf
#define _snprintf snprintf
#endif
#ifndef _vsnprintf
#define _vsnprintf vsnprintf
#endif
#endif // !_MSC_VER
