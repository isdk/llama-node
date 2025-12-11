#!/bin/bash
# 生成 LLVM IR 的测试脚本

set -e

echo "=== Testing Clang++ IR with libstdc++ ==="

# 检查 clang++ 是否可用
if ! command -v clang++ &> /dev/null; then
    echo "Error: clang++ not found"
    exit 1
fi

# 检查 llc 是否可用
if ! command -v llc &> /dev/null; then
    echo "Error: llc not found"
    exit 1
fi

SOURCE_FILE="test_external_lib.cpp"
IR_FILE="test_external_lib.bc"
OBJ_FILE="test_external_lib.o"

echo ""
echo "Step 1: Compiling C++ to LLVM IR with libstdc++..."
clang++ -c -emit-llvm -O3 -fPIC \
    -stdlib=libstdc++ \
    -fno-exceptions \
    -fno-rtti \
    -o "$IR_FILE" \
    "$SOURCE_FILE"

echo "✓ Generated $IR_FILE"

echo ""
echo "Step 2: Converting IR to human-readable format..."
llvm-dis "$IR_FILE" -o "${IR_FILE%.bc}.ll"
echo "✓ Generated ${IR_FILE%.bc}.ll"

echo ""
echo "Step 3: Checking for STL symbols..."
if grep -q "std::" "${IR_FILE%.bc}.ll"; then
    echo "✓ Found STL symbols (libstdc++):"
    grep "std::" "${IR_FILE%.bc}.ll" | head -5
else
    echo "✓ No STL symbols in IR (functions were inlined)"
fi

echo ""
echo "Step 4: Compiling IR to object file..."
llc -filetype=obj -O3 -o "$OBJ_FILE" "$IR_FILE"
echo "✓ Generated $OBJ_FILE"

echo ""
echo "Step 5: Examining object file symbols..."
echo "Exported symbols:"
nm "$OBJ_FILE" | grep " T " || echo "  (none)"

echo ""
echo "Step 6: Checking object file size..."
ls -lh "$OBJ_FILE"

echo ""
echo "=== Test completed successfully! ==="
echo ""
echo "Files generated:"
echo "  - $IR_FILE (binary IR)"
echo "  - ${IR_FILE%.bc}.ll (human-readable IR)"
echo "  - $OBJ_FILE (object file)"
echo ""
echo "Next steps:"
echo "  1. Add $IR_FILE to llama/CMakeLists.txt"
echo "  2. Build the addon: pnpm run build && node ./dist/cli/cli.js source build"
echo "  3. Test the functions from Node.js"
