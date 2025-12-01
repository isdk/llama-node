# 本地测试 GitHub Actions 工作流

本指南说明如何使用 `act` 在本地测试 GitHub Actions 工作流。

## 前置要求

- ✅ `act` 已安装 (version 0.2.82)
- ✅ `gh` (GitHub CLI) 已登录
- ✅ Docker 运行中（act 使用 Docker 容器模拟 GitHub Actions runners）

## 快速开始

### 1. 查看可用的作业

```bash
./test-act.sh --list
```

### 2. 测试特定作业

```bash
# 测试构建作业
./test-act.sh --job build

# 测试我们刚修复的 resolve-next-release 作业（验证补丁是否工作）
./test-act.sh --job resolve-next-release

# 测试独立测试
./test-act.sh --job standalone-tests
```

### 3. 直接使用 act 命令

```bash
# 列出所有作业
act -l -W .github/workflows/build.yml

# 运行特定作业
act push -j build -W .github/workflows/build.yml

# 模拟 main 分支的 push 事件
act push -W .github/workflows/build.yml -e <(echo '{"ref":"refs/heads/main"}')

# 查看工作流图
act -g -W .github/workflows/build.yml
```

## 重点测试作业

### 1. `resolve-next-release` 作业 ⭐️

这是我们刚刚修复补丁的作业，用来验证：
- ✅ `patch` 命令能否正确应用补丁到符号链接的 node_modules
- ✅ semantic-release dry run 是否正常工作

```bash
./test-act.sh --job resolve-next-release
```

### 2. `build` 作业

基础构建作业，速度较快：

```bash
./test-act.sh --job build
```

### 3. `standalone-tests` 作业

运行不依赖模型的测试：

```bash
./test-act.sh --job standalone-tests
```

## 配置文件

### `.actrc`
act 的配置文件，包含：
- Docker 镜像映射
- 密钥文件路径
- 环境变量文件路径

### `.secrets`
包含 GitHub token 和其他密钥（已自动生成）：
```
GITHUB_TOKEN=<your_github_token>
NPM_TOKEN=<placeholder>
```

### `.env.act`
环境变量配置：
```
CI=true
ARTIFACT_NAME=linux-1
NODE_LLAMA_CPP_GPU=false
```

## 优化 Act 运行 - 缓存和复用策略

### 核心问题：每次都重新安装依赖

默认情况下，`act` 每次运行都会：
- 🔄 重新创建容器
- 📥 重新执行 `git clone`、`npm install` 等耗时步骤
- 🗑️ 任务结束后删除容器

这导致重复运行非常慢，尤其是需要频繁测试时。

### 解决方案：使用关键参数

#### 1. `-r` / `--reuse` - 复用容器 ⭐️

**作用**：任务完成后不删除容器，下次运行时复用同一容器。

**效果**：
- ✅ 环境保持不变（已安装的软件、依赖仍在）
- ✅ `apt-get install` 第二次运行几乎瞬间完成
- ✅ `pnpm install` 如果 `node_modules` 还在，也会快很多

```bash
act -j build -r
```

**注意**：虽然步骤会重新"执行"，但因为环境已就绪，耗时极短。

#### 2. `-b` / `--bind` - 绑定本地目录 ⭐️

**作用**：将本地目录**挂载**到容器，而不是复制一份。

**效果**：
- ✅ 跳过 `actions/checkout`：直接使用本地文件，无需重新 clone
- ✅ 共享构建产物：本地的 `dist/`、`node_modules/` 可以在容器中使用
- ✅ 实时反映代码变更：修改本地文件后，容器内立即生效

```bash
act -j build -b
```

#### 3. `--artifact-server-path` - 启用 Artifact Server ⚠️

**问题背景**：
- `actions/upload-artifact@v4` 需要 Artifact Server 支持
- `act` 默认不启用，会报错：`Unable to get the ACTIONS_RUNTIME_TOKEN`

**⚠️ 已知问题**：
即使指定了 `--artifact-server-path`，`upload-artifact@v4` 仍可能报错 `ECONNRESET`。这是因为 `act` 的 artifact server 功能不够稳定，action 仍然尝试连接 GitHub API。

**解决方法（三选一）**：

**选项 1：跳过 artifact 步骤（推荐）**
```bash
# 使用 -b 绑定本地目录后，不需要 artifact 传递
# 所有文件已经在本地，直接访问即可
act -j build -r -b
```

**选项 2：使用简化的 act 专用 workflow**
```bash
# 使用专门为 act 创建的简化 workflow（无 artifact 依赖）
act -j build-binaries-local -W .github/workflows/act-local-build.yml -r -b
```

**选项 3：使用本地脚本（最实用）**
```bash
# 完全绕过 act，直接在宿主机运行
./scripts/local-manual-release.sh
```

**不推荐**（不稳定）：
```bash
act -j build-binaries --artifact-server-path /tmp/act-artifacts  # 可能失败
```

### ⚡ 推荐的优化组合

#### 基础优化（适用于大多数场景）✅

```bash
act -j build -r -b
```

- 复用容器 + 绑定本地目录
- **加速约 70-90%**（取决于网络和依赖数量）
- 使用 `-b` 后，文件已在本地，不需要 artifact 传递

#### 测试完整构建流程（Linux 二进制）✅

**方法 1：使用本地脚本**（最简单）
```bash
./scripts/local-manual-release.sh
```

**方法 2：使用简化版 workflow**
```bash
act -j build-binaries-local -W .github/workflows/act-local-build.yml -r -b
```

这两种方法都跳过了有问题的 artifact upload/download 步骤。

#### 快速迭代（开发调试）✅

```bash
# 第一次运行（建立环境）
act -j standalone-tests -r -b

# 后续运行（极速）
act -j standalone-tests -r -b
```

**提示**：修改本地代码后，因为使用了 `-b`，容器内会立即看到变更，测试非常快。

### 🧹 清理容器

当你不再需要缓存的容器时：

```bash
# 查看所有 act 创建的容器
docker ps -a | grep act

# 删除所有停止的容器
docker container prune

# 或者手动删除特定容器
docker rm <container_id>
```

## 限制和注意事项

### ⚠️ 不能完全模拟的作业

1. **`build-binaries`**:
   - ❌ **平台限制**：在 Linux 上运行的 Docker 容器**只能**构建 Linux 二进制文件
   - ❌ **跨平台构建不可行**：即使 `.actrc` 将 `macos-latest` 映射到 Ubuntu 镜像，容器内依然是 Linux
     - 无法运行 `choco`（Windows 包管理器）
     - 无法运行 `brew`（macOS 包管理器）
     - 无法使用 MSVC（Windows 编译器）或 Xcode（macOS 编译器）
   - ✅ **Linux 二进制可以测试**：
     ```bash
     # 只构建 Linux 版本（需要 artifact server）
     act -j build-binaries -r -b --artifact-server-path /tmp/act-artifacts
     ```
   - 💡 **建议**：
     - 本地只测试 Linux 构建流程
     - Windows/macOS 构建依赖 GitHub Actions CI 的真实环境
     - 或使用 `scripts/local-manual-release.sh` 在本地构建 Linux 版本

2. **`model-dependent-tests`**:
   - 需要下载大型模型文件
   - 在本地可能非常慢
   - 建议：使用本地测试命令代替

3. **`release`**:
   - 需要有效的 NPM_TOKEN
   - 会尝试实际发布（除非工作流有保护）
   - 建议：只在必要时测试，确保 dry-run 模式

### ✅ 推荐的本地测试策略

1. **快速验证补丁**:
   ```bash
   # 只测试 resolve-next-release
   ./test-act.sh --job resolve-next-release
   ```

2. **验证构建流程**:
   ```bash
   # 测试 build + standalone-tests
   ./test-act.sh --job build
   ./test-act.sh --job standalone-tests
   ```

3. **完整测试**（耗时）:
   ```bash
   # 运行所有可以在本地运行的作业
   act push -W .github/workflows/build.yml
   ```

## 调试技巧

### 查看详细输出

```bash
act -v push -j build -W .github/workflows/build.yml
```

### 进入失败的容器调试

```bash
# 添加 --reuse 标志保持容器运行
act push -j build -W .github/workflows/build.yml --reuse

# 在另一个终端中
docker ps  # 找到容器 ID
docker exec -it <container_id> bash
```

### 测试单个步骤

修改 workflow 文件，临时注释掉不需要的步骤。

## 验证补丁修复

为了验证我们的补丁修复（将 `git apply` 改为 `patch`），运行：

```bash
./test-act.sh --job resolve-next-release
```

预期行为：
1. ✅ 三个补丁都成功应用
2. ✅ semantic-release dry run 执行成功
3. ✅ 生成 next version 输出

如果看到类似 "error: affected file ... is beyond a symbolic link" 的错误，说明补丁未正确应用。

## 其他资源

- [act 官方文档](https://github.com/nektos/act)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [semantic-release 文档](https://semantic-release.gitbook.io/)
