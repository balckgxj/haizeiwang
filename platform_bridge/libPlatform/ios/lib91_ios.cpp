// ---------------------------------------------------------------------------
// lib91 平台桥接的 iOS 实现
//
// 与 win32/lib91.cpp 逻辑一致，仅做两处可移植化：
//   - timeGetTime()  -> std::chrono
//   - GetComputerName/TCHAR -> 未使用（loginUin/nickName 直接复用登录账号，
//     本地版账号即唯一 ID，与 win32 行为一致）
//   - MessageBoxW -> CCLOG 占位（本地版无内购/论坛）
//
// 本文件在 CMake 中仅 iOS 构建编译，配合 PROJECT91 宏：
//   - LoadingFrame.cpp  用 PROJECT91 分支定义 _platfrom="version_ios_91.cfg"
//   - GamePrecedure.cpp 用 PROJECT91 分支注册 lib91 平台
// ---------------------------------------------------------------------------
#include "../include/lib91.h"
#include "libOS.h"
#include "libPlatform.h"
#include "cocos2d.h"

#include <chrono>

bool lib91_mLogined = false;
long long lib91_mLoginTime = 0;

static std::string loginName = "";
static std::string loginPwd  = "";
static lib91_ShowLoginUi      s_showLoginUi     = NULL;
static lib91_LoginSubmitted   s_loginSubmitted  = NULL;

static long long nowMs()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

const std::string& lib91_getLoginPassword()
{
	return loginPwd;
}

const std::string& lib91_getLoginAccount()
{
	return loginName;
}

void lib91_resetLogin()
{
	loginName = "";
	loginPwd  = "";
	lib91_mLogined = false;
}

void lib91_setLoginUiProvider(lib91_ShowLoginUi show, lib91_LoginSubmitted submitted)
{
	s_showLoginUi    = show;
	s_loginSubmitted = submitted;
}

void lib91_requestLoginUi(const char* message)
{
	lib91_mLogined = false;
	if (s_showLoginUi)
	{
		s_showLoginUi(message);
		return;
	}
	// 兜底：客户端未注册游戏内登录页时，走 libOS 登录框
	std::string acc, pwd;
	bool ok = libOS::getInstance()->showLoginbox(
		"\xE6\xB5\xB7\xE8\xB4\xBC\xE7\x8E\x8B\xEF\xBC\x8D\xE7\x99\xBB\xE5\xBD\x95", acc, pwd);
	if (!ok || acc.empty() || pwd.empty())
	{
		CCLOGERROR("[lib91] login ui unavailable and no credentials provided");
		return;
	}
	lib91_setLoginCredentials(acc.c_str(), pwd.c_str());
}

void lib91_setLoginCredentials(const char* account, const char* password)
{
	loginName = account ? account : "";
	loginPwd  = password ? password : "";
	if (loginName.empty() || loginPwd.empty())
	{
		lib91_mLogined = false;
		return;
	}
	lib91_mLogined = true;
	CCLOG("[lib91] credentials submitted for account: %s", loginName.c_str());
	if (s_loginSubmitted) s_loginSubmitted();
	libPlatformManager::getPlatform()->_boardcastLoginResult(true, "");
}

void lib91::init(bool privateLogin)
{
	lib91_mLogined = false;
	_boardcastUpdateCheckDone(true,"");
}
bool lib91::getLogined()
{
	// 本地版：只有完成账号+密码输入后才算登录成功
	return lib91_mLogined;
}

void lib91::login()
{
	lib91_mLoginTime = nowMs();

	// 没有凭据时只请求游戏内登录页，不阻塞、不自动放行
	if (loginName.empty() || loginPwd.empty())
	{
		lib91_requestLoginUi(NULL);
		return;
	}

	lib91_mLogined = true;
	libPlatformManager::getPlatform()->_boardcastLoginResult(true,"");
}

const std::string& lib91::loginUin()
{
	return loginName;
}
const std::string& lib91::sessionID()
{
	static std::string ret;
	ret = loginName;
	return ret;
}
const std::string& lib91::nickName()
{
	static std::string ret;
	ret = loginName;
	return ret;
}
void lib91::switchUsers()
{
	loginName="";
	loginPwd="";
	lib91_mLogined = false;
    login();
}
void lib91::logout()
{

}

void lib91::buyGoods( BUYINFO& info)
{
	CCLOG("[lib91] buyGoods stub (local build)");
	char ser[128];
	sprintf(ser,"%lld", nowMs());
	info.cooOrderSerial = ser;
	_boardcastBuyinfoSent(true,info,"success");
}

void lib91::openBBS()
{
	CCLOG("[lib91] openBBS stub (local build)");
}

void lib91::userFeedBack()
{

}

void lib91::gamePause()
{

}

void lib91::updateApp()
{

}

void lib91::final()
{

}

const std::string lib91::getClientChannel()
{
	return "91";
}

void lib91::_enableLogin()
{

}

const unsigned int lib91::getPlatformId()
{
	return 0u;
}

std::string lib91::getPlatformMoneyName()
{
	return "91dou";
}

void lib91::notifyEnterGame()
{
}
