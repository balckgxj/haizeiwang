#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#pragma comment(lib, "dbghelp.lib")
int main(int argc, char** argv)
{
    SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEBUG | SYMOPT_LOAD_ANYTHING);
    if (!SymInitialize(GetCurrentProcess(), "E://PCGame//Haizeiwang//build//Debug", FALSE)) { printf("SymInitialize failed\n"); return 1; }
    ULONG64 base = SymLoadModuleExW(GetCurrentProcess(), NULL, L"E://PCGame//Haizeiwang//build//Debug//Haizeiwang.exe", NULL, 0x10000000, 0, NULL, 0);
    printf("base=%llX err=%u\n", base, GetLastError());
    IMAGEHLP_MODULEW64 mi; memset(&mi,0,sizeof(mi)); mi.SizeOfStruct=sizeof(mi);
    if (SymGetModuleInfoW64(GetCurrentProcess(), base, &mi))
        wprintf(L"SymType=%d\n", mi.SymType);
    for (int a=2;a<argc;++a){
        DWORD64 rva=_strtoui64(argv[a],NULL,16);
        char buf[sizeof(SYMBOL_INFO)+512]; SYMBOL_INFO* si=(SYMBOL_INFO*)buf;
        si->SizeOfStruct=sizeof(SYMBOL_INFO); si->MaxNameLen=511; DWORD64 disp=0;
        if (SymFromAddr(GetCurrentProcess(), base+rva, &disp, si))
            printf("RVA 0x%llX -> %s + 0x%llX\n", rva, si->Name, disp);
        else printf("RVA 0x%llX -> err %u\n", rva, GetLastError());
    }
    SymCleanup(GetCurrentProcess()); return 0;
}
