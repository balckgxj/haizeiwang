#pragma once
#include <string>
#include "cocos2d.h"

// [haizei] 2.x 移植：自定义着色器精灵基类（fightcard.sha 按血量比例灰度/闪白）。
// 3.x 渲染走 Renderer 命令管线，注意两点：
//  1) 必须同时重写三参 initWithTexture(texture, rect, rotated) —— 图集帧路径
//     (initWithSpriteFrame -> 三参版) 才能挂上自定义程序；只重写二参会漏掉
//     立绘在图集里的情况（打斗灰度整个失效的根因之一）。
//  2) 2.x 的 draw() 重写在 3.x 签名变为 draw(Renderer*, Mat4, uint32_t)。
//     移植时曾被改名 drawShader() 后无人调用，血量 uniform 永远为 0。
//     现在正确重写 draw()：先 use 自定义程序、更新 uniforms，再交给
//     Sprite::draw 生成 TrianglesCommand（命令用 getGLProgramState()，
//     即本节点刚 setGLProgram 的自定义程序）。
class SpriteShader : public cocos2d::CCSprite
{
protected:
	virtual char* getShaderfile() = 0;
	//used to get uniforms from name into handle
	virtual void initUniforms() = 0;
	//used to set uniforms value 
	virtual void setUniforms() = 0;
public:
	~SpriteShader();
	// 二参版（2.x 兼容签名）：统一转发三参版
	bool initWithTexture(cocos2d::CCTexture2D* texture, const cocos2d::CCRect&  rect);
	// 三参版：图集帧 initWithSpriteFrame 走这里
	bool initWithTexture(cocos2d::CCTexture2D* texture, const cocos2d::Rect& rect, bool rotated = false);
	// 3.x 渲染入口：更新自定义 uniforms 后走标准命令管线
	virtual void draw(cocos2d::Renderer* renderer, const cocos2d::Mat4& transform, uint32_t flags) override;
	void initProgram();
	void listenBackToForeground(cocos2d::CCObject *obj);
};
