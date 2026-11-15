
#include "stdafx.h"

#include "AsyncSprite.h"
#include "cocos2d.h"


USING_NS_CC;

void AsyncSprite::setAsyncTexture( const std::string & texturename )
{
	mTextureName = texturename;

	const char * name = texturename.c_str();
	std::string path = cocos2d::FileUtils::getInstance()->fullPathForFilename(texturename.c_str()).c_str();
	cocos2d::CCTexture2D* tex = cocos2d::Director::getInstance()->getTextureCache()->textureForKey(path.c_str());
	if(tex!=0)
	{
		CCNode* _node = getChildByTag(TAG_SPRITE);
		if(_node)
			removeChildByTag(TAG_SPRITE);
		cocos2d::CCSprite *spirte = cocos2d::CCSprite::createWithTexture(tex);
		addChild(spirte,0,TAG_SPRITE);
	}
	else
	{
		cocos2d::Director::getInstance()->getTextureCache()->addImageAsync(path, [this](cocos2d::Texture2D* tex) { this->loadImageDone((cocos2d::Ref*)tex); }, nullptr);
	}

}


void AsyncSprite::setAsyncFrame( const std::string & frameName,const std::string & plistname )
{
	mFrameName = frameName;
	mTextureName ="";
	mPlistName = plistname;

	cocos2d::CCSpriteFrame* frame = cocos2d::SpriteFrameCache::getInstance()->spriteFrameByName(frameName.c_str());
	if(frame)
	{
		CCNode* _node = getChildByTag(TAG_SPRITE);
		if(_node)
			removeChildByTag(TAG_SPRITE);
		cocos2d::CCSprite *spirte = cocos2d::CCSprite::createWithSpriteFrame(frame);
		addChild(spirte,0,TAG_SPRITE);
	}
	else
	{
		const char *pszPath = cocos2d::FileUtils::getInstance()->fullPathForFilename(plistname.c_str()).c_str();
		cocos2d::CCDictionary* mDict = CCDictionary::createWithContentsOfFileThreadSafe(pszPath);
		mDict->retain();

		std::string texturePath("");

		CCDictionary* metadataDict = (CCDictionary*)mDict->objectForKey("metadata");
		if (metadataDict)
		{
			// try to read  texture file name from meta data
			texturePath = metadataDict->valueForKey("textureFileName")->getCString();
		}

		if (! texturePath.empty())
		{
			// build texture path relative to plist file
			texturePath = cocos2d::FileUtils::getInstance()->fullPathFromRelativeFile(texturePath.c_str(), pszPath);
		}
		else
		{
			// build texture path by replacing file extension
			texturePath = pszPath;

			// remove .xxx
			size_t startPos = texturePath.find_last_of("."); 
			texturePath = texturePath.erase(startPos);

			// append .png
			texturePath = texturePath.append(".png");

			CCLOG("cocos2d: CCSpriteFrameCache: Trying to use file %s as texture", texturePath.c_str());
		}

		mTextureName = texturePath;
		cocos2d::Director::getInstance()->getTextureCache()->addImageAsync(texturePath, [this](cocos2d::Texture2D* tex) { this->loadFrameDone((cocos2d::Ref*)tex); }, nullptr);
	}

}
void AsyncSprite::setColor(const cocos2d::ccColor3B color){
	mColor = color;
}


void AsyncSprite::loadImageDone( cocos2d::CCObject* texture )
{
	if(texture)
	{
		std::string path = cocos2d::FileUtils::getInstance()->fullPathForFilename(mTextureName.c_str()).c_str();
		cocos2d::CCTexture2D* tex = cocos2d::Director::getInstance()->getTextureCache()->textureForKey(path.c_str());
		if(tex!=0)
		{
			CCNode* _node = getChildByTag(TAG_SPRITE);
			if(_node)
				removeChildByTag(TAG_SPRITE);
			cocos2d::CCSprite *spirte = cocos2d::CCSprite::createWithTexture(tex);
			spirte->setColor(mColor);
			addChild(spirte,0,TAG_SPRITE);
		}
	}
}

void AsyncSprite::loadFrameDone( cocos2d::CCObject* texture )
{
	if(texture && !mPlistName.empty())
	{
		CCTexture2D *pTexture = cocos2d::Director::getInstance()->getTextureCache()->addImage(mTextureName.c_str());

		if (pTexture)
		{
			cocos2d::SpriteFrameCache::getInstance()->addSpriteFramesWithFile(mPlistName.c_str(), pTexture);
			cocos2d::CCSpriteFrame* frame = cocos2d::SpriteFrameCache::getInstance()->spriteFrameByName(mFrameName.c_str());
			if(frame)
			{
				CCNode* _node = getChildByTag(TAG_SPRITE);
				if(_node)
					removeChildByTag(TAG_SPRITE);
				cocos2d::CCSprite *spirte = cocos2d::CCSprite::createWithSpriteFrame(frame);
				addChild(spirte,0,TAG_SPRITE);
			}
		}
	}
}

AsyncSprite* AsyncSprite::createWithSprite( cocos2d::CCSprite *pSprite )
{
	AsyncSprite *pobSprite = new AsyncSprite();
//	pobSprite->childSprite = pSprite;
	if (pobSprite &&pobSprite->initWithSprite(pSprite))
	{
		pobSprite->autorelease();
		return pobSprite;
	}
	CC_SAFE_DELETE(pobSprite);
	return NULL;
}

bool AsyncSprite::initWithSprite( cocos2d::CCSprite* pSprite)
{
	if(!pSprite)
		return false;
	addChild(pSprite,0,TAG_SPRITE);
	return true;
}
