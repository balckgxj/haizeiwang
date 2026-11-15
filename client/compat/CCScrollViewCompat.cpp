#include "CCScrollViewCompat.h"
#include "ui/UIScrollView.h"
#include "ui/UILayout.h"
#include <cstdlib>

NS_CC_BEGIN
namespace extension {

CCScrollView* CCScrollView::create()
{
    CCScrollView* ret = new (std::nothrow) CCScrollView();
    if (ret && ret->init())
    {
        ret->autorelease();
        return ret;
    }
    CC_SAFE_DELETE(ret);
    return nullptr;
}

CCScrollView* CCScrollView::create(cocos2d::Size size, cocos2d::Node* container)
{
    CCScrollView* ret = new (std::nothrow) CCScrollView();
    if (ret && ret->init())
    {
        ret->autorelease();
        ret->setViewSize(size);
        if (container)
        {
            ret->setContainer(container);
        }
        return ret;
    }
    CC_SAFE_DELETE(ret);
    return nullptr;
}

CCScrollView::CCScrollView()
{
}

CCScrollView::~CCScrollView()
{
}

bool CCScrollView::init()
{
    if (!cocos2d::ui::ScrollView::init())
    {
        return false;
    }
    // [parity] 2.x 的 CCScrollView 与内部 CCMenu 是协同关系：
    // CCMenu 以 kCCMenuHandlerPriority(-128) 先收触摸且不吞（setScrollViewChild(true)），
    // ScrollView 随后也能收到拖动。3.x ui::Widget 默认 setSwallowTouches(true)，
    // 一旦 ScrollView 先吞掉触摸，容器内后加入的按钮（如主城阵容头像 framedButton）
    // 就永远收不到事件。这里关掉吞触摸，恢复 2.x 的协同分发。
    this->setSwallowTouches(false);
    // [parity] 2.x 的 CCScrollView 默认 m_bBounceable = false（不可回弹，拖到边界即停）。
    // ccbi 里 bounces=true 的滚动视图会经 CCScrollViewLoader 显式 setBounceable(true) 打开。
    cocos2d::ui::ScrollView::setDirection(cocos2d::ui::ScrollView::Direction::BOTH);
    this->setBounceEnabled(false);
    this->setClippingEnabled(true);
    this->setScrollBarEnabled(false);
    _compatViewSize = this->getContentSize();

    auto cb = [this](cocos2d::Ref*, cocos2d::ui::ScrollView::EventType type) {
        if (!_compatDelegate)
        {
            return;
        }
        switch (type)
        {
        case cocos2d::ui::ScrollView::EventType::SCROLLING:
        {
            // 记录最后拖动方向，作为 2.x initSpeed（业务只关心符号）的近似
            cocos2d::Vec2 now = this->getContentOffset();
            _compatFlingDir = cocos2d::Vec2(now.x - _compatLastOffset.x, now.y - _compatLastOffset.y);
            _compatLastOffset = now;
            _compatDelegate->scrollViewDidScroll(this);
            break;
        }
        case cocos2d::ui::ScrollView::EventType::SCROLLING_BEGAN:
            _compatLastOffset = this->getContentOffset();
            _compatFlingDir = cocos2d::Vec2::ZERO;
            break;
        case cocos2d::ui::ScrollView::EventType::SCROLLING_ENDED:
        case cocos2d::ui::ScrollView::EventType::AUTOSCROLL_ENDED:
            // [haizei] 2.x：松手（可无惯性）后触发 deaccelerateStop（翻页吸附等）
            _compatDelegate->scrollViewDidDeaccelerateStop(this, cocos2d::Vec2(_compatFlingDir.x * 60.0f, _compatFlingDir.y * 60.0f));
            break;
        default:
            break;
        }
    };
    this->addEventListener(cb);
    return true;
}

bool CCScrollView::onTouchBegan(Touch* touch, Event* event)
{
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    bool ret = cocos2d::ui::ScrollView::onTouchBegan(touch, event);
    if (sDiag)
    {
        CCLOG("[SVDiag] onTouchBegan ret=%d dir=%d view=(%.0f,%.0f) touch=(%.0f,%.0f) innerPos=(%.0f,%.0f)",
              (int)ret, (int)_compatDirection,
              _compatViewSize.width, _compatViewSize.height,
              touch->getLocation().x, touch->getLocation().y,
              getInnerContainer()->getPosition().x, getInnerContainer()->getPosition().y);
    }
    return ret;
}
void CCScrollView::onTouchMoved(Touch* touch, Event* event)
{
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    if (sDiag)
    {
        CCLOG("[SVDiag] onTouchMoved touch=(%.0f,%.0f) innerPosBefore=(%.0f,%.0f)",
              touch->getLocation().x, touch->getLocation().y,
              getInnerContainer()->getPosition().x, getInnerContainer()->getPosition().y);
    }
    cocos2d::ui::ScrollView::onTouchMoved(touch, event);
    if (sDiag)
    {
        CCLOG("[SVDiag]   innerPosAfter=(%.0f,%.0f) scrolling=%d",
              getInnerContainer()->getPosition().x, getInnerContainer()->getPosition().y,
              (int)this->isScrolling());
    }
}
void CCScrollView::onTouchEnded(Touch* touch, Event* event)
{
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    if (sDiag)
    {
        CCLOG("[SVDiag] onTouchEnded touch=(%.0f,%.0f) innerPosBefore=(%.0f,%.0f) bounceable=%d",
              touch->getLocation().x, touch->getLocation().y,
              getInnerContainer()->getPosition().x, getInnerContainer()->getPosition().y,
              (int)_compatBounceable);
    }
    // bounceable=false 时 base 的 handleReleaseLogic 不会回弹(startBounceBackIfNeeded 返回 false)，
    // 且惯性已关闭，故松手后停在拖动位置（越界部分在拖动过程中已被 clamp）。
    cocos2d::ui::ScrollView::onTouchEnded(touch, event);
    if (sDiag)
    {
        CCLOG("[SVDiag]   innerPosAfter=(%.0f,%.0f) scrolling=%d",
              getInnerContainer()->getPosition().x, getInnerContainer()->getPosition().y,
              (int)this->isScrolling());
    }
}

void CCScrollView::setContainer(cocos2d::Node* container)
{
    // [haizei] 2.x 原版：NULL 直接 return
    if (!container)
    {
        return;
    }
    if (_compatContainer == container)
    {
        return;
    }
    if (_compatContainer)
    {
        _compatContainer->removeFromParent();
    }

    // [haizei] 2.x 语义：container 的 position 就是初始 contentOffset。
    // 先把业务/ccbi 里设定的位置记下来，容器挂到 innerContainer 后归零，
    // 再以 offset 的形式恢复。
    cocos2d::Vec2 initialOffset = container->getPosition();

    _compatContainer = container;

    // [haizei] 2.x 原版 setContainer：强制 anchor(0,0)，
    // 让 container 的 position/offset 直接对应其左下角。
    _compatContainer->setIgnoreAnchorPointForPosition(false);
    _compatContainer->setAnchorPoint(cocos2d::Vec2::ZERO);

    // 3.x ui::ScrollView::addChild 覆写会自动把子节点挂进 innerContainer，
    // 拖动/惯性/回弹移动 innerContainer 时业务内容随之移动 ——
    // 这是 2.x「移动 container」的等价物。
    this->addChild(_compatContainer);
    _compatContainer->setPosition(cocos2d::Vec2::ZERO);

    cocos2d::Size s = _compatContainer->getContentSize();
    if (s.width <= 0.f || s.height <= 0.f)
    {
        s = _compatViewSize;
    }
    if (std::getenv("HAIZEI_MENU_DIAG") != nullptr)
    {
        cocos2d::Size baseContent = cocos2d::Node::getContentSize();
        cocos2d::Vec2 wp = this->convertToWorldSpace(cocos2d::Vec2::ZERO);
        CCLOG("[SVDiag] setContainer viewSize=(%.0f,%.0f) nodeContent=(%.0f,%.0f) baseContent=(%.0f,%.0f) dir=%d worldPos=(%.0f,%.0f)",
              _compatViewSize.width, _compatViewSize.height,
              s.width, s.height,
              baseContent.width, baseContent.height,
              (int)_compatDirection, wp.x, wp.y);
    }
    this->setInnerContainerSize(s);

    // setInnerContainerSize 会按 3.x 语义重排 inner 位置，这里恢复 2.x 初始偏移
    this->applyOffset(initialOffset);

    _setChildMenu(_compatContainer);
}

cocos2d::Node* CCScrollView::getContainer()
{
    return _compatContainer;
}

void CCScrollView::setViewSize(const cocos2d::Size& size)
{
    _compatViewSize = size;
    // [haizei] 视口变化时保持当前 2.x offset 不变
    cocos2d::Vec2 off = this->getContentOffset();
    cocos2d::ui::ScrollView::setContentSize(size);
    if (_compatContainer)
    {
        cocos2d::Size cs = _compatContainer->getContentSize();
        if (cs.width <= 0.f || cs.height <= 0.f)
        {
            cs = size;
        }
        this->setInnerContainerSize(cs);
    }
    this->applyOffset(off);
}

const cocos2d::Size& CCScrollView::getViewSize() const
{
    return _compatViewSize;
}

void CCScrollView::setContentSize(const cocos2d::Size& size)
{
    // [haizei] 2.x 原版：setContentSize 设的是 container(内容)大小 + updateInset，
    // 视口大小不变；container 为 NULL 时完全空操作。业务代码大量依赖此语义。
    //
    // 但 3.x ui::Widget::onEnter -> updateSizeAndPosition 会在【每次进场景】时用
    // 节点自身尺寸重放 setContentSize（值 == 当前 3.x 节点 _contentSize，即视口尺寸）。
    // 若把它当 2.x 语义处理，container/inner 尺寸会被砸回视口尺寸，滚动余量归零，
    // 拖动变成纯橡皮筋、松手弹回原点（主页头像行/底部导航横滑失效的根因）。
    // 因此：传入值 == 当前 3.x 节点尺寸时，视为 3.x 节点尺寸重放，直接跳过。
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    const cocos2d::Size nodeSize = cocos2d::Node::getContentSize();
    const bool isNodeSizeReplay =
        (fabsf(size.width - nodeSize.width) < 0.01f &&
         fabsf(size.height - nodeSize.height) < 0.01f);
    if (sDiag)
    {
        CCLOG("[SVDiag] setContentSize size=(%.0f,%.0f) container=%p nodeSize=(%.0f,%.0f) replay=%d",
              size.width, size.height, (void*)_compatContainer,
              nodeSize.width, nodeSize.height, (int)isNodeSizeReplay);
    }
    if (!_compatContainer || isNodeSizeReplay)
    {
        // 2.x：container 为 NULL 是空操作；3.x 尺寸重放不改变任何业务布局
        return;
    }
    _compatContainer->setContentSize(size);
    cocos2d::Vec2 off = this->getContentOffset();
    this->setInnerContainerSize(size);
    this->applyOffset(off);
}

const cocos2d::Size& CCScrollView::getContentSize() const
{
    // [haizei] 2.x 原版：返回 container(内容)的大小
    if (_compatContainer)
    {
        return _compatContainer->getContentSize();
    }
    return _compatViewSize;
}

// ---------------------------------------------------------------------------
// [haizei] 2.x contentOffset 语义：
//   offset == container 的 position（原值，不取反），即「内容块左下角」相对
//   视口左下角的位置。3.x 的 innerContainer（Layout，anchor 任意）挂业务
//   container（anchor(0,0)，position(0,0)），故：
//   offset = innerContainer.position - anchor * innerSize  （= inner 左下角）
//   该换算与 anchor 无关地成立，拖动/clamp 语义与 2.x 完全一致。
// ---------------------------------------------------------------------------
static cocos2d::Vec2 s_innerBottomLeft(const cocos2d::Node* inner)
{
    cocos2d::Vec2 p = inner->getPosition();
    cocos2d::Size s = inner->getContentSize();
    cocos2d::Vec2 a = inner->getAnchorPoint();
    return cocos2d::Vec2(p.x - a.x * s.width, p.y - a.y * s.height);
}

static cocos2d::Vec2 s_innerPosForBottomLeft(const cocos2d::Node* inner, const cocos2d::Vec2& offset)
{
    cocos2d::Size s = inner->getContentSize();
    cocos2d::Vec2 a = inner->getAnchorPoint();
    return cocos2d::Vec2(offset.x + a.x * s.width, offset.y + a.y * s.height);
}

void CCScrollView::applyOffset(const cocos2d::Vec2& offset)
{
    auto inner = this->getInnerContainer();
    if (!inner)
    {
        return;
    }
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    if (sDiag)
    {
        cocos2d::Size cs = inner->getContentSize();
        cocos2d::Vec2 a = inner->getAnchorPoint();
        CCLOG("[SVDiag] applyOffset offset=(%.1f,%.1f) innerAnchor=(%.2f,%.2f) innerSize=(%.0f,%.0f) posBefore=(%.1f,%.1f)",
              offset.x, offset.y, a.x, a.y, cs.width, cs.height,
              inner->getPosition().x, inner->getPosition().y);
    }
    inner->setPosition(s_innerPosForBottomLeft(inner, offset));
    if (sDiag)
    {
        CCLOG("[SVDiag] applyOffset posAfter=(%.1f,%.1f)",
              inner->getPosition().x, inner->getPosition().y);
    }
}

void CCScrollView::setContentOffset(cocos2d::Vec2 offset, bool animated)
{
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    if (sDiag)
    {
        CCLOG("[SVDiag] setContentOffset called offset=(%.1f,%.1f) animated=%d bounceable=%d innerPos=(%.1f,%.1f)",
              offset.x, offset.y, (int)animated, (int)_compatBounceable,
              getInnerContainer()->getPosition().x, getInnerContainer()->getPosition().y);
    }
    if (animated)
    {
        setContentOffsetInDuration(offset, 0.2f);
        return;
    }
    // [haizei] 2.x 原版：不可回弹时把 offset clamp 到 [min, max]
    if (!_compatBounceable)
    {
        cocos2d::Vec2 minOffset = this->minContainerOffset();
        cocos2d::Vec2 maxOffset = this->maxContainerOffset();
        offset.x = MAX(minOffset.x, MIN(maxOffset.x, offset.x));
        offset.y = MAX(minOffset.y, MIN(maxOffset.y, offset.y));
    }
    applyOffset(offset);
}

cocos2d::Vec2 CCScrollView::getContentOffset()
{
    auto inner = this->getInnerContainer();
    if (!inner)
    {
        return cocos2d::Vec2::ZERO;
    }
    return s_innerBottomLeft(inner);
}

void CCScrollView::setContentOffsetInDuration(cocos2d::Vec2 offset, float dt)
{
    auto inner = this->getInnerContainer();
    if (!inner)
    {
        return;
    }
    inner->stopAllActions();
    inner->runAction(cocos2d::MoveTo::create(dt, s_innerPosForBottomLeft(inner, offset)));
}

cocos2d::Vec2 CCScrollView::minContainerOffset()
{
    // [haizei] 2.x 原版：内容超出视口的部分取负值，不足视口时为 0
    float x = 0.f, y = 0.f;
    if (_compatContainer)
    {
        cocos2d::Size cs = _compatContainer->getContentSize();
        x = _compatViewSize.width  - cs.width  * _compatContainer->getScaleX();
        y = _compatViewSize.height - cs.height * _compatContainer->getScaleY();
    }
    return cocos2d::Vec2(x < 0.f ? x : 0.f, y < 0.f ? y : 0.f);
}

cocos2d::Vec2 CCScrollView::maxContainerOffset()
{
    // [haizei] 2.x 原版：内容不足视口的余量取正值，超出视口时为 0
    float x = 0.f, y = 0.f;
    if (_compatContainer)
    {
        cocos2d::Size cs = _compatContainer->getContentSize();
        x = _compatViewSize.width  - cs.width  * _compatContainer->getScaleX();
        y = _compatViewSize.height - cs.height * _compatContainer->getScaleY();
    }
    return cocos2d::Vec2(x > 0.f ? x : 0.f, y > 0.f ? y : 0.f);
}

void CCScrollView::setDirection(CCScrollViewDirection eDirection)
{
    _compatDirection = eDirection;
    switch (eDirection)
    {
    case kCCScrollViewDirectionHorizontal:
        cocos2d::ui::ScrollView::setDirection(cocos2d::ui::ScrollView::Direction::HORIZONTAL);
        break;
    case kCCScrollViewDirectionVertical:
        cocos2d::ui::ScrollView::setDirection(cocos2d::ui::ScrollView::Direction::VERTICAL);
        break;
    case kCCScrollViewDirectionBoth:
        cocos2d::ui::ScrollView::setDirection(cocos2d::ui::ScrollView::Direction::BOTH);
        break;
    default:
        cocos2d::ui::ScrollView::setDirection(cocos2d::ui::ScrollView::Direction::NONE);
        break;
    }
}

CCScrollViewDirection CCScrollView::getDirection()
{
    return _compatDirection;
}

void CCScrollView::setBounceable(bool bBounceable)
{
    // [haizei] 2.x 语义：bounceable=false 时拖动到边界即硬停、松手不回弹。
    // 之前关 3.x 回弹会导致"完全滚不动"，根因是 inner 容器尺寸被 3.x Widget::onEnter
    // 的 setContentSize 重放砸回视口尺寸（已在 setContentSize 里修复）。尺寸正确后，
    // 关闭 bounce 是安全的：3.x scrollChildren 只会 clamp 越界部分，界内正常滚动。
    // 惯性(减速滑行)保持开启——2.x 松手后同样有 deaccel，故不随 bounce 关闭。
    _compatBounceable = bBounceable;
    this->setBounceEnabled(bBounceable);
}

void CCScrollView::setScrollDeaccelRate(float fRate)
{
    // 3.x ui::ScrollView û�� decelerationRate �ӿڣ������¼ 2.x ��ֵ��ӳ�䵽���Թ�������
    _compatDeaccelRate = fRate;
    this->setInertiaScrollEnabled(fRate > 0.0f);
}

float CCScrollView::getScrollDeaccelRate()
{
    return _compatDeaccelRate;
}

void CCScrollView::setClippingToBounds(bool bClippingToBounds)
{
    _compatClipping = bClippingToBounds;
    this->setClippingEnabled(bClippingToBounds);
}

void CCScrollView::setZoomScale(float s)
{
    _compatZoomScale = s;
    if (_compatContainer)
    {
        _compatContainer->setScale(s);
        cocos2d::Size cs = _compatContainer->getContentSize();
        this->setInnerContainerSize(cocos2d::Size(cs.width * s, cs.height * s));
    }
}

float CCScrollView::getZoomScale()
{
    return _compatZoomScale;
}

bool CCScrollView::isDragging()
{
    return this->isScrolling();
}

bool CCScrollView::isTouchMoved()
{
    return this->isScrolling();
}

void CCScrollView::setDelegate(CCScrollViewDelegate* pDelegate)
{
    _compatDelegate = pDelegate;
}

CCScrollViewDelegate* CCScrollView::getDelegate()
{
    return _compatDelegate;
}

void CCScrollView::updateInset()
{
    // [haizei] 2.x 原版 updateInset 只重算回弹 inset 不动位置；
    // 3.x 用 innerContainer 尺寸承载回弹范围，这里同步尺寸并保持当前 offset。
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    if (sDiag)
    {
        CCLOG("[SVDiag] updateInset called innerPos=(%.1f,%.1f)",
              getInnerContainer()->getPosition().x, getInnerContainer()->getPosition().y);
    }
    if (_compatContainer)
    {
        cocos2d::Vec2 off = this->getContentOffset();
        cocos2d::Size cs = _compatContainer->getContentSize();
        this->setInnerContainerSize(cocos2d::Size(cs.width * _compatZoomScale,
                                                  cs.height * _compatZoomScale));
        this->applyOffset(off);
    }
}

// [haizei] 2.x 原版 getViewRect：视口的世界坐标矩形（含祖先缩放）
cocos2d::Rect CCScrollView::_getViewRect() const
{
    // convertToWorldSpace 是 const 方法吗？Node::convertToWorldSpace 非 const，
    // 但 2.x 原版在非 const 上下文调用；这里 const_cast 保持接口 const。
    cocos2d::Node* self = const_cast<CCScrollView*>(this);
    cocos2d::Vec2 worldPos = self->convertToWorldSpace(cocos2d::Vec2::ZERO);

    float scaleX = self->getScaleX();
    float scaleY = self->getScaleY();
    for (cocos2d::Node* p = self->getParent(); p != nullptr; p = p->getParent())
    {
        scaleX *= p->getScaleX();
        scaleY *= p->getScaleY();
    }
    return cocos2d::Rect(worldPos.x, worldPos.y,
                         _compatViewSize.width * scaleX,
                         _compatViewSize.height * scaleY);
}

// [haizei] 2.x 原版 _setChildMenu：递归把 container 内所有 Menu
// 设为 scrollview 协作模式（不吞触摸 + 视口命中限制 + 位移阈值激活）
void CCScrollView::_setChildMenu(cocos2d::Node* parent)
{
    if (!parent)
    {
        return;
    }
    cocos2d::Rect displayArea = this->_getViewRect();
    static const bool sDiag = (std::getenv("HAIZEI_MENU_DIAG") != nullptr);
    int menuCount = 0;
    if (sDiag)
    {
        cocos2d::Size vs = this->getContentSize();
        CCLOG("[SVDiag] _setChildMenu rect=(%.0f,%.0f,%.0f,%.0f) viewSize=(%.0f,%.0f) contentSize=(%.0f,%.0f)",
              displayArea.origin.x, displayArea.origin.y, displayArea.size.width, displayArea.size.height,
              _compatViewSize.width, _compatViewSize.height, vs.width, vs.height);
    }
    std::function<void(cocos2d::Node*)> walk = [&](cocos2d::Node* node)
    {
        if (!node->getChildren().empty())
        {
            for (auto& child : node->getChildren())
            {
                cocos2d::Menu* menu = dynamic_cast<cocos2d::Menu*>(child);
                if (menu)
                {
                    menuCount++;
                    menu->setScrollViewChild(true);
                    // [parity] 传视口节点，Menu 在触摸时实时换算世界矩形；
                    // 此处缓存的 displayArea 在 setContainer 阶段尚未入场景树，坐标不可靠。
                    menu->setTouchArea(displayArea, this);
                }
                walk(child);
            }
        }
    };
    walk(parent);
    if (sDiag)
    {
        CCLOG("[SVDiag] _setChildMenu done menus=%d", menuCount);
    }
}

void CCScrollView::forceRecaculateChildren()
{
    // [haizei] 2.x 原版：forceRecaculateChildren = _setChildMenu
    if (_compatContainer)
    {
        _setChildMenu(_compatContainer);
    }
}

} // namespace extension
NS_CC_END
