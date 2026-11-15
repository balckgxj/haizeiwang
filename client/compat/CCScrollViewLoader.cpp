// [haizei] 见 CCScrollViewLoader.h 的说明
#include "CCScrollViewLoader.h"

#define PROPERTY_CONTAINER "container"
#define PROPERTY_DIRECTION "direction"
#define PROPERTY_CLIPSTOBOUNDS "clipsToBounds"
#define PROPERTY_BOUNCES "bounces"
#define PROPERTY_SCALE "scale"

void CCScrollViewLoader::onHandlePropTypeSize(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, cocos2d::Size pSize, cocosbuilder::CCBReader * ccbReader)
{
    if (strcmp(pPropertyName, PROPERTY_CONTENTSIZE) == 0) {
        ((cocos2d::extension::CCScrollView *)pNode)->setViewSize(pSize);
    } else {
        cocosbuilder::NodeLoader::onHandlePropTypeSize(pNode, pParent, pPropertyName, pSize, ccbReader);
    }
}

void CCScrollViewLoader::onHandlePropTypeCheck(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, bool pCheck, cocosbuilder::CCBReader * ccbReader)
{
    if (strcmp(pPropertyName, PROPERTY_CLIPSTOBOUNDS) == 0) {
        ((cocos2d::extension::CCScrollView *)pNode)->setClippingToBounds(pCheck);
    } else if (strcmp(pPropertyName, PROPERTY_BOUNCES) == 0) {
        ((cocos2d::extension::CCScrollView *)pNode)->setBounceable(pCheck);
    } else {
        cocosbuilder::NodeLoader::onHandlePropTypeCheck(pNode, pParent, pPropertyName, pCheck, ccbReader);
    }
}

void CCScrollViewLoader::onHandlePropTypeCCBFile(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, cocos2d::Node * pCCBFileNode, cocosbuilder::CCBReader * ccbReader)
{
    if (strcmp(pPropertyName, PROPERTY_CONTAINER) == 0) {
        ((cocos2d::extension::CCScrollView *)pNode)->setContainer(pCCBFileNode);
        ((cocos2d::extension::CCScrollView *)pNode)->updateInset();
    } else {
        cocosbuilder::NodeLoader::onHandlePropTypeCCBFile(pNode, pParent, pPropertyName, pCCBFileNode, ccbReader);
    }
}

void CCScrollViewLoader::onHandlePropTypeFloat(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, float pFloat, cocosbuilder::CCBReader * ccbReader)
{
    if (strcmp(pPropertyName, PROPERTY_SCALE) == 0) {
        ((cocos2d::extension::CCScrollView *)pNode)->setScale(pFloat);
    } else {
        cocosbuilder::NodeLoader::onHandlePropTypeFloat(pNode, pParent, pPropertyName, pFloat, ccbReader);
    }
}

void CCScrollViewLoader::onHandlePropTypeIntegerLabeled(cocos2d::Node * pNode, cocos2d::Node * pParent, const char* pPropertyName, int pIntegerLabeled, cocosbuilder::CCBReader * ccbReader)
{
    if (strcmp(pPropertyName, PROPERTY_DIRECTION) == 0) {
        ((cocos2d::extension::CCScrollView *)pNode)->setDirection((cocos2d::extension::CCScrollViewDirection)pIntegerLabeled);
    } else {
        cocosbuilder::NodeLoader::onHandlePropTypeIntegerLabeled(pNode, pParent, pPropertyName, pIntegerLabeled, ccbReader);
    }
}
