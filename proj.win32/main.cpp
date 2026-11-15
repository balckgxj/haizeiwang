// ---------------------------------------------------------------------------
//  Windows 入口（cocos2d-x 3.17 版）
//  老版本见 reference/old_win32/main.cpp（2.x + CCEGLView::sharedOpenGLView）
//
//  这里用 console 子系统的 main()：一是避开 APIENTRY / _tWinMain 这些
//  Windows 入口约定，二是调试期能直接在控制台看 CCLOG 输出。
//  正式发版若要隐藏控制台，把 CMakeLists 里的 add_executable 加回 WIN32 并
//  改回 WinMain 即可。
// ---------------------------------------------------------------------------
#include "AppDelegate.h"
#include "base/CCDirector.h"
#include "platform/CCApplication.h"

#ifdef _WIN32
// ---------------------------------------------------------------------------
// [haizei] 崩溃时打印调用栈（函数名+偏移）到 crash_stack.txt
// 迁移期反复出现空指针崩溃，有了栈就不用一轮轮“改-崩-查 map 文件”了
// ---------------------------------------------------------------------------
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <crtdbg.h>

#pragma comment(lib, "dbghelp.lib")

static LONG WINAPI haizei_crash_handler(EXCEPTION_POINTERS* info)
{
    HANDLE file = CreateFileA("crash_stack.txt", GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE)
        return EXCEPTION_CONTINUE_SEARCH;

    char line[512];
    sprintf(line, "exception code: 0x%08lX at addr %p\n",
            info->ExceptionRecord->ExceptionCode,
            info->ExceptionRecord->ExceptionAddress);
    DWORD written = 0;
    WriteFile(file, line, (DWORD)strlen(line), &written, nullptr);

    SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES);
    SymInitialize(GetCurrentProcess(), nullptr, TRUE);

    HANDLE thread = GetCurrentThread();
    CONTEXT ctx = *info->ContextRecord;
    STACKFRAME64 frame;
    memset(&frame, 0, sizeof(frame));
#ifdef _WIN64
    DWORD machine = IMAGE_FILE_MACHINE_AMD64;
    frame.AddrPC.Offset = ctx.Rip;
    frame.AddrFrame.Offset = ctx.Rbp;
    frame.AddrStack.Offset = ctx.Rsp;
#else
    DWORD machine = IMAGE_FILE_MACHINE_I386;
    frame.AddrPC.Offset = ctx.Eip;
    frame.AddrFrame.Offset = ctx.Ebp;
    frame.AddrStack.Offset = ctx.Esp;
#endif
    frame.AddrPC.Mode = AddrModeFlat;
    frame.AddrFrame.Mode = AddrModeFlat;
    frame.AddrStack.Mode = AddrModeFlat;

    for (int i = 0; i < 32; ++i)
    {
        if (!StackWalk64(machine, GetCurrentProcess(), thread, &frame, &ctx,
                         nullptr, SymFunctionTableAccess64, SymGetModuleBase64, nullptr))
            break;
        DWORD64 pc = frame.AddrPC.Offset;
        if (pc == 0)
            break;

        char nameBuf[256] = {0};
        SYMBOL_INFO* sym = (SYMBOL_INFO*)nameBuf;
        sym->SizeOfStruct = sizeof(SYMBOL_INFO);
        sym->MaxNameLen = 200;
        DWORD64 disp = 0;
        if (SymFromAddr(GetCurrentProcess(), pc, &disp, sym))
            sprintf(line, "#%02d %s +0x%llX\n", i, sym->Name, (unsigned long long)disp);
        else
            sprintf(line, "#%02d %p\n", i, (void*)pc);
        WriteFile(file, line, (DWORD)strlen(line), &written, nullptr);
    }
    SymCleanup(GetCurrentProcess());
    CloseHandle(file);
    return EXCEPTION_CONTINUE_SEARCH;
}
#endif

// 强制链接 GamePackets.cpp（包工厂靠静态初始化器注册，见该文件尾部说明）
extern void haizei_force_link_game_packets();

USING_NS_CC;

int main(int argc, char** argv)
{
    UNREFERENCED_PARAMETER(argc);
    UNREFERENCED_PARAMETER(argv);

#ifdef _WIN32
    SetUnhandledExceptionFilter(haizei_crash_handler);

    // [haizei] Debug 构建里 CCAssert/assert 会弹“abort() has been called”模态框并冻结进程，
    // 导致自动化巡检卡死且拿不到根因。这里把断言/错误从模态框改为写 stderr（被 verify_run.log 捕获），
    // 并去掉 abort 消息框，便于巡检检测与定位（Release 下这些函数无副作用）。
    _CrtSetReportMode(_CRT_ASSERT, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ASSERT, _CRTDBG_FILE_STDERR);
    _CrtSetReportMode(_CRT_ERROR, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ERROR, _CRTDBG_FILE_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif

    haizei_force_link_game_packets();

    AppDelegate app;
    return Application::getInstance()->run();
}
