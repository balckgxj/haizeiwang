// pdbsym.exe: 用 DIA 从 PDB 解析指定 RVA 的最近符号（无 ATL 依赖）
// 用法: pdbsym.exe <pdb路径> <rva1(hex)> ...
#include <windows.h>
#include <dia2.h>
#include <diacreate.h>
#include <stdio.h>
#include <string>

static std::wstring BStrToW(BSTR b){ std::wstring r; if(b){ r=b; SysFreeString(b);} return r; }

static void printSym(const wchar_t* tag, IDiaSymbol* pSym, DWORD rva)
{
    if (!pSym) { wprintf(L"RVA 0x%X -> <null>\n", rva); return; }
    DWORD symRva = 0;
    ULONGLONG len = 0;
    BSTR n = NULL;
    pSym->get_relativeVirtualAddress(&symRva);
    pSym->get_length(&len);
    pSym->get_name(&n);
    std::wstring name = BStrToW(n);
    wprintf(L"%s 0x%X -> %s + 0x%X (sym rva 0x%X size %llu)\n",
            tag, rva, name.c_str(), (symRva <= rva ? rva - symRva : 0), symRva, len);
}

int main(int argc, char** argv)
{
    if (argc < 3) { printf("usage: pdbsym <pdb> <rva>...\n"); return 1; }
    CoInitialize(NULL);
    int rc = 1;
    IDiaDataSource* pSource = NULL;
    IDiaSession* pSession = NULL;
    IDiaEnumSymbolsByAddr* pEnum = NULL;
    do {
        HRESULT hr = NoRegCoCreate(L"E:\\Softwares\\VS2022BuildTools\\Common7\\IDE\\CommonExtensions\\Microsoft\\TestWindow\\VsTest\\TestHostNetFramework\\x64\\msdia140.dll",
                                   CLSID_DiaSource, __uuidof(IDiaDataSource), (void**)&pSource);
        if (FAILED(hr)) { printf("NoRegCoCreate failed 0x%08X\n", hr); break; }
        wchar_t pdbW[MAX_PATH*2];
        MultiByteToWideChar(CP_UTF8, 0, argv[1], -1, pdbW, MAX_PATH*2);
        hr = pSource->loadDataFromPdb(pdbW);
        if (FAILED(hr)) { printf("loadDataFromPdb failed 0x%08X\n", hr); break; }
        hr = pSource->openSession(&pSession);
        if (FAILED(hr)) { printf("openSession failed 0x%08X\n", hr); break; }
        hr = pSession->getSymbolsByAddr(&pEnum);
        if (FAILED(hr)) { printf("getSymbolsByAddr failed 0x%08X\n", hr); break; }
        rc = 0;
        for (int a = 2; a < argc; ++a)
        {
            DWORD rva = (DWORD)_strtoui64(argv[a], NULL, 16);
            IDiaSymbol* pSym = NULL;
            hr = pEnum->symbolByRVA(rva, &pSym);
            if (FAILED(hr) || !pSym)
            {
                printf("RVA 0x%X -> symbolByRVA failed 0x%08X\n", rva, hr);
                if (pSym) pSym->Release();
                continue;
            }
            DWORD symRva = 0; pSym->get_relativeVirtualAddress(&symRva);
            printSym(L"RVA", pSym, rva);
            // 若定位到的符号在 rva 之后，向前（地址更小方向）回退几次找包含者
            IDiaSymbol* pPrev = NULL;
            DWORD cur = symRva;
            pSym->Release(); pSym = NULL;
            int guard = 0;
            while (cur > rva && guard++ < 64)
            {
                hr = pEnum->symbolByRVA(cur - 1, &pPrev);
                if (FAILED(hr) || !pPrev) break;
                DWORD pr = 0; pPrev->get_relativeVirtualAddress(&pr);
                printSym(L"  prev", pPrev, rva);
                cur = pr;
                pPrev->Release(); pPrev = NULL;
                if (pr == 0) break;
            }
        }
    } while(0);
    if (pEnum) pEnum->Release();
    if (pSession) pSession->Release();
    if (pSource) pSource->Release();
    CoUninitialize();
    return rc;
}
