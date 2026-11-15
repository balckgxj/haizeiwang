# ---------------------------------------------------------------------------
#  Haizeiwang (草帽船/海贼王) —— cocos2d-x 3.17.2 多端工程
#
#  老工程: cocos2d-x 2.1.3 + C++，见 reference/old_win32
#  新工程: 3.17.2 + CMake，Windows(x64) / Android(arm64-v8a) / iOS(arm64)
#
#  用法:
#    cmake -S . -B build -G "Visual Studio 17 2022" -A x64
#    cmake --build build --config Release --target Haizeiwang
# ---------------------------------------------------------------------------
cmake_minimum_required(VERSION 3.15)
project(Haizeiwang C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ---- 引擎 ----------------------------------------------------------------
set(COCOS2DX_ROOT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/engine/cocos2d-x")
set(CMAKE_MODULE_PATH "${COCOS2DX_ROOT_PATH}/cmake/Modules")

set(BUILD_TESTS     OFF CACHE BOOL "" FORCE)
set(BUILD_LUA_LIBS  OFF CACHE BOOL "" FORCE)   # 阶段一关闭，见 docs/MIGRATION.md
set(BUILD_JS_LIBS   OFF CACHE BOOL "" FORCE)

include(CocosBuildSet)
add_subdirectory(${COCOS2DX_ROOT_PATH}/cocos ${ENGINE_BINARY_PATH}/cocos)

# ---- 编译选项 ------------------------------------------------------------
if(MSVC)
    # 并行编译 + /Zi 共写 PDB 会触发 C3130（内部编译器错误），改用 /Z7 把调试信息写进 obj
    foreach(cfg DEBUG RELWITHDEBINFO)
        string(REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_${cfg} "${CMAKE_CXX_FLAGS_${cfg}}")
    endforeach()

    # 老代码是 VS2010 年代写的，先把“仅警告”的项关掉，集中精力解决真正的错误
    add_compile_options(/wd4996 /wd4244 /wd4267 /wd4305 /wd4018 /wd4101 /wd4102
                        /wd4189 /wd4456 /wd4457 /wd4458 /wd4459 /wd4701 /wd4702
                        /wd4703 /wd4715 /wd4800 /bigobj)
    add_compile_options(/MP)
    # 老代码里有 std::min/std::max，Windows SDK 的 min/max 宏会破坏它们
    add_compile_definitions(NOMINMAX _CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS)
    # VS 工程模板里一直有 _WINDOWS，老代码大量用它做平台分支判断
    add_compile_definitions(_WINDOWS)
endif()

# ---- 工程 ----------------------------------------------------------------
add_subdirectory(third_party)
add_subdirectory(client)

# 可执行文件 ---------------------------------------------------------------
if(IOS)
    # ---- iOS app（cocos 模板入口：main.m -> AppController -> RootViewController）
    # 资源以 Xcode 资源组打进 .app 包
    cocos_mark_multi_resources(haizei_res RES_TO "Resources"
        FOLDERS ${CMAKE_CURRENT_SOURCE_DIR}/client/Resources)
    set(APP_UI_RES
        ${CMAKE_CURRENT_SOURCE_DIR}/proj.ios/Images.xcassets
        ${CMAKE_CURRENT_SOURCE_DIR}/proj.ios/LaunchScreen.storyboard
        ${CMAKE_CURRENT_SOURCE_DIR}/proj.ios/LaunchScreenBackground.png
        )
    add_executable(Haizeiwang MACOSX_BUNDLE
        ${CMAKE_CURRENT_SOURCE_DIR}/proj.ios/main.m
        ${CMAKE_CURRENT_SOURCE_DIR}/proj.ios/AppController.mm
        ${CMAKE_CURRENT_SOURCE_DIR}/proj.ios/RootViewController.mm
        ${APP_UI_RES}
        ${haizei_res}
        )
    target_include_directories(Haizeiwang PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/client/Classes)
    target_link_libraries(Haizeiwang PRIVATE haizei_game cocos2d protobuf jsoncpp tinyxml)
    # [haizei] 同 Windows /WHOLEARCHIVE：强制拉入 haizei_game 全部 .o，
    # 保住 116 个 REGISTER_PAGE 等静态初始化器注册（ld 用 -force_load 指定单个库）
    target_link_options(Haizeiwang PRIVATE
        "-Wl,-force_load,$<TARGET_LINKER_FILE:haizei_game>")
    setup_cocos_app_config(Haizeiwang)
    cocos_pak_xcode(Haizeiwang
        INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/proj.ios/Info.plist
        BUNDLE_NAME "Haizeiwang"
        GUI_IDENTIFIER "com.haizei.dzm"
        SHORT_VERSION_STRING "1.8.5"
        BUNDLE_VERSION "1")
    set_xcode_property(Haizeiwang IPHONEOS_DEPLOYMENT_TARGET "12.0")
    set_xcode_property(Haizeiwang ONLY_ACTIVE_ARCH "YES")
    set_xcode_property(Haizeiwang ENABLE_BITCODE "NO")
    set_xcode_property(Haizeiwang CODE_SIGNING_ALLOWED "NO")
    set_xcode_property(Haizeiwang CODE_SIGN_IDENTITY "")
    set_xcode_property(Haizeiwang PRODUCT_BUNDLE_IDENTIFIER "com.haizei.dzm")
else()
    add_executable(Haizeiwang ${CMAKE_CURRENT_SOURCE_DIR}/proj.win32/main.cpp)
    target_link_libraries(Haizeiwang PRIVATE haizei_game cocos2d protobuf jsoncpp tinyxml)
    # [haizei] 游戏代码大量依赖静态初始化器自动注册（116 个 REGISTER_PAGE 注册页面、
    # GamePackets.cpp 注册包工厂等）。这些 .obj 编在 haizei_game 静态库里、没人引用其
    # 符号时，链接器会整个丢弃 → 运行时注册表全空（页面打不开/发包崩溃）。
    # /WHOLEARCHIVE 强制把整个静态库的所有 .obj 拉进 exe。
    target_link_options(Haizeiwang PRIVATE "/WHOLEARCHIVE:$<TARGET_LINKER_FILE:haizei_game>")
    # [haizei] 生成 map 文件：崩溃日志里的偏移可以直接查到函数名
    target_link_options(Haizeiwang PRIVATE "/MAP:${CMAKE_BINARY_DIR}/Haizeiwang.map")
endif()

# 注意：这里故意不链接 libcurl。
# 3.17 的 prebuilt libcurl.dll 依赖 x86 版 libssl/libcrypto，本机没有；
# CurlDownload 需要的 6 个接口由 client/compat/compat_curl_stub.cpp 提供桩实现，
# 效果是“客户端认为没有可下载的更新”，本地单机/本地服不影响。
# 阶段二做热更时改成链接自己编的 libcurl 并删掉那个桩。

# 运行时把资源目录放到 exe 旁边
if(WIN32)
    add_custom_command(TARGET Haizeiwang POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_CURRENT_SOURCE_DIR}/client/Resources"
                "$<TARGET_FILE_DIR:Haizeiwang>/Resources"
        COMMENT "copy Resources")

    # 引擎运行时还要 glew32.dll / zlib1.dll
    foreach(_dll
            "${CMAKE_CURRENT_SOURCE_DIR}/engine/cocos2d-x/external/win32-specific/gles/prebuilt/glew32.dll"
            "${CMAKE_CURRENT_SOURCE_DIR}/engine/cocos2d-x/external/win32-specific/zlib/prebuilt/zlib1.dll")
        if(EXISTS "${_dll}")
            add_custom_command(TARGET Haizeiwang POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_dll}" "$<TARGET_FILE_DIR:Haizeiwang>"
                COMMENT "copy ${_dll}")
        endif()
    endforeach()
endif()
