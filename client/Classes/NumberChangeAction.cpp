
#include "stdafx.h"


#include "NumberChangeAction.h"
#include "StringConverter.h"

USING_NS_CC;

void NumberChangeAction::startWithTarget( cocos2d::Node *pTarget )
{
	ActionInterval::startWithTarget(pTarget);
	CCLabelBMFont *label = dynamic_cast<CCLabelBMFont*>(pTarget);
	mStartNumber = 0;
	if(label)
	{
		if(getDuration()<=0)
		{
			if(mDecimalCount == 0)
				label->setString(StringConverter::toString((int)mTargetNumber).c_str());
			else
			{
				char outputStr[32];
				if(mDecimalCount>7)mDecimalCount = 7;
				if(mTargetNumber>1e20)
					mTargetNumber = 1e20;
				std::string fmt = "%."+StringConverter::toString(mDecimalCount)+"f";
				sprintf(outputStr,fmt.c_str(),mTargetNumber);
				label->setString(outputStr);
			}
		}
		else
		{
			mStartNumber = StringConverter::parseReal(label->getString());
		}
	}
}

NumberChangeAction* NumberChangeAction::create( float duration, float targetNumber, int decimalCount /*= 0*/ )
{
	NumberChangeAction *pRet = new NumberChangeAction();
	if (pRet && pRet->initWithDuration(duration))
	{
		pRet->mTargetNumber = targetNumber;
		pRet->mDecimalCount = decimalCount;
		pRet->autorelease();
		return pRet;
	}
	CC_SAFE_DELETE(pRet);
	return nullptr;
}

NumberChangeAction* NumberChangeAction::clone() const
{
	NumberChangeAction* pRet = new NumberChangeAction();
	if (pRet && pRet->initWithDuration(_duration))
	{
		pRet->mTargetNumber = mTargetNumber;
		pRet->mDecimalCount = mDecimalCount;
		pRet->mStartNumber = mStartNumber;
		pRet->autorelease();
		return pRet;
	}
	CC_SAFE_DELETE(pRet);
	return nullptr;
}

NumberChangeAction* NumberChangeAction::reverse() const
{
	return NumberChangeAction::create(_duration, mTargetNumber, mDecimalCount);
}

void NumberChangeAction::update( float time )
{
	if(!_target)return;

	CCLabelBMFont *label = dynamic_cast<CCLabelBMFont*>(_target);
	if(label && getDuration()>0)
	{
		float rate = getElapsed()/getDuration();

		float curNum = mStartNumber + rate*(mTargetNumber - mStartNumber);
		if(getElapsed()>getDuration())
			curNum = mTargetNumber;

		if(mDecimalCount == 0)
			label->setString(StringConverter::toString((int)curNum).c_str());
		else
		{
			char outputStr[32];
			if(mDecimalCount>7)mDecimalCount = 7;
			if(curNum>1e20)
				curNum = 1e20;
			std::string fmt = "%."+StringConverter::toString(mDecimalCount)+"f";
			sprintf(outputStr,fmt.c_str(),curNum);
			label->setString(outputStr);
		}

	}
}
