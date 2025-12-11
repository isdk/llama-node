# 在 NAPI Addon 中集成 Clang 编译的虚拟机代码

## 概述

本文档介绍如何在 `node-llama.node` 的 NAPI addon 中集成和调用 Clang 编译的虚拟机代码。我们将探讨多种方案，从简单到复杂，帮助你选择最适合的实现方式。

## 背景

当前项目结构：
- **Addon 代码**: `llama/addon/*.cpp` (NAPI C++ 绑定)
- **编译器**: Linux 使用 GCC，Windows 使用 Clang/LLVM
- **目标**: 在 addon 中动态加载和执行 Clang 编译的代码

## 方案选择

### 方案 1: LLVM JIT (推荐用于动态代码执行)

使用 LLVM 的 JIT 编译器在运行时编译和执行 LLVM IR。

#### 优势
- ✅ 真正的运行时代码生成
- ✅ 可以动态优化
- ✅ 与 Clang 工具链无缝集成
- ✅ 支持热重载

#### 劣势
- ❌ 需要链接 LLVM 库（体积大）
- ❌ 复杂度较高
- ❌ 编译时间增加

#### 实现步骤

##### 1. 修改 CMakeLists.txt

```cmake
# llama/CMakeLists.txt

# 查找 LLVM
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

# 添加 LLVM 包含目录
include_directories(${LLVM_INCLUDE_DIRS})
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

# 查找需要的 LLVM 组件
llvm_map_components_to_libnames(llvm_libs
    Core
    ExecutionEngine
    MCJIT
    Support
    nativecodegen
    OrcJIT
)

# 链接 LLVM 库到 addon
target_link_libraries(${PROJECT_NAME} ${llvm_libs})
```

##### 2. 创建 JIT 执行器类

创建 `llama/addon/LLVMJitExecutor.h`:

```cpp
#pragma once

#include <napi.h>
#include <llvm/ExecutionEngine/Orc/LLJIT.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/TargetSelect.h>
#include <memory>
#include <string>

class LLVMJitExecutor {
public:
    LLVMJitExecutor();
    ~LLVMJitExecutor();

    // 从 LLVM IR 字符串加载模块
    bool loadIRFromString(const std::string& irCode, std::string& errorMsg);

    // 从 .ll 文件加载模块
    bool loadIRFromFile(const std::string& filepath, std::string& errorMsg);

    // 查找并调用函数
    template<typename RetType, typename... Args>
    RetType callFunction(const std::string& funcName, Args... args);

    // 获取函数指针
    void* getFunctionPointer(const std::string& funcName);

private:
    std::unique_ptr<llvm::orc::LLJIT> jit;
    llvm::orc::ThreadSafeContext context;

    void initializeJIT();
};
```

创建 `llama/addon/LLVMJitExecutor.cpp`:

```cpp
#include "LLVMJitExecutor.h"
#include <llvm/IR/LLVMContext.h>
#include <llvm/IRReader/IRReader.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/Support/MemoryBuffer.h>

LLVMJitExecutor::LLVMJitExecutor() {
    initializeJIT();
}

LLVMJitExecutor::~LLVMJitExecutor() {
    // LLJIT 会自动清理
}

void LLVMJitExecutor::initializeJIT() {
    // 初始化 LLVM 目标
    llvm::InitializeNativeTarget();
    llvm::InitializeNativeTargetAsmPrinter();
    llvm::InitializeNativeTargetAsmParser();

    // 创建 JIT 实例
    auto jitOrErr = llvm::orc::LLJITBuilder().create();
    if (!jitOrErr) {
        llvm::errs() << "Failed to create LLJIT: "
                     << llvm::toString(jitOrErr.takeError()) << "\n";
        return;
    }
    jit = std::move(*jitOrErr);

    // 创建线程安全的上下文
    context = llvm::orc::ThreadSafeContext(std::make_unique<llvm::LLVMContext>());
}

bool LLVMJitExecutor::loadIRFromString(const std::string& irCode, std::string& errorMsg) {
    if (!jit) {
        errorMsg = "JIT not initialized";
        return false;
    }

    // 创建内存缓冲区
    auto memBuf = llvm::MemoryBuffer::getMemBuffer(irCode);

    // 解析 IR
    llvm::SMDiagnostic err;
    auto module = llvm::parseIR(*memBuf, err, *context.getContext());

    if (!module) {
        llvm::raw_string_ostream os(errorMsg);
        err.print("IR parsing", os);
        return false;
    }

    // 添加模块到 JIT
    auto tsm = llvm::orc::ThreadSafeModule(std::move(module), context);
    auto addErr = jit->addIRModule(std::move(tsm));

    if (addErr) {
        errorMsg = llvm::toString(std::move(addErr));
        return false;
    }

    return true;
}

bool LLVMJitExecutor::loadIRFromFile(const std::string& filepath, std::string& errorMsg) {
    if (!jit) {
        errorMsg = "JIT not initialized";
        return false;
    }

    llvm::SMDiagnostic err;
    auto module = llvm::parseIRFile(filepath, err, *context.getContext());

    if (!module) {
        llvm::raw_string_ostream os(errorMsg);
        err.print("IR file parsing", os);
        return false;
    }

    auto tsm = llvm::orc::ThreadSafeModule(std::move(module), context);
    auto addErr = jit->addIRModule(std::move(tsm));

    if (addErr) {
        errorMsg = llvm::toString(std::move(addErr));
        return false;
    }

    return true;
}

void* LLVMJitExecutor::getFunctionPointer(const std::string& funcName) {
    if (!jit) return nullptr;

    auto symOrErr = jit->lookup(funcName);
    if (!symOrErr) {
        llvm::errs() << "Function not found: " << funcName << "\n";
        llvm::consumeError(symOrErr.takeError());
        return nullptr;
    }

    return reinterpret_cast<void*>(symOrErr->getValue());
}

template<typename RetType, typename... Args>
RetType LLVMJitExecutor::callFunction(const std::string& funcName, Args... args) {
    using FuncType = RetType(*)(Args...);
    auto funcPtr = reinterpret_cast<FuncType>(getFunctionPointer(funcName));

    if (!funcPtr) {
        throw std::runtime_error("Function not found: " + funcName);
    }

    return funcPtr(args...);
}
```

##### 3. 创建 NAPI 绑定

创建 `llama/addon/AddonJitExecutor.h`:

```cpp
#pragma once

#include <napi.h>
#include "LLVMJitExecutor.h"
#include <memory>

class AddonJitExecutor : public Napi::ObjectWrap<AddonJitExecutor> {
public:
    static Napi::Object Init(Napi::Env env, Napi::Object exports);
    AddonJitExecutor(const Napi::CallbackInfo& info);
    ~AddonJitExecutor();

private:
    std::unique_ptr<LLVMJitExecutor> executor;

    // NAPI 方法
    Napi::Value LoadIRFromString(const Napi::CallbackInfo& info);
    Napi::Value LoadIRFromFile(const Napi::CallbackInfo& info);
    Napi::Value CallFunction(const Napi::CallbackInfo& info);
};
```

创建 `llama/addon/AddonJitExecutor.cpp`:

```cpp
#include "AddonJitExecutor.h"

Napi::Object AddonJitExecutor::Init(Napi::Env env, Napi::Object exports) {
    Napi::Function func = DefineClass(env, "JitExecutor", {
        InstanceMethod("loadIRFromString", &AddonJitExecutor::LoadIRFromString),
        InstanceMethod("loadIRFromFile", &AddonJitExecutor::LoadIRFromFile),
        InstanceMethod("callFunction", &AddonJitExecutor::CallFunction),
    });

    Napi::FunctionReference* constructor = new Napi::FunctionReference();
    *constructor = Napi::Persistent(func);
    env.SetInstanceData(constructor);

    exports.Set("JitExecutor", func);
    return exports;
}

AddonJitExecutor::AddonJitExecutor(const Napi::CallbackInfo& info)
    : Napi::ObjectWrap<AddonJitExecutor>(info) {
    executor = std::make_unique<LLVMJitExecutor>();
}

AddonJitExecutor::~AddonJitExecutor() {
    // unique_ptr 会自动清理
}

Napi::Value AddonJitExecutor::LoadIRFromString(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsString()) {
        Napi::TypeError::New(env, "String expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    std::string irCode = info[0].As<Napi::String>().Utf8Value();
    std::string errorMsg;

    bool success = executor->loadIRFromString(irCode, errorMsg);

    if (!success) {
        Napi::Error::New(env, "Failed to load IR: " + errorMsg)
            .ThrowAsJavaScriptException();
        return env.Null();
    }

    return Napi::Boolean::New(env, true);
}

Napi::Value AddonJitExecutor::LoadIRFromFile(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsString()) {
        Napi::TypeError::New(env, "String expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    std::string filepath = info[0].As<Napi::String>().Utf8Value();
    std::string errorMsg;

    bool success = executor->loadIRFromFile(filepath, errorMsg);

    if (!success) {
        Napi::Error::New(env, "Failed to load IR file: " + errorMsg)
            .ThrowAsJavaScriptException();
        return env.Null();
    }

    return Napi::Boolean::New(env, true);
}

Napi::Value AddonJitExecutor::CallFunction(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsString()) {
        Napi::TypeError::New(env, "Function name expected").ThrowAsJavaScriptException();
        return env.Null();
    }

    std::string funcName = info[0].As<Napi::String>().Utf8Value();

    // 示例：调用一个返回 int 的无参函数
    try {
        int result = executor->callFunction<int>(funcName);
        return Napi::Number::New(env, result);
    } catch (const std::exception& e) {
        Napi::Error::New(env, e.what()).ThrowAsJavaScriptException();
        return env.Null();
    }
}
```

##### 4. 注册到 addon

修改 `llama/addon/addon.cpp`:

```cpp
#include "AddonJitExecutor.h"

Napi::Object registerCallback(Napi::Env env, Napi::Object exports) {
    // ... 现有代码 ...

    // 注册 JIT 执行器
    AddonJitExecutor::Init(env, exports);

    return exports;
}
```

##### 5. TypeScript 使用示例

```typescript
import {JitExecutor} from "node-llama-cpp";

// 创建 JIT 执行器
const jit = new JitExecutor();

// LLVM IR 代码示例
const irCode = `
define i32 @add(i32 %a, i32 %b) {
entry:
  %sum = add i32 %a, %b
  ret i32 %sum
}

define i32 @multiply(i32 %a, i32 %b) {
entry:
  %product = mul i32 %a, %b
  ret i32 %product
}
`;

// 加载 IR
jit.loadIRFromString(irCode);

// 调用函数
const result = jit.callFunction("add", 5, 3);
console.log("5 + 3 =", result); // 输出: 8
```

---

### 方案 2: 预编译共享库 (推荐用于静态代码)

将 Clang 编译的代码编译成共享库 (.so/.dll/.dylib)，然后在 addon 中动态加载。

#### 优势
- ✅ 简单直接
- ✅ 无需链接 LLVM
- ✅ 性能最优
- ✅ 可以使用任何语言编写

#### 劣势
- ❌ 不支持运行时代码生成
- ❌ 需要管理多个二进制文件

#### 实现步骤

##### 1. 编写虚拟机代码

创建 `llama/vm/vm_functions.c`:

```c
// 简单的虚拟机函数示例
#include <stdint.h>

// 导出符号（重要！）
#ifdef _WIN32
    #define VM_EXPORT __declspec(dllexport)
#else
    #define VM_EXPORT __attribute__((visibility("default")))
#endif

VM_EXPORT int32_t vm_add(int32_t a, int32_t b) {
    return a + b;
}

VM_EXPORT int32_t vm_multiply(int32_t a, int32_t b) {
    return a * b;
}

VM_EXPORT float vm_compute(float* data, size_t len) {
    float sum = 0.0f;
    for (size_t i = 0; i < len; i++) {
        sum += data[i] * data[i];
    }
    return sum;
}
```

##### 2. 使用 Clang 编译共享库

创建 `llama/vm/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.19)
project(llama_vm C)

# 强制使用 Clang
set(CMAKE_C_COMPILER clang)

# 编译选项
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -fPIC")

# 创建共享库
add_library(llama_vm SHARED
    vm_functions.c
)

# 设置输出名称
set_target_properties(llama_vm PROPERTIES
    PREFIX ""
    OUTPUT_NAME "llama_vm"
)

# 安装到 addon 目录
install(TARGETS llama_vm
    LIBRARY DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../addon
    RUNTIME DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../addon
)
```

编译脚本 `llama/vm/build.sh`:

```bash
#!/bin/bash
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
cmake --install .
```

##### 3. 在 Addon 中加载共享库

创建 `llama/addon/VMLoader.h`:

```cpp
#pragma once

#include <string>
#include <memory>

#ifdef _WIN32
    #include <windows.h>
    typedef HMODULE LibHandle;
#else
    #include <dlfcn.h>
    typedef void* LibHandle;
#endif

class VMLoader {
public:
    VMLoader();
    ~VMLoader();

    bool loadLibrary(const std::string& path, std::string& errorMsg);
    void* getFunction(const std::string& name);
    void unload();

    template<typename FuncType>
    FuncType getFunctionAs(const std::string& name) {
        return reinterpret_cast<FuncType>(getFunction(name));
    }

private:
    LibHandle handle;
    bool loaded;
};
```

创建 `llama/addon/VMLoader.cpp`:

```cpp
#include "VMLoader.h"

VMLoader::VMLoader() : handle(nullptr), loaded(false) {}

VMLoader::~VMLoader() {
    unload();
}

bool VMLoader::loadLibrary(const std::string& path, std::string& errorMsg) {
    if (loaded) {
        unload();
    }

#ifdef _WIN32
    handle = LoadLibraryA(path.c_str());
    if (!handle) {
        DWORD error = GetLastError();
        errorMsg = "Failed to load library: error code " + std::to_string(error);
        return false;
    }
#else
    handle = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        errorMsg = std::string("Failed to load library: ") + dlerror();
        return false;
    }
#endif

    loaded = true;
    return true;
}

void* VMLoader::getFunction(const std::string& name) {
    if (!loaded || !handle) return nullptr;

#ifdef _WIN32
    return reinterpret_cast<void*>(GetProcAddress(handle, name.c_str()));
#else
    return dlsym(handle, name.c_str());
#endif
}

void VMLoader::unload() {
    if (loaded && handle) {
#ifdef _WIN32
        FreeLibrary(handle);
#else
        dlclose(handle);
#endif
        handle = nullptr;
        loaded = false;
    }
}
```

##### 4. 创建 NAPI 绑定

创建 `llama/addon/AddonVMLoader.cpp`:

```cpp
#include <napi.h>
#include "VMLoader.h"
#include <memory>

class AddonVMLoader : public Napi::ObjectWrap<AddonVMLoader> {
public:
    static Napi::Object Init(Napi::Env env, Napi::Object exports) {
        Napi::Function func = DefineClass(env, "VMLoader", {
            InstanceMethod("load", &AddonVMLoader::Load),
            InstanceMethod("callInt32Function", &AddonVMLoader::CallInt32Function),
        });

        exports.Set("VMLoader", func);
        return exports;
    }

    AddonVMLoader(const Napi::CallbackInfo& info)
        : Napi::ObjectWrap<AddonVMLoader>(info) {
        loader = std::make_unique<VMLoader>();
    }

private:
    std::unique_ptr<VMLoader> loader;

    Napi::Value Load(const Napi::CallbackInfo& info) {
        Napi::Env env = info.Env();

        if (info.Length() < 1 || !info[0].IsString()) {
            Napi::TypeError::New(env, "Library path expected")
                .ThrowAsJavaScriptException();
            return env.Null();
        }

        std::string path = info[0].As<Napi::String>().Utf8Value();
        std::string errorMsg;

        if (!loader->loadLibrary(path, errorMsg)) {
            Napi::Error::New(env, errorMsg).ThrowAsJavaScriptException();
            return env.Null();
        }

        return Napi::Boolean::New(env, true);
    }

    Napi::Value CallInt32Function(const Napi::CallbackInfo& info) {
        Napi::Env env = info.Env();

        if (info.Length() < 1 || !info[0].IsString()) {
            Napi::TypeError::New(env, "Function name expected")
                .ThrowAsJavaScriptException();
            return env.Null();
        }

        std::string funcName = info[0].As<Napi::String>().Utf8Value();

        // 获取函数指针 (示例: int32_t func(int32_t, int32_t))
        using FuncType = int32_t(*)(int32_t, int32_t);
        auto func = loader->getFunctionAs<FuncType>(funcName);

        if (!func) {
            Napi::Error::New(env, "Function not found: " + funcName)
                .ThrowAsJavaScriptException();
            return env.Null();
        }

        // 获取参数
        int32_t arg1 = info[1].As<Napi::Number>().Int32Value();
        int32_t arg2 = info[2].As<Napi::Number>().Int32Value();

        // 调用函数
        int32_t result = func(arg1, arg2);

        return Napi::Number::New(env, result);
    }
};
```

##### 5. TypeScript 使用示例

```typescript
import {VMLoader} from "node-llama-cpp";
import path from "path";

const vm = new VMLoader();

// 加载共享库
const libPath = path.join(__dirname, "llama_vm.so"); // Linux
// const libPath = path.join(__dirname, "llama_vm.dll"); // Windows
// const libPath = path.join(__dirname, "llama_vm.dylib"); // macOS

vm.load(libPath);

// 调用函数
const result = vm.callInt32Function("vm_add", 10, 20);
console.log("10 + 20 =", result); // 输出: 30
```

---

### 方案 3: WebAssembly (WASM) (推荐用于跨平台)

使用 Clang 编译到 WebAssembly，然后在 Node.js 中执行。

#### 优势
- ✅ 完全跨平台
- ✅ 沙箱安全
- ✅ 可以与 JavaScript 无缝交互
- ✅ 不需要修改 addon

#### 劣势
- ❌ 性能略低于原生代码
- ❌ 需要 WASM 运行时

#### 实现步骤

##### 1. 编写代码

创建 `vm/wasm_functions.c`:

```c
#include <stdint.h>

// WASM 导出函数
__attribute__((export_name("add")))
int32_t add(int32_t a, int32_t b) {
    return a + b;
}

__attribute__((export_name("multiply")))
int32_t multiply(int32_t a, int32_t b) {
    return a * b;
}
```

##### 2. 使用 Clang 编译到 WASM

```bash
# 安装 wasi-sdk
# https://github.com/WebAssembly/wasi-sdk

clang --target=wasm32-wasi \
    -O3 \
    -nostdlib \
    -Wl,--no-entry \
    -Wl,--export-all \
    -o vm_functions.wasm \
    wasm_functions.c
```

##### 3. 在 TypeScript 中使用

```typescript
import fs from "fs";
import path from "path";

async function loadWASM() {
    const wasmPath = path.join(__dirname, "vm_functions.wasm");
    const wasmBuffer = fs.readFileSync(wasmPath);

    const wasmModule = await WebAssembly.instantiate(wasmBuffer);
    const {add, multiply} = wasmModule.instance.exports as any;

    console.log("5 + 3 =", add(5, 3));
    console.log("5 * 3 =", multiply(5, 3));
}

loadWASM();
```

---

## 推荐方案对比

| 方案 | 复杂度 | 性能 | 灵活性 | 跨平台 | 适用场景 |
|------|--------|------|--------|--------|----------|
| **LLVM JIT** | 高 | 高 | 极高 | 中 | 需要运行时代码生成 |
| **共享库** | 低 | 极高 | 中 | 低 | 静态代码，性能关键 |
| **WASM** | 中 | 中 | 高 | 极高 | 跨平台，安全沙箱 |

## 快速开始建议

### 如果你想要...

1. **最简单的方案**: 使用**方案 2 (共享库)**
   - 编译一个 `.so` 文件
   - 用 `dlopen` 加载
   - 直接调用函数

2. **最灵活的方案**: 使用**方案 1 (LLVM JIT)**
   - 可以动态生成代码
   - 适合需要 JIT 编译的场景

3. **最跨平台的方案**: 使用**方案 3 (WASM)**
   - 一次编译，到处运行
   - 不需要修改 addon

## 下一步

1. 选择适合你需求的方案
2. 按照步骤实现基础功能
3. 编写测试用例
4. 集成到现有的 addon 中

## 参考资料

- [LLVM ORC JIT](https://llvm.org/docs/ORCv2.html)
- [Node.js N-API](https://nodejs.org/api/n-api.html)
- [WebAssembly](https://webassembly.org/)
- [Clang Compiler](https://clang.llvm.org/)
