# LLVM IR 集成指南索引

本文档作为在 `node-llama.node` 项目中集成 LLVM IR 的中心索引。以下文档详细介绍了从基础概念到高级优化的完整方案。

## 📚 核心文档列表

### 1. 基础集成
- **[在 Addon 中集成 Clang 虚拟机代码](integrating-clang-vm-in-addon.md)**
  - 概述了三种集成方案：JIT、共享库、静态链接。
  - 推荐从静态链接方案开始。

- **[静态链接 LLVM IR 指南](static-linking-llvm-ir.md)**
  - **必读**。详细介绍了如何将预编译的 `.bc` 文件静态链接到 NAPI addon 中。
  - 包含 CMake 配置和 C++ 代码示例。

### 2. 兼容性与构建
- **[Clang/GCC STL 兼容性指南](clang-gcc-stl-compatibility.md)**
  - 解决了 Clang 生成的 IR 与 GCC 编译的项目之间的 STL 兼容性问题。
  - 核心解决方案：使用 `-stdlib=libstdc++`。

- **[跨平台智能 IR 构建](cross-platform-ir-build.md)**
  - 提供了自动化脚本，用于在不同平台（Linux/Windows/macOS）上生成兼容的 IR。

### 3. 优化与分发策略 (高级)
- **[LLVM IR 两阶段优化与运行时分发](llvm-ir-two-stage-optimization.md)**
  - **核心架构文档**。
  - 解释了 IR 生成阶段（向量宽度锁定）与编译阶段（指令选择）的区别。
  - 定义了跨架构（x64/ARM64）和多特性（Base/AVX2/AVX512）的 IR 变体矩阵。
  - 提供了 Node.js 运行时检测 CPU 能力并加载对应包的完整方案。

- **[IR 与 Prebuilt 策略集成](ir-prebuilt-strategy.md)**
  - 分析了项目现有的 Prebuilt 多包策略。
  - 提供了将 IR 方案融入现有架构的具体建议。

## 🚀 快速实施路线图

1.  **准备阶段**:
    - 阅读 [静态链接 LLVM IR 指南](static-linking-llvm-ir.md) 了解基本流程。
    - 阅读 [Clang/GCC STL 兼容性指南](clang-gcc-stl-compatibility.md) 确保存档兼容性。

2.  **构建系统**:
    - 使用 [跨平台智能 IR 构建](cross-platform-ir-build.md) 中的脚本生成 IR。
    - 按照 [LLVM IR 两阶段优化](llvm-ir-two-stage-optimization.md) 中的建议，生成多版本 IR（Base/AVX2/NEON 等）。

3.  **集成与分发**:
    - 参考 [IR 与 Prebuilt 策略集成](ir-prebuilt-strategy.md) 更新 CI/CD 流程。
    - 实现 [LLVM IR 两阶段优化](llvm-ir-two-stage-optimization.md) 中的运行时加载逻辑。

---

## 常见问题 (FAQ)

**Q: 为什么不能只用 `-march=native`？**
A: `llc` 不支持 `-march=native`，且 IR 生成阶段使用 `-march=native` 会导致生成的 IR 无法跨平台。正确做法是生成通用 IR（或特定架构变体），然后在构建时使用 `llc -mcpu=<cpu>`。

**Q: ARM 芯片兼容吗？**
A: 不兼容 x86 的 AVX 指令集。ARM 需要独立的 IR 变体（主要是 NEON）。详见 [LLVM IR 两阶段优化](llvm-ir-two-stage-optimization.md)。

**Q: 如何处理 STL？**
A: 在 Linux 上生成 IR 时，必须强制 Clang 使用 `-stdlib=libstdc++` 以兼容 GCC。详见 [Clang/GCC STL 兼容性指南](clang-gcc-stl-compatibility.md)。
