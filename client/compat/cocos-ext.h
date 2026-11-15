#pragma once
// ---------------------------------------------------------------------------
//  2.x 的 cocos-ext.h 里包含 CCScrollView / CCScale9Sprite / CCControlButton
//  等扩展控件；3.17 里它们被拆到 cocos/ui 与 extensions/GUI。
//  这里做统一补齐，保证老代码的 #include "cocos-ext.h" 仍然有效。
// ---------------------------------------------------------------------------
#include "cocos2d.h"

#include "extensions/cocos-ext.h"
#include "ui/CocosGUI.h"
#include "cocosbuilder/CCBReader.h"

#include "CCScrollViewCompat.h"
#include "revi/CCReViScrollViewFacade.h"
