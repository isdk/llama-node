#!/bin/bash
set -e

# 简化版 APT 镜像源设置脚本（不需要 bc 命令）
# 直接使用预设的国内镜像源

echo "🔍 检测系统信息..."
DISTRO=$(lsb_release -rs 2>/dev/null || echo "22.04")
CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")

echo "📋 系统版本: Ubuntu $DISTRO ($CODENAME)"

# 允许通过环境变量设置首选镜像
PREFERRED_MIRROR="${APT_MIRROR:-mirrors.aliyun.com}"

echo "🚀 使用镜像源: $PREFERRED_MIRROR"
echo ""

# 备份原有配置
if [ ! -f /etc/apt/sources.list.bak ]; then
    echo "💾 备份原有配置到 /etc/apt/sources.list.bak"
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
fi

# 生成新的 sources.list
echo "📝 配置新的镜像源..."
cat > /etc/apt/sources.list << EOF
# 由 setup-apt-mirror-simple.sh 自动生成
# 镜像源: $PREFERRED_MIRROR
# 生成时间: $(date)

deb http://$PREFERRED_MIRROR/ubuntu/ $CODENAME main restricted universe multiverse
deb http://$PREFERRED_MIRROR/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb http://$PREFERRED_MIRROR/ubuntu/ $CODENAME-backports main restricted universe multiverse
deb http://$PREFERRED_MIRROR/ubuntu/ $CODENAME-security main restricted universe multiverse

# deb-src http://$PREFERRED_MIRROR/ubuntu/ $CODENAME main restricted universe multiverse
# deb-src http://$PREFERRED_MIRROR/ubuntu/ $CODENAME-updates main restricted universe multiverse
# deb-src http://$PREFERRED_MIRROR/ubuntu/ $CODENAME-backports main restricted universe multiverse
# deb-src http://$PREFERRED_MIRROR/ubuntu/ $CODENAME-security main restricted universe multiverse
EOF

echo "✅ 镜像源配置完成！"
echo ""
echo "可用的镜像源选项："
echo "  - mirrors.aliyun.com (阿里云，默认)"
echo "  - mirrors.tuna.tsinghua.edu.cn (清华)"
echo "  - mirrors.ustc.edu.cn (中科大)"
echo "  - repo.huaweicloud.com (华为云)"
echo ""
echo "使用方式: APT_MIRROR=mirrors.tuna.tsinghua.edu.cn sudo -E bash $0"
