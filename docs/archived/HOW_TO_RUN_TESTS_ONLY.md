# GitHub工作流 - 只运行测试的方法

## 方案1：使用Commit消息控制（推荐）⭐

### 使用方法
在commit消息中添加特殊标记：

```bash
# 只运行测试，跳过构建二进制文件和发布
git commit -m "test: fix CI tests [skip-binaries]"

# 或者只跳过发布
git commit -m "fix: update tests [skip-release]"
```

### 配置修改
在 `.github/workflows/build.yml` 的相应job中添加条件：

```yaml
build-binaries:
  name: Build binaries - ${{ matrix.config.name }}
  # 添加这个条件
  if: "!contains(github.event.head_commit.message, '[skip-binaries]') && !contains(github.event.head_commit.message, '[skip-build]')"
  needs:
    - build
  # ... 其余配置

release:
  name: Release
  # 添加这个条件
  if: |
    !contains(github.event.head_commit.message, '[skip-release]') &&
    !contains(github.event.head_commit.message, '[skip-build]') &&
    needs.resolve-next-release.outputs.next-version != '' &&
    needs.resolve-next-release.outputs.next-version != 'false'
  # ... 其余配置
```

---

## 方案2：使用GitHub Actions Web界面手动触发

### 步骤
1. 访问: `https://github.com/<你的仓库>/actions`
2. 点击左侧的 "Build" 工作流
3. 点击右上角的 "Run workflow" 按钮
4. 选择分支
5. 点击 "Run workflow"

**优点**:
- 不需要修改配置
- 适合临时测试

**缺点**:
- 会运行所有job（包括构建二进制）
- 无法选择性跳过

---

## 方案3：创建专门的测试工作流（最灵活）

创建一个新的工作流文件 `.github/workflows/test-only.yml`：

```yaml
name: Tests Only
on:
  workflow_dispatch:
    inputs:
      test_type:
        description: 'Test type to run'
        required: true
        default: 'all'
        type: choice
        options:
          - all
          - standalone
          - model-dependent

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 10
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "pnpm"
      - name: Install modules
        run: pnpm install
      - name: Build
        run: pnpm run build
      - name: Download latest llama.cpp release
        env:
          CI: true
        run: node ./dist/cli/cli.js source download --release latest --skipBuild --noBundle --noUsageExample --updateBinariesReleaseMetadataAndSaveGitBundle
      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          include-hidden-files: true
          name: "build"
          path: "dist"
      - name: Upload llama.cpp artifact
        uses: actions/upload-artifact@v4
        with:
          include-hidden-files: true
          name: "llama.cpp"
          path: |
            llama/binariesGithubRelease.json
            llama/llama.cpp.info.json
            llama/llama.cpp
            llama/gitRelease.bundle

  standalone-tests:
    name: Standalone tests
    if: inputs.test_type == 'all' || inputs.test_type == 'standalone'
    runs-on: ubuntu-22.04
    needs:
      - build
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 10
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "pnpm"
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: build
          path: dist
      - name: Download llama.cpp artifact
        uses: actions/download-artifact@v4
        with:
          name: llama.cpp
          path: llama
      - name: Install dependencies on ubuntu
        run: |
          sudo bash .github/scripts/setup-apt-mirror.sh || true
          sudo apt-get update
          sudo apt-get install ninja-build cmake
      - name: Install modules
        run: pnpm install
      - name: Build binary
        run: node ./dist/cli/cli.js source build --noUsageExample
      - name: Run standalone tests
        run: pnpm run test:standalone

  model-dependent-tests:
    name: Model dependent tests
    if: inputs.test_type == 'all' || inputs.test_type == 'model-dependent'
    runs-on: macos-13
    env:
      NODE_LLAMA_CPP_GPU: false
    needs:
      - build
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 10
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "pnpm"
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: build
          path: dist
      - name: Download llama.cpp artifact
        uses: actions/download-artifact@v4
        with:
          name: llama.cpp
          path: llama
      - name: Install dependencies on macOS
        run: |
          brew install cmake ninja
      - name: Install modules
        run: pnpm install
      - name: Build binary
        run: node ./dist/cli/cli.js source build --noUsageExample
      - name: Inspect hardware
        run: node ./dist/cli/cli.js inspect gpu
      - name: Download models or ensure all models are downloaded
        run: pnpm run dev:setup:downloadAllTestModels --group essential
      - name: Run model dependent tests
        env:
          NODE_OPTIONS: "--max-old-space-size=4096"
        run: pnpm run test:modelDependent test/modelDependent/qwen* test/modelDependent/bge* test/modelDependent/nomic* test/modelDependent/model.test.ts
```

### 使用方法
1. 创建上述文件
2. 推送到GitHub
3. 在Actions页面选择 "Tests Only" 工作流
4. 点击 "Run workflow"
5. 选择要运行的测试类型（all/standalone/model-dependent）

---

## 方案4：使用workflow输入参数（推荐用于现有工作流）

修改现有的 `build.yml`，添加输入参数：

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
        description: 'Skip building binaries'
        required: false
        default: false
        type: boolean
      skip_release:
        description: 'Skip release'
        required: false
        default: true  # 默认跳过发布
        type: boolean

jobs:
  build:
    # ... 保持不变

  build-binaries:
    name: Build binaries - ${{ matrix.config.name }}
    if: ${{ !inputs.skip_binaries }}
    needs:
      - build
    # ... 其余配置

  release:
    name: Release
    if: |
      !inputs.skip_release &&
      needs.resolve-next-release.outputs.next-version != '' &&
      needs.resolve-next-release.outputs.next-version != 'false'
    # ... 其余配置
```

### 使用方法
1. 修改 `build.yml` 添加上述配置
2. 在GitHub Actions页面手动触发时，可以勾选选项
3. 推送commit时会运行完整流程

---

## 快速对比

| 方案 | 优点 | 缺点 | 推荐场景 |
|------|------|------|----------|
| **方案1: Commit消息** | 简单，无需UI操作 | 需要修改工作流 | 频繁测试 ⭐ |
| **方案2: Web手动触发** | 无需修改 | 无法选择性跳过 | 临时使用 |
| **方案3: 独立测试工作流** | 最灵活 | 需要额外文件 | 长期使用 ⭐⭐ |
| **方案4: 输入参数** | 灵活，可选择 | 修改现有流程 | 平衡方案 ⭐ |

---

## 当前情况建议

基于你的情况（刚修复了测试），我推荐：

### 立即操作（最快）
使用**方案2**：直接在GitHub网页上手动触发工作流

### 长期优化（推荐）
实施**方案1**：在build.yml中添加commit消息检查

```yaml
# 在 build-binaries job 添加：
if: "!contains(github.event.head_commit.message, '[skip-binaries]')"

# 在 release job 添加：
if: |
  !contains(github.event.head_commit.message, '[skip-release]') &&
  needs.resolve-next-release.outputs.next-version != '' &&
  needs.resolve-next-release.outputs.next-version != 'false'
```

然后以后测试时：
```bash
git commit -m "test: verify CI fixes [skip-binaries] [skip-release]"
```

需要我帮你实施其中某个方案吗？
