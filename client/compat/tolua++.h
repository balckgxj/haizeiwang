#pragma once
// 阶段一占位：老代码里 #include "tolua++.h" 只用于 tolua 注册函数声明。
// 阶段二接回 cocos2d-x 3.17 的 lua-bindings 后删除本文件。
struct lua_State;

#ifndef TOLUA_API
#define TOLUA_API
#endif
