#!/bin/bash
set -e

# Smart APT Mirror Selector
# 智能 APT 镜像选择器
# 逻辑：
# 1. 检测当前源速度。如果足够快（< 0.5s），则保持不变。
# 2. 从 mirrors.ubuntu.com/CN.txt 获取推荐列表（支持 HTTPS）。
# 3. 对候选源进行测速，应用最快的源。

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 正在初始化智能镜像选择器...${NC}"

# 获取系统代号 (e.g., jammy, focal)
if command -v lsb_release >/dev/null 2>&1; then
    CODENAME=$(lsb_release -cs)
else
    CODENAME=$(grep "VERSION_CODENAME=" /etc/os-release | cut -d= -f2)
    if [ -z "$CODENAME" ]; then
        CODENAME="jammy"
    fi
fi

echo -e "📋 系统版本: ${YELLOW}$CODENAME${NC}"

# 获取当前 sources.list 中的第一个主镜像 URL
# 提取完整 URL，例如 http://archive.ubuntu.com/ubuntu
CURRENT_MIRROR_URL=$(grep -E "^deb" /etc/apt/sources.list | head -n 1 | awk '{print $2}')
if [ -z "$CURRENT_MIRROR_URL" ]; then
    CURRENT_MIRROR_URL="http://archive.ubuntu.com/ubuntu/"
fi

# 确保 URL 以 / 结尾
[[ "${CURRENT_MIRROR_URL}" != */ ]] && CURRENT_MIRROR_URL="${CURRENT_MIRROR_URL}/"

# 测速函数 (返回秒数，超时返回 10)
test_speed() {
    local url=$1
    # 构造测试 URL: mirror_base_url/dists/codename/Release
    # 例如: https://mirrors.tuna.tsinghua.edu.cn/ubuntu/dists/jammy/Release
    local test_url="${url}dists/$CODENAME/Release"

    local time=$(curl -o /dev/null -s -w '%{time_starttransfer}' --connect-timeout 2 --max-time 3 "$test_url" || echo "10")
    echo "$time"
}

echo -e "⚡ 测试当前镜像源: ${YELLOW}$CURRENT_MIRROR_URL${NC}"
CURRENT_SPEED=$(test_speed "$CURRENT_MIRROR_URL")

# 阈值：0.5秒
THRESHOLD="0.5"

if (( $(echo "$CURRENT_SPEED < $THRESHOLD" | bc -l 2>/dev/null || awk -v s="$CURRENT_SPEED" -v t="$THRESHOLD" 'BEGIN {print (s < t)}') )); then
    echo -e "${GREEN}✅ 当前镜像源速度极快 ($CURRENT_SPEED s)，无需切换。${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  当前镜像源较慢 ($CURRENT_SPEED s)，开始寻找更快的镜像...${NC}"
fi

# 黑名单列表 (部分镜像虽然测速快但实际不可用或不稳定)
BLACKLIST=(
    "mirrors.dgut.edu.cn"
    "mirrors.jxust.edu.cn"
)

# 检查是否在黑名单中的函数
is_blacklisted() {
    local url=$1
    for bad in "${BLACKLIST[@]}"; do
        if [[ "$url" == *"$bad"* ]]; then
            return 0 # True, is blacklisted
        fi
    done
    return 1 # False
}

# --- 寻找更快的镜像 ---

CANDIDATES=()

# 1. 从 Ubuntu 官方 GeoIP 服务获取推荐镜像 (使用 CN.txt 获取中国镜像，包含 https)
echo -e "🌐 从 mirrors.ubuntu.com/CN.txt 获取推荐镜像..."
if curl -s --connect-timeout 3 http://mirrors.ubuntu.com/CN.txt > /tmp/ubuntu_mirrors.txt; then
    # 读取所有推荐镜像
    while IFS= read -r line; do
        # 忽略空行
        if [ -z "$line" ]; then continue; fi
        # 确保 URL 以 / 结尾
        [[ "${line}" != */ ]] && line="${line}/"

        # 检查黑名单
        if is_blacklisted "$line"; then
            # 仅在 verbose 模式或调试时显示，这里为了简洁忽略输出，或者打印一行日志
            # echo "   跳过黑名单镜像: $line"
            continue
        fi

        CANDIDATES+=("$line")
    done < /tmp/ubuntu_mirrors.txt
fi

# 2. 添加国内知名源作为保底 (使用完整 URL)
# 如果上面的列表获取失败，或者列表里没有这些源，这里作为补充
if ! is_blacklisted "https://mirrors.aliyun.com/ubuntu/"; then CANDIDATES+=("https://mirrors.aliyun.com/ubuntu/"); fi
if ! is_blacklisted "https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"; then CANDIDATES+=("https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"); fi
if ! is_blacklisted "https://mirrors.ustc.edu.cn/ubuntu/"; then CANDIDATES+=("https://mirrors.ustc.edu.cn/ubuntu/"); fi
if ! is_blacklisted "https://mirror.sjtu.edu.cn/ubuntu/"; then CANDIDATES+=("https://mirror.sjtu.edu.cn/ubuntu/"); fi

# 去重
IFS=" " read -r -a UNIQUE_CANDIDATES <<< "$(echo "${CANDIDATES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

FASTEST_MIRROR_URL=""
FASTEST_TIME=10

echo -e "🏎️  开始测速对比 (${#UNIQUE_CANDIDATES[@]} 个候选)..."

for mirror_url in "${UNIQUE_CANDIDATES[@]}"; do
    # 跳过空行
    if [ -z "$mirror_url" ]; then continue; fi

    # 提取域名用于显示
    display_name=$(echo "$mirror_url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

    printf "   %-35s " "$display_name"

    speed=$(test_speed "$mirror_url")

    # 忽略异常快的速度 (< 0.0001s)，通常意味着连接错误、立即被拒或无效响应
    is_too_fast=$(echo "$speed < 0.0001" | bc -l 2>/dev/null || awk -v s="$speed" 'BEGIN {print (s < 0.0001)}')
    if [ "$is_too_fast" -eq 1 ]; then
        printf "%.4fs (忽略: 异常)\n" "$speed"
        continue
    fi

    is_faster=$(echo "$speed < $FASTEST_TIME" | bc -l 2>/dev/null || awk -v s="$speed" -v t="$FASTEST_TIME" 'BEGIN {print (s < t)}')

    if [ "$is_faster" -eq 1 ]; then
        FASTEST_TIME=$speed
        FASTEST_MIRROR_URL=$mirror_url
        printf "${GREEN}%.4fs (当前最快)${NC}\n" "$speed"
    else
        printf "%.4fs\n" "$speed"
    fi
done

if [ -z "$FASTEST_MIRROR_URL" ]; then
    echo -e "${YELLOW}❌ 未能找到更快的镜像，保持原样。${NC}"
    exit 0
fi

echo -e "\n${GREEN}🏆 选定最佳镜像: $FASTEST_MIRROR_URL ($FASTEST_TIME s)${NC}"

# 备份并应用
if [ ! -f /etc/apt/sources.list.bak ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
fi

echo "📝 更新 /etc/apt/sources.list ..."
# 直接使用完整 URL，不需要再添加 http:// 前缀
cat > /etc/apt/sources.list << EOF
# Generated by smart-apt-mirror.sh
# Selected Mirror: $FASTEST_MIRROR_URL
# Speed: $FASTEST_TIME s

deb ${FASTEST_MIRROR_URL} $CODENAME main restricted universe multiverse
deb ${FASTEST_MIRROR_URL} $CODENAME-updates main restricted universe multiverse
deb ${FASTEST_MIRROR_URL} $CODENAME-backports main restricted universe multiverse
deb ${FASTEST_MIRROR_URL} $CODENAME-security main restricted universe multiverse
EOF

echo -e "${GREEN}✅ 镜像源已更新完成。${NC}"
