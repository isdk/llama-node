# 在GitHub网页上手动触发工作流

## 🌐 基础方法（当前可用）

### 步骤1: 访问Actions页面

1. 打开你的GitHub仓库
2. 点击顶部的 **Actions** 标签页
3. 在左侧边栏找到 **Build** 工作流

### 步骤2: 手动触发

1. 点击左侧的 **Build** 工作流
2. 右上角会看到 **Run workflow** 按钮（绿色）
3. 点击按钮
4. 选择分支（默认是main）
5. 点击绿色的 **Run workflow** 按钮

### 当前限制

❌ **无法选择性跳过步骤**
- 会运行**完整的工作流**（包括build-binaries和release）
- 无法只运行测试部分
- 耗时约2小时

---

## ✨ 改进方案 - 添加输入参数

### 方案1: 添加Skip选项（推荐）

修改 `.github/workflows/build.yml`：

```yaml
name: Build
on:
  push:
    branches:
      - main
      - beta
  pull_request:
  workflow_dispatch:
    inputs:
      skip_binaries:
        description: '跳过二进制构建（节省90%时间）'
        required: false
        default: false
        type: boolean
      skip_release:
        description: '跳过发布到npm'
        required: false
        default: true
        type: boolean
```

然后修改job条件：

```yaml
build-binaries:
  if: |
    (github.event_name != 'workflow_dispatch' || !inputs.skip_binaries) &&
    !contains(github.event.head_commit.message, '[skip-binaries]') &&
    !contains(github.event.head_commit.message, '[skip-build]')

release:
  if: |
    (github.event_name != 'workflow_dispatch' || !inputs.skip_release) &&
    !contains(github.event.head_commit.message, '[skip-binaries]') &&
    !contains(github.event.head_commit.message, '[skip-build]') &&
    needs.resolve-next-release.outputs.next-version != '' &&
    needs.resolve-next-release.outputs.next-version != 'false'
```

**使用效果**:
- 打开Actions页面，点击"Run workflow"
- 会看到两个复选框：
  - ☑️ 跳过二进制构建
  - ☑️ 跳过发布到npm（默认选中）
- 选择后点击运行

---

### 方案2: 添加测试类型选择

更灵活的配置：

```yaml
workflow_dispatch:
  inputs:
    run_mode:
      description: '运行模式'
      required: true
      default: 'tests-only'
      type: choice
      options:
        - tests-only          # 只运行测试（~10分钟）
        - build-and-test      # 构建+测试，跳过release（~30分钟）
        - full                # 完整流程（~2小时）
    test_type:
      description: '测试类型'
      required: false
      default: 'all'
      type: choice
      options:
        - all
        - standalone
        - model-dependent
```

条件配置：

```yaml
build-binaries:
  if: |
    github.event_name != 'workflow_dispatch' ||
    inputs.run_mode == 'full'

standalone-tests:
  if: |
    github.event_name != 'workflow_dispatch' ||
    inputs.test_type == 'all' ||
    inputs.test_type == 'standalone'

model-dependent-tests:
  if: |
    github.event_name != 'workflow_dispatch' ||
    inputs.test_type == 'all' ||
    inputs.test_type == 'model-dependent'

release:
  if: |
    (github.event_name != 'workflow_dispatch' || inputs.run_mode == 'full') &&
    needs.resolve-next-release.outputs.next-version != '' &&
    needs.resolve-next-release.outputs.next-version != 'false'
```

**使用效果**:
- 选择运行模式：只测试 / 构建+测试 / 完整
- 选择测试类型：全部 / 独立 / 模型依赖

---

## 🚀 快速实施

我推荐**方案1**（添加Skip选项），因为：
- ✅ 简单明了
- ✅ 与commit消息标记一致
- ✅ 默认值合理（跳过release）

### 实施步骤

需要我帮你：
1. 修改 `build.yml` 添加inputs配置
2. 更新job条件
3. 提交并推送

修改后的使用流程：

```
1. 访问 https://github.com/你的用户名/repo/actions/workflows/build.yml
2. 点击 "Run workflow"
3. 选择分支: main
4. ☑️ 勾选 "跳过二进制构建"（节省时间）
5. ☑️ 勾选 "跳过发布到npm"（默认已勾选）
6. 点击 "Run workflow"
```

结果：只运行测试，~10分钟完成！

---

## 📱 使用GitHub CLI

如果你安装了`gh` CLI：

```bash
# 手动触发（完整流程）
gh workflow run build.yml

# 触发并传递参数（需要先添加inputs配置）
gh workflow run build.yml -f skip_binaries=true -f skip_release=true

# 查看运行状态
gh run list --workflow=build.yml

# 查看最新运行的日志
gh run view --log
```

---

## 📊 对比：三种触发方式

| 方式 | 跳过binaries | 跳过release | 灵活性 | 便捷性 |
|------|-------------|-------------|--------|--------|
| **Commit标记** | ✅ | ✅ | 低 | 高 |
| **Web手动触发**（当前） | ❌ | ❌ | 无 | 中 |
| **Web+Inputs**（改进） | ✅ | ✅ | 高 | 高 |
| **CLI** | ✅ | ✅ | 高 | 中 |

---

## 💡 推荐使用场景

### 场景1: 快速测试验证
```bash
# 方式1: Commit标记
git commit -m "test: quick test [skip-binaries]"
git push

# 方式2: Web界面（改进后）
访问Actions → Run workflow → ☑️ 跳过二进制 → Run
```

### 场景2: 正式发布
```bash
# 方式1: 正常推送
git commit -m "feat: new feature"
git push

# 方式2: Web界面
访问Actions → Run workflow → 取消所有勾选 → Run
```

### 场景3: 只测试特定类型（需要方案2）
```
访问Actions → Run workflow →
  运行模式: tests-only
  测试类型: standalone
→ Run
```

---

需要我帮你实施哪个方案吗？我可以直接修改配置文件！
