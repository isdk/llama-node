# 编译器统一方案：全面采用 LLVM/Clang

## 背景

当前项目在不同平台使用不同的编译器：
- **Windows**: LLVM/Clang（已实现）
- **macOS**: Apple Clang（系统默认）
- **Linux 本地编译**: 系统默认（通常是 GCC）
- **Linux 交叉编译**: GNU 工具链（`aarch64-linux-gnu-gcc` 等）

本文档提出将所有平台统一为 LLVM/Clang 的实施方案。

## 动机

### 优势
1. **统一构建体验**：所有平台使用相同编译器，减少平台差异
2. **更好的 C++ 标准支持**：Clang 对现代 C++ 特性支持更完整
3. **简化交叉编译**：LLVM 原生支持多目标架构
4. **一致性保证**：减少因编译器差异导致的 bug
5. **现代化优化**：更好的 SIMD 和 LTO 支持

### 挑战
1. CI/CD 配置需要调整
2. 需要配置 sysroot 和链接器
3. 潜在的兼容性问题需要测试
4. 团队需要熟悉 Clang 交叉编译

## 实施阶段

### 阶段 1：准备工作（1-2周）

#### 1.1 创建 LLVM 版本的 toolchain 文件

```cmake
# llama/toolchains/llvm.linux.host-x64.target-arm64.cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

set(target aarch64-linux-gnu)
set(CMAKE_C_COMPILER_TARGET ${target})
set(CMAKE_CXX_COMPILER_TARGET ${target})

# 设置 sysroot
set(CMAKE_SYSROOT /usr/aarch64-linux-gnu)
set(CMAKE_FIND_ROOT_PATH /usr/aarch64-linux-gnu)

# 优化标志
set(arch_c_flags "-march=armv8-a")
set(CMAKE_C_FLAGS_INIT "${arch_c_flags}")
set(CMAKE_CXX_FLAGS_INIT "${arch_c_flags}")

# 使用 lld 链接器（可选，但推荐）
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld")
```

类似地创建：
- `llvm.linux.host-x64.target-arm71.cmake`
- `llvm.linux.host-arm64.target-x64.cmake`

#### 1.2 更新 CI 依赖安装脚本

修改 `.github/workflows/build.yml`:

```yaml
- name: Install dependencies on Ubuntu (1) - LLVM version
  if: matrix.config.name == 'Ubuntu (1)'
  run: |
    sudo bash .github/scripts/setup-apt-mirror.sh || true
    sudo apt-get update

    # 安装 LLVM 工具链
    sudo apt-get install -y clang lld ninja-build libtbb-dev

    # 安装交叉编译 sysroot
    sudo apt-get install -y \
      libc6-dev-arm64-cross \
      libc6-dev-armel-cross \
      linux-libc-dev-arm64-cross \
      linux-libc-dev-armel-cross

    # 验证安装
    clang --version
    lld --version
    ls -la /usr/aarch64-linux-gnu
    ls -la /usr/arm-linux-gnueabihf

    # 安装 CMake
    wget -c https://github.com/Kitware/CMake/releases/download/v3.31.7/cmake-3.31.7-linux-x86_64.tar.gz
    sudo tar --strip-components=1 -C /usr/local -xzf cmake-3.31.7-linux-x86_64.tar.gz
    rm -f ./cmake-3.31.7-linux-x86_64.tar.gz

    cmake --version
```

### 阶段 2：并行测试（2-4周）

#### 2.1 添加编译器选择矩阵

```yaml
strategy:
  matrix:
    config:
      - name: "Ubuntu (1) - GCC"
        os: ubuntu-22.04
        compiler: gcc
      - name: "Ubuntu (1) - Clang"
        os: ubuntu-22.04
        compiler: clang
```

#### 2.2 条件化 toolchain 选择

在构建脚本中添加逻辑：

```typescript
const toolchainFile = process.env.USE_CLANG === 'true'
  ? 'llvm.linux.host-x64.target-arm64.cmake'
  : 'linux.host-x64.target-arm64.cmake';
```

#### 2.3 性能基准测试

创建测试脚本 `scripts/benchmark-compilers.ts`:

```typescript
// 对比 GCC vs Clang 编译的二进制性能
// 测试指标：
// - 推理速度（tokens/s）
// - 内存使用
// - 二进制大小
// - 编译时间
```

### 阶段 3：验证与修复（2-3周）

#### 3.1 兼容性测试清单

- [ ] Linux x64 → ARM64 交叉编译成功
- [ ] Linux x64 → ARMv7 交叉编译成功
- [ ] Linux ARM64 → x64 交叉编译成功
- [ ] 所有目标平台的二进制能正常运行
- [ ] CUDA 支持正常
- [ ] Vulkan 支持正常
- [ ] 性能测试通过（不低于 GCC 版本的 95%）

#### 3.2 常见问题修复

**问题 1：找不到系统头文件**
```bash
# 解决方案：显式指定 sysroot
export CFLAGS="--sysroot=/usr/aarch64-linux-gnu"
export CXXFLAGS="--sysroot=/usr/aarch64-linux-gnu"
```

**问题 2：链接错误**
```bash
# 解决方案：使用 lld 或指定正确的链接器路径
export LDFLAGS="-fuse-ld=lld"
# 或
export LDFLAGS="-B/usr/aarch64-linux-gnu/bin"
```

**问题 3：ABI 不兼容**
```cmake
# 确保使用正确的 ABI 标志
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfloat-abi=hard")  # for ARM
```

### 阶段 4：全面切换（1周）

#### 4.1 更新默认 toolchain

将 LLVM toolchain 设为默认：

```cmake
# llama/CMakeLists.txt
if(CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # 默认使用 LLVM toolchain
    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
            set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/toolchains/llvm.linux.host-x64.target-arm64.cmake")
        endif()
    endif()
endif()
```

#### 4.2 删除旧的 GCC toolchain 文件

```bash
rm llama/toolchains/linux.host-x64.target-arm64.cmake
rm llama/toolchains/linux.host-x64.target-arm71.cmake
rm llama/toolchains/linux.host-arm64.target-x64.cmake
```

#### 4.3 更新文档

修改 `docs/guide/building-from-source.md`:

```markdown
## 编译器要求

本项目使用 LLVM/Clang 作为统一的编译器：

- **Windows**: Clang (LLVM)
- **macOS**: Apple Clang
- **Linux**: Clang (LLVM)

### Linux 依赖安装

```bash
# Ubuntu/Debian
sudo apt-get install clang lld

# 交叉编译依赖
sudo apt-get install libc6-dev-arm64-cross
```

### 阶段 5：监控与优化（持续）

#### 5.1 监控指标

- CI 构建时间变化
- 二进制性能变化
- 用户报告的兼容性问题

#### 5.2 优化方向

1. **编译速度优化**
   ```cmake
   # 使用 ccache
   find_program(CCACHE_PROGRAM ccache)
   if(CCACHE_PROGRAM)
       set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
       set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
   endif()
   ```

2. **二进制大小优化**
   ```cmake
   # Release 模式使用 LTO
   if(CMAKE_BUILD_TYPE STREQUAL "Release")
       set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
   endif()
   ```

3. **性能优化**
   ```cmake
   # 针对目标 CPU 优化
   set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -march=native")
   ```

## 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| CI 构建失败 | 中 | 高 | 并行测试阶段充分验证 |
| 性能下降 | 低 | 高 | 基准测试，必要时回退 |
| 兼容性问题 | 中 | 中 | 在多个 Linux 发行版测试 |
| 用户构建失败 | 低 | 中 | 更新文档，提供清晰的错误信息 |

## 回退计划

如果在阶段 3 发现不可解决的问题：

1. 保留 GCC toolchain 文件
2. 提供环境变量选择编译器：
   ```bash
   export NODE_LLAMA_CPP_COMPILER=gcc  # 或 clang
   ```
3. 在文档中说明两种方案的差异

## 成功标准

- [ ] 所有 CI 测试通过
- [ ] 性能不低于 GCC 版本
- [ ] 文档完整更新
- [ ] 至少 2 周无相关 bug 报告

## 时间表

| 阶段 | 预计时间 | 负责人 |
|------|----------|--------|
| 阶段 1：准备 | 1-2周 | TBD |
| 阶段 2：并行测试 | 2-4周 | TBD |
| 阶段 3：验证修复 | 2-3周 | TBD |
| 阶段 4：全面切换 | 1周 | TBD |
| 阶段 5：监控优化 | 持续 | TBD |

**总计：6-10周**

## 参考资料

- [LLVM Cross Compilation](https://clang.llvm.org/docs/CrossCompilation.html)
- [CMake Toolchain Files](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)
- [Debian Cross Compilation](https://wiki.debian.org/CrossCompiling)
