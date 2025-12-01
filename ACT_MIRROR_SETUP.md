# Act APT 镜像源智能配置指南

本文档说明如何在使用 `act` 运行 GitHub Actions 时，自动配置最适合当前网络环境的 APT 镜像源。

## 核心策略：智能测速与按需切换

为了同时兼容 GitHub Actions 云环境（海外，速度快）和本地 `act` 运行环境（国内，需要镜像），我们采用以下策略：

1.  **优先检测当前源速度**：脚本首先测试当前配置的镜像源（通常是 `archive.ubuntu.com` 或 Azure 镜像）。
    *   如果响应时间 **< 0.5秒**，判定为云环境或网络状况良好，**保持原样，不进行任何修改**。这避免了在 GitHub Actions 上因切换到外部镜像而导致的性能下降。
2.  **自动获取候选镜像**：如果当前源较慢，脚本会从 Ubuntu 官方服务 `mirrors.ubuntu.com` 获取推荐镜像列表，并加入国内知名源（阿里云、清华、中科大等）作为候选。
3.  **并发测速优选**：对候选镜像进行实际连接测试，选择响应最快的一个替换 `/etc/apt/sources.list`。

## 实现方式

### 1. 脚本逻辑

脚本位于 `.github/scripts/setup-apt-mirror.sh`。它不依赖复杂的外部工具（如 `netselect`），仅使用 `curl` 和基础 Shell 命令，确保兼容性。

### 2. Workflow 集成

在 `.github/workflows/build.yml` 中，我们在所有 `apt-get update` 之前调用该脚本：

```yaml
- name: Install dependencies on Ubuntu
  run: |
    # 智能设置最快镜像源（仅在当前源慢时生效）
    sudo bash .github/scripts/setup-apt-mirror.sh || true

    sudo apt-get update
    sudo apt-get install ...
```

## 如何测试

### 本地测试

在项目根目录运行测试脚本：

```bash
./test-apt-mirror-setup.sh
```

### Docker 环境测试

模拟真实的 `act` 运行环境：

```bash
./test-docker-mirror.sh
```

### Act 运行

直接运行 act，观察输出：

```bash
act -j build-binaries --verbose
```

在日志中，你应该能看到类似以下的输出：

*   **在 GitHub Actions 上**：
    ```
    ⚡ 测试当前镜像源: azure.archive.ubuntu.com
    ✅ 当前镜像源速度极快 (0.052s)，无需切换。
    ```

*   **在本地 (中国) 上**：
    ```
    ⚡ 测试当前镜像源: archive.ubuntu.com
    ⚠️  当前镜像源较慢 (5.231s)，开始寻找更快的镜像...
    🌐 从 mirrors.ubuntu.com 获取推荐镜像...
    🏎️  开始测速对比 (8 个候选)...
       mirrors.aliyun.com                  0.123s (当前最快)
       mirrors.tuna.tsinghua.edu.cn        0.156s
       ...
    🏆 选定最佳镜像: mirrors.aliyun.com (0.123s)
    📝 更新 /etc/apt/sources.list ...
    ✅ 镜像源已更新完成。
    ```

## 维护

如果需要添加更多的候选源，可以直接编辑 `.github/scripts/setup-apt-mirror.sh` 中的 `CANDIDATES` 数组。
