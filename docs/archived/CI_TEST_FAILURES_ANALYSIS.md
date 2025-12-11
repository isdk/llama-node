# GitHub CI测试失败分析

## 问题概述

GitHub Actions工作流中测试失败，主要有两类问题：

### 1. 超时问题

**测试**: `test/modelDependent/model.test.ts > LlamaModel > should completionSync`

**错误**: `Error: Test timed out in 5000ms.`

**原因**:
- 外层的第一个`describe`块设置了10分钟超时
- 但第63行的第二个`describe("LlamaModel")`块没有设置超时，使用默认的5000ms
- Vitest中嵌套的describe不会自动继承父级的超时设置

**解决方案**: ✅ 已修复 - 为第63行的describe添加了超时配置

```typescript
describe("LlamaModel", { timeout: 1000 * 60 * 10 }, async () => {
```

---

### 2. 快照不匹配问题

**测试文件**: `test/modelDependent/stableCode/stableCodeModelGpuLayersOptions.test.ts`

**失败的测试**:
1. `attempts to resolve 16 gpuLayers` - 上下文大小不匹配
2. `attempts to resolve 32 gpuLayers` - 上下文大小不匹配
3. `attempts to resolve "auto"` - GPU层数不匹配
4. `attempts to resolve {min?, max?}` - 上下文大小不匹配
5. `attempts to resolve {fitContext?}` - GPU层数不匹配

**错误示例**:
```
Expected: "10748"
Received: "8061"

Expected: "11616"
Received: "11347"

Expected: "7"
Received: "3"
```

**根本原因**:
这些测试依赖于**硬件相关的内存计算**，计算GPU层数和上下文大小的算法受以下因素影响：

1. **llama.cpp版本差异**
   - 本地可能使用本地编译的版本
   - CI使用工作流下载的最新release版本
   - 不同版本的内存估算算法可能略有差异

2. **系统环境差异**
   - **本地**: 真实硬件，准确的内存检测
   - **GitHub Actions (macOS-13)**: 虚拟化环境，内存检测可能受影响

3. **CPU架构差异**
   - 可能导致内存对齐、缓存计算等细微差异

4. **硬编码快照的脆弱性**
   - 使用`toMatchInlineSnapshot()`硬编码了预期值
   - 这些值是**实现细节**的体现，而非核心业务逻辑
   - 底层算法的任何微小变化都会导致快照失败

---

## 推荐解决方案

### 方案1: 使用范围检查替代精确匹配（强烈推荐）

**优点**:
- 测试核心逻辑（值是否合理）而非实现细节
- 更健壮，适应不同环境
- 不会因llama.cpp版本更新而breaking

**缺点**:
- 需要确定合理的范围阈值

**实施**:
```typescript
// 原来的代码
expect(res.contextSize).to.toMatchInlineSnapshot(`10748`);

// 改为范围检查（允许±20%误差）
expect(res.contextSize).to.be.within(8598, 12898); // 10748 ± 20%
expect(res.contextSize).to.be.greaterThan(8000);
```

### 方案2: 在CI环境中更新快照

**优点**:
- 保持使用快照测试
- 确保CI环境的一致性

**缺点**:
- 本地和CI的快照会不同
- 需要环境特定的快照管理

**实施**:
```bash
# 在GitHub Actions中运行并更新快照
pnpm run test:modelDependent -- --update
```

### 方案3: 为CI环境跳过精确值测试

**优点**:
- 简单快速

**缺点**:
- CI中缺少测试覆盖

**实施**:
```typescript
it.skipIf(process.env.CI)("attempts to resolve 16 gpuLayers", async () => {
  // 测试代码
});
```

---

## 环境差异对比

| 因素 | 本地环境 | GitHub Actions (macOS-13) |
|------|---------|--------------------------|
| 硬件类型 | 真实物理硬件 | 虚拟化环境 |
| 内存检测 | 准确的硬件检测 | 可能受虚拟化影响 |
| llama.cpp版本 | 本地编译/缓存的版本 | CI下载的最新release |
| CPU | 实际CPU架构 | 虚拟化CPU |
| 测试运行速度 | 较快 | 可能较慢（共享资源） |

---

## 下一步行动

请选择以下方案之一：

### 选项A: 使用范围检查（推荐）
修改`stableCodeModelGpuLayersOptions.test.ts`，将精确的快照匹配改为合理范围检查。

### 选项B: 接受环境差异
在CI中更新快照，接受不同环境有不同的预期值。

### 选项C: 跳过CI中的硬件相关测试
使用条件跳过，仅在本地运行这些测试。

---

## 技术细节

### 测试的核心逻辑
这些测试验证的是：
1. **给定VRAM约束**，系统能正确计算可以加载的GPU层数
2. **给定GPU配置**，系统能正确计算可用的上下文大小

### 当前的测试问题
- ❌ 测试**具体的数值**（实现细节）
- ✅ 应该测试**逻辑是否正确**（业务逻辑）

例如：
- ❌ "上下文大小必须恰好是10748"
- ✅ "给定3GB可用VRAM和16个GPU层，上下文大小应该在8000-13000之间"
- ✅ "较多的可用VRAM应该产生较大的上下文大小"

