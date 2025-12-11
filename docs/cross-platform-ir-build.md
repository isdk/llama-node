# 跨平台 STL 兼容的 LLVM IR 构建方案

## 问题分析

### 挑战
1. **不同系统使用不同编译器**：
   - Linux: GCC (libstdc++)
   - Windows: Clang/LLVM (可能是 libc++ 或 MSVC STL)
   - macOS: Apple Clang (libc++)

2. **需求**：
   - 保持 STL 兼容性
   - 避免纯 C API 的不便
   - 支持 `-march=native` CPU 优化

## 解决方案：智能 IR 构建系统

### 方案概述

**核心思路**：在构建时根据目标平台和编译器自动选择正确的 STL 实现。

---

## 实施步骤

### 步骤 1: 创建多版本 IR 构建脚本

创建 `scripts/build-ir-for-platform.sh`:

```bash
#!/bin/bash
# 为不同平台生成兼容的 LLVM IR

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IR_SOURCE_DIR="${PROJECT_ROOT}/external/ir-sources"
IR_OUTPUT_DIR="${PROJECT_ROOT}/llama/ir"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Building LLVM IR for current platform ===${NC}"

# 检测平台
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# 检测编译器
detect_compiler() {
    if command -v clang++ &> /dev/null; then
        echo "clang++"
    elif command -v g++ &> /dev/null; then
        echo "g++"
    else
        echo "none"
    fi
}

# 获取 STL 库选项
get_stdlib_option() {
    local platform=$1
    local compiler=$2

    case "$platform" in
        linux)
            # Linux 通常使用 libstdc++
            if [[ "$compiler" == "clang++" ]]; then
                echo "-stdlib=libstdc++"
            else
                echo ""  # GCC 默认使用 libstdc++
            fi
            ;;
        macos)
            # macOS 使用 libc++
            echo "-stdlib=libc++"
            ;;
        windows)
            # Windows 根据编译器决定
            if [[ "$compiler" == "clang++" ]]; then
                echo "-stdlib=libc++"
            else
                echo ""  # MSVC
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# 获取优化选项
get_optimization_flags() {
    local enable_native=$1

    if [[ "$enable_native" == "true" ]]; then
        echo "-march=native -mtune=native"
    else
        # 保守的优化，兼容性更好
        echo "-march=x86-64 -mtune=generic"
    fi
}

# 主函数
main() {
    local platform=$(detect_platform)
    local compiler=$(detect_compiler)
    local enable_native="${ENABLE_NATIVE_OPTIMIZATION:-false}"

    echo -e "${YELLOW}Platform:${NC} $platform"
    echo -e "${YELLOW}Compiler:${NC} $compiler"
    echo -e "${YELLOW}Native optimization:${NC} $enable_native"

    if [[ "$compiler" == "none" ]]; then
        echo "Error: No C++ compiler found"
        exit 1
    fi

    # 获取编译选项
    local stdlib_option=$(get_stdlib_option "$platform" "$compiler")
    local opt_flags=$(get_optimization_flags "$enable_native")

    echo -e "${YELLOW}STL option:${NC} $stdlib_option"
    echo -e "${YELLOW}Optimization flags:${NC} $opt_flags"

    # 创建输出目录
    mkdir -p "$IR_OUTPUT_DIR"

    # 编译所有 IR 源文件
    for source_file in "$IR_SOURCE_DIR"/*.cpp; do
        if [[ ! -f "$source_file" ]]; then
            continue
        fi

        local base_name=$(basename "$source_file" .cpp)
        local ir_file="$IR_OUTPUT_DIR/${base_name}.bc"

        echo ""
        echo -e "${GREEN}Building:${NC} $base_name"

        # 构建命令
        local cmd="$compiler -c -emit-llvm -O3 -fPIC"
        cmd="$cmd $stdlib_option"
        cmd="$cmd $opt_flags"
        cmd="$cmd -fno-exceptions -fno-rtti"
        cmd="$cmd -o $ir_file"
        cmd="$cmd $source_file"

        echo -e "${YELLOW}Command:${NC} $cmd"

        # 执行编译
        eval $cmd

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ Generated:${NC} $ir_file"

            # 生成人类可读的 IR
            llvm-dis "$ir_file" -o "${ir_file%.bc}.ll" 2>/dev/null || true
        else
            echo "Error: Failed to compile $source_file"
            exit 1
        fi
    done

    echo ""
    echo -e "${GREEN}=== IR build completed ===${NC}"
    echo ""
    echo "Generated files:"
    ls -lh "$IR_OUTPUT_DIR"/*.bc 2>/dev/null || echo "  (none)"
}

main "$@"
```

### 步骤 2: 创建 CMake 集成

修改 `llama/CMakeLists.txt`，添加智能 IR 处理：

```cmake
# ============================================
# 智能 LLVM IR 编译支持
# ============================================

option(ENABLE_IR_NATIVE_OPTIMIZATION "Enable -march=native for IR compilation" OFF)

# 检测当前平台的编译器
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(IR_COMPILER "g++")
    set(IR_STDLIB_FLAG "")  # GCC 默认使用 libstdc++
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(IR_COMPILER "clang++")

    # 根据平台选择 STL
    if(APPLE)
        set(IR_STDLIB_FLAG "-stdlib=libc++")
    elseif(UNIX)
        # Linux: 使用 libstdc++ 以匹配 GCC
        set(IR_STDLIB_FLAG "-stdlib=libstdc++")
    elseif(WIN32)
        set(IR_STDLIB_FLAG "-stdlib=libc++")
    endif()
elseif(MSVC)
    set(IR_COMPILER "cl")
    set(IR_STDLIB_FLAG "")
endif()

message(STATUS "IR Compiler: ${IR_COMPILER}")
message(STATUS "IR STL Flag: ${IR_STDLIB_FLAG}")

# 设置优化标志
if(ENABLE_IR_NATIVE_OPTIMIZATION)
    set(IR_OPT_FLAGS "-march=native -mtune=native")
    message(STATUS "IR Native Optimization: ENABLED")
else()
    # 保守优化，保持兼容性
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
        set(IR_OPT_FLAGS "-march=x86-64 -mtune=generic")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(IR_OPT_FLAGS "-march=armv8-a")
    else()
        set(IR_OPT_FLAGS "")
    endif()
    message(STATUS "IR Native Optimization: DISABLED (using generic)")
endif()

# 查找 IR 源文件
file(GLOB IR_SOURCE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/external/ir-sources/*.cpp")

# 编译 IR 源文件
set(IR_OBJECT_FILES "")

if(IR_SOURCE_FILES)
    find_program(LLVM_LLC llc)

    if(NOT LLVM_LLC)
        message(WARNING "llc not found, IR compilation will be skipped")
    else()
        foreach(IR_SOURCE ${IR_SOURCE_FILES})
            get_filename_component(IR_NAME ${IR_SOURCE} NAME_WE)

            # IR 文件路径
            set(IR_BC_FILE "${CMAKE_CURRENT_BINARY_DIR}/ir/${IR_NAME}.bc")
            set(IR_OBJ_FILE "${CMAKE_CURRENT_BINARY_DIR}/ir/${IR_NAME}.o")

            # 步骤 1: C++ -> LLVM IR
            add_custom_command(
                OUTPUT ${IR_BC_FILE}
                COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/ir
                COMMAND ${IR_COMPILER}
                    -c -emit-llvm -O3 -fPIC
                    ${IR_STDLIB_FLAG}
                    ${IR_OPT_FLAGS}
                    -fno-exceptions -fno-rtti
                    -o ${IR_BC_FILE}
                    ${IR_SOURCE}
                DEPENDS ${IR_SOURCE}
                COMMENT "Compiling C++ to IR: ${IR_NAME}.cpp -> ${IR_NAME}.bc"
                VERBATIM
            )

            # 步骤 2: LLVM IR -> 目标代码
            add_custom_command(
                OUTPUT ${IR_OBJ_FILE}
                COMMAND ${LLVM_LLC}
                    -filetype=obj -O3
                    ${ENABLE_IR_NATIVE_OPTIMIZATION ? "-march=native" : ""}
                    -o ${IR_OBJ_FILE}
                    ${IR_BC_FILE}
                DEPENDS ${IR_BC_FILE}
                COMMENT "Compiling IR to object: ${IR_NAME}.bc -> ${IR_NAME}.o"
                VERBATIM
            )

            list(APPEND IR_OBJECT_FILES ${IR_OBJ_FILE})
        endforeach()

        # 创建自定义目标
        add_custom_target(compile_ir_sources ALL
            DEPENDS ${IR_OBJECT_FILES}
            COMMENT "Compiling all IR sources"
        )

        message(STATUS "Found ${list_length(IR_SOURCE_FILES)} IR source files")
    endif()
endif()

# ... 原有的 addon 构建 ...

# 链接 IR 目标文件
if(IR_OBJECT_FILES)
    target_sources(${PROJECT_NAME} PRIVATE ${IR_OBJECT_FILES})
    add_dependencies(${PROJECT_NAME} compile_ir_sources)
    message(STATUS "Linking ${list_length(IR_OBJECT_FILES)} IR object files")
endif()
```

### 步骤 3: 创建 C++ 包装层（保持 STL 便利性）

创建 `llama/addon/IRWrapper.h`:

```cpp
#pragma once

#include <napi.h>
#include <vector>
#include <string>
#include <memory>

// 声明 IR 中的 C 风格函数
extern "C" {
    // 向量操作
    float ir_compute_vector_norm(const float* data, size_t len);
    void ir_sort_array(int* data, size_t len);
    int ir_find_max(const int* data, size_t len);

    // 矩阵操作
    void ir_matrix_multiply(const float* a, const float* b, float* c,
                           size_t m, size_t n, size_t p);
}

// C++ 包装类，提供 STL 友好的接口
class IRWrapper {
public:
    // 向量操作（接受 std::vector）
    static float computeVectorNorm(const std::vector<float>& vec) {
        return ir_compute_vector_norm(vec.data(), vec.size());
    }

    static std::vector<int> sortArray(std::vector<int> vec) {
        ir_sort_array(vec.data(), vec.size());
        return vec;
    }

    static int findMax(const std::vector<int>& vec) {
        return ir_find_max(vec.data(), vec.size());
    }

    // 矩阵操作
    static std::vector<float> matrixMultiply(
        const std::vector<float>& a,
        const std::vector<float>& b,
        size_t m, size_t n, size_t p
    ) {
        std::vector<float> c(m * p);
        ir_matrix_multiply(a.data(), b.data(), c.data(), m, n, p);
        return c;
    }

    // NAPI 绑定
    static Napi::Value ComputeVectorNorm(const Napi::CallbackInfo& info);
    static Napi::Value SortArray(const Napi::CallbackInfo& info);
    static Napi::Value FindMax(const Napi::CallbackInfo& info);
    static Napi::Value MatrixMultiply(const Napi::CallbackInfo& info);
};
```

创建 `llama/addon/IRWrapper.cpp`:

```cpp
#include "IRWrapper.h"

Napi::Value IRWrapper::ComputeVectorNorm(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsArray()) {
        Napi::TypeError::New(env, "Array expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    Napi::Array arr = info[0].As<Napi::Array>();
    std::vector<float> vec;
    vec.reserve(arr.Length());

    for (uint32_t i = 0; i < arr.Length(); i++) {
        vec.push_back(arr.Get(i).As<Napi::Number>().FloatValue());
    }

    float result = computeVectorNorm(vec);
    return Napi::Number::New(env, result);
}

Napi::Value IRWrapper::SortArray(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsArray()) {
        Napi::TypeError::New(env, "Array expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    Napi::Array arr = info[0].As<Napi::Array>();
    std::vector<int> vec;
    vec.reserve(arr.Length());

    for (uint32_t i = 0; i < arr.Length(); i++) {
        vec.push_back(arr.Get(i).As<Napi::Number>().Int32Value());
    }

    auto sorted = sortArray(vec);

    Napi::Array result = Napi::Array::New(env, sorted.size());
    for (size_t i = 0; i < sorted.size(); i++) {
        result[i] = Napi::Number::New(env, sorted[i]);
    }

    return result;
}

Napi::Value IRWrapper::FindMax(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsArray()) {
        Napi::TypeError::New(env, "Array expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    Napi::Array arr = info[0].As<Napi::Array>();
    std::vector<int> vec;
    vec.reserve(arr.Length());

    for (uint32_t i = 0; i < arr.Length(); i++) {
        vec.push_back(arr.Get(i).As<Napi::Number>().Int32Value());
    }

    int result = findMax(vec);
    return Napi::Number::New(env, result);
}

Napi::Value IRWrapper::MatrixMultiply(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    // 参数验证...
    Napi::Array arrA = info[0].As<Napi::Array>();
    Napi::Array arrB = info[1].As<Napi::Array>();
    size_t m = info[2].As<Napi::Number>().Uint32Value();
    size_t n = info[3].As<Napi::Number>().Uint32Value();
    size_t p = info[4].As<Napi::Number>().Uint32Value();

    std::vector<float> a, b;
    a.reserve(m * n);
    b.reserve(n * p);

    for (uint32_t i = 0; i < arrA.Length(); i++) {
        a.push_back(arrA.Get(i).As<Napi::Number>().FloatValue());
    }
    for (uint32_t i = 0; i < arrB.Length(); i++) {
        b.push_back(arrB.Get(i).As<Napi::Number>().FloatValue());
    }

    auto c = matrixMultiply(a, b, m, n, p);

    Napi::Array result = Napi::Array::New(env, c.size());
    for (size_t i = 0; i < c.size(); i++) {
        result[i] = Napi::Number::New(env, c[i]);
    }

    return result;
}
```

### 步骤 4: 关于 `-march=native` 的处理

#### 方案 A: 构建时优化（推荐用于本地构建）

```bash
# 本地构建时启用
cmake -DENABLE_IR_NATIVE_OPTIMIZATION=ON ...
```

**优势**：
- ✅ 最优性能
- ✅ 针对当前 CPU 优化

**劣势**：
- ❌ 生成的二进制不可移植
- ❌ 不适合分发

#### 方案 B: 运行时检测 + 多版本 IR（推荐用于分发）

创建多个 IR 版本：

```bash
# 生成通用版本
clang++ -c -emit-llvm -O3 -march=x86-64 -o lib_generic.bc lib.cpp

# 生成 AVX2 版本
clang++ -c -emit-llvm -O3 -march=haswell -o lib_avx2.bc lib.cpp

# 生成 AVX512 版本
clang++ -c -emit-llvm -O3 -march=skylake-avx512 -o lib_avx512.bc lib.cpp
```

在 CMake 中：

```cmake
# 编译多个版本
set(IR_VARIANTS "generic;avx2;avx512")
set(IR_MARCH_FLAGS_generic "-march=x86-64")
set(IR_MARCH_FLAGS_avx2 "-march=haswell")
set(IR_MARCH_FLAGS_avx512 "-march=skylake-avx512")

foreach(VARIANT ${IR_VARIANTS})
    # 为每个变体生成 IR
    add_custom_command(
        OUTPUT ${IR_BC_FILE_${VARIANT}}
        COMMAND clang++ -c -emit-llvm -O3 ${IR_MARCH_FLAGS_${VARIANT}} ...
    )
endforeach()
```

运行时选择：

```cpp
// 在 addon 初始化时检测 CPU 特性
#include <cpuid.h>

bool has_avx512() {
    unsigned int eax, ebx, ecx, edx;
    if (__get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx)) {
        return (ebx & bit_AVX512F) != 0;
    }
    return false;
}

bool has_avx2() {
    unsigned int eax, ebx, ecx, edx;
    if (__get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx)) {
        return (ebx & bit_AVX2) != 0;
    }
    return false;
}

// 选择合适的函数指针
void init_ir_functions() {
    if (has_avx512()) {
        compute_func = &compute_avx512;
    } else if (has_avx2()) {
        compute_func = &compute_avx2;
    } else {
        compute_func = &compute_generic;
    }
}
```

#### 方案 C: 混合方案（最佳实践）

```cmake
# 默认：通用优化（用于分发）
# 可选：本地优化（用于本地构建）

if(CI_BUILD OR DISTRIBUTE_BUILD)
    # CI 或分发构建：使用通用优化
    set(IR_OPT_FLAGS "-march=x86-64 -mtune=generic")
    message(STATUS "IR: Using generic optimization for distribution")
else()
    # 本地构建：可选择启用 native 优化
    if(ENABLE_IR_NATIVE_OPTIMIZATION)
        set(IR_OPT_FLAGS "-march=native -mtune=native")
        message(STATUS "IR: Using native optimization for local build")
    else()
        set(IR_OPT_FLAGS "-march=x86-64 -mtune=generic")
        message(STATUS "IR: Using generic optimization")
    endif()
endif()
```

---

## 使用指南

### 1. 准备 IR 源文件

创建 `external/ir-sources/my_lib.cpp`:

```cpp
#include <vector>
#include <algorithm>
#include <cmath>

extern "C" float ir_compute_vector_norm(const float* data, size_t len) {
    std::vector<float> vec(data, data + len);
    float sum = 0.0f;
    for (float v : vec) {
        sum += v * v;
    }
    return std::sqrt(sum);
}

extern "C" void ir_sort_array(int* data, size_t len) {
    std::vector<int> vec(data, data + len);
    std::sort(vec.begin(), vec.end());
    std::copy(vec.begin(), vec.end(), data);
}
```

### 2. 构建（自动适配平台）

```bash
# 通用构建（兼容性最好）
cmake -B build
cmake --build build

# 本地优化构建（性能最好）
cmake -B build -DENABLE_IR_NATIVE_OPTIMIZATION=ON
cmake --build build

# 分发构建（禁用 native 优化）
cmake -B build -DCI_BUILD=ON
cmake --build build
```

### 3. 在 TypeScript 中使用

```typescript
import {getLlama} from "node-llama-cpp";

const llama = await getLlama();

// 使用 IR 函数（STL 友好的接口）
const norm = llama.computeVectorNorm([3, 4]);
console.log("Norm:", norm); // 5.0

const sorted = llama.sortArray([5, 2, 8, 1]);
console.log("Sorted:", sorted); // [1, 2, 5, 8]
```

---

## 总结

### ✅ 这个方案的优势

1. **自动平台适配**：
   - Linux + GCC → 使用 libstdc++
   - Linux + Clang → 使用 libstdc++（兼容 GCC）
   - macOS + Clang → 使用 libc++
   - Windows + Clang → 使用 libc++

2. **保持 STL 便利性**：
   - IR 内部使用 STL
   - C++ 包装层提供 STL 接口
   - 接口边界使用 C ABI

3. **灵活的优化策略**：
   - 分发版本：通用优化（`-march=x86-64`）
   - 本地构建：可选 native 优化（`-march=native`）
   - 高级：多版本 IR + 运行时选择

4. **完全自动化**：
   - CMake 自动检测平台和编译器
   - 自动选择正确的 STL 实现
   - 自动应用优化标志

### 📋 回答你的问题

1. **STL 兼容性** → ✅ 自动适配，无需手动配置
2. **避免纯 C API** → ✅ 使用 C++ 包装层
3. **`-march=native` 优化** → ✅ 支持，可配置

### 🎯 推荐配置

```bash
# 开发时（本地）
cmake -DENABLE_IR_NATIVE_OPTIMIZATION=ON

# 分发时（CI）
cmake -DCI_BUILD=ON
```
