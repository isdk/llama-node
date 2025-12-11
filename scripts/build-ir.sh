#!/bin/bash
# 智能 IR 构建脚本 - 自动适配平台和编译器

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
IR_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../external/ir-sources" && pwd)"
IR_OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../llama/ir" && pwd)"
ENABLE_NATIVE="${ENABLE_NATIVE_OPTIMIZATION:-false}"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Smart LLVM IR Builder                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# 检测平台
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# 检测编译器
detect_compiler() {
    # 优先使用 clang++
    if command -v clang++ &> /dev/null; then
        echo "clang++"
        return 0
    elif command -v g++ &> /dev/null; then
        echo "g++"
        return 0
    fi
    return 1
}

# 获取编译器版本
get_compiler_version() {
    local compiler=$1
    $compiler --version | head -n 1
}

# 获取 STL 选项
get_stdlib_option() {
    local platform=$1
    local compiler=$2

    if [[ "$compiler" != "clang++" ]]; then
        echo ""
        return
    fi

    case "$platform" in
        linux)
            # Linux: 使用 libstdc++ 以兼容 GCC
            echo "-stdlib=libstdc++"
            ;;
        macos)
            # macOS: 使用 libc++
            echo "-stdlib=libc++"
            ;;
        windows)
            # Windows: 使用 libc++
            echo "-stdlib=libc++"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 获取优化标志
get_optimization_flags() {
    local enable_native=$1
    local arch=$(uname -m)

    if [[ "$enable_native" == "true" ]]; then
        echo "-march=native -mtune=native"
    else
        # 根据架构选择保守的优化
        case "$arch" in
            x86_64|amd64)
                echo "-march=x86-64 -mtune=generic"
                ;;
            aarch64|arm64)
                echo "-march=armv8-a"
                ;;
            armv7l)
                echo "-march=armv7-a"
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

# 主函数
main() {
    local platform=$(detect_platform)
    local compiler=$(detect_compiler)

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✗ Error: No C++ compiler found${NC}"
        echo "  Please install clang++ or g++"
        exit 1
    fi

    local compiler_version=$(get_compiler_version "$compiler")
    local stdlib_option=$(get_stdlib_option "$platform" "$compiler")
    local opt_flags=$(get_optimization_flags "$ENABLE_NATIVE")

    # 显示配置
    echo -e "${YELLOW}Platform:${NC}         $platform ($(uname -m))"
    echo -e "${YELLOW}Compiler:${NC}         $compiler"
    echo -e "${YELLOW}Version:${NC}          $compiler_version"
    echo -e "${YELLOW}STL:${NC}              ${stdlib_option:-default}"
    echo -e "${YELLOW}Optimization:${NC}     ${opt_flags:-none}"
    echo -e "${YELLOW}Native opt:${NC}       $ENABLE_NATIVE"
    echo ""

    # 检查源文件目录
    if [[ ! -d "$IR_SOURCE_DIR" ]]; then
        echo -e "${RED}✗ Error: Source directory not found: $IR_SOURCE_DIR${NC}"
        exit 1
    fi

    # 创建输出目录
    mkdir -p "$IR_OUTPUT_DIR"

    # 查找源文件
    local source_files=("$IR_SOURCE_DIR"/*.cpp)
    local file_count=0

    for file in "${source_files[@]}"; do
        if [[ -f "$file" ]]; then
            ((file_count++))
        fi
    done

    if [[ $file_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠ Warning: No .cpp files found in $IR_SOURCE_DIR${NC}"
        echo "  Create .cpp files there to compile them to IR"
        exit 0
    fi

    echo -e "${GREEN}Found $file_count source file(s)${NC}"
    echo ""

    # 编译每个源文件
    local success_count=0
    local fail_count=0

    for source_file in "${source_files[@]}"; do
        if [[ ! -f "$source_file" ]]; then
            continue
        fi

        local base_name=$(basename "$source_file" .cpp)
        local ir_bc_file="$IR_OUTPUT_DIR/${base_name}.bc"
        local ir_ll_file="$IR_OUTPUT_DIR/${base_name}.ll"

        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Building:${NC} $base_name"
        echo ""

        # 构建编译命令
        local compile_cmd=(
            "$compiler"
            -c -emit-llvm
            -O3 -fPIC
            $stdlib_option
            $opt_flags
            -fno-exceptions
            -fno-rtti
            -o "$ir_bc_file"
            "$source_file"
        )

        # 显示命令（美化）
        echo -e "${YELLOW}Command:${NC}"
        echo "  $compiler -c -emit-llvm -O3 -fPIC \\"
        [[ -n "$stdlib_option" ]] && echo "    $stdlib_option \\"
        [[ -n "$opt_flags" ]] && echo "    $opt_flags \\"
        echo "    -fno-exceptions -fno-rtti \\"
        echo "    -o $ir_bc_file \\"
        echo "    $source_file"
        echo ""

        # 执行编译
        if "${compile_cmd[@]}" 2>&1; then
            echo -e "${GREEN}✓ Generated IR:${NC} $ir_bc_file"

            # 生成人类可读的 IR
            if command -v llvm-dis &> /dev/null; then
                llvm-dis "$ir_bc_file" -o "$ir_ll_file" 2>/dev/null
                echo -e "${GREEN}✓ Generated LL:${NC} $ir_ll_file"
            fi

            # 显示文件大小
            local bc_size=$(du -h "$ir_bc_file" | cut -f1)
            echo -e "${YELLOW}Size:${NC} $bc_size"

            ((success_count++))
        else
            echo -e "${RED}✗ Failed to compile $base_name${NC}"
            ((fail_count++))
        fi

        echo ""
    done

    # 总结
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Build Summary${NC}"
    echo -e "  Success: ${GREEN}$success_count${NC}"
    [[ $fail_count -gt 0 ]] && echo -e "  Failed:  ${RED}$fail_count${NC}"
    echo ""

    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}✓ IR files ready in:${NC} $IR_OUTPUT_DIR"
        echo ""
        echo "Next steps:"
        echo "  1. Build the addon: pnpm run build"
        echo "  2. Compile addon: node ./dist/cli/cli.js source build"
        echo "  3. Test from Node.js"
    fi

    if [[ $fail_count -gt 0 ]]; then
        exit 1
    fi
}

# 运行
main "$@"
