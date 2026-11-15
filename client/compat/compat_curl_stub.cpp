// ---------------------------------------------------------------------------
// libcurl 桩实现
//
// 背景：cocos2d-x 3.17 的 external/curl/prebuilt/win32/libcurl.dll 依赖
//        libssl-1_1.dll / libcrypto-1_1.dll（而且本机只有 x64 版），
//        为了先让客户端在本机跑起来，这里把 CurlDownload.cpp 用到的 6 个
//        接口做成桩：所有下载请求一律失败，客户端只会认为“没有更新”。
//
// 阶段二要做热更时，换成自己用源码编译的 libcurl（建议开 WinSSL），
// 删掉本文件即可。
// ---------------------------------------------------------------------------
#define CURL_STATICLIB
#include "curl/curl.h"

extern "C" {

CURLcode curl_global_init(long flags)
{
    (void)flags;
    return CURLE_FAILED_INIT;
}

void curl_global_cleanup(void)
{
}

CURL* curl_easy_init(void)
{
    return nullptr;
}

CURLcode curl_easy_setopt(CURL* curl, CURLoption option, ...)
{
    (void)curl;
    (void)option;
    return CURLE_FAILED_INIT;
}

CURLcode curl_easy_perform(CURL* curl)
{
    (void)curl;
    return CURLE_FAILED_INIT;
}

void curl_easy_cleanup(CURL* curl)
{
    (void)curl;
}

}
