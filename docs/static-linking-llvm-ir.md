# 静态链接 LLVM IR 到 NAPI Addon

## 概述

本文档介绍如何将预编译的 LLVM IR 文件在构建时编译并静态链接到 NAPI addon 中。

## 工作流程

```
外部函数库 (C/C++)
    ↓ (clang -emit-llvm)
LLVM IR 文件 (.ll 或 .bc)
    ↓ (复制到项目)
项目构建系统 (CMake)
    ↓ (llc 或 clang)
目标代码 (.o)
    ↓ (静态链接)
NAPI Addon (.node)
```

## 详细实施步骤

### 步骤 1: 准备外部函数库并生成 LLVM IR

#### 1.1 创建示例函数库

假设你有一个外部函数库 `external_lib.c`:

```c
// external_lib.c
#include <stdint.h>
#include <math.h>

// 一些复杂的计算函数
float compute_vector_norm(const float* vec, size_t len) {
    float sum = 0.0f;
    for (size_t i = 0; i < len; i++) {
        sum += vec[i] * vec[i];
    }
    return sqrtf(sum);
}

int32_t factorial(int32_t n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

void matrix_multiply(const float* a, const float* b, float* c,
                     size_t m, size_t n, size_t p) {
    for (size_t i = 0; i < m; i++) {
        for (size_t j = 0; j < p; j++) {
            c[i * p + j] = 0.0f;
            for (size_t k = 0; k < n; k++) {
                c[i * p + j] += a[i * n + k] * b[k * p + j];
            }
        }
    }
}
```

#### 1.2 使用 Clang 生成 LLVM IR

```bash
# 生成人类可读的 LLVM IR (.ll 文件)
clang -S -emit-llvm -O3 -o external_lib.ll external_lib.c

# 或者生成二进制 LLVM IR (.bc 文件，更紧凑)
clang -c -emit-llvm -O3 -o external_lib.bc external_lib.c
```

**重要编译选项说明**：
- `-S -emit-llvm`: 生成文本格式的 IR (.ll)
- `-c -emit-llvm`: 生成二进制格式的 IR (.bc)
- `-O3`: 优化级别（可选：-O0, -O1, -O2, -O3, -Os, -Oz）
- `-fPIC`: 如果需要位置无关代码（推荐）
- `-march=native`: 针对当前 CPU 优化（注意：会失去可移植性）

**推荐的完整命令**：
```bash
clang -c -emit-llvm -O3 -fPIC \
    -fno-exceptions \
    -fno-rtti \
    -o external_lib.bc \
    external_lib.c
```

#### 1.3 验证生成的 IR

```bash
# 查看 .ll 文件内容
cat external_lib.ll

# 将 .bc 转换为 .ll 查看
llvm-dis external_lib.bc -o external_lib_readable.ll

# 验证 IR 的有效性
llvm-as external_lib.ll -o /dev/null
```

---

### 步骤 2: 集成到项目构建系统

#### 2.1 项目目录结构

```
llama/
├── CMakeLists.txt          # 主构建文件
├── addon/
│   ├── addon.cpp
│   ├── AddonModel.cpp
│   └── ...
├── ir/                      # 新建：存放 LLVM IR 文件
│   ├── external_lib.bc      # 预编译的 IR
│   ├── another_lib.bc
│   └── README.md
└── llama.cpp/
    └── ...
```

#### 2.2 创建 IR 目录和说明文件

创建 `llama/ir/README.md`:

```markdown
# LLVM IR 库

本目录存放预编译的 LLVM IR 文件，这些文件将在构建时编译并静态链接到 addon 中。

## 添加新的 IR 文件

1. 使用 Clang 生成 IR:
   ```bash
   clang -c -emit-llvm -O3 -fPIC -o your_lib.bc your_lib.c
   ```

2. 将 `.bc` 文件复制到此目录

3. 在 `../CMakeLists.txt` 中添加到 `IR_FILES` 列表

## IR 文件列表

- `external_lib.bc`: 外部计算函数库
```

#### 2.3 修改 CMakeLists.txt

修改 `llama/CMakeLists.txt`，添加 IR 编译支持：

```cmake
cmake_minimum_required(VERSION 3.19)

# ... 现有配置 ...

project("llama-addon" C CXX)

# ============================================
# LLVM IR 静态链接支持
# ============================================

# 查找 LLVM 工具
find_program(LLVM_LLC llc)
find_program(LLVM_DIS llvm-dis)
find_program(LLVM_LINK llvm-link)

if(NOT LLVM_LLC)
    message(WARNING "llc not found, LLVM IR compilation will be skipped")
    set(ENABLE_IR_COMPILATION OFF)
else()
    message(STATUS "Found llc: ${LLVM_LLC}")
    set(ENABLE_IR_COMPILATION ON)
endif()

# 定义 IR 文件列表
set(IR_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/ir/external_lib.bc
    # 在这里添加更多 IR 文件
)

# 编译 IR 文件为目标代码
set(IR_OBJECT_FILES "")

if(ENABLE_IR_COMPILATION)
    foreach(IR_FILE ${IR_FILES})
        get_filename_component(IR_NAME ${IR_FILE} NAME_WE)

        # 输出目标文件路径
        set(OBJ_FILE "${CMAKE_CURRENT_BINARY_DIR}/ir_objects/${IR_NAME}.o")

        # 添加自定义命令：IR -> 目标代码
        add_custom_command(
            OUTPUT ${OBJ_FILE}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/ir_objects
            COMMAND ${LLVM_LLC} -filetype=obj -O3 -o ${OBJ_FILE} ${IR_FILE}
            DEPENDS ${IR_FILE}
            COMMENT "Compiling LLVM IR: ${IR_NAME}.bc -> ${IR_NAME}.o"
            VERBATIM
        )

        list(APPEND IR_OBJECT_FILES ${OBJ_FILE})
    endforeach()

    # 创建一个自定义目标来触发 IR 编译
    add_custom_target(compile_ir_files ALL
        DEPENDS ${IR_OBJECT_FILES}
        COMMENT "Compiling all LLVM IR files"
    )
endif()

# ============================================
# 原有的 addon 构建配置
# ============================================

# ... 现有代码 ...

file(GLOB SOURCE_FILES "addon/*.cpp" "addon/**/*.cpp" ${GPU_INFO_SOURCES})

add_library(${PROJECT_NAME} SHARED ${SOURCE_FILES} ${CMAKE_JS_SRC} ${GPU_INFO_HEADERS})

# 添加 IR 目标文件到链接
if(ENABLE_IR_COMPILATION AND IR_OBJECT_FILES)
    target_sources(${PROJECT_NAME} PRIVATE ${IR_OBJECT_FILES})
    add_dependencies(${PROJECT_NAME} compile_ir_files)
    message(STATUS "Linking ${list_length(IR_OBJECT_FILES)} LLVM IR object files")
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "" SUFFIX ".node")
target_link_libraries(${PROJECT_NAME} ${CMAKE_JS_LIB})
target_link_libraries(${PROJECT_NAME} "llama")
target_link_libraries(${PROJECT_NAME} "common")

# ... 其余配置 ...
```

#### 2.4 可选：支持 IR 链接优化（LTO）

如果你想在链接前合并多个 IR 文件并进行跨模块优化：

```cmake
# 在 CMakeLists.txt 中添加

if(ENABLE_IR_COMPILATION AND IR_FILES)
    # 合并所有 IR 文件
    set(MERGED_IR_FILE "${CMAKE_CURRENT_BINARY_DIR}/merged_ir.bc")

    add_custom_command(
        OUTPUT ${MERGED_IR_FILE}
        COMMAND ${LLVM_LINK} -o ${MERGED_IR_FILE} ${IR_FILES}
        DEPENDS ${IR_FILES}
        COMMENT "Linking LLVM IR files together"
        VERBATIM
    )

    # 编译合并后的 IR
    set(MERGED_OBJ_FILE "${CMAKE_CURRENT_BINARY_DIR}/merged_ir.o")

    add_custom_command(
        OUTPUT ${MERGED_OBJ_FILE}
        COMMAND ${LLVM_LLC} -filetype=obj -O3 -o ${MERGED_OBJ_FILE} ${MERGED_IR_FILE}
        DEPENDS ${MERGED_IR_FILE}
        COMMENT "Compiling merged LLVM IR"
        VERBATIM
    )

    add_custom_target(compile_merged_ir ALL
        DEPENDS ${MERGED_OBJ_FILE}
    )

    target_sources(${PROJECT_NAME} PRIVATE ${MERGED_OBJ_FILE})
    add_dependencies(${PROJECT_NAME} compile_merged_ir)
endif()
```

---

### 步骤 3: 在 Addon 中声明和使用 IR 函数

#### 3.1 创建 C++ 头文件声明

创建 `llama/addon/external_ir_functions.h`:

```cpp
#pragma once

#include <stdint.h>
#include <cstddef>

// 声明 IR 中的函数（使用 C 链接）
extern "C" {
    // 来自 external_lib.bc
    float compute_vector_norm(const float* vec, size_t len);
    int32_t factorial(int32_t n);
    void matrix_multiply(const float* a, const float* b, float* c,
                        size_t m, size_t n, size_t p);
}
```

**重要提示**：
- 使用 `extern "C"` 避免 C++ 名称修饰
- 确保函数签名与 IR 中的完全一致
- 如果 IR 是从 C++ 生成的，可能需要使用修饰后的名称

#### 3.2 在 Addon 中使用

修改或创建 `llama/addon/AddonIRFunctions.cpp`:

```cpp
#include <napi.h>
#include "external_ir_functions.h"
#include <vector>

// 包装 compute_vector_norm
Napi::Value AddonComputeVectorNorm(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsArray()) {
        Napi::TypeError::New(env, "Array expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    Napi::Array arr = info[0].As<Napi::Array>();
    size_t len = arr.Length();

    std::vector<float> vec(len);
    for (size_t i = 0; i < len; i++) {
        Napi::Value val = arr[i];
        vec[i] = val.As<Napi::Number>().FloatValue();
    }

    // 调用 IR 编译的函数
    float result = compute_vector_norm(vec.data(), len);

    return Napi::Number::New(env, result);
}

// 包装 factorial
Napi::Value AddonFactorial(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsNumber()) {
        Napi::TypeError::New(env, "Number expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    int32_t n = info[0].As<Napi::Number>().Int32Value();

    // 调用 IR 编译的函数
    int32_t result = factorial(n);

    return Napi::Number::New(env, result);
}

// 包装 matrix_multiply
Napi::Value AddonMatrixMultiply(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    // 参数验证省略...

    Napi::Array matrixA = info[0].As<Napi::Array>();
    Napi::Array matrixB = info[1].As<Napi::Array>();
    size_t m = info[2].As<Napi::Number>().Uint32Value();
    size_t n = info[3].As<Napi::Number>().Uint32Value();
    size_t p = info[4].As<Napi::Number>().Uint32Value();

    // 转换数据...
    std::vector<float> a(m * n);
    std::vector<float> b(n * p);
    std::vector<float> c(m * p);

    // 填充 a 和 b...

    // 调用 IR 编译的函数
    matrix_multiply(a.data(), b.data(), c.data(), m, n, p);

    // 转换结果为 JS 数组...
    Napi::Array result = Napi::Array::New(env, m * p);
    for (size_t i = 0; i < m * p; i++) {
        result[i] = Napi::Number::New(env, c[i]);
    }

    return result;
}
```

#### 3.3 注册到 Addon

修改 `llama/addon/addon.cpp`:

```cpp
#include "external_ir_functions.h"

// 声明包装函数
Napi::Value AddonComputeVectorNorm(const Napi::CallbackInfo& info);
Napi::Value AddonFactorial(const Napi::CallbackInfo& info);
Napi::Value AddonMatrixMultiply(const Napi::CallbackInfo& info);

Napi::Object registerCallback(Napi::Env env, Napi::Object exports) {
    // ... 现有导出 ...

    // 导出 IR 函数
    exports.Set("computeVectorNorm", Napi::Function::New(env, AddonComputeVectorNorm));
    exports.Set("factorial", Napi::Function::New(env, AddonFactorial));
    exports.Set("matrixMultiply", Napi::Function::New(env, AddonMatrixMultiply));

    return exports;
}

NODE_API_MODULE(NODE_GYP_MODULE_NAME, registerCallback)
```

---

### 步骤 4: TypeScript 类型定义和使用

#### 4.1 添加 TypeScript 类型定义

修改或创建 `src/bindings/AddonTypes.ts`:

```typescript
export type AddonFunctions = {
    // ... 现有类型 ...

    // IR 函数
    computeVectorNorm(vector: number[]): number;
    factorial(n: number): number;
    matrixMultiply(
        matrixA: number[],
        matrixB: number[],
        m: number,
        n: number,
        p: number
    ): number[];
};
```

#### 4.2 在 TypeScript 中使用

```typescript
import {getLlama} from "node-llama-cpp";

const llama = await getLlama();

// 调用 IR 编译的函数
const vector = [3.0, 4.0];
const norm = llama.computeVectorNorm(vector);
console.log("Vector norm:", norm); // 5.0

const fact = llama.factorial(5);
console.log("5! =", fact); // 120

// 矩阵乘法示例
const A = [1, 2, 3, 4]; // 2x2
const B = [5, 6, 7, 8]; // 2x2
const C = llama.matrixMultiply(A, B, 2, 2, 2);
console.log("Matrix product:", C);
```

---

### 步骤 5: 构建和测试

#### 5.1 构建项目

```bash
cd /home/riceball/dev/ai/gpt/libs_c/node-llama.node/new_arch

# 清理旧构建
rm -rf llama/localBuilds

# 构建
pnpm run build
node ./dist/cli/cli.js source build --noUsageExample
```

#### 5.2 验证 IR 编译

检查构建日志，应该看到：

```
-- Found llc: /usr/bin/llc
-- Linking 1 LLVM IR object files
...
[ 10%] Compiling LLVM IR: external_lib.bc -> external_lib.o
...
[100%] Built target llama-addon
```

#### 5.3 测试

创建测试文件 `test/ir-functions.test.ts`:

```typescript
import {describe, it, expect} from "vitest";
import {getLlama} from "../src/index.js";

describe("IR Functions", () => {
    it("should compute vector norm", async () => {
        const llama = await getLlama();
        const result = llama.computeVectorNorm([3, 4]);
        expect(result).toBeCloseTo(5.0);
    });

    it("should compute factorial", async () => {
        const llama = await getLlama();
        expect(llama.factorial(0)).toBe(1);
        expect(llama.factorial(5)).toBe(120);
        expect(llama.factorial(10)).toBe(3628800);
    });

    it("should multiply matrices", async () => {
        const llama = await getLlama();
        const A = [1, 2, 3, 4];
        const B = [5, 6, 7, 8];
        const C = llama.matrixMultiply(A, B, 2, 2, 2);

        // [1 2] × [5 6] = [19 22]
        // [3 4]   [7 8]   [43 50]
        expect(C).toEqual([19, 22, 43, 50]);
    });
});
```

运行测试：
```bash
pnpm test test/ir-functions.test.ts
```

---

## 高级技巧

### 1. 条件编译 IR

在 CMakeLists.txt 中添加选项：

```cmake
option(ENABLE_EXTERNAL_IR "Enable external LLVM IR libraries" ON)

if(ENABLE_EXTERNAL_IR)
    # IR 编译逻辑
endif()
```

构建时控制：
```bash
cmake -DENABLE_EXTERNAL_IR=OFF ...
```

### 2. 多平台 IR 支持

为不同平台准备不同的 IR：

```cmake
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(IR_FILES ${CMAKE_CURRENT_SOURCE_DIR}/ir/linux/external_lib.bc)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(IR_FILES ${CMAKE_CURRENT_SOURCE_DIR}/ir/windows/external_lib.bc)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(IR_FILES ${CMAKE_CURRENT_SOURCE_DIR}/ir/macos/external_lib.bc)
endif()
```

### 3. IR 版本管理

在 `llama/ir/` 目录中添加版本信息：

```
ir/
├── v1.0/
│   └── external_lib.bc
├── v1.1/
│   └── external_lib.bc
└── current -> v1.1/
```

CMakeLists.txt 中引用：
```cmake
set(IR_VERSION "v1.1")
set(IR_FILES ${CMAKE_CURRENT_SOURCE_DIR}/ir/${IR_VERSION}/external_lib.bc)
```

### 4. 自动化 IR 生成

创建脚本 `scripts/generate-ir.sh`:

```bash
#!/bin/bash
set -e

IR_SOURCE_DIR="external/libs"
IR_OUTPUT_DIR="llama/ir"

echo "Generating LLVM IR from external libraries..."

for src_file in ${IR_SOURCE_DIR}/*.c; do
    base_name=$(basename "$src_file" .c)
    echo "Processing $base_name..."

    clang -c -emit-llvm -O3 -fPIC \
        -fno-exceptions \
        -fno-rtti \
        -o "${IR_OUTPUT_DIR}/${base_name}.bc" \
        "$src_file"

    echo "Generated ${base_name}.bc"
done

echo "Done!"
```

### 5. IR 优化管道

使用 `opt` 工具进一步优化 IR：

```bash
# 基础优化
opt -O3 -o optimized.bc input.bc

# 自定义优化管道
opt -passes='default<O3>,inline,mem2reg,gvn,dce' -o optimized.bc input.bc

# 针对特定架构优化
llc -O3 -march=x86-64 -mcpu=native -filetype=obj -o output.o optimized.bc
```

在 CMakeLists.txt 中集成：

```cmake
find_program(LLVM_OPT opt)

if(LLVM_OPT)
    add_custom_command(
        OUTPUT ${OPTIMIZED_IR}
        COMMAND ${LLVM_OPT} -O3 -o ${OPTIMIZED_IR} ${INPUT_IR}
        DEPENDS ${INPUT_IR}
        COMMENT "Optimizing LLVM IR"
    )
endif()
```

---

## 故障排除

### 问题 1: 找不到 llc

**错误**:
```
llc not found, LLVM IR compilation will be skipped
```

**解决方案**:
```bash
# Ubuntu/Debian
sudo apt-get install llvm

# macOS
brew install llvm

# 手动指定路径
cmake -DLLVM_LLC=/usr/local/bin/llc ...
```

### 问题 2: 链接错误 - 未定义的符号

**错误**:
```
undefined reference to `compute_vector_norm'
```

**解决方案**:
1. 检查 IR 文件是否正确编译
2. 验证函数名称（使用 `llvm-nm`）:
   ```bash
   llvm-nm external_lib.bc | grep compute
   ```
3. 确保使用 `extern "C"` 声明
4. 检查 IR 是否成功添加到链接：
   ```bash
   nm llama-addon.node | grep compute
   ```

### 问题 3: IR 版本不兼容

**错误**:
```
error: Invalid bitcode signature
```

**解决方案**:
确保生成 IR 的 Clang 版本与编译 IR 的 LLVM 版本兼容：

```bash
# 检查版本
clang --version
llc --version

# 使用相同版本的工具链
clang-15 -c -emit-llvm ...
llc-15 -filetype=obj ...
```

### 问题 4: 性能问题

如果 IR 编译的代码性能不佳：

1. **启用优化**:
   ```bash
   clang -c -emit-llvm -O3 -fPIC ...
   llc -O3 -filetype=obj ...
   ```

2. **使用 LTO**:
   ```cmake
   set_property(TARGET ${PROJECT_NAME} PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
   ```

3. **针对目标 CPU 优化**:
   ```bash
   llc -O3 -march=native -mcpu=native -filetype=obj ...
   ```

---

## 总结

这个方案的优势：

✅ **可移植性**: IR 是平台无关的
✅ **性能**: 编译时优化，无运行时开销
✅ **灵活性**: 可以在外部维护函数库
✅ **简单**: 不需要运行时 JIT
✅ **安全**: 静态链接，无动态加载风险

适用场景：
- 需要集成第三方库但不想暴露源代码
- 跨平台分发预编译的优化代码
- 在构建时进行跨模块优化（LTO）
- 保持代码的可移植性同时优化性能

下一步：
1. 准备你的外部函数库
2. 生成 LLVM IR
3. 按照本文档修改 CMakeLists.txt
4. 构建并测试
