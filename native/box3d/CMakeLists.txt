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

# Link the static CRT to match what LDC links by default. With CMake's default
# dynamic CRT the C objects reference the UCRT through import symbols while the
# D linker supplies the static libucrt, leaving b3Alloc's _aligned_malloc and
# b3Free's _aligned_free unresolved.
if(MSVC)
    set_property(TARGET box3d PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded")
endif()

# Cross-platform determinism.
#
# The solver uses only + - * / and sqrt, all of which IEEE 754 specifies bit-exactly,
# so identical results across platforms are achievable. Two compiler behaviours break
# that guarantee and both are on by default:
#
#   1. FMA contraction. `a + s * b` (b3MulAdd, the solver's hottest expression) fuses
#      into a single fmadd on ARM64, and on x86-64 when FMA is enabled. Fusing rounds
#      once where the unfused form rounds twice, so an ARM64 build diverges from a
#      baseline SSE2 x86-64 build.
#   2. Fast math, which permits reassociation and drops denormal/NaN handling.
#
# Do not add -march=native or -mfma here: enabling FMA on x86-64 lets the compiler
# contract and would diverge from other x86-64 builds.
if(MSVC)
    # /fp:precise forbids reassociation and contraction for cl.exe.
    target_compile_options(box3d PRIVATE /fp:precise)
    # clang-cl accepts /fp:precise but still contracts, so disable it explicitly.
    if(CMAKE_C_COMPILER_ID MATCHES "Clang")
        target_compile_options(box3d PRIVATE -ffp-contract=off)
    endif()
else()
    target_compile_options(box3d PRIVATE -ffp-contract=off -fno-fast-math)
endif()

# 32-bit x86 evaluates float expressions in 80-bit x87 registers, which no other
# target reproduces. Force SSE2 so intermediates are rounded to 32 bits.
if(CMAKE_SIZEOF_VOID_P EQUAL 4 AND CMAKE_SYSTEM_PROCESSOR MATCHES "(i.86|x86)")
    if(MSVC)
        target_compile_options(box3d PRIVATE /arch:SSE2)
    else()
        target_compile_options(box3d PRIVATE -msse2 -mfpmath=sse)
    endif()
endif()
