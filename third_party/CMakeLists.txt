# 老工程自带的第三方库：protobuf 2.5 / jsoncpp 0.5.0 / tinyxml 1
# 说明：protobuf 2.5 是为了直接复用 client/Protobuf 下已生成的 *.pb.cc，
#       等客户端稳定后再升级到 protobuf 3.x（见 docs/MIGRATION.md 阶段 5）。

# ---- protobuf ------------------------------------------------------------
file(GLOB_RECURSE PB_SRC ${CMAKE_CURRENT_SOURCE_DIR}/protobuf/google/protobuf/*.cc)
list(FILTER PB_SRC EXCLUDE REGEX "unittest")
list(FILTER PB_SRC EXCLUDE REGEX "test_util")
list(FILTER PB_SRC EXCLUDE REGEX "/testdata/")
list(FILTER PB_SRC EXCLUDE REGEX "/testing/")
list(FILTER PB_SRC EXCLUDE REGEX "/compiler/")
list(FILTER PB_SRC EXCLUDE REGEX "/io/test")

add_library(protobuf STATIC ${PB_SRC})
target_include_directories(protobuf PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/protobuf)
if(MSVC)
    target_compile_options(protobuf PRIVATE /wd4267 /wd4244 /wd4996 /wd4018)
endif()
message(STATUS "protobuf sources: ${CMAKE_MATCH_0}")
list(LENGTH PB_SRC PB_LEN)
message(STATUS "protobuf source count: ${PB_LEN}")

# ---- jsoncpp -------------------------------------------------------------
file(GLOB JSON_SRC ${CMAKE_CURRENT_SOURCE_DIR}/jsoncpp/src/lib_json/*.cpp)
add_library(jsoncpp STATIC ${JSON_SRC})
target_include_directories(jsoncpp PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/jsoncpp/include ${CMAKE_CURRENT_SOURCE_DIR}/jsoncpp/src/lib_json)

# ---- tinyxml -------------------------------------------------------------
file(GLOB TINYXML_SRC ${CMAKE_CURRENT_SOURCE_DIR}/tinyxml/*.cpp)
add_library(tinyxml STATIC ${TINYXML_SRC})
target_include_directories(tinyxml PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/tinyxml)
