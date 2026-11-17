
#include "stdafx.h"

#include "SpriteShader.h"
#include "cocos2d.h"

USING_NS_CC;

SpriteShader::~SpriteShader(void)
{
	cocos2d::__NotificationCenter::getInstance()->removeObserver(this, EVNET_COME_TO_FOREGROUND);
}


void SpriteShader::listenBackToForeground(CCObject *obj)
{
	setShaderProgram(NULL);
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
	if( CCSprite::initWithTexture(texture, rect, rotated) ) 
	{
		cocos2d::__NotificationCenter::getInstance()->addObserver(this, callfuncO_selector(SpriteShader::listenBackToForeground), EVNET_COME_TO_FOREGROUND, nullptr);

		this->initProgram();

		return true;
	}

	return false;
}

void SpriteShader::initProgram()
{
	GLchar * fragSource = (GLchar*) CCString::createWithContentsOfFile(
		cocos2d::FileUtils::getInstance()->fullPathForFilename(getShaderfile()).c_str())->getCString();
	CCGLProgram* pProgram = new CCGLProgram();
	pProgram->initWithVertexShaderByteArray(ccPositionTextureColor_vert, fragSource);
	setShaderProgram(pProgram);
	pProgram->release();

	CHECK_GL_ERROR_DEBUG();

	getShaderProgram()->addAttribute(kCCAttributeNamePosition, kCCVertexAttrib_Position);
	getShaderProgram()->addAttribute(kCCAttributeNameColor, kCCVertexAttrib_Color);
	getShaderProgram()->addAttribute(kCCAttributeNameTexCoord, kCCVertexAttrib_TexCoords);

	CHECK_GL_ERROR_DEBUG();

	getShaderProgram()->link();

	CHECK_GL_ERROR_DEBUG();

	getShaderProgram()->updateUniforms();

	CHECK_GL_ERROR_DEBUG();

	initUniforms();

	CHECK_GL_ERROR_DEBUG();
}

// [haizei] 3.x 渲染入口。旧 2.x 版本在 draw() 里手工设置顶点属性并 glDrawArrays；
// 3.x 改为命令管线，不能直接发 GL 调用。做法：
//   1) 确保节点程序是自定义着色器（Sprite::draw 的 TrianglesCommand 用
//      getGLProgramState()，它包装的正是节点 GLProgram）；
//   2) use() 后调用子类 setUniforms() 把 currentLife/displayLife/addColor/
//      flashType 上传（GLProgramState 只管内建 uniform，不会覆盖自定义值）；
//   3) 交给 Sprite::draw 走标准命令渲染。
void SpriteShader::draw(cocos2d::Renderer* renderer, const cocos2d::Mat4& transform, uint32_t flags)
{
	CCGLProgram* prog = getShaderProgram();
	if (prog)
	{
		if (getGLProgram() != prog)
		{
			setGLProgram(prog);
		}
		prog->use();
		setUniforms();
	}
	CCSprite::draw(renderer, transform, flags);
}
