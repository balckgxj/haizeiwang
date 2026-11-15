// pdbsym2.exe: 用 DbgHelp 从 PDB 解析 RVA/VA 符号
// 用法: pdbsym2.exe <exe或pdb路径> <rva(hex)> ...
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <string>
#pragma comment(lib, "dbghelp.lib")

int main(int argc, char** argv)
{
    if (argc < 3) { printf("usage: pdbsym2 <module> <rva>...\n"); return 1; }
    SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES);
    if (!SymInitialize(GetCurrentProcess(), NULL, FALSE)) { printf("SymInitialize failed\n"); return 1; }
    wchar_t modW[MAX_PATH*2];
    MultiByteToWideChar(CP_UTF8, 0, argv[1], -1, modW, MAX_PATH*2);
    ULONG64 base = SymLoadModuleExW(GetCurrentProcess(), NULL, modW, NULL, 0x10000000, 0, NULL, 0);
    if (!base) { printf("SymLoadModuleExW failed %u\n", GetLastError()); return 1; }
    for (int a = 2; a < argc; ++a)
    {
        DWORD64 rva = _strtoui64(argv[a], NULL, 16);
        DWORD64 addr = base + rva;
        char buf[sizeof(SYMBOL_INFO) + 256];
        SYMBOL_INFO* si = (SYMBOL_INFO*)buf;
        si->SizeOfStruct = sizeof(SYMBOL_INFO);
        si->MaxNameLen = 255;
        DWORD64 disp = 0;
        if (SymFromAddr(GetCurrentProcess(), addr, &disp, si))
            printf("RVA 0x%llX -> %s + 0x%llX\n", rva, si->Name, disp);
        else
            printf("RVA 0x%llX -> <none> (err %u)\n", rva, GetLastError());
    }
    SymCleanup(GetCurrentProcess());
    return 0;
}
