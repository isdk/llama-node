#!/bin/bash
# 测试 llc 的 CPU 优化能力

set -e

echo "=== Testing llc CPU-specific optimization ==="
echo ""

# 获取当前 CPU 型号
HOST_CPU=$(llc --version 2>&1 | grep "Host CPU" | awk '{print $3}')
echo "Detected Host CPU: $HOST_CPU"
echo ""

# 创建测试代码
cat > /tmp/test_cpu_opt.cpp << 'EOF'
#include <cmath>

// 向量点积（适合 SIMD 优化）
extern "C" float dot_product(const float* a, const float* b, size_t len) {
    float sum = 0.0f;
    #pragma clang loop vectorize(enable)
    for (size_t i = 0; i < len; i++) {
        sum += a[i] * b[i];
    }
    return sum;
}

// 矩阵乘法
extern "C" void matrix_mul(const float* a, const float* b, float* c, size_t n) {
    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) {
            float sum = 0.0f;
            for (size_t k = 0; k < n; k++) {
                sum += a[i * n + k] * b[k * n + j];
            }
            c[i * n + j] = sum;
        }
    }
}
EOF

echo "Step 1: 生成通用 IR"
clang++ -c -emit-llvm -O3 -fPIC -o /tmp/test_generic.bc /tmp/test_cpu_opt.cpp
echo "✓ Generated IR"
echo ""

echo "Step 2a: llc 编译（通用 x86-64）"
llc -O3 -filetype=obj -o /tmp/test_generic.o /tmp/test_generic.bc
llc -O3 -filetype=asm -o /tmp/test_generic.s /tmp/test_generic.bc
echo "✓ Generated generic object file"
echo ""

echo "Step 2b: llc 编译（针对当前 CPU: $HOST_CPU）⭐"
llc -mcpu=$HOST_CPU -O3 -filetype=obj -o /tmp/test_native.o /tmp/test_generic.bc
llc -mcpu=$HOST_CPU -O3 -filetype=asm -o /tmp/test_native.s /tmp/test_generic.bc
echo "✓ Generated CPU-optimized object file"
echo ""

echo "Step 3: 对比汇编代码"
echo ""
echo "--- Generic version (x86-64) ---"
grep -A 15 "dot_product:" /tmp/test_generic.s | head -20
echo ""

echo "--- CPU-optimized version ($HOST_CPU) ---"
grep -A 15 "dot_product:" /tmp/test_native.s | head -20
echo ""

echo "Step 4: 检查 SIMD 指令使用"
echo ""
echo "Generic version SIMD instructions:"
grep -E "(vmov|vadd|vmul|vfma|xmm|ymm|zmm)" /tmp/test_generic.s | head -5 || echo "  No advanced SIMD found"
echo ""

echo "CPU-optimized version SIMD instructions:"
grep -E "(vmov|vadd|vmul|vfma|xmm|ymm|zmm)" /tmp/test_native.s | head -5 || echo "  No advanced SIMD found"
echo ""

echo "Step 5: 文件大小对比"
ls -lh /tmp/test_generic.o /tmp/test_native.o
echo ""

echo "Step 6: 查看 llc 支持的 CPU 列表"
echo ""
echo "Available CPUs for x86-64:"
llc -march=x86-64 -mcpu=help 2>&1 | grep -E "(znver|skylake|haswell|native)" | head -10
echo ""

echo "=== 总结 ==="
echo "✓ llc 支持 -mcpu=<cpu_name> 针对特定 CPU 优化"
echo "✓ 当前 CPU: $HOST_CPU"
echo "✓ 使用方法: llc -mcpu=$HOST_CPU -O3 -filetype=obj -o output.o input.bc"
echo ""
echo "注意："
echo "  - llc 不支持 -march=native"
echo "  - 但支持 -mcpu=<具体CPU型号>"
echo "  - 可以用 llc --version 查看 Host CPU"
