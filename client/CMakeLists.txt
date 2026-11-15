# 游戏逻辑（原 client/Game/Classes，业务逻辑不改，只做 3.x API 适配）
set(GAME_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(BRIDGE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../platform_bridge)

file(GLOB GAME_CORE_SRC   ${GAME_DIR}/Classes/*.cpp)
file(GLOB GAME_PB_SRC     ${GAME_DIR}/Protobuf/*.cc)
file(GLOB GAME_COMPAT_SRC ${GAME_DIR}/compat/*.cpp ${GAME_DIR}/compat/revi/*.cpp)
# Platform/GamePlatform.cpp 里有带解密的 getFileData（0xEF 0xFE + xor + zlib），
# 少了它配置表全是乱码
file(GLOB GAME_PLATFORM_SRC ${GAME_DIR}/Platform/*.cpp)
if(APPLE)
    # iOS/Mac 版平台层（ObjC++）：带解密 getFileData 的苹果实现
    file(GLOB GAME_PLATFORM_MM_SRC ${GAME_DIR}/Platform/*.mm)
    list(APPEND GAME_PLATFORM_SRC ${GAME_PLATFORM_MM_SRC})
endif()

# 平台层：Windows 用 win32 实现，iOS 用老手游原生的 libOS/iOS 实现
if(WIN32)
    set(BRIDGE_SRC
        ${BRIDGE_DIR}/libPlatform/include/libPlatform.cpp
        ${BRIDGE_DIR}/libPlatform/win32/lib91.cpp
        ${BRIDGE_DIR}/libPlatform/win32/libAG.cpp
        ${BRIDGE_DIR}/libPlatform/win32/libPP.cpp
        ${BRIDGE_DIR}/libPlatform/win32/libTB.cpp
        ${BRIDGE_DIR}/libOS/win32/libOS.cpp
        ${BRIDGE_DIR}/libOS/win32/inputBox.cpp
        ${BRIDGE_DIR}/libOS/win32/BulletinBoardPage.cpp
    )
elseif(IOS)
    file(GLOB BRIDGE_IOS_SRC
         ${BRIDGE_DIR}/libOS/iOS/*.mm
         ${BRIDGE_DIR}/libOS/iOS/*.m)
    set(BRIDGE_SRC
        ${BRIDGE_DIR}/libPlatform/include/libPlatform.cpp
        ${BRIDGE_IOS_SRC}
    )
endif()

# Lua 胶水（Gamelua.cpp 是 tolua++ 生成的 4.6 万行）与 pb.cpp 暂时排除，
# 阶段二开启 Lua 时再纳入（见 docs/MIGRATION.md）。
list(REMOVE_ITEM GAME_CORE_SRC
     ${GAME_DIR}/Classes/Gamelua.cpp
     ${GAME_DIR}/Classes/pb.cpp)

add_library(haizei_game STATIC
    ${GAME_CORE_SRC} ${GAME_PB_SRC} ${GAME_COMPAT_SRC} ${GAME_PLATFORM_SRC} ${BRIDGE_SRC})

target_include_directories(haizei_game PUBLIC
    ${GAME_DIR}/compat
    ${GAME_DIR}/Classes
    ${GAME_DIR}/Platform
    ${GAME_DIR}/Protobuf
    ${BRIDGE_DIR}/libPlatform/include
    ${BRIDGE_DIR}/libOS/include
    ${COCOS2DX_ROOT_PATH}/external/zlib/include
    ${COCOS2DX_ROOT_PATH}/external/curl/include
    ${COCOS2DX_ROOT_PATH}/cocos/editor-support
)

# 关键：强制包含兼容层，204 个源文件不用逐个加 include
if(MSVC)
    target_compile_options(haizei_game PUBLIC "/FI${GAME_DIR}/compat/haizei_compat.h")
else()
    # Clang（iOS）：-include<file> 连写形式，等价于 MSVC 的 /FI
    target_compile_options(haizei_game PUBLIC "-include${GAME_DIR}/compat/haizei_compat.h")
endif()

# curl 按静态方式声明，这样 compat_curl_stub.cpp 里的桩才能顶上
# （否则 curl.h 会把调用声明成 __declspec(dllimport)，仍然依赖 libcurl.dll）
target_compile_definitions(haizei_game PUBLIC CURL_STATICLIB)

target_link_libraries(haizei_game PUBLIC cocos2d protobuf jsoncpp tinyxml)

if(WIN32)
    target_link_libraries(haizei_game PUBLIC ws2_32 winmm)
elseif(IOS)
    # libOS.mm / MD5 / 平台桥接用到的系统框架（引擎已链 UIKit/OpenGLES 等基础框架）
    target_link_libraries(haizei_game PUBLIC
        "-framework Foundation"
        "-framework UIKit"
        "-framework Security"
        "-framework SystemConfiguration"
        "-framework CFNetwork")
endif()
