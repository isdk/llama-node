# LLVM IR 与项目 Prebuilt 策略的集成方案

## 项目现状分析

### ✅ 当前项目的优秀策略

你的项目已经采用了**多 prebuilt 包**策略：

```
packages/prebuilt-llama-node/
├── linux-x64/              # 通用 x86-64
├── linux-x64-cuda/         # CUDA 加速
├── linux-x64-vulkan/       # Vulkan 加速
├── linux-arm64/            # ARM64
├── win-x64/                # Windows x64
├── mac-arm64-metal/        # macOS ARM + Metal
└── ...
```

### 🎯 关键优化：`GGML_CPU_ALL_VARIANTS`

在 CI 构建时（`compileLLamaCpp.ts:155-157`）：

```typescript
if (buildOptions.arch === "x64" && !cmakeCustomOptions.has("GGML_CPU_ALL_VARIANTS")) {
    cmakeCustomOptions.set("GGML_CPU_ALL_VARIANTS", "ON");
    cmakeCustomOptions.set("GGML_BACKEND_DL", "ON");
}
```

这会编译多个 CPU 变体：
- **基础版本**: SSE2（所有 x86-64 CPU）
- **AVX 版本**: AVX 指令集
- **AVX2 版本**: AVX2 指令集
- **AVX512 版本**: AVX-512 指令集（如果支持）

运行时动态加载最优版本！

---

## LLVM IR 的正确集成策略

### 方案：与现有策略保持一致

#### 选项 1: 多 IR 变体（推荐，与项目一致）

**生成多个优化级别的 IR**：

```bash
# 基础版本（通用 x86-64）
clang++ -c -emit-llvm -O3 -fPIC -march=x86-64 \
    -stdlib=libstdc++ \
    -o external_lib_base.bc \
    external_lib.cpp

# AVX2 版本
clang++ -c -emit-llvm -O3 -fPIC -march=haswell \
    -stdlib=libstdc++ \
    -o external_lib_avx2.bc \
    external_lib.cpp

# AVX512 版本
clang++ -c -emit-llvm -O3 -fPIC -march=skylake-avx512 \
    -stdlib=libstdc++ \
    -o external_lib_avx512.bc \
    external_lib.cpp
```

**目录结构**：

```
llama/ir/
├── variants/
│   ├── base/
│   │   └── external_lib.bc      # x86-64 基础
│   ├── avx2/
│   │   └── external_lib.bc      # AVX2 优化
│   └── avx512/
│       └── external_lib.bc      # AVX-512 优化
└── README.md
```

**CMake 集成**：

```cmake
# 编译所有 IR 变体
set(IR_VARIANTS "base;avx2;avx512")

foreach(VARIANT ${IR_VARIANTS})
    set(IR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ir/variants/${VARIANT}")

    if(EXISTS ${IR_DIR})
        file(GLOB VARIANT_IR_FILES "${IR_DIR}/*.bc")

        foreach(IR_FILE ${VARIANT_IR_FILES})
            get_filename_component(IR_NAME ${IR_FILE} NAME_WE)
            set(OBJ_FILE "${CMAKE_CURRENT_BINARY_DIR}/ir_objects/${VARIANT}/${IR_NAME}.o")

            # 编译 IR（保持原有优化级别）
            add_custom_command(
                OUTPUT ${OBJ_FILE}
                COMMAND ${CMAKE_COMMAND} -E make_directory
                    ${CMAKE_CURRENT_BINARY_DIR}/ir_objects/${VARIANT}
                COMMAND llc -O3 -filetype=obj -o ${OBJ_FILE} ${IR_FILE}
                DEPENDS ${IR_FILE}
                COMMENT "Compiling IR variant: ${VARIANT}/${IR_NAME}"
            )

            list(APPEND IR_OBJECT_FILES_${VARIANT} ${OBJ_FILE})
        endforeach()
    endif()
endforeach()

# 链接所有变体（类似 GGML_CPU_ALL_VARIANTS）
target_sources(${PROJECT_NAME} PRIVATE
    ${IR_OBJECT_FILES_base}
    ${IR_OBJECT_FILES_avx2}
    ${IR_OBJECT_FILES_avx512}
)
```

**运行时选择**（在 addon 中）：

```cpp
// 类似 llama.cpp 的 CPU 检测
#include <cpuid.h>

enum class CPUVariant {
    Base,
    AVX2,
    AVX512
};

CPUVariant detect_cpu_variant() {
    unsigned int eax, ebx, ecx, edx;

    // 检测 AVX-512
    if (__get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx)) {
        if (ebx & bit_AVX512F) {
            return CPUVariant::AVX512;
        }
    }

    // 检测 AVX2
    if (__get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx)) {
        if (ebx & bit_AVX2) {
            return CPUVariant::AVX2;
        }
    }

    return CPUVariant::Base;
}

// 函数指针表
extern "C" {
    // 基础版本
    float ir_compute_base(const float* data, size_t len);

    // AVX2 版本
    float ir_compute_avx2(const float* data, size_t len);

    // AVX512 版本
    float ir_compute_avx512(const float* data, size_t len);
}

// 运行时选择
static auto selected_compute = []() {
    switch (detect_cpu_variant()) {
        case CPUVariant::AVX512:
            return &ir_compute_avx512;
        case CPUVariant::AVX2:
            return &ir_compute_avx2;
        default:
            return &ir_compute_base;
    }
}();

// 统一接口
extern "C" float ir_compute(const float* data, size_t len) {
    return selected_compute(data, len);
}
```

---

#### 选项 2: 单一通用 IR + 本地编译 fallback（与项目一致）

**分发策略**：

1. **Prebuilt 包**：包含预编译的多个 IR 变体
2. **Fallback**：如果没有 prebuilt，本地编译时使用 `-march=native`

**实现**：

```cmake
# 检查是否有 prebuilt IR
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ir/prebuilt/${PLATFORM_ARCH}")
    # 使用 prebuilt IR（多变体）
    file(GLOB IR_FILES "${CMAKE_CURRENT_SOURCE_DIR}/ir/prebuilt/${PLATFORM_ARCH}/*.bc")
    message(STATUS "Using prebuilt IR for ${PLATFORM_ARCH}")
else()
    # Fallback: 本地编译，使用 native 优化
    file(GLOB IR_SOURCE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/external/ir-sources/*.cpp")

    foreach(IR_SOURCE ${IR_SOURCE_FILES})
        # 生成 IR（native 优化）
        add_custom_command(
            OUTPUT ${IR_BC_FILE}
            COMMAND clang++ -c -emit-llvm -O3 -fPIC
                -march=native
                -stdlib=libstdc++
                -o ${IR_BC_FILE}
                ${IR_SOURCE}
            COMMENT "Compiling IR with native optimization (fallback)"
        )
    endforeach()

    message(STATUS "Building IR from source with native optimization")
endif()
```

---

## 推荐方案总结

### 🎯 方案 A: 多 IR 变体（最佳，与项目一致）

**优势**：
- ✅ 与现有 `GGML_CPU_ALL_VARIANTS` 策略一致
- ✅ 分发 prebuilt 包，用户无需编译
- ✅ 运行时自动选择最优版本
- ✅ 性能最优

**劣势**：
- ⚠️ 需要维护多个 IR 文件
- ⚠️ 包体积稍大

**适用场景**：
- 分发给最终用户
- 需要最佳性能
- 与项目现有策略保持一致

---

### 🎯 方案 B: 单一通用 IR + Fallback（简单）

**优势**：
- ✅ 只需维护一个通用 IR
- ✅ Fallback 时自动 native 优化
- ✅ 简单易维护

**劣势**：
- ⚠️ Prebuilt 包性能不是最优
- ⚠️ 依赖 fallback 编译

**适用场景**：
- 开发阶段
- 内部使用
- 不需要极致性能

---

## 实际建议

### 对于你的项目

基于你已有的优秀架构，我建议：

#### 1. **短期**：使用方案 B（简单快速）

```bash
# 生成单一通用 IR
clang++ -c -emit-llvm -O3 -fPIC -march=x86-64 \
    -stdlib=libstdc++ \
    -o external_lib.bc \
    external_lib.cpp

# 放到项目中
cp external_lib.bc llama/ir/
```

构建时：
- 如果有 prebuilt IR → 使用
- 否则 → 本地编译（`-march=native`）

#### 2. **长期**：升级到方案 A（与项目一致）

```bash
# 生成多个变体
./scripts/build-ir-variants.sh

# 集成到 prebuilt 包
packages/prebuilt-llama-node/linux-x64/ir/
├── base/
├── avx2/
└── avx512/
```

运行时自动选择最优版本，就像 `GGML_CPU_ALL_VARIANTS` 一样。

---

## 总结

### ✅ 你的理解完全正确

1. **Prebuilt 多包策略** → 正确且高效
2. **CPU 优化分级**（base/avx2/avx512）→ 与 llama.cpp 一致
3. **Fallback 本地编译** → native 优化

### 🎯 IR 应该遵循相同策略

- **分发**：多个优化级别的 IR（base/avx2/avx512）
- **运行时**：自动选择最优版本
- **Fallback**：本地编译时使用 `-march=native`

这样 IR 方案就完美融入你的现有架构了！

需要我帮你实现具体的某个部分吗？
