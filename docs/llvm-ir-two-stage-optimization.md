# LLVM IR 两阶段优化与运行时分发最佳实践

## 核心概念：优化发生在哪里？

在 LLVM 编译管线中，优化主要发生在两个阶段：

1.  **IR 生成阶段 (`clang++`)**:
    -   **高层优化**: 函数内联、常量折叠。
    -   **循环向量化 (Loop Vectorization)**: ⚠️ **关键点！** 编译器会根据目标架构决定向量宽度（例如 SSE2 为 128位，AVX2 为 256位，NEON 为 128位）。

2.  **机器码生成阶段 (`llc`)**:
    -   **指令选择**: 选择目标 CPU 支持的最佳指令。
    -   **寄存器分配**: 针对目标 CPU 的寄存器数量进行优化。

由于 IR 生成阶段锁定了向量宽度，**我们需要为不同的 CPU 架构和特性生成不同的 IR 变体**。

---

## 1. 跨架构 IR 变体矩阵

为了覆盖主流硬件并获得最佳性能，建议构建以下 IR 变体矩阵：

### 目录结构建议

```
llama/ir/
├── x64/                  # x86-64 架构
│   ├── base.bc           # SSE2 (兼容所有 x64)
│   ├── avx2.bc           # AVX2 (Haswell+)
│   └── avx512.bc         # AVX-512 (Skylake-X+)
└── arm64/                # ARM64 架构
    ├── neon.bc           # NEON (兼容所有 ARMv8)
    └── sve.bc            # SVE (高性能 ARM，可选)
```

### 生成命令

#### x86-64 系列
```bash
# Base (SSE2)
clang++ -c -emit-llvm -O3 -march=x86-64 -o ir/x64/base.bc lib.cpp

# AVX2
clang++ -c -emit-llvm -O3 -march=haswell -o ir/x64/avx2.bc lib.cpp

# AVX-512
clang++ -c -emit-llvm -O3 -march=skylake-avx512 -o ir/x64/avx512.bc lib.cpp
```

#### ARM64 系列
```bash
# NEON (通用)
clang++ -c -emit-llvm -O3 --target=aarch64-linux-gnu -march=armv8-a+simd \
    -o ir/arm64/neon.bc lib.cpp

# SVE (高性能)
clang++ -c -emit-llvm -O3 --target=aarch64-linux-gnu -march=armv8-a+sve \
    -o ir/arm64/sve.bc lib.cpp
```

---

## 2. 构建系统集成 (CMake)

构建系统需要根据**目标架构**和**Host CPU 能力**选择正确的 IR 文件。

```cmake
# 检测目标架构
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    set(TARGET_ARCH "arm64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    set(TARGET_ARCH "x64")
endif()

# 选择 IR 变体
if(TARGET_ARCH STREQUAL "x64")
    # 逻辑：优先选择最高级指令集
    if(HOST_CPU_SUPPORTS_AVX512 AND EXISTS ".../ir/x64/avx512.bc")
        set(IR_VARIANT "avx512")
    elseif(HOST_CPU_SUPPORTS_AVX2 AND EXISTS ".../ir/x64/avx2.bc")
        set(IR_VARIANT "avx2")
    else()
        set(IR_VARIANT "base")
    endif()
elseif(TARGET_ARCH STREQUAL "arm64")
    # ARM64 逻辑
    if(HOST_CPU_SUPPORTS_SVE AND EXISTS ".../ir/arm64/sve.bc")
        set(IR_VARIANT "sve")
    else()
        set(IR_VARIANT "neon")
    endif()
endif()

# 编译选中的 IR
set(IR_FILE "${CMAKE_CURRENT_SOURCE_DIR}/ir/${TARGET_ARCH}/${IR_VARIANT}.bc")
# ... 使用 llc -mcpu=native 编译 IR_FILE ...
```

---

## 3. 运行时分发与按需下载 (Smart Downloader)

为了避免用户下载所有变体的包（这会浪费大量带宽），建议使用 `postinstall` 脚本在安装后立即下载最适合当前机器的 NPM 包。

### 策略：从 NPM Registry 下载

我们不使用 `npm install`（因为在 postinstall 中运行不安全），而是直接从 NPM Registry 下载对应的 `.tgz` 包并解压到 `node_modules`。

### 跨平台 CPU 检测方案

我们需要在不引入重量级 native 依赖的情况下，跨平台检测 CPU 特性（特别是 SVE）。

| 平台 | 检测方法 | 关键指标 |
|------|----------|----------|
| **Linux / Android** | 读取 `/proc/cpuinfo` | `flags` (x86), `Features` (ARM) |
| **macOS** | `sysctl` 命令 | `machdep.cpu.features` |
| **Windows** | 环境变量 / PowerShell | 基础检测或假设 AVX2 |

### 脚本实现 (`scripts/download-optimized-addon.ts`)

该脚本在 `npm install` 后运行，执行以下步骤：

1.  **检测 OS 和 Arch**。
2.  **检测 CPU 特性**：
    -   **Linux/Android ARM64**: 读取 `/proc/cpuinfo`，查找 `Features` 行中的 `sve`。
    -   **Linux x64**: 查找 `avx512f`, `avx2`。
3.  **构建 NPM 包名**:
    -   SVE: `@isdk/llama-node-linux-arm64-sve`
    -   AVX2: `@isdk/llama-node-linux-x64-avx2`
4.  **构建 Registry URL**: `https://registry.npmjs.org/@isdk/llama-node-linux-arm64-sve/-/llama-node-linux-arm64-sve-1.0.0.tgz`
5.  **下载并解压**: 解压到 `node_modules/@isdk/llama-node-linux-arm64-sve`。

### package.json 配置

```json
{
  "scripts": {
    "postinstall": "node -r ts-node/register scripts/download-optimized-addon.ts"
  },
  "optionalDependencies": {
    "@isdk/llama-node-linux-x64": "..."
    // 保留最通用的包作为 fallback，确保基础可用性
  }
}
```

---

## 总结

完整的端到端高性能方案：

1.  **开发时**: 生成 **x64(Base/AVX2/AVX512)** 和 **ARM64(NEON/SVE)** 的 IR 变体。
2.  **构建时**: CI 系统根据矩阵构建多个版本的 NAPI Addon (Prebuilt 包)。
3.  **分发时**: 将每个变体发布为独立的 NPM 包（如 `@isdk/llama-node-linux-arm64-sve`）。
4.  **安装时**: `postinstall` 脚本检测用户 CPU 能力，从 NPM Registry 下载最优包。

这不仅解决了 IR 的优化问题，也完美解决了包体积膨胀的问题，同时利用了 NPM 的基础设施。
