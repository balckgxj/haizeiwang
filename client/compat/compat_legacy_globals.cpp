// ---------------------------------------------------------------------------
// 2.x 时代若干全局函数的补充实现
//   - cocos2d::CCLog : 2.x 的日志函数，3.x 只保留了 CCLOG 宏
//
// 说明：getFileData / saveFileInPath 的真实实现（带 0xEF 0xFE 解密）在
//       client/Platform/GamePlatform.cpp，不要在这里重复定义。
// ---------------------------------------------------------------------------
#include <cstdarg>
#include <cstdio>
#include "platform/CCCommon.h"

namespace cocos2d {

void CCLog(const char* pszFormat, ...)
{
    if (!pszFormat)
    {
        return;
    }
    va_list args;
    va_start(args, pszFormat);
    char buf[4096];
    vsnprintf(buf, sizeof(buf) - 1, pszFormat, args);
    va_end(args);
    buf[sizeof(buf) - 1] = '\0';
    CCLOG("%s", buf);
}

}
