#pragma once
// ---------------------------------------------------------------------------
//  CCScrollView —— 用 cocos2d::ui::ScrollView 复刻 2.x 的 CCScrollView 接口。
//
//  老工程 111 个文件、340 处引用 CCScrollView，全部依赖 2.x 语义：
//      create(Size, container) / setContainer / setContentOffset / getViewSize ...
//  这里做一个薄适配层，语义尽量对齐 2.x，避免逐页改写业务代码。
// ---------------------------------------------------------------------------
#include "cocos2d.h"
#include "ui/UIScrollView.h"

namespace cocos2d {
namespace extension {

class CCScrollView;

// 2.x: CCScrollViewDelegate
class CCScrollViewDelegate
{
public:
    virtual ~CCScrollViewDelegate() {}
    virtual void scrollViewDidScroll(CCScrollView* view) { CC_UNUSED_PARAM(view); }
    virtual void scrollViewDidZoom(CCScrollView* view) { CC_UNUSED_PARAM(view); }
    // 2.x 里还有这几个回调（3.x 没有），CCReViScrollViewFacade 会重写它们
    virtual void scrollViewDidDeaccelerateScrolling(CCScrollView* view, cocos2d::Vec2 initSpeed)
    {
        CC_UNUSED_PARAM(view);
        CC_UNUSED_PARAM(initSpeed);
    }
    virtual void scrollViewDidDeaccelerateStop(CCScrollView* view, cocos2d::Vec2 initSpeed)
    {
        CC_UNUSED_PARAM(view);
        CC_UNUSED_PARAM(initSpeed);
    }
    virtual void scrollViewDidScrollToTop(CCScrollView* view) { CC_UNUSED_PARAM(view); }
};

// 2.x 的滚动方向枚举（数值保持与原版一致，便于老代码里的比较）
enum CCScrollViewDirection
{
    kCCScrollViewDirectionNone = -1,
    kCCScrollViewDirectionHorizontal = 0,
    kCCScrollViewDirectionVertical,
    kCCScrollViewDirectionBoth
};

class CCScrollView : public cocos2d::ui::ScrollView
{
public:
    static CCScrollView* create();
    static CCScrollView* create(cocos2d::Size size, cocos2d::Node* container = nullptr);

    CCScrollView();
    virtual ~CCScrollView();

    virtual bool init() override;

    // [haizei] 触摸链路诊断（仅 HAIZEI_MENU_DIAG 时打日志，默认静默并原样转发）
    virtual bool onTouchBegan(Touch* touch, Event* event) override;
    virtual void onTouchMoved(Touch* touch, Event* event) override;
    virtual void onTouchEnded(Touch* touch, Event* event) override;

    // ---- 容器 -----------------------------------------------------------
    virtual void setContainer(cocos2d::Node* container);
    virtual cocos2d::Node* getContainer();

    // ---- 视口 -----------------------------------------------------------
    virtual void setViewSize(const cocos2d::Size& size);
    virtual const cocos2d::Size& getViewSize() const;
    // 2.x 里 setContentSize 等同于设置视口大小
    virtual void setContentSize(const cocos2d::Size& size) override;
    virtual const cocos2d::Size& getContentSize() const override;

    // ---- 偏移 -----------------------------------------------------------
    virtual void setContentOffset(cocos2d::Vec2 offset, bool animated = false);
    virtual cocos2d::Vec2 getContentOffset();
    virtual void setContentOffsetInDuration(cocos2d::Vec2 offset, float dt);
    virtual cocos2d::Vec2 maxContainerOffset();
    virtual cocos2d::Vec2 minContainerOffset();

    // ---- 行为 -----------------------------------------------------------
    virtual void setDirection(CCScrollViewDirection eDirection);
    virtual CCScrollViewDirection getDirection();
    virtual void setBounceable(bool bBounceable);
    // 2.x 的滚动阻尼接口，3.x 用 setDecelerationRate
    virtual void setScrollDeaccelRate(float fRate);
    virtual float getScrollDeaccelRate();
    virtual void setClippingToBounds(bool bClippingToBounds);
    virtual void setZoomScale(float s);
    virtual float getZoomScale();
    virtual bool isDragging();
    virtual bool isTouchMoved();
    virtual void setDelegate(CCScrollViewDelegate* pDelegate);
    virtual CCScrollViewDelegate* getDelegate();

    // 2.x 常用的“重新布局”
    virtual void updateInset();
    // [haizei] 2.x 原版：forceRecaculateChildren = _setChildMenu（刷新菜单协作状态）
    virtual void forceRecaculateChildren();

protected:
    void applyOffset(const cocos2d::Vec2& offset);
    // [haizei] 2.x 原版 _setChildMenu：递归把 container 内所有 Menu 设为
    // scrollview 协作模式（不吞触摸 + 视口命中限制 + 位移阈值激活）
    void _setChildMenu(cocos2d::Node* parent);
    // [haizei] 2.x 原版 getViewRect：视口的世界坐标矩形（含祖先缩放）
    cocos2d::Rect _getViewRect() const;
    cocos2d::Size   _compatViewSize;
    cocos2d::Node*  _compatContainer = nullptr;
    CCScrollViewDelegate* _compatDelegate = nullptr;
    CCScrollViewDirection _compatDirection = kCCScrollViewDirectionBoth;
    // 2.x 默认 m_bBounceable=false；ccbi bounces=true 时由 loader 打开
    bool  _compatBounceable = false;
    bool  _compatClipping = true;
    float _compatZoomScale = 1.0f;
    float _compatDeaccelRate = 0.0f;
    // [haizei] 拖动方向记录（2.x initSpeed 的符号近似）
    cocos2d::Vec2 _compatLastOffset;
    cocos2d::Vec2 _compatFlingDir;
};

} // namespace extension
} // namespace cocos2d

// 老代码大多 using namespace cocos2d; 或 cocos2d::extension;
namespace cocos2d {
using extension::CCScrollView;
using extension::CCScrollViewDelegate;
using extension::CCScrollViewDirection;
using extension::kCCScrollViewDirectionNone;
using extension::kCCScrollViewDirectionHorizontal;
using extension::kCCScrollViewDirectionVertical;
using extension::kCCScrollViewDirectionBoth;
}
