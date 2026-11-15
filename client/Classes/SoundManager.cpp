
#include "stdafx.h"

#include "SoundManager.h"
#include "GameMessages.h"
#include "BlackBoard.h"

#include "SimpleAudioEngine.h"
#include "DataTableManager.h"
#define generalmusic "general.mp3"
#define battlemusic "battle.mp3"
#define clicksound "click.mp3"

SoundManager::SoundManager(void)
	:mMusicOn(false),mEffectOn(true)
{
}


SoundManager::~SoundManager(void)
{
}

void SoundManager::playLoadingMusic()
{
	std::string stepKey = "SetttingsMusic";
	bool _localMusic=cocos2d::UserDefault::getInstance()->getIntegerForKey(stepKey.c_str(),1)==1?true:false;
	if(_localMusic)
	{
		mPlayMusic=VaribleManager::Get()->getSetting("LoadingMusic");
		CocosDenshion::SimpleAudioEngine::getInstance()->playBackgroundMusic(VaribleManager::Get()->getSetting("LoadingMusic").c_str(), true);
	}
}
void SoundManager::playGeneralMusic()
{
    if(mMusicOn && mPlayMusic!=generalmusic)
	{
		CocosDenshion::SimpleAudioEngine::getInstance()->playBackgroundMusic(generalmusic, true);
	}
	mPlayMusic = generalmusic;
}
void SoundManager::playFightMusic()
{
    if(mMusicOn && mPlayMusic != battlemusic)
		CocosDenshion::SimpleAudioEngine::getInstance()->playBackgroundMusic(battlemusic, true);
	mPlayMusic = battlemusic;
}

void SoundManager::playMusic( std::string music )
{
	if(mMusicOn)
		CocosDenshion::SimpleAudioEngine::getInstance()->playBackgroundMusic(music.c_str(), true);
	mPlayMusic = music;
}

void SoundManager::onReceiveMassage( const GameMessage * message )
{
	if(mEffectOn)
	{
		if(!BlackBoard::Get()->isSamSungi9100Audio)
		{
			CocosDenshion::SimpleAudioEngine::getInstance()->playEffect( clicksound , false);
		}
	}
}

void SoundManager::init()
{
    MessageManager::Get()->regisiterMessageHandler(MSG_BUTTON_PRESSED, this);
    
	CocosDenshion::SimpleAudioEngine::getInstance()->preloadBackgroundMusic(battlemusic);
	CocosDenshion::SimpleAudioEngine::getInstance()->preloadBackgroundMusic(generalmusic);
	if(!BlackBoard::Get()->isSamSungi9100Audio)
	{
		CocosDenshion::SimpleAudioEngine::getInstance()->preloadEffect(clicksound);
	}
	
}

void SoundManager::setMusicOn( bool isOn)
{
	if(mMusicOn != isOn)
	{
		mMusicOn = isOn;
		if(isOn)
		{
			if(mPauseMusic == mPlayMusic)
				CocosDenshion::SimpleAudioEngine::getInstance()->resumeBackgroundMusic();
			else
				CocosDenshion::SimpleAudioEngine::getInstance()->playBackgroundMusic(mPlayMusic.c_str(), true);
		}
		else
		{
			CocosDenshion::SimpleAudioEngine::getInstance()->pauseBackgroundMusic();
			mPauseMusic = mPlayMusic;
		}
		std::string stepKey = "SetttingsMusic";
		cocos2d::UserDefault::getInstance()->setIntegerForKey(stepKey.c_str(),mMusicOn?1:0);
		cocos2d::UserDefault::getInstance()->flush();
	}
}

void SoundManager::setEffectOn( bool isOn)
{
	mEffectOn = isOn;
	if(!isOn)
	{
		if(!BlackBoard::Get()->isSamSungi9100Audio)
		{
			CocosDenshion::SimpleAudioEngine::getInstance()->stopAllEffects();
		}
	}
	std::string stepKey = "SetttingsEffect";
	cocos2d::UserDefault::getInstance()->setIntegerForKey(stepKey.c_str(),mEffectOn?1:0);
	cocos2d::UserDefault::getInstance()->flush();
}

int SoundManager::playEffect( std::string effect )
{
	if(mEffectOn)
	{
		//CocosDenshion::SimpleAudioEngine::getInstance()->unloadEffect( effect.c_str());
		if(!BlackBoard::Get()->isSamSungi9100Audio)
		{
			return CocosDenshion::SimpleAudioEngine::getInstance()->playEffect( effect.c_str() , false);
		}
		else
		{
			return -1;
		}
	}
	return -1;
}

void SoundManager::appGotoBackground()
{
	CocosDenshion::SimpleAudioEngine::getInstance()->pauseBackgroundMusic();
	if(!BlackBoard::Get()->isSamSungi9100Audio)
	{
		CocosDenshion::SimpleAudioEngine::getInstance()->pauseAllEffects();
	}
}	

void SoundManager::appResumeBackground()
{
	if(mMusicOn)
		CocosDenshion::SimpleAudioEngine::getInstance()->resumeBackgroundMusic();
	if(mEffectOn)
	{
		if(!BlackBoard::Get()->isSamSungi9100Audio)
		{
			CocosDenshion::SimpleAudioEngine::getInstance()->resumeAllEffects();
		}
	}
}

SoundManager* SoundManager::getInstance()
{
	return SoundManager::Get();
}

void SoundManager::stopAllEffect()
{
	CocosDenshion::SimpleAudioEngine::getInstance()->stopAllEffects();
}

void SoundManager::stopMusic()
{
	mPlayMusic = "";
	CocosDenshion::SimpleAudioEngine::getInstance()->stopBackgroundMusic();
}
