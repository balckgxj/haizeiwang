#pragma once
// ---------------------------------------------------------------------------
//  阶段一的 Lua 占位实现
//
//  老工程用到 Lua 的地方很窄（CCLuaEngine::defaultEngine / executeScriptFile /
//  executeEvent / executeGlobalFunctionByName），只有 11 个文件。
//  3.17 引擎自带 ScriptEngineProtocol / ScriptEngineManager，这里让占位引擎
//  继承它，签名就能对上；阶段二接回真正的 lua-bindings 时删掉本文件即可。
// ---------------------------------------------------------------------------
#include "cocos2d.h"
#include "base/CCScriptSupport.h"

struct lua_State;

namespace cocos2d {

class LuaStack
{
public:
    lua_State* getLuaState() const { return nullptr; }
};

class CCLuaEngine : public ScriptEngineProtocol
{
public:
    static CCLuaEngine* defaultEngine()
    {
        static CCLuaEngine engine;
        return &engine;
    }

    virtual ccScriptType getScriptType() override { return kScriptTypeLua; }

    LuaStack* getLuaStack() { return &_stack; }

    virtual int executeString(const char*) override { return 0; }
    virtual int executeScriptFile(const char*) override { return 0; }
    virtual int executeGlobalFunction(const char*) override { return 0; }
    virtual int sendEvent(ScriptEvent*) override { return 0; }
    virtual bool handleAssert(const char*) override { return false; }
    virtual bool parseConfig(ConfigType, const std::string&) override { return true; }

    // 2.x 里的重载，老业务代码在用
    int executeEvent(int, const char*) { return 0; }
    int executeEvent(int, const char*, Ref*, const char*) { return 0; }
    int executeGlobalFunctionByName(const char*, Ref*, const char*) { return 0; }
    void addSearchPath(const char*) {}
    void reload(const char*) {}

private:
    LuaStack _stack;
};
typedef CCLuaEngine LuaEngine;

} // namespace cocos2d

// tolua 生成的注册函数（阶段一为空实现）
inline int tolua_Gamelua_open(lua_State*) { return 0; }
inline int luaopen_pb(lua_State*) { return 0; }
