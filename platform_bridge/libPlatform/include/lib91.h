#pragma once

#include "libPlatform.h"

class lib91 : public libPlatform
{
public:
	void _enableLogin();
	/**
	call this function first of all.
	NOTICE: Platform should call _boardcastInitDone to notify client logic WHEN initialization is done.
	*/
	virtual void init(bool privateLogin = false);

	/**
	MUST call this function AFTER initialization is done(after call back function).
	NOTICE: Platform should call _boardcastUpdateCheckDone to notify client logic WHEN update checking is done.
	*/
    virtual void updateApp();

	/**
	MUST call this function AFTER updating is done(after call back function).
	NOTICE: Platform should call _boardcastLoginResult to notify client logic WHEN login is done.
	*/
	virtual void login();

	/** logout platform*/
	virtual void logout();

	/** optional: finalize the platform*/
	virtual void final();

	/** show the platform window to switch users */
	virtual void switchUsers();

	/** buy platform RMB*/
	virtual void buyGoods(BUYINFO&);
	
	/** call platform open bbs function. if the platform doesn't have this usage, just open an url! */
	virtual void openBBS();
	/** call platform open feedback function. if the platform doesn't have this usage, just open an email link! */
	virtual void userFeedBack();
	/** optional: call platform open game pause function.*/
	virtual void gamePause();

	/** check whether is logined */
	virtual bool getLogined();

	/** IMPORTANT: get the only ID for game. MUST be unique! */
	virtual const std::string& loginUin();
	/** optional: get the session ID.*/
	virtual const std::string& sessionID();
	/** optional: get the nick name. which is shown on the loading scene */
	virtual const std::string& nickName();

	const std::string getClientChannel();

	virtual const unsigned int getPlatformId();

	void notifyEnterGame();
    
    std::string getPlatformMoneyName();
};

/** 本地版新增：取当前登录密码（供 LoginPacket 发送） */
const std::string& lib91_getLoginPassword();
/** 本地版新增：清空已保存的账号密码（密码错误重试时调用） */
void lib91_resetLogin();

/* [haizei] 游戏内账号密码登录页接入 ----------------------------------------
 * 平台层不直接依赖客户端 UI：由客户端在启动时注册「显示登录页」回调与
 * 「凭据已提交」回调。lib91::login() 在没有凭据时只请求显示登录页，
 * 登录页收集到账号密码后调用 lib91_setLoginCredentials 完成登录广播。
 * 这样 Win32 原生弹窗与 localAccount.txt 自动登录都被游戏内 UI 取代。
 */
typedef void (*lib91_ShowLoginUi)(const char* message);
typedef void (*lib91_LoginSubmitted)();

/** 注册登录页提供者；show 为 NULL 时回退到「无凭据则不登录」 */
void lib91_setLoginUiProvider(lib91_ShowLoginUi show, lib91_LoginSubmitted submitted);
/** 请求显示登录页（message 可为 NULL，用于密码错误等提示） */
void lib91_requestLoginUi(const char* message);
/** 登录页提交账号密码：保存凭据、触发 submitted 回调、广播登录成功 */
void lib91_setLoginCredentials(const char* account, const char* password);
/** 当前登录账号 */
const std::string& lib91_getLoginAccount();


