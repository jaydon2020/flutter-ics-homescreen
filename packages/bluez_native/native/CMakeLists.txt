cmake_minimum_required(VERSION 3.22)
project(bluez_nc CXX C)

set(CMAKE_CXX_STANDARD  23)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ── sdbus-cpp v2 as submodule ────────────────────────────────────────────────
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDBUSCPP_BUILD_CODEGEN OFF CACHE BOOL "" FORCE)
set(SDBUSCPP_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
add_subdirectory(third_party/sdbus-cpp EXCLUDE_FROM_ALL)

# ── dart_api_dl — compile as plain C ────────────────────────────────────────
add_library(dart_api_dl OBJECT src/dart_api_dl.c)
target_include_directories(dart_api_dl PUBLIC include)

# ── Core static library (for tests) ─────────────────────────────────────────
add_library(bluez_native STATIC
    src/object_manager.cpp
    src/adapter_bridge.cpp
    src/device_bridge.cpp
    src/gatt_bridge.cpp
    src/pairing_agent.cpp
    $<TARGET_OBJECTS:dart_api_dl>
)

target_include_directories(bluez_native
    PUBLIC include
)

target_link_libraries(bluez_native PUBLIC sdbus-c++ pthread)

# ── Shared library for Dart FFI ──────────────────────────────────────────────
add_library(bluez_nc SHARED
    src/bluez_bridge.cpp
    src/object_manager.cpp
    src/adapter_bridge.cpp
    src/device_bridge.cpp
    src/gatt_bridge.cpp
    src/pairing_agent.cpp
    $<TARGET_OBJECTS:dart_api_dl>
)

target_include_directories(bluez_nc
    PRIVATE include
)

target_link_libraries(bluez_nc PRIVATE sdbus-c++ pthread)

set_target_properties(bluez_nc PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME "bluez_nc"
)

# When building in-tree (not via the Dart native asset hook), stage the
# shared library into lib/ so the legacy DynamicLibrary.open() loader and
# in-tree tooling can locate it. The hook build sets BLUEZ_HOOK_BUILD=ON
# and consumes the artifact directly from the CMake build directory.
option(BLUEZ_HOOK_BUILD "Build is driven by the Dart package:hooks build hook" OFF)
if(NOT BLUEZ_HOOK_BUILD)
    set_target_properties(bluez_nc PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib"
    )
endif()

if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(test)
endif()
