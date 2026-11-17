
#include "stdafx.h"

#include "AppDelegate.h"
#include "GamePrecedure.h"
#include "SimpleAudioEngine.h"
#include "ThreadSocket.h"
#include "SoundManager.h"
#include "CCBManager.h"
#include "CCBScriptContainer.h"
#include "TimeCalculator.h"
// desktop 版 GLViewImpl 需要 glfw3.h，仅桌面平台包含；
// iOS/Mac 由 cocos2d.h 按平台自动引入对应 CCGLViewImpl-ios.h
#if (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32) || (CC_TARGET_PLATFORM == CC_PLATFORM_MAC) || (CC_TARGET_PLATFORM == CC_PLATFORM_LINUX)
#include "platform/desktop/CCGLViewImpl-desktop.h"
#endif
#include <time.h>

//
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
#include <jni.h>
#include "..\..\cocos2dx\platform\android\jni\JniHelper.h"
#include "../../cocos2dx/platform/android/jni/Java_org_cocos2dx_lib_Cocos2dxHelper.h"
#endif
//

static time_t timestamp = time(0);//see this file

//
USING_NS_CC;

AppDelegate::AppDelegate() {

}

AppDelegate::~AppDelegate() 
{

}


bool AppDelegate::applicationDidFinishLaunching()
{
	// initialize director
	CCDirector *pDirector = cocos2d::Director::getInstance();

	// 3.x：窗口与 GLView 必须在这里创建（2.x 是 CCEGLView::sharedOpenGLView 自己建好的）
	// [parity] 必须与老版 proj.win32/main.cpp 的 CCEGLView::setFrameSize(480, 640) 一致。
	// designSize 由 frame 宽高比推导：asp=640/480=1.333 -> designSize.width=480/asp=360，
	// 即老版的设计区 360x480。若误用 480x720，asp=1.5 会得到 320x480，横向少 40 个
	// 设计像素，所有 UI 元素的横坐标相对老版整体偏移：大按钮还能容错，阵容头像、
	// 空位加号、底部导航栏这类小按钮用老版坐标就会点空（A/B 实测 7 项无响应）。
	if (pDirector->getOpenGLView() == nullptr)
	{
		auto glview = cocos2d::GLViewImpl::create("Haizeiwang");
		glview->setFrameSize(480, 640);
		pDirector->setOpenGLView(glview);
	}

	pDirector->setProjection(kCCDirectorProjection2D);
	CCSize screenSize = pDirector->getOpenGLView()->getFrameSize();

	/*
	480*854		320*569.333
	320*480		320*480
	640*1136	320*568
	768*1024	360*480
	800*1280	320*512
	480*800		320*533.333
	720*1280	320*568.889
	738*1152	320*480
	*/
	CCSize designSize = CCSizeMake(320, 480);
	float asp = screenSize.height/screenSize.width;
	if(asp >1.5f)
		designSize.height = 320*asp;
	else
		designSize.width = 480/asp;

	//CCSize designSize = CCSize(screenSize.width/2.0f,screenSize.height/2.0f);//CCSizeMake(320, 568);

	if (screenSize.height > 480)
	{
		//cocos2d::FileUtils::getInstance()->setResourceDirectory("iphonehd");
		cocos2d::FileUtils::getInstance()->addSearchResolutionsOrder("iphonehd/");
		//pDirector->setContentScaleFactor(screenSize.height/designSize.height);
	}
 	else
 	{
 		cocos2d::FileUtils::getInstance()->addSearchResolutionsOrder("iphone/");
 	}


	cocos2d::Director::getInstance()->getOpenGLView()->setDesignResolutionSize(designSize.width, designSize.height, kResolutionNoBorder);
	//cocos2d::Director::getInstance()->getOpenGLView()->setViewPortInPoints(screenSize.width,screenSize.height,1,1);

#if defined(_DEBUG) //|| (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
	// [parity] 老版提交的是 Release 客户端，不显示 FPS 统计条。Debug 下开启会让
	// "GL verts / GL calls / 30.0" 半透明文字盖住主城底部功能栏，与老版视觉、
	// 操作对比都不一致。需要性能统计时临时改回 true 即可。
	pDirector->setDisplayStats(false);
#endif
	

	// set FPS. the default value is 1.0/60 if you don't call this
	pDirector->setAnimationInterval(1.0 / 30);

    //GamePrecedure::Get()->enterMainMenu();
	GamePrecedure::Get()->enterLoading();

	return true;
}

// This function will be called when the app is inactive. When comes a phone call,it's be invoked too
void AppDelegate::applicationDidEnterBackground()
{
#if (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32)
    // [haizei] Win32 桌面窗口最小化/失焦 ≠ 应用进入后台。老工程把移动端生命周期原样带过来：
    // 断线、停动画，且 Debug 构建里带「跨天 / 同小时超过 1 分钟 / 有待发包」等 exit(0) 测试逻辑，
    // 玩家一最小化窗口游戏就被强制退出，长时自动化巡检也会出现随机静默退出。
    // 桌面端保持运行状态；下方移动端逻辑在 Win32 不编译。
    return;
#else
    if(GamePrecedure::Get()->isInLoadingSceneAndNeedExit())
	{
	#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)

	#else
        exit(0);
	#endif
	}
	//
	#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
	if (getIsOnTempShortPauseJNI() == false)
	#endif
		ThreadSocket::Get()->disconnect();
	//
	cocos2d::Director::getInstance()->stopAnimation();
	SoundManager::Get()->appGotoBackground();
    
    if(!GamePrecedure::Get()->isInLoadingScene())
	{
        GamePrecedure::Get()->enterBackGround();
    }
	if(TimeCalculator::getInstance()->hasKey("ExitGameTime"))
	{
		if(TimeCalculator::getInstance()->getTimeLeft("ExitGameTime")<=0)
		{
			exit(0);
		}
	}
	//--begin xinzheng 2013-7-18
	{
		
		time_t nowstamp = time(0);
		struct tm* timetm = localtime(&timestamp);
		struct tm savetm = {0};
		memcpy(&savetm, timetm, sizeof(struct tm));
		/*
			localtime返回同一个struct tm实例的指针
		*/
		struct tm* nowtm = localtime(&nowstamp);
		if (nowtm->tm_yday > savetm.tm_yday)
		{
			exit(0);
		}
#if _DEBUG
		//test
		if (nowtm->tm_yday == savetm.tm_yday && (nowtm->tm_hour == savetm.tm_hour) && (nowtm->tm_min-savetm.tm_min) > 1)
		{
			exit(0);
		}
#endif
		//
		timestamp = nowstamp;
	}
	//--end
#endif
}

// this function will be called when the app is active again
void AppDelegate::applicationWillEnterForeground()
{
#if (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32)
    // [haizei] 与 applicationDidEnterBackground() 对称：桌面端最小化/恢复不改变游戏状态。
    return;
#else
    if(!GamePrecedure::Get()->isInLoadingScene())
        GamePrecedure::Get()->enterForeGround();
    
	cocos2d::Director::getInstance()->startAnimation();
	SoundManager::Get()->appResumeBackground();
#endif
}

void AppDelegate::purgeCachedData( void )
{
	CCBScriptContainer::purgeCachedData();
	//
	CCBManager::Get()->purgeCachedData();
	//
	cocos2d::Director::getInstance()->getTextureCache()->removeUnusedTextures();
	cocos2d::SpriteFrameCache::getInstance()->removeUnusedSpriteFrames();
}

void AppDelegate::applicationWillGoToExit()
{
	this->purgeCachedData();
	//
	CCBManager::Get()->Free();
	//
	MessageManager::Get()->Free();
	//
	PacketManager::Get()->Free();
	//
	
	//CurlDownload::Get()->Free();
	//
	SoundManager::Get()->Free();

	//
	Language::Get()->Free();
	//
	GamePrecedure::Get()->Free();
	//
	ThreadSocket::Get()->Free();
	
	//
	
	//

}

void globalPurgeCachedData()
{
	// [migrate] 2.x 接口在 3.x 已移除（Application::purgeCachedData）

	cocos2d::Director::getInstance()->purgeCachedData();

	// [migrate] 2.x 接口在 3.x 已移除（TextureCache::dumpCachedTextureInfo）
}


#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
extern "C" {

	JNIEXPORT void JNICALL Java_org_cocos2dx_lib_Cocos2dxHelper_nativeGameDestroy(JNIEnv*  env, jobject thiz) {
		cocos2d::Application::getInstance()->applicationWillGoToExit();
	}

	JNIEXPORT void JNICALL Java_org_cocos2dx_lib_Cocos2dxHelper_nativePurgeCachedData(JNIEnv*  env, jobject thiz) {
		
	// [migrate] 2.x 接口在 3.x 已移除（Application::purgeCachedData）

		cocos2d::Director::getInstance()->purgeCachedData();

	// [migrate] 2.x 接口在 3.x 已移除（TextureCache::dumpCachedTextureInfo）

	}
}
#endif
