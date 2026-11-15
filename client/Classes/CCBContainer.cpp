
#include "stdafx.h"

#include "CCBContainer.h"
#include "Language.h"
#include "GameMessages.h"
#include "waitingManager.h"
#include "script_support/CCScriptSupport.h"
#include "CCLuaEngine.h"
#include "CCScrollViewLoader.h"
#include <algorithm>

USING_NS_CC;

USING_NS_CC_EXT;

CCBContainer::CCBContainer(CCBContainerListener* ccContainerListener, int tag)
	:mActionManager(0)
	,mCCBContainerListener(ccContainerListener)
	,mCCBTag(tag)
{
	//containterCount++;
	//CCLOG("Container size:%d",containterCount);
}

CCBContainer::CCBContainer( void )
	:mActionManager(0)
	,mCCBContainerListener(0)
	,mCCBTag(0)
{
	//containterCount++;
	//CCLOG("Container size:%d",containterCount);
}


void CCBContainer::setListener( CCBContainerListener* listener , int tag)
{
	mCCBContainerListener = listener;
	mCCBTag = tag;
}

CCBContainer::~CCBContainer(void)
{
// 	containterCount--;
// 	CCLOG("Container size:%d",containterCount);
	unload();
	//if(mActionManager)mActionManager->release();
}

void CCBContainer::loadCcbiFile( const std::string& filename, bool froceLoad/* = false*/ )
{
	if(getLoaded())
	{
		if(froceLoad)
			removeAllChildren();
		else
			return;
	}
	mLoadedCCBFile = filename;
	CCLOG("load ccbi file: %s", mLoadedCCBFile.c_str());

	/* Create an autorelease CCNodeLoaderLibrary. */
	cocos2d::extension::CCNodeLoaderLibrary * ccNodeLoaderLibrary = cocos2d::extension::CCNodeLoaderLibrary::newDefaultCCNodeLoaderLibrary();
	// [haizei] 引擎默认的 cocosbuilder::ScrollViewLoader 创建的是 3.x 的
	// cocos2d::extension::ScrollView，和 compat 层的 CCScrollView 不是同一个类，
	// 业务代码 dynamic_cast 会失败（CareerPage::Enter 因此崩溃过）。
	// registerNodeLoader 是 multimap，必须先移除默认的再注册我们的。
	ccNodeLoaderLibrary->unregisterNodeLoader("CCScrollView");
	ccNodeLoaderLibrary->registerNodeLoader("CCScrollView", CCScrollViewLoader::loader());
	/* Create an autorelease CCBReader. */
	// [haizei] 2.x 的构造是 (library, listener, assigner, selector, data)，
	// 3.x 变成了 (library, assigner, selector, listener)。
	// 之前只传了 assigner，selector 没传 → 所有按钮回调
	// “Skipping selector 'onXXX' since no CCBSelectorResolver is present”。
	cocos2d::extension::CCBReader * ccbReader = new cocos2d::extension::CCBReader(ccNodeLoaderLibrary,this,this);

	/* Read a ccbi file. */
	if (filename.empty())
	{
		CCLOGERROR("[CCBContainer] loadCcbiFile called with empty filename; skip.");
		ccbReader->release();
		return;
	}
	// [haizei] 2.x 语义：把原始文件名交给 CCBReader，由 reader 内部补 ".ccbi"
	// 后缀后再搜路径。技能表里 ccbFile 存的是无后缀名（如 "s_slga"），
	// 迁移时额外加的 fullPathForFilename 预处理对无后缀名会返回空串，
	// readNodeGraphFromFile("") 静默返回 nullptr → 技能特效整个失效。
	// 这里先补齐后缀再交给 reader，行为与 2.x 一致。
	std::string ccbName = filename;
	if (ccbName.size() < 5 || ccbName.compare(ccbName.size() - 5, 5, ".ccbi") != 0)
		ccbName += ".ccbi";
	cocos2d::CCNode *node = ccbReader->readNodeGraphFromFile(ccbName.c_str(),this);
	if (!node)
	{
		// [haizei] 资源缺失或 ccbi 解析失败：原实现会带着 nullptr 继续
		// addChild/updateNode，导致 updateNode(nullptr)->getChildren() 空指针崩溃。
		// 这里提前返回，让页面以“空容器”安全存在，而不是拖垮整个进程。
		CCLOGERROR("[CCBContainer] failed to load ccbi (missing or invalid): %s", filename.c_str());
		ccbReader->release();
		return;
	}
	mActionManager = ccbReader->getAnimationManager();
	//mActionManager->runAnimations("Default");
	mActionManager->retain();
	mActionManager->setAnimationCompletedCallback(this,callfunc_selector(CCBContainer::_animationDone));
	ccbReader->release();

	Language::Get()->updateNode(node);

	addChild(node);
	setContentSize(node->getContentSize());
}

void CCBContainer::runAnimation( const std::string& actionname )
{
	if(mActionManager)
		mActionManager->runAnimations(actionname.c_str());
}

bool CCBContainer::onAssignCCBMemberVariable( cocos2d::CCObject* pTarget, const char* pMemberVariableName, cocos2d::CCNode* pNode )
{
	if(pTarget!=this) return false;
	//
	std::string var = pMemberVariableName;
	//CCBI文件自身保证不重名节点
	std::transform(var.begin(),var.end(),var.begin(),tolower);//xinzheng 2013-05-27 重做的一版资源 存在命名大小写出入，程序处理以支持
	VARIABLE_MAP::iterator it = mVariables.find(var);
	
	if(it!=mVariables.end())
	{
		if(it->second!=pNode)
		{
			it->second->release();
			it->second = pNode;
			pNode->retain();
			return true;
		}
		else
			return true;
	}

	pNode->retain();
	mVariables.insert(std::make_pair(var,pNode));
	return true;
}

cocos2d::CCObject* CCBContainer::getVariable( const std::string& variablename )
{
	std::string var(variablename);
	std::transform(var.begin(),var.end(),var.begin(),tolower);//xinzheng 2013-05-27 重做的一版资源 存在命名大小写出入，程序处理以支持
	VARIABLE_MAP::iterator it = mVariables.find(var);
	if(it!=mVariables.end())
		return it->second;
	else
	{
		// [haizei] 调试：未命中时打印 ccbi 与变量名
		CCLOG("[CCBVar] MISS '%s' in %s (have %d vars)", variablename.c_str(), mLoadedCCBFile.c_str(), (int)mVariables.size());
		return NULL;
	}
}


cocos2d::SEL_MenuHandler CCBContainer::onResolveCCBCCMenuItemSelectorWithSender( cocos2d::CCObject * pTarget, const char* pSelectorName, cocos2d::CCNode* sender )
{
	if(pTarget!=this)
		return NULL;
	std::string name = pSelectorName;
	MENUITEM_MAP::iterator it = mMenus.find(sender);
	if(it!=mMenus.end())
		it->second = name;
	else
		mMenus.insert(std::make_pair(sender,name));

	return menu_selector(CCBContainer::_menuItemClicked);
}

void CCBContainer::_menuItemClicked( cocos2d::CCObject * pSender )
{
	if(waitingManager::Get()->getWaitting())
		return;

	MENUITEM_MAP::iterator it = mMenus.find(pSender);
	if(it!=mMenus.end())
	{
		MsgButtonPressed msg;
		msg.ccb = mLoadedCCBFile;
		msg.func = it->second;
		msg.tag = mCCBTag;
		MessageManager::Get()->sendMessage(&msg);
		CCLOG("CCB:Button pressed! ccb:%s, func:%s, tag:%d",msg.ccb.c_str(),msg.func.c_str(),msg.tag);

		int ret = 0;
		if(cocos2d::ScriptEngineManager::getInstance()->getScriptEngine())
		{
			std::string luaName = mLoadedCCBFile;
			size_t lastdot = mLoadedCCBFile.find_last_of('.');
			if(lastdot!=std::string::npos)
				luaName = mLoadedCCBFile.substr(0,lastdot);
			std::string funname = luaName + "_"+ it->second;
			ret = ((cocos2d::CCLuaEngine*)cocos2d::ScriptEngineManager::getInstance()->getScriptEngine())->executeGlobalFunctionByName(funname.c_str(), this, "CCBContainer");
		}

		if(!ret)
		{
			onMenuItemAction(it->second,pSender);
			if(mCCBContainerListener)
				mCCBContainerListener->onMenuItemAction(it->second, pSender, mCCBTag);
		}
	}
}

bool CCBContainer::getLoaded()
{
	return getChildrenCount()>0;
}

void CCBContainer::unload()
{
	if(mActionManager)mActionManager->release();
	mActionManager = 0;
	VARIABLE_MAP::iterator it = mVariables.begin();
	for(;it!=mVariables.end();++it)
		if(it->second)it->second->release();

	mVariables.clear();
	mMenus.clear();
	mCCBContainerListener = 0;
	removeAllChildren();
}

void CCBContainer::_animationDone()
{
	onAnimationDone(mActionManager->getLastCompletedSequenceName());
	if(mCCBContainerListener)
		mCCBContainerListener->onAnimationDone(mActionManager->getLastCompletedSequenceName());
}

bool CCBContainer::init()
{
	mCCBContainerListener = 0;;
	mCCBTag = 0;
	mLoadedCCBFile = "";
	return true;
}

std::string CCBContainer::dumpInfo()
{
	std::string info;
	info = "CCBContainer variables name info :\n";
	VARIABLE_MAP::iterator it = mVariables.begin();
	for(;it!=mVariables.end();++it)
	{
		info += it->first + "  " + typeid(*(it->second)).name();
		info += "\n";
	}

	info += "CCBContainer menuitems name info :\n";
	MENUITEM_MAP::iterator itr = mMenus.begin();
	for(;itr!=mMenus.end();++itr)
	{
		info += itr->second;
		info += "\n";
	}

	return info;
}

unsigned long CCBContainer::containterCount = 0;

