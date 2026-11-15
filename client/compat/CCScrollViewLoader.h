#pragma once
// ---------------------------------------------------------------------------
// [haizei] CCScrollViewLoader —— cocosbuilder 的 CCScrollView 加载器（3.x 版）
//
// 3.x 引擎自带的 cocosbuilder::ScrollViewLoader 创建的是 cocos2d::extension::ScrollView
//（3.x 的旧 extension 类），而本工程业务代码用的是 compat 层的
// cocos2d::extension::CCScrollView（ui::ScrollView 复刻 2.x 接口）。
// 类不匹配 → ccbi 里 75 处 CCScrollView 全部 dynamic_cast 失败 →
// CareerPage::Enter 里 mNavContent->setScrollDeaccelRate 空指针崩溃。
//
// 用法：在 CCBContainer::loadCcbiFile 里先 unregister 引擎默认的，
// 再注册本 loader（registerNodeLoader 是 multimap，不先移除会插在后面、
// getCCNodeLoader 仍返回引擎那个）。
// ---------------------------------------------------------------------------
#include "cocos2d.h"
#include "editor-support/cocosbuilder/CCNodeLoader.h"
#include "CCScrollViewCompat.h"

class CCScrollViewLoader : public cocosbuilder::NodeLoader
{
public:
    CCB_STATIC_NEW_AUTORELEASE_OBJECT_METHOD(CCScrollViewLoader, loader);

protected:
    CCB_VIRTUAL_NEW_AUTORELEASE_CREATECCNODE_METHOD(cocos2d::extension::CCScrollView);

    virtual void onHandlePropTypeSize(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, cocos2d::Size pSize, cocosbuilder::CCBReader * ccbReader);
    virtual void onHandlePropTypeCheck(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, bool pCheck, cocosbuilder::CCBReader * ccbReader);
    virtual void onHandlePropTypeCCBFile(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, cocos2d::Node * pCCBFileNode, cocosbuilder::CCBReader * ccbReader);
    virtual void onHandlePropTypeFloat(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, float pFloat, cocosbuilder::CCBReader * ccbReader);
    virtual void onHandlePropTypeIntegerLabeled(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, int pIntegerLabeled, cocosbuilder::CCBReader * ccbReader);
};
