# Contributing to node-llama.node

欢迎贡献！本文档包含所有开发相关的信息。

## 目录

- [快速开始](#快速开始)
- [开发环境设置](#开发环境设置)
- [测试](#测试)
- [GitHub Actions工作流](#github-actions工作流)
- [本地测试工作流](#本地测试工作流-act)
- [CI测试修复参考](#ci测试修复参考)
- [架构和设计文档](#架构和设计文档)
- [提交代码](#提交代码)

---

## 快速开始

```bash
# 安装依赖
pnpm install

# 构建项目
pnpm run build

# 下载llama.cpp
node ./dist/cli/cli.js source download --release latest

# 编译本地二进制
node ./dist/cli/cli.js source build

# 运行测试
pnpm run test:standalone          # 独立测试（不需要模型）
pnpm run test:modelDependent      # 模型依赖测试（需要模型）
```

---

## 开发环境设置

### 前置要求

- **Node.js** 20+
- **pnpm** 10
- **CMake** 3.31+
- **Ninja** build system
- **C++** 编译器（GCC/Clang/MSVC）

### 可选工具

- **act** - 本地测试GitHub Actions
- **gh** (GitHub CLI) - GitHub命令行工具
- **Docker** - 用于act容器化测试

### 安装依赖

```bash
# macOS
brew install cmake ninja

# Ubuntu/Debian
sudo apt-get install ninja-build cmake g++

# Windows
choco install cmake ninja visualstudio2022buildtools
```

---

## 测试

### 测试类型

#### 1. 独立测试（Standalone Tests）

不需要下载模型的快速测试：

```bash
pnpm run test:standalone
```

#### 2. 模型依赖测试（Model Dependent Tests）

需要下载模型的完整测试：

```bash
# 下载测试所需的模型（仅essential组）
pnpm run dev:setup:downloadAllTestModels --group essential

# 运行测试
pnpm run test:modelDependent
```

#### 3. 运行特定测试

```bash
# 运行特定文件
pnpm run test:modelDependent test/modelDependent/model.test.ts

# 运行特定模式
pnpm run test:modelDependent test/modelDependent/qwen*
```

### 测试配置

测试配置位于 `vitest.config.ts`：
- **单进程**: 确保资源正确释放
- **超时**: 长时间运行的测试设置为10分钟
- **快照**: 使用自定义序列化器

### ⚠️ CI测试注意事项

#### 避免硬编码快照

❌ **不要这样做**（脆弱，依赖环境）:
```typescript
expect(res.contextSize).toMatchInlineSnapshot(`10748`);
```

✅ **应该这样做**（健壮，跨环境）:
```typescript
expect(res.contextSize).to.be.greaterThan(7500);
expect(res.contextSize).to.be.lessThan(13500);
```

**原因**: 硬件相关的计算（GPU层数、内存大小）在不同环境中会有差异：
- llama.cpp版本差异
- 虚拟化 vs 物理硬件
- CPU架构差异

详见: [CI测试修复参考](#ci测试修复参考)

---

## GitHub Actions工作流

### 工作流触发条件

- **push到main/beta**: 完整构建 + 发布
- **Pull Request**: 完整构建 + 测试
- **workflow_dispatch**: 手动触发

### 主要作业

| 作业 | 描述 | 运行时间 |
|------|------|----------|
| `build` | 构建TypeScript代码 | ~5分钟 |
| `build-binaries` | 编译6个平台的二进制文件 | ~90分钟 |
| `standalone-tests` | 运行独立测试 | ~3分钟 |
| `model-dependent-tests` | 运行模型测试 | ~7分钟 |
| `release` | 语义化发布到npm | ~15分钟 |

### 手动触发参数

通过 `workflow_dispatch` 手动触发时，可使用以下三个正交参数：

#### 1. binary_mode（二进制构建模式）

| 选项 | 说明 |
|------|------|
| `skip` | 跳过构建（仅测试） |
| `build` ⭐ | 正常构建（使用缓存） |
| `force_rebuild` | 强制重新构建（忽略缓存） |

#### 2. release_mode（发布模式）

| 选项 | 说明 |
|------|------|
| `skip` | 跳过发布 |
| `normal` ⭐ | 正常发布（已存在版本跳过） |
| `force_republish` | 强制重新发布（覆盖已存在版本） |

#### 3. test_mode（测试模式）

| 选项 | 说明 |
|------|------|
| `all` ⭐ | 运行所有测试 |
| `standalone` | 仅 standalone 测试 |
| `model_dependent` | 仅 model dependent 测试 |
| `skip` | 跳过所有测试 |

> ⭐ 表示默认值

**常用场景**：

| 场景 | binary_mode | release_mode | test_mode |
|------|-------------|--------------|-----------|
| 完整发布流程 | `build` | `normal` | `all` |
| 仅运行测试 | `skip` | `skip` | `all` |
| 修复 prebuilt 包 | `build` | `force_republish` | `skip` |
| 强制完全重建发布 | `force_rebuild` | `force_republish` | `all` |
| 快速 standalone 测试 | `skip` | `skip` | `standalone` |

### 通过 Commit 消息控制

在commit消息中添加标记可以跳过特定步骤：

```bash
# 跳过二进制构建（节省90%时间）
git commit -m "test: fix tests [skip-binaries]"

# 跳过发布
git commit -m "test: update tests [skip-release]"

# 完全跳过工作流
git commit -m "docs: update README [skip ci]"
```

---

## 本地测试工作流 (act)

使用`act`可以在本地Docker容器中测试GitHub Actions工作流。

### 安装act

```bash
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# 验证安装
act --version
```

### 快速使用

```bash
# 列出所有作业
act -l -W .github/workflows/build.yml

# 运行特定作业
act push -j build -W .github/workflows/build.yml

# 使用优化参数（复用容器 + 绑定本地目录）
act -j build -r -b
```

### ⚡ 性能优化

#### 推荐配置（加速70-90%）

```bash
# -r: 复用容器（避免重新安装依赖）
# -b: 绑定本地目录（跳过git clone）
act -j build -r -b
```

**第一次运行**: ~10分钟（建立环境）
**后续运行**: ~1-2分钟（极速）

#### 配置文件

- `.actrc` - act配置（Docker镜像、密钥路径）
- `.secrets` - GitHub token和其他密钥
- `.env.act` - 环境变量

### ⚠️ 限制

**不能完全模拟的作业**:

1. **build-binaries**:
   - ❌ 只能在Linux容器构建Linux二进制
   - ❌ 无法跨平台构建Windows/macOS
   - ✅ 可使用 `./scripts/local-manual-release.sh` 构建Linux版本

2. **model-dependent-tests**:
   - 需要下载大型模型
   - 建议直接在宿主机运行测试

3. **release**:
   - 需要有效的NPM_TOKEN
   - 可能触发实际发布

### 调试技巧

```bash
# 查看详细日志
act -v push -j build -W .github/workflows/build.yml

# 保持容器运行以便调试
act push -j build -W .github/workflows/build.yml --reuse

# 进入容器
docker ps  # 找到容器ID
docker exec -it <container_id> bash
```

详见: `ACT_TESTING.md`

---

## CI测试修复参考

### 常见CI测试失败

#### 1. 超时问题

**症状**: `Error: Test timed out in 5000ms`

**原因**: Vitest嵌套describe不继承父级超时

**修复**:
```typescript
// ❌ 错误 - 嵌套describe不继承超时
describe("ParentTest", { timeout: 60000 }, () => {
  describe("ChildTest", () => {  // 使用默认5000ms
    it("test", () => { /* ... */ });
  });
});

// ✅ 正确 - 显式设置超时
describe("ChildTest", { timeout: 60000 }, () => {
  it("test", () => { /* ... */ });
});
```

#### 2. GPU层数/上下文大小快照不匹配

**症状**:
```
Expected: "10748"
Received: "8061"
```

**原因**:
- llama.cpp版本差异
- 虚拟化环境内存估算不同
- CPU架构差异

**修复策略**:

| 场景 | 修复方法 |
|------|----------|
| 正常情况 | 使用±20-30%范围 |
| Auto模式 | 允许降级到CPU（0层） |
| 极限条件 | 使用更宽松范围 |

```typescript
// ❌ 不要: 硬编码值
expect(res.contextSize).toMatchInlineSnapshot(`10748`);

// ✅ 应该: 合理范围
expect(res.contextSize).to.be.greaterThan(7500);
expect(res.contextSize).to.be.lessThan(13500);

// ✅ Auto模式: 考虑CPU降级
expect(res.gpuLayers).to.be.within(0, 6);  // 0表示纯CPU
expect(res.contextSize).to.be.greaterThan(6000);
```

### 完整的修复案例

详见以下文档：
- `CI_FIXES_COMPLETE_CHECKLIST.md` - 完整修复清单
- `CI_TEST_FAILURES_ANALYSIS.md` - 问题分析
- `CI_TEST_FIXES_SUMMARY.md` - 修复总结
- `CI_TEST_FIXES_ROUND2.md` - 第二轮修复

---

## 架构和设计文档

### 核心组件

#### 1. 绑定层（Bindings）

- **位置**: `src/bindings/`
- **职责**: Node.js与llama.cpp的C++接口
- **关键文件**:
  - `getLlama.ts` - 初始化和配置
  - `addon/` - C++绑定实现

#### 2. 模型层（Model）

- **LlamaModel**: 模型加载和配置
  - GPU层数配置
  - 内存映射（mmap）
  - 权重加载

#### 3. 上下文层（Context）

- **LlamaContext**: 推理上下文管理
  - 序列管理
  - 批处理
  - LoRA适配器

#### 4. 推理层（Inference）

- **LlamaCompletion**: 文本生成
- **LlamaEmbedding**: 向量嵌入
- **LlamaReranker**: 重排序

### 开发笔记

详细的架构分析和设计决策:
- `dev.md` - 详细的开发笔记和API分析
- `analysis_binding.md` - 绑定层分析
- `CLI_REFACTORING.md` - CLI重构文档

---

## 提交代码

### Commit规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```bash
# 功能
git commit -m "feat(model): add GPU layer auto-configuration"

# 修复
git commit -m "fix(test): resolve CI snapshot mismatches"

# 文档
git commit -m "docs: update contributing guide"

# 测试
git commit -m "test: add range checks for GPU tests"

# 构建/CI
git commit -m "build: optimize GitHub Actions workflow"
```

### Pull Request

1. **Fork** 仓库
2. **创建分支**: `git checkout -b feature/your-feature`
3. **提交代码**: 遵循commit规范
4. **推送分支**: `git push origin feature/your-feature`
5. **创建PR**: 使用PR模板

### PR检查清单

- [ ] 代码通过本地测试
- [ ] 添加/更新了测试
- [ ] 更新了相关文档
- [ ] 遵循代码规范
- [ ] commit消息符合规范
- [ ] 没有引入breaking changes（或在commit中标记）

### 代码审查

所有PR都需要至少一个维护者的审查。审查关注：
- 代码质量和可维护性
- 测试覆盖率
- 文档完整性
- 性能影响

---

## 获取帮助

- **Issues**: 报告bug或请求功能
- **Discussions**: 提问和讨论
- **文档**: https://node-llama-cpp.withcat.ai/

---

## 许可证

通过贡献，您同意您的代码将根据项目的许可证进行许可。

---

**感谢您的贡献！** 🙏
