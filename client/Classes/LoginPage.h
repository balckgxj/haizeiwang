#pragma once

#include "cocos2d.h"
#include "ui/UIEditBox/UIEditBox.h"

// [haizei] 游戏内账号密码登录页
// 取代 Win32 原生登录框与 localAccount.txt 自动登录。凭据交给 lib91 后，
// 由原有 LoadingFrame → 选服 → OPLogin 链路连服务端；首次登录的新账号由服务端自动注册。
class LoginPage : public cocos2d::LayerColor, public cocos2d::ui::EditBoxDelegate
{
public:
    CREATE_FUNC(LoginPage);

    virtual bool init() override;
    virtual void editBoxReturn(cocos2d::ui::EditBox* editBox) override;

    /** 显示登录页；message 非空时作为提示（如「密码错误，请重新输入」） */
    static void show(const char* message);
    static void hide();

private:
    static LoginPage* s_instance;

    cocos2d::ui::EditBox* m_account;
    cocos2d::ui::EditBox* m_password;
    cocos2d::Label*       m_hint;
    cocos2d::MenuItemLabel* m_rememberItem;
    cocos2d::Label*       m_rememberLabel;
    bool m_remember;

    void applySaved(const char* message);
    void onSubmit();
    void onToggleRemember();
    void onSwitchAccount();
    void refreshRemember();
};
