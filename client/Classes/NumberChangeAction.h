#pragma once
#include "cocos2d.h"

// 数字滚动动画：把 CCLabelBMFont 上的数字从 0 滚到 targetNumber
// 2.x -> 3.x：copyWithZone/CCZone 已被 clone()/reverse() 取代
class NumberChangeAction : public cocos2d::ActionInterval
{
public:
    static NumberChangeAction* create(float duration, float targetNumber, int decimalCount = 0);

    virtual void startWithTarget(cocos2d::Node* pTarget) override;
    virtual void update(float time) override;
    virtual NumberChangeAction* clone() const override;
    virtual NumberChangeAction* reverse() const override;

protected:
    float mStartNumber = 0.0f;
    float mTargetNumber = 0.0f;
    int   mDecimalCount = 0;
};
