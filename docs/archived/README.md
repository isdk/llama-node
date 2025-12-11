# 归档的开发文档

本目录包含已整合到主要贡献指南（`CONTRIBUTING.md`）中的历史文档。

## 📦 归档文件

### CI测试修复文档（2025-12-02）

这些文档记录了修复GitHub Actions CI测试失败的过程：

- **CI_FIXES_COMPLETE_CHECKLIST.md** - 7个CI错误的完整修复清单
- **CI_TEST_FAILURES_ANALYSIS.md** - 初始问题分析（超时+快照不匹配）
- **CI_TEST_FIXES_ROUND2.md** - 第二轮修复（Auto模式降级问题）
- **CI_TEST_FIXES_SUMMARY.md** - 第一轮修复总结
- **fix-ci-snapshot-tests.md** - 快照测试修复指南

**核心要点**（已整合到CONTRIBUTING.md）:
- ✅ 避免硬编码快照值（使用范围检查）
- ✅ 考虑环境差异（llama.cpp版本、虚拟化、架构）
- ✅ Auto模式需考虑CPU降级场景
- ✅ 嵌套describe需显式设置超时

### GitHub Actions文档

- **HOW_TO_RUN_TESTS_ONLY.md** - 如何只运行测试，跳过二进制构建

**已整合**: commit消息标记功能现在在CONTRIBUTING.md和`.github/RUN_TESTS_ONLY.md`中说明

---

## 🔗 当前文档结构

主要文档（活跃使用）：
- `CONTRIBUTING.md` - 主要贡献指南（整合所有开发信息）
- `ACT_TESTING.md` - 详细的本地测试指南
- `dev.md` - 技术笔记和架构分析
- `.github/RUN_TESTS_ONLY.md` - 命令快速参考

---

## 📚 为什么归档？

这些文档的内容已经被**提炼和整合**到`CONTRIBUTING.md`中：
- 新贡献者只需阅读一个文档
- 减少文档冗余和维护负担
- 保留历史作为参考

归档而非删除的原因：
- 保留详细的问题解决过程
- 可作为未来类似问题的参考
- 记录项目演进历史

---

## 💡 需要这些信息？

请先查看 `CONTRIBUTING.md` 中对应的章节：
- **测试** → "测试"部分
- **CI修复** → "CI测试修复参考"部分
- **GitHub Actions** → "GitHub Actions工作流"部分

如果需要更详细的历史背景，可以参考本目录中的文档。

---

**最后更新**: 2025-12-02
