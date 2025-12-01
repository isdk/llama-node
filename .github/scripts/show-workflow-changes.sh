#!/bin/bash
# 此脚本展示如何在 workflow 中集成 APT 镜像源设置

echo "创建 workflow 补丁示例..."

cat > /tmp/workflow-mirror-patch-example.txt << 'EOF'
=== 如何修改 .github/workflows/build.yml ===

在每个 "Install dependencies on Ubuntu" 步骤中，
在 "sudo apt-get update" 之前添加镜像源设置。

修改前：
------
      - name: Install dependencies on Ubuntu (1)
        if: matrix.config.name == 'Ubuntu (1)'
        run: |
          sudo apt-get update
          sudo apt-get install ninja-build libtbb-dev g++-aarch64-linux-gnu

修改后：
------
      - name: Install dependencies on Ubuntu (1)
        if: matrix.config.name == 'Ubuntu (1)'
        run: |
          sudo bash .github/scripts/setup-apt-mirror-simple.sh
          sudo apt-get update
          sudo apt-get install ninja-build libtbb-dev g++-aarch64-linux-gnu

---

同样的修改应用到以下步骤：
1. "Install dependencies on Ubuntu (1)" (line ~110)
2. "Install dependencies on Ubuntu (2)" (line ~128)
3. "Install dependencies on ubuntu" in standalone-tests (line ~414)
4. "Install Vulkan SDK on Ubuntu" (line ~194) - 在 apt update 之前

EOF

cat /tmp/workflow-mirror-patch-example.txt
