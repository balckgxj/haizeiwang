
#include "stdafx.h"

#include <stdio.h>
#include <map>
#include <string>

#include "SpriteShader.h"
#include "cocos2d.h"

USING_NS_CC;

// [haizei] 着色器程序缓存：同一 shader 文件只编译/链接一次
static std::map<std::string, CCGLProgram*>& shaderProgramCache()
{
	static std::map<std::string, CCGLProgram*> cache;
	return cache;
}

SpriteShader::~SpriteShader(void)
{
	cocos2d::__NotificationCenter::getInstance()->removeObserver(this, EVNET_COME_TO_FOREGROUND);
}


void SpriteShader::listenBackToForeground(CCObject *obj)
{
	// GL 上下文丢失：所有缓存的 program 都失效，清空后重建
	for (auto& kv : shaderProgramCache())
	{
		kv.second->release();
	}
	shaderProgramCache().clear();

	initProgram();
}

// [haizei] 二参版只是兼容旧签名，统一走三参版，保证任何加载路径都挂上自定义程序
bool SpriteShader::initWithTexture(CCTexture2D* texture, const CCRect& rect)
{
	return initWithTexture(texture, rect, false);
}

// [haizei] 三参版：Sprite::initWithSpriteFrame 内部就是调它（CCSprite.cpp:289），
// 图集帧加载的角色立绘必须在这里挂自定义程序，否则 fightcard.sha 永远不生效
bool SpriteShader::initWithTexture(CCTexture2D* texture, const cocos2d::Rect& rect, bool rotated)
{
	if (CCSprite::initWithTexture(texture, rect, rotated))
	{
		cocos2d::__NotificationCenter::getInstance()->addObserver(this, callfuncO_selector(SpriteShader::listenBackToForeground), EVNET_COME_TO_FOREGROUND, nullptr);

		this->initProgram();

		return true;
	}

	return false;
}

void SpriteShader::initProgram()
{
	const char* file = getShaderfile();
	const std::string key(file);

	CCGLProgram* pProgram = NULL;
	auto it = shaderProgramCache().find(key);
	if (it != shaderProgramCache().end())
	{
		pProgram = it->second;
	}
	else
	{
		GLchar * fragSource = (GLchar*) CCString::createWithContentsOfFile(
			cocos2d::FileUtils::getInstance()->fullPathForFilename(file).c_str())->getCString();
		pProgram = new CCGLProgram(); // refcount=1，由缓存持有

		// [haizei] 本项目 3.x 引擎为兼容 2.x 坐标，把 CCSprite 默认程序改成了
		// SHADER_NAME_POSITION_TEXTURE_COLOR_NO_MVP：Quad 顶点已是世界空间，
		// 顶点着色器只乘 CC_PMatrix。自定义 shader 必须沿用同一个顶点着色器，
		// 否则会再乘一次 CC_MVPMatrix，人物立绘错位/缩成色块。
		pProgram->initWithVertexShaderByteArray(ccPositionTextureColor_noMVP_vert, fragSource);

		pProgram->addAttribute(kCCAttributeNamePosition, kCCVertexAttrib_Position);
		pProgram->addAttribute(kCCAttributeNameColor, kCCVertexAttrib_Color);
		pProgram->addAttribute(kCCAttributeNameTexCoord, kCCVertexAttrib_TexCoords);

		pProgram->link();
		pProgram->updateUniforms();

		shaderProgramCache()[key] = pProgram;
	}

	// [haizei] 3.x 渲染器只认命令携带的 GLProgramState。
	// 不能用 setGLProgram()/setShaderProgram()：那会拿到 program 级共享 state，
	// 同 program 的所有精灵共用血量/闪白 uniform，互相覆盖。
	// 每精灵独立 GLProgramState，渲染器执行命令时统一应用本精灵的 uniform。
	cocos2d::GLProgramState* state = cocos2d::GLProgramState::create(pProgram);
	setGLProgramState(state);

	initUniforms();
}

// [haizei] 3.x 渲染入口。绝不能在这里 prog->use() / 直接 glUniform——
// 那些是立即执行的 GL 调用，会污染当前激活的程序与纹理绑定，打乱渲染器批次。
// 正确做法：把 uniform 值写进 GLProgramState（存储式），Sprite::draw
// 生成的 TrianglesCommand 携带本精灵的 state，渲染器执行命令时统一应用。
void SpriteShader::draw(cocos2d::Renderer* renderer, const cocos2d::Mat4& transform, uint32_t flags)
{
	setUniforms();

	CCSprite::draw(renderer, transform, flags);
}
