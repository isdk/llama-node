# 工作流Skip标记说明

## 完整逻辑

当在commit消息中使用 `[skip-binaries]` 或 `[skip-build]` 时：

### ✅ 会运行的Job

1. **build** - TypeScript编译
   - 时间: ~5分钟
   - 产出: `dist/` 目录

2. **standalone-tests** - 独立测试
   - 时间: ~3分钟
   - 依赖: build

3. **model-dependent-tests** - 模型测试
   - 时间: ~7分钟
   - 依赖: build

4. **resolve-next-release** - 解析下一个版本号
   - 时间: ~2分钟
   - 依赖: build
   - 仅在main/beta分支运行

### ❌ 会跳过的Job

1. **build-binaries** - 编译6个平台的二进制文件
   - 原本时间: ~90分钟
   - 原因: commit消息包含 `[skip-binaries]` 或 `[skip-build]`

2. **release** - 发布到npm
   - 原本时间: ~15分钟
   - 原因: **需要二进制文件才能发布**
   - 逻辑: 如果跳过了binaries，也必须跳过release

## 对比表

| 场景 | build | binaries | tests | release | 总时间 |
|------|-------|----------|-------|---------|--------|
| **普通commit** | ✅ | ✅ (90分钟) | ✅ | ✅ (如果有版本) | ~2小时 |
| **`[skip-binaries]`** | ✅ | ❌ | ✅ | ❌ | ~10分钟 |
| **`[skip ci]`** | ❌ | ❌ | ❌ | ❌ | 0分钟 |

## 工作流配置

### build-binaries Job

```yaml
build-binaries:
  if: "!contains(github.event.head_commit.message, '[skip-binaries]') &&
       !contains(github.event.head_commit.message, '[skip-build]')"
```

### release Job

```yaml
release:
  if: |
    !contains(github.event.head_commit.message, '[skip-binaries]') &&
    !contains(github.event.head_commit.message, '[skip-build]') &&
    needs.resolve-next-release.outputs.next-version != '' &&
    needs.resolve-next-release.outputs.next-version != 'false'
```

**重要**: release Job 依赖 build-binaries 的输出（bins目录），所以：
- 如果跳过binaries → 必须跳过release
- 否则release会失败（找不到二进制文件）

## 使用场景

### 场景1: 测试修复验证

```bash
git commit -m "test: fix CI snapshot tests [skip-binaries]"
git push
```

**结果**: ✅ 快速验证测试是否通过（~10分钟）

### 场景2: 文档更新

```bash
git commit -m "docs: update README [skip ci]"
git push
```

**结果**: ✅ 完全跳过CI

### 场景3: 正式发布

```bash
git commit -m "feat: add new feature"
git push
```

**结果**: ✅ 完整流程（~2小时，如果语义化版本判定需要发布）

## 标记参考

| 标记 | 效果 |
|------|------|
| `[skip-binaries]` | 跳过binaries + release |
| `[skip-build]` | 跳过binaries + release（同上） |
| `[skip ci]` | 跳过整个工作流（GitHub默认） |
| `[ci skip]` | 跳过整个工作流（GitHub默认） |

## 注意事项

1. **标记位置**: 可以放在commit消息任何位置
   ```bash
   git commit -m "[skip-binaries] test: quick test"
   git commit -m "test: quick test [skip-binaries]"
   ```

2. **PR检查**: PR不受skip标记影响，总是运行完整流程

3. **手动触发**: 通过GitHub Actions UI手动触发时，无法使用commit标记

4. **多个标记**: 可以组合（虽然没必要）
   ```bash
   git commit -m "test: updates [skip-binaries] [skip ci]"  # skip ci会阻止所有
   ```

---

**最佳实践**:
开发测试时使用 `[skip-binaries]`，正式发布前移除标记跑完整流程。
