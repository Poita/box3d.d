# Minimal static-library build of Box3D for the box3d.d bindings.
# Compiles only the core library (no samples/tests/docs) so it can be built
# self-contained on any platform with a C17 compiler.
cmake_minimum_required(VERSION 3.16)
project(box3d_native LANGUAGES C)

file(GLOB BOX3D_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c")

add_library(box3d STATIC ${BOX3D_SOURCES})

target_include_directories(box3d
    PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include"
    PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Box3D requires C17 for _Static_assert and anonymous unions.
set_target_properties(box3d PROPERTIES
    C_STANDARD 17
    C_STANDARD_REQUIRED YES
    C_EXTENSIONS YES
    POSITION_INDEPENDENT_CODE ON)

if(MSVC)
    target_compile_options(box3d PRIVATE /W3)
else()
    target_compile_options(box3d PRIVATE -Wall)
endif()
