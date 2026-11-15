#include "stdafx.h"
#include "LoginPage.h"
#include "lib91.h"
#include "ui/UIScale9Sprite.h"

USING_NS_CC;
using namespace cocos2d::ui;

// 中文一律用 UTF-8 字节转义，避免 MSVC 源码编码差异（沿用 lib91.cpp 的约定）
#define HZ_GAME       "\xE6\xA2\xA6\xE6\x83\xB3\xE6\xB5\xB7\xE8\xB4\xBC\xE7\x8E\x8B"
#define HZ_TITLE      "\xE8\xB4\xA6\xE5\x8F\xB7\xE5\xAF\x86\xE7\xA0\x81\xE7\x99\xBB\xE5\xBD\x95" /* 账号密码登录 */
#define HZ_ACC_PH     "\xE8\xAF\xB7\xE8\xBE\x93\xE5\x85\xA5\xE8\xB4\xA6\xE5\x8F\xB7"             /* 请输入账号 */
#define HZ_PWD_PH     "\xE8\xAF\xB7\xE8\xBE\x93\xE5\x85\xA5\xE5\xAF\x86\xE7\xA0\x81"             /* 请输入密码 */
#define HZ_LOGIN      "\xE7\x99\xBB\x20\xE5\xBD\x95"                                             /* 登 录 */
#define HZ_REMEMBER   "\xE8\xAE\xB0\xE4\xBD\x8F\xE5\xAF\x86\xE7\xA0\x81"                         /* 记住密码 */
#define HZ_SWITCH     "\xE5\x88\x87\xE6\x8D\xA2\xE8\xB4\xA6\xE5\x8F\xB7"                         /* 切换账号 */
#define HZ_NEED_BOTH  "\xE8\xAF\xB7\xE8\xBE\x93\xE5\x85\xA5\xE8\xB4\xA6\xE5\x8F\xB7\xE5\x92\x8C\xE5\xAF\x86\xE7\xA0\x81"
#define HZ_DEFAULT    "\xE8\xAF\xB7\xE8\xBE\x93\xE5\x85\xA5\xE8\xB4\xA6\xE5\x8F\xB7\xE5\xAF\x86\xE7\xA0\x81\xEF\xBC\x8C\xE6\x96\xB0\xE8\xB4\xA6\xE5\x8F\xB7\xE9\xA6\x96\xE6\xAC\xA1\xE7\x99\xBB\xE5\xBD\x95\xE8\x87\xAA\xE5\x8A\xA8\xE6\xB3\xA8\xE5\x86\x8C"
#define HZ_CLEARED    "\xE5\xB7\xB2\xE6\xB8\x85\xE7\xA9\xBA\xE8\xB4\xA6\xE5\x8F\xB7\xEF\xBC\x8C\xE8\xAF\xB7\xE8\xBE\x93\xE5\x85\xA5\xE6\x96\xB0\xE7\x9A\x84\xE8\xB4\xA6\xE5\x8F\xB7\xE5\xAF\x86\xE7\xA0\x81"
#define HZ_FOOTER     "\x47\x4D\x20\xE6\x9D\x83\xE9\x99\x90\xE7\x94\xB1\xE6\x9C\x8D\xE5\x8A\xA1\xE7\xAB\xAF\xE4\xB8\x8B\xE5\x8F\x91\xEF\xBC\x9B\xE8\xAE\xB0\xE4\xBD\x8F\xE7\x9A\x84\xE5\xAF\x86\xE7\xA0\x81\xE6\x98\x8E\xE6\x96\x87\xE4\xBF\x9D\xE5\xAD\x98\xE5\x9C\xA8\xE6\x9C\xAC\xE6\x9C\xBA\xEF\xBC\x8C\xE4\xBB\x85\xE9\x99\x90\xE8\xB0\x83\xE8\xAF\x95\xE4\xBD\xBF\xE7\x94\xA8"

static const char* kKeyAccount  = "haizei_login_account";
static const char* kKeyPassword = "haizei_login_password";
static const char* kKeyRemember = "haizei_login_remember";

LoginPage* LoginPage::s_instance = NULL;

static Label* makeLabel(const char* text, int size, const Color3B& color)
{
    Label* l = Label::createWithSystemFont(text, "Microsoft YaHei", size);
    if (l) l->setColor(color);
    return l;
}

bool LoginPage::init()
{
    if (!LayerColor::initWithColor(Color4B(6, 10, 22, 205))) return false;

    m_account = NULL;
    m_password = NULL;
    m_hint = NULL;
    m_rememberItem = NULL;
    m_rememberLabel = NULL;
    m_remember = false;

    const Size win = Director::getInstance()->getWinSize();
    const float cx = win.width * 0.5f;
    const float cy = win.height * 0.5f;
    const float panelW = (win.width > 440.f) ? 420.f : (win.width - 40.f);
    const float panelH = 400.f;

    // 面板
    LayerColor* panel = LayerColor::create(Color4B(28, 34, 52, 250), panelW, panelH);
    panel->setPosition(Vec2(cx - panelW * 0.5f, cy - panelH * 0.5f));
    this->addChild(panel, 1);

    auto addText = [&](const char* txt, int size, const Color3B& col, float y, int z) -> Label* {
        Label* l = makeLabel(txt, size, col);
        if (l) { l->setPosition(Vec2(cx, cy + y)); this->addChild(l, z); }
        return l;
    };

    addText(HZ_GAME, 24, Color3B(255, 205, 105), 158, 3);
    addText(HZ_TITLE, 19, Color3B(225, 232, 245), 124, 3);

    const float boxW = panelW - 60.f;
    auto makeBox = [&](float y, const char* placeholder, bool password) -> EditBox* {
        LayerColor* bg = LayerColor::create(Color4B(255, 255, 255, 30), boxW, 44.f);
        bg->setPosition(Vec2(cx - boxW * 0.5f, cy + y - 22.f));
        this->addChild(bg, 2);

        EditBox* box = EditBox::create(Size(boxW, 44.f), Scale9Sprite::create());
        box->setPosition(Vec2(cx, cy + y));
        box->setFontColor(Color3B(240, 244, 255));
        box->setFontSize(20);
        box->setPlaceHolder(placeholder);
        box->setInputMode(EditBox::InputMode::SINGLE_LINE);
        box->setMaxLength(32);
        box->setReturnType(EditBox::KeyboardReturnType::DONE);
        box->setDelegate(this);
        if (password) box->setInputFlag(EditBox::InputFlag::PASSWORD);
        this->addChild(box, 3);
        return box;
    };

    m_account  = makeBox(72.f, HZ_ACC_PH, false);
    m_password = makeBox(12.f, HZ_PWD_PH, true);

    // 记住密码 / 切换账号
    m_rememberLabel = makeLabel("[ ] " HZ_REMEMBER, 14, Color3B(190, 200, 220));
    m_rememberItem = MenuItemLabel::create(m_rememberLabel, [this](Ref*) { onToggleRemember(); });
    m_rememberItem->setPosition(Vec2(cx - 92.f, cy - 34.f));

    Label* swLabel = makeLabel(HZ_SWITCH, 14, Color3B(150, 190, 255));
    MenuItemLabel* swItem = MenuItemLabel::create(swLabel, [this](Ref*) { onSwitchAccount(); });
    swItem->setPosition(Vec2(cx + 92.f, cy - 34.f));

    // 登录按钮
    LayerColor* btnBg = LayerColor::create(Color4B(47, 111, 237, 255), boxW, 48.f);
    btnBg->setPosition(Vec2(cx - boxW * 0.5f, cy - 112.f));
    this->addChild(btnBg, 2);
    Label* btnLabel = makeLabel(HZ_LOGIN, 22, Color3B::WHITE);
    MenuItemLabel* btnItem = MenuItemLabel::create(btnLabel, [this](Ref*) { onSubmit(); });
    btnItem->setPosition(Vec2(cx, cy - 88.f));

    Menu* menu = Menu::create(m_rememberItem, swItem, btnItem, NULL);
    menu->setPosition(Vec2::ZERO);
    this->addChild(menu, 4);

    m_hint = addText(HZ_DEFAULT, 13, Color3B(255, 190, 120), -140.f, 3);
    if (m_hint) {
        m_hint->setWidth(panelW - 50.f);
        m_hint->setAlignment(TextHAlignment::CENTER);
    }
    addText(HZ_FOOTER, 11, Color3B(140, 152, 175), -176.f, 3);

    // 吃掉落在输入框之外的点击，避免穿透到下层 LoadingFrame 按钮；
    // 输入框内的点击放行给 EditBox 自己处理。
    auto touch = EventListenerTouchOneByOne::create();
    touch->setSwallowTouches(true);
    touch->onTouchBegan = [this](Touch* t, Event*) -> bool {
        const Vec2 p = t->getLocation();
        if (m_account && m_account->getBoundingBox().containsPoint(p)) return false;
        if (m_password && m_password->getBoundingBox().containsPoint(p)) return false;
        return true;
    };
    _eventDispatcher->addEventListenerWithSceneGraphPriority(touch, this);

    refreshRemember();
    return true;
}

void LoginPage::refreshRemember()
{
    if (!m_rememberLabel) return;
    m_rememberLabel->setString(m_remember ? (std::string("[x] ") + HZ_REMEMBER)
                                          : (std::string("[ ] ") + HZ_REMEMBER));
}

void LoginPage::applySaved(const char* message)
{
    UserDefault* ud = UserDefault::getInstance();
    m_remember = ud->getBoolForKey(kKeyRemember, false);
    const std::string acc = ud->getStringForKey(kKeyAccount);
    const std::string pwd = ud->getStringForKey(kKeyPassword);
    refreshRemember();

    if (m_account)  m_account->setText(acc.c_str());
    if (m_password) m_password->setText("");
    if (m_hint)     m_hint->setString((message && *message) ? message : HZ_DEFAULT);

    // 勾选「记住密码」且不是密码错误重试时，自动提交；用户输入错误后不自动重放旧密码
    if (m_remember && !acc.empty() && !pwd.empty() && !(message && *message))
    {
        this->runAction(Sequence::create(
            DelayTime::create(0.15f),
            CallFunc::create([this, acc, pwd]() {
                if (!this->isVisible()) return;
                hide();
                lib91_setLoginCredentials(acc.c_str(), pwd.c_str());
            }),
            NULL));
    }
}

void LoginPage::onSubmit()
{
    const char* a = m_account ? m_account->getText() : NULL;
    const char* p = m_password ? m_password->getText() : NULL;
    std::string acc = a ? a : "";
    std::string pwd = p ? p : "";
    // 去掉首尾空白
    while (!acc.empty() && (acc[0] == ' ' || acc[0] == '\t')) acc.erase(0, 1);
    while (!acc.empty() && (acc[acc.size()-1] == ' ' || acc[acc.size()-1] == '\t')) acc.erase(acc.size()-1);
    while (!pwd.empty() && (pwd[0] == ' ' || pwd[0] == '\t')) pwd.erase(0, 1);
    while (!pwd.empty() && (pwd[pwd.size()-1] == ' ' || pwd[pwd.size()-1] == '\t')) pwd.erase(pwd.size()-1);

    if (acc.empty() || pwd.empty())
    {
        if (m_hint) m_hint->setString(HZ_NEED_BOTH);
        return;
    }

    UserDefault* ud = UserDefault::getInstance();
    ud->setStringForKey(kKeyAccount, acc);
    ud->setStringForKey(kKeyPassword, m_remember ? pwd : std::string(""));
    ud->setBoolForKey(kKeyRemember, m_remember);
    ud->flush();

    hide();
    lib91_setLoginCredentials(acc.c_str(), pwd.c_str());
}

void LoginPage::onToggleRemember()
{
    m_remember = !m_remember;
    UserDefault::getInstance()->setBoolForKey(kKeyRemember, m_remember);
    if (!m_remember) UserDefault::getInstance()->setStringForKey(kKeyPassword, std::string(""));
    UserDefault::getInstance()->flush();
    refreshRemember();
}

void LoginPage::onSwitchAccount()
{
    UserDefault::getInstance()->setStringForKey(kKeyAccount, std::string(""));
    UserDefault::getInstance()->setStringForKey(kKeyPassword, std::string(""));
    UserDefault::getInstance()->setBoolForKey(kKeyRemember, false);
    UserDefault::getInstance()->flush();
    m_remember = false;
    refreshRemember();
    if (m_account)  m_account->setText("");
    if (m_password) m_password->setText("");
    if (m_hint)     m_hint->setString(HZ_CLEARED);
    lib91_resetLogin();
}

void LoginPage::editBoxReturn(EditBox*)
{
    onSubmit();
}

void LoginPage::show(const char* message)
{
    Scene* scene = Director::getInstance()->getRunningScene();
    if (!scene) { CCLOGERROR("[LoginPage] no running scene"); return; }

    if (!s_instance)
    {
        s_instance = LoginPage::create();
        if (!s_instance) { CCLOGERROR("[LoginPage] create failed"); return; }
        s_instance->retain();
    }
    if (s_instance->getParent() != scene)
    {
        s_instance->removeFromParent();
        scene->addChild(s_instance, 9999);
    }
    s_instance->setVisible(true);
    s_instance->applySaved(message);
    CCLOG("[LoginPage] shown");
}

void LoginPage::hide()
{
    if (!s_instance) return;
    s_instance->setVisible(false);
    s_instance->removeFromParent();
}
