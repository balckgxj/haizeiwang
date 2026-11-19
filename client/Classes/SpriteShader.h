#pragma once
#include <string>
#include "cocos2d.h"

// [haizei] 2.x 移植：自定义着色器精灵基类（fightcard.sha 按血量比例灰度/闪白）。
// 3.x 渲染走 Renderer 命令管线，移植要点：
//  1) 必须重写三参 initWithTexture(texture, rect, rotated) —— 图集帧路径
//     (initWithSpriteFrame -> 三参版) 才能挂上自定义程序。
//  2) 不能在 draw() 里 prog->use()+glUniform（会污染中帧 GL 状态，
//     批渲染纹理/程序错乱——曾经把整个人物画成棕色块的根因）；
//     也不能用 setGLProgram() 挂程序（program 级共享 GLProgramState，
//     多精灵 uniform 互相覆盖）。
//     正确做法：initProgram 里给每个精灵独立 GLProgramState::create(program)
//     后 setGLProgramState()；draw() 只把 uniform 值写入 GLProgramState，
//     由渲染器在命令执行时统一应用。
class SpriteShader : public cocos2d::CCSprite
{
protected:
	virtual char* getShaderfile() = 0;
	// GLProgramState 按名字解析 uniform，此钩子保留为兼容（通常为空实现）
	virtual void initUniforms() = 0;
	// 每帧把 uniform 值写入 getGLProgramState()（存储式，非立即上传）
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
