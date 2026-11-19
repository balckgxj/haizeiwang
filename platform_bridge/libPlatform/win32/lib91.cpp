#include "..\include\lib91.h"
#include <windows.h>
#include "libOS.h"
#include "libPlatform.h"

// [haizei] 默认使用更好看的游戏内嵌账号密码登录页（LoginPage）。
// 客户端注册 LoginPage provider 后，lib91::login() 无凭据时请求内嵌页；
// 凭据统一由 lib91_setLoginCredentials 写入并广播登录结果。
// Win32 原生 LoginBox 仅作为未注册 provider 时的兜底。
#include "cocos2d.h"

bool lib91_mLogined = false;
DWORD lib91_mLoginTime = 0;

static std::string loginName = "";
static std::string loginPwd  = "";
static lib91_ShowLoginUi      s_showLoginUi     = NULL;
static lib91_LoginSubmitted   s_loginSubmitted  = NULL;

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
	// 兜底：客户端未注册游戏内登录页时，沿用 Win32 原生登录框
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
	// 本地版：只有完成账号+密码输入后才算登录成功（原逻辑2秒后自动放行已删除）
	return lib91_mLogined;
}

void lib91::login()
{
	lib91_mLoginTime = timeGetTime();

	// 没有凭据时只请求游戏内登录页，不阻塞、不自动放行；
	// 登录页提交后由 lib91_setLoginCredentials 广播登录结果。
	if (loginName.empty() || loginPwd.empty())
	{
		lib91_requestLoginUi(NULL);
		return;
	}

	lib91_mLogined = true;
	libPlatformManager::getPlatform()->_boardcastLoginResult(true,"");
}

//in win32 return a number caculated by computer name
const std::string& lib91::loginUin()
{	
	return loginName;
}
const std::string& lib91::sessionID()
{
	static TCHAR chBuf[128];
	DWORD dwRet=128;
	GetComputerName(chBuf,&dwRet);
    static std::string ret;
    ret = (char*)chBuf;
	return ret;
}
const std::string& lib91::nickName()
{
	static TCHAR chBuf[128];
	DWORD dwRet=128;
	GetComputerName(chBuf,&dwRet);
    static std::string ret;
    ret = (char*)chBuf;
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
	::MessageBoxW(nullptr,L"Bought a item!!",L"shop",MB_OK);
	char ser[128];
	sprintf(ser,"%d",timeGetTime());
	info.cooOrderSerial = ser;
	_boardcastBuyinfoSent(true,info,"success");
}


void lib91::openBBS()
{
	::MessageBoxW(nullptr,L"open a bbs!!",L"url",MB_OK);
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
