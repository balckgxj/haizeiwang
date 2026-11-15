// 老代码里有 #include "CCScrollView.h" 的写法（2.x 的 extension 头文件名），
// 3.x 已经改成 ui/UIScrollView.h，这里做一个转发头。
#pragma once
#include "CCScrollViewCompat.h"
