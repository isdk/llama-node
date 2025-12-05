# dev

src/evaluator/LlamaModel/LlamaModel.ts
src/evaluator/LlamaContext/LlamaContext.ts
src/evaluator/LlamaChatSession/LlamaChatSession.ts
src/evaluator/LlamaChat/LlamaChat.ts
generateResponse
src/evaluator/LlamaCompletion.ts

## 分析

* 模型Load: `model = await llama.loadModel({modelPath})`,看看可以配置哪些参数在这里
  * 参阅: `LlamaModelOptions` in `src/evaluator/LlamaModel/LlamaModel.ts`
  * `modelPath`
  * `gpuLayers`: 默认为"auto"
    * "auto",
    * "max": 尝试装入所有layers in VRAM, 如果VRAM不够将触发异常
    * `number`
    * `{min?: number, max?: number, fitContext?: {contextSize: number}}`
      * 适应当前的 VRAM 状态，并尝试在其中容纳尽可能多的层，但至少是最小层数和最多层数。将 `fitContext` 设置为你打算使用模型创建的上下文的参数，这样它就会在计算中考虑它，并为这样的上下文留下足够的内存。
  * `vocabOnly` 仅加载词汇表，而不加载权重张量。
  * `useMmap`: 使用 mmap（内存映射文件）加载模型。如果当前系统支持，则默认为 true。
  * `useMlock`: 强制系统将模型保留在 RAM/VRAM 中。请谨慎使用，因为如果可用资源不足，这可能会导致系统崩溃。
  * `checkTensors`: 在实际加载模型之前检查张量有效性。使用会增加加载模型所需的时间。默认为 false。
  * `defaultContextFlashAttention`: 默认情况下，为使用此模型创建的上下文启用 Flash 注意。仅适用于支持 Flash 注意的型号。对 flash attention 的支持目前处于试验阶段，可能并不总是按预期工作。请谨慎使用。默认为 false。
    * 如果模型不支持，则此选项将被忽略。
  * `onLoadProgress`: 在加载模型时使用负载百分比的回调`(loadProgress: number)=>void`, `loadProgress` 介于 0 （不包括） 和 1 （包括 0） 和 1 （包括） 之间的数字。
  * `loadSignal: AbortSignal`: 用于中止模型加载的 abort 信号
  * `ignoreMemorySafetyChecks`: 忽略内存不足错误并继续模型加载。如果没有足够的 VRAM 来拟合模型，可能会导致进程崩溃。默认为 false。
  * `metadataOverrides`: 用于加载模型的元数据覆盖。
* `content = await model.createContext({contextSize: 4096})` 这里也有参数 `上下文`
  * 参阅： `LlamaContextOptions` in `src/evaluator/LlamaContext/types.ts`
  * `sequences: number`: 默认值为 1。
    * 上下文的序列数。每个序列都是一个不同的 “文本生成过程”，可以与同一上下文中的其他序列并行运行。尽管单个上下文具有多个序列，但这些序列彼此独立，并且不会彼此共享数据。这对性能有益，因为可以并行评估多个序列（在同一批次上）。
    * 每个序列都会增加上下文的内存使用量。
  * `contextSize: number|"auto"|{min?: number, max?: number}`: 默认为 “auto”。
    * “auto” - 适应当前的 VRAM 状态，并尝试将上下文大小设置为尽可能高的大小，直到达到训练模型的大小。
    * Number - 将上下文大小设置为特定数量的令牌。如果 VRAM 不足，将引发错误。请谨慎使用。
    * {min？： number， max？： number} - 适应当前 VRAM 状态并尝试将上下文大小设置为尽可能高的大小，直到训练模型的大小，但至少是最小值和最大值。
  * `batchSize: number`: GPU 一次可以处理的令牌数。默认为 512，如果 contextSize 小于 512，则默认为 contextSize。
  * `flashAttention: boolean`: Flash 注意是注意力机制中的一种优化，它使推理更快、更高效，并且使用更少的内存。
    * 如果模型不支持，则此选项将被忽略。
    * 默认为 false （继承自模型选项 defaultContextFlashAttention）。
  * `threads: number|{ ideal: number; min: number; }`: 用于评估令牌的线程数。设置为 0 以使用当前计算机硬件支持的最大线程数。
    * 此值被视为提示，当其他评估正在运行时，实际使用的线程数可能会较低。要确保始终使用要使用的最小线程数，请将其设置为具有 `min` 属性的对象
    * 如果 Llama 实例的 `maxThreads` 设置为 0，则此值将始终是实际使用的线程数。
    * 如果 Llama 实例的 `maxThreads` 设置为 0，则默认为 Llama 实例的 `.cpuMathCores` 值，否则默认为 Llama 实例的 `maxThreads`（有关详细信息，请参阅 `getLlama` 方法的 `maxThreads` 选项）。
  * `batching: BatchingOptions`: 控制并行序列处理行为。
    * `dispatchSchedule: "nextCycle"|CustomBatchingDispatchSchedule`: 该策略用于在有待处理的项目时分派要处理的项目。默认为 “nextCycle”。
    * `itemPrioritizationStrategy:  "maximumParallelism"|"firstInFirstOut"|CustomBatchingPrioritizationStrategy`: 该策略用于确定要处理的待处理项目的优先级。
      * “maximumParallelism” - 尽可能并行地处理许多不同的序列。默认为 “maximumParallelism”。
      * “firstInFirstOut” - 按添加顺序处理项目。
  * `lora: string|{ adapters: { filePath: string; scale: number; }[]; onLoadProgress: void; }`
    * 将提供的 LoRA 适配器加载到上下文中。LoRA 适配器用于修改预训练模型的权重，以适应新的任务或领域，而无需从头开始进行大量的重新训练。
    * 如果提供了字符串，则将其视为单个 LoRA 适配器文件的路径。
  * `createSignal: AbortSignal`: 用于中止上下文创建的 abort 信号
  * `ignoreMemorySafetyChecks: boolean`: 忽略内存不足错误并继续创建上下文。如果新上下文没有足够的 VRAM，可能会导致进程崩溃。默认为 false。
  * `failedCreationRemedy: false|{ retries: number; autoContextSizeShrink: number | (contextSize: number) => number; }`
    * 在创建失败的上下文时，使用较小的上下文大小重试创建。
    * 仅当 contextSize 设置为 “auto” 时有效，保留为默认值或设置为具有 min 和/或 max 属性的对象。
    * 将 retries 设置为 false 以禁用。
  * `performanceTracking`: 跟踪上下文的推理性能，因此使用 .printTimings（） 将起作用。默认为 false。
    * 好像是直接调用llama.cpp的内部过程打印信息。
* `contextSequence = context.getSequence();` `上下文序列`,用于保存`推理`状态产生的Tokens的隔离组件。`evaluate`（推理）将“追加”到该状态的令牌构建，您可以使用 .contextTokens 访问当前状态token, 也就是说当前上下文推理产生的tokens保存在这里。
* 消息生成,系统模板通过派生： `ChatWrapper`
* 它提了一个新思路，为了避免用户伪造系统提示，通过构建`LlamaText`,`SpecialTokensText`，延后token化，这样，普通文本不会将其中的特殊tag名称作为token（`SpecialTokensText`）,具体实现在`model.tokenize()`
  * `model.tokenize("<system>some text", specialTokens=false)`, 第二参数就控制tokenize是否生成特殊token.
    * 参考 https://node-llama-cpp.withcat.ai/guide/tokens
    * 其实是调用 llama.cpp 本来就有的功能: `common_tokenize(vocab, text, add_special, parse_special)`:
      * add_special 始终 false, 有这个`parse_special` 控制是否处理特殊token.
  * 这样看来，我可以完全绕开它的 `ChatWrapper` 这套。
    * 好像不行，`src/evaluator/LlamaChat/LlamaChat.ts` 以及 `GenerateResponseState` 内部都使用了`ChatWrapper`,必须自定义一个`ChatWrapper`传入，不使用`chatWrapper: "auto"`
    * 需要参考 [LlamaChatSession](https://node-llama-cpp.withcat.ai/guide/chat-session) in `src/evaluator/LlamaChatSession/LlamaChatSession.ts` 进行修改自己的类来使用 [LlamaChat](https://node-llama-cpp.withcat.ai/guide/external-chat-state)
      * 使用 `ChatWrapper` 将系统提示信息插入聊天记录的第一项。
      * `LlamaChatSession` 用户管理聊天记录以及聊天状态
    * https://node-llama-cpp.withcat.ai/guide/chat-wrapper 参考这里简单的例子可以改，传入的历史是我的格式。
      * 然后将其转为 LlamaText 格式即可。
  * 我方案是在字符串中启用`\0`包裹的字符串作为 `pure text` 不能有`special_token`, 而在其外的则可以用。
  * 这可以在formatPrompt的时候将消息内容文字进行处理: 转义内容中的“`\0`”，将内容用`\0`包裹后再进行格式化。

## Build System

### llama.cpp Version Management

项目使用以下机制管理 llama.cpp 的版本：

#### 版本固定位置

1. **`llama/binariesGithubRelease.json`**（主要版本控制文件）
   - 存储当前使用的 llama.cpp release 标签
   - **已提交到 git** 仓库
   - 内容示例：`{"release": "latest"}` 或 `{"release": "b1234"}`
   - 通过 `src/bindings/utils/binariesGithubRelease.ts` 读写

2. **`llama/llama.cpp.info.json`**（详细版本信息）
   - 存储详细的版本信息（repo、具体 tag/commit hash、克隆时间等）
   - **被 gitignore**，在构建时动态生成
   - 包含 llama.cpp 仓库的完整元数据

3. **`llama/llama.cpp/.git`**（源码仓库）
   - 实际的 llama.cpp git 仓库
   - **被 gitignore**，在构建时下载/克隆
   - 通过 `git rev-parse HEAD` 获取精确的 commit hash

4. **`src/config.ts`**（配置入口）
   ```typescript
   // 第 40 行
   export const builtinLlamaCppRelease = await getBinariesGithubRelease();
   ```

#### GitHub Actions 工作流参数

`.github/workflows/build.yml` 使用三个正交的 choice 参数控制构建流程：

**binary_mode（二进制构建模式）**：
- `skip` - 跳过构建（仅测试）
- `build` ⭐ - 正常构建（使用缓存）
- `force_rebuild` - 强制重新构建（忽略缓存）

**release_mode（发布模式）**：
- `skip` - 跳过发布
- `normal` ⭐ - 正常发布（已存在版本跳过）
- `force_republish` - 强制重新发布（覆盖已存在版本）

**test_mode（测试模式）**：
- `all` ⭐ - 运行所有测试
- `standalone` - 仅 standalone 测试
- `model_dependent` - 仅 model dependent 测试
- `skip` - 跳过所有测试

> ⭐ 表示默认值

**参数设计原则**：
- **正交性**：每个维度独立选择，不会互相冲突
- **无歧义**：每个选项的行为明确
- **灵活组合**：可根据需要自由组合

**常用场景**：

| 场景 | binary_mode | release_mode | test_mode |
|------|-------------|--------------|-----------|
| 完整发布 | `build` | `normal` | `all` |
| 仅测试 | `skip` | `skip` | `all` |
| 修复 prebuilt | `build` | `force_republish` | `skip` |
| 强制重建发布 | `force_rebuild` | `force_republish` | `all` |

#### GitHub Actions 构建缓存策略

在 `.github/workflows/build.yml` 中，我们使用以下策略来缓存预构建的二进制文件：

**缓存键组成**（第 129-163 行）：
```yaml
- name: Get llama.cpp version for cache
  id: llama-cpp-version
  shell: bash
  run: |
    # Use tag/release name instead of commit hash for cache key
    # Commit hash changes after squash even if content is identical
    # Tag is stable and doesn't change

    # First, try to get tag from llama.cpp.info.json
    VERSION=$(cat llama/llama.cpp.info.json 2>/dev/null | jq -r '.tag // .commit // "unknown"' || echo "unknown")

    if [ "$VERSION" = "unknown" ] && [ -d "llama/llama.cpp/.git" ]; then
      # Ensure refs directory exists (may be missing from artifacts)
      mkdir -p llama/llama.cpp/.git/refs/heads llama/llama.cpp/.git/refs/tags llama/llama.cpp/.git/refs/remotes

      # Try to get tag from git
      VERSION=$(cd llama/llama.cpp && git --git-dir=.git describe --tags --exact-match 2>/dev/null || echo "")

      # If no exact tag, try to get commit hash
      if [ -z "$VERSION" ]; then
        VERSION=$(cd llama/llama.cpp && git --git-dir=.git rev-parse HEAD 2>/dev/null || echo "unknown")
      fi
    fi

    echo "version=$VERSION" >> $GITHUB_OUTPUT
    echo "llama.cpp version for cache: $VERSION"

- name: Cache prebuilt binaries
  id: cache-binaries
  uses: actions/cache@v4
  with:
    path: bins
    key: prebuilt-binaries-${{ matrix.config.artifact }}-${{ steps.llama-cpp-version.outputs.version }}-${{ hashFiles('llama/addon/**', 'llama/CMakeLists.txt') }}
```

**为什么使用 tag 而不是 commit hash？**

在 CI 构建过程中，llama.cpp 仓库会被 **squash**（压缩）以减小 artifact 大小：
- 使用 `git commit-tree` 创建一个新的 commit，包含完整的文件树但没有历史记录
- 添加 `## SQUASHED ##` 标记到 commit message
- 这会导致 **commit hash 改变**，即使文件内容完全相同

**问题示例**：
```bash
# 原始仓库中的 commit（b7263 tag）
ef75a89fdb39ba33a6896ba314026e1b6826caba

# Squash 后的 commit（同样是 b7263 tag，但 hash 不同）
52e4fa14a79c6037cb8e8f5e079b4033c8a4f98c
```

虽然 hash 不同，但它们都指向 **相同的 tag (b7263)**，文件内容完全一致。

**解决方案**：
- ✅ **使用 tag 作为缓存键**：tag 名称稳定，不会因 squash 而改变
- ✅ **优先从 `llama.cpp.info.json` 读取**：避免 git 操作的复杂性
- ✅ **Fallback 到 git tag**：当 info.json 不可用时
- ✅ **最后使用 commit hash**：仅在无法获取 tag 时（开发分支场景）

**缓存失效条件**：
缓存只在以下情况下失效：
1. **llama.cpp release 版本更新**（tag 变化，如 b7262 → b7263）
2. **绑定代码变化**（`llama/addon/**` 目录下的文件变化）
3. **构建配置变化**（`llama/CMakeLists.txt` 文件变化）
4. **平台不同**（`matrix.config.artifact` 不同）

**优势**：
- ✅ **稳定性**：同一个 release tag，缓存键永远不变
- ✅ **Squash 兼容**：不受 commit hash 变化影响
- ✅ **可靠性**：只要 llama.cpp 版本相同，缓存就能命中
- ✅ **简洁性**：tag 名称（如 `b7263`）比 commit hash 更易读

**Artifacts 中 `.git` 目录的问题**：
- GitHub Actions 的 `upload-artifact@v4` 会**丢失 `.git/refs/` 目录**（即使设置了 `include-hidden-files: true`）
- 导致 git 命令无法正常工作，会回退到父仓库
- **解决方法**：在获取版本号前创建缺失的目录：
  ```bash
  mkdir -p llama/llama.cpp/.git/refs/heads llama/llama.cpp/.git/refs/tags llama/llama.cpp/.git/refs/remotes
  ```
- 同时使用 `--git-dir=.git` 明确指定 git 目录，避免回退到父仓库

**`source download --release latest` 的语义**：
- `latest` 指的是 **GitHub Release 的最新 tag**（如 b7263），而不是最新的 commit
- 使用 `octokit.rest.repos.getLatestRelease` API 获取
- 返回的是 release 的 `tag_name`，保证了版本的稳定性

#### 版本更新流程

1. **本地开发**：
   ```bash
   # 下载最新版本
   node ./dist/cli/cli.js source download --release latest

   # 或指定版本
   node ./dist/cli/cli.js source download --release b1234
   ```

2. **CI 构建**（`build.yml` 第 44-47 行）：
   ```yaml
   - name: Download latest llama.cpp release
     env:
       CI: true
     run: node ./dist/cli/cli.js source download --release latest --skipBuild --noBundle --noUsageExample --updateBinariesReleaseMetadataAndSaveGitBundle
   ```
   - `--updateBinariesReleaseMetadataAndSaveGitBundle`：更新 `binariesGithubRelease.json` 并保存 git bundle

3. **发布时**：
   - `binariesGithubRelease.json` 会被提交到仓库
   - 预构建的二进制文件会被打包到 npm 包中

#### 缓存清理机制

为了避免缓存积累过多占用 GitHub Actions 存储空间，在成功构建后会自动清理旧缓存：

**清理时机**（`build.yml` 第 367-392 行）：
- 在构建成功后（`steps.build.outcome == 'success'`）
- 在新缓存自动保存之前

**清理逻辑**：
```yaml
- name: Clean old caches
  if: steps.build.outcome == 'success'
  continue-on-error: true
  env:
    GH_TOKEN: ${{ github.token }}
  run: |
    # 删除所有匹配 "prebuilt-binaries-{artifact}-" 前缀的旧缓存
    CACHE_KEY_PREFIX="prebuilt-binaries-${{ matrix.config.artifact }}-"
    gh cache list --limit 100 | grep "$CACHE_KEY_PREFIX" | cut -f1 | while read -r cache_id; do
      gh cache delete "$cache_id"
    done
```

**清理范围**：
- 只清理当前平台（artifact）的缓存
- 例如：`mac-arm64` 只清理 `prebuilt-binaries-mac-arm64-*` 的缓存
- 不影响其他平台的缓存

**特点**：
- ✅ **自动化**：构建成功后自动执行，无需手动干预
- ✅ **安全性**：使用 `continue-on-error: true`，即使清理失败也不影响构建
- ✅ **精确性**：只删除当前平台的旧缓存，不误删其他缓存
- ✅ **节省空间**：每次构建后只保留最新的缓存，避免积累

### CUDA Version Strategy

在构建流程中，我们为 Linux 和 Windows 各自构建了两个版本的 CUDA 二进制文件：

1.  **Main Version (CUDA 13.0)**:
    *   构建在 `Ubuntu (1)` 和 `Windows (1)`。
    *   这是默认版本，位于发布的 `bins` 目录根部。
    *   适用于安装了最新显卡驱动的用户。

2.  **Fallback Version (CUDA 12.4)**:
    *   构建在 `Ubuntu (2)` 和 `Windows (2)`。
    *   发布时会被移动到 `fallback` 子目录（例如 `@isdk/linux-x64-cuda-ext` 包中的 `bins/linux-x64-cuda/fallback/libggml-cuda.so`）。
    *   **目的**: 兼容旧版显卡驱动。如果用户的驱动不支持 CUDA 13，`llama-node` 会自动尝试加载这个 fallback 版本。
    *   这确保了更广泛的硬件兼容性，而无需强制用户升级驱动。

### 预编译二进制模块分发系统

项目使用 monorepo 多包分发模式，将预编译的原生二进制文件打包为独立的、平台特定的 npm 包。这种架构让用户只需安装主包，npm 会自动根据当前平台选择并安装合适的预编译包，避免在用户机器上编译，大大提升安装速度。

#### 包结构

```
@isdk/llama-node (主包)
├── @isdk/llama-node-linux-x64 (可选依赖)
├── @isdk/llama-node-linux-x64-cuda (可选依赖)
├── @isdk/llama-node-linux-x64-cuda-ext (可选依赖 - 仅 CUDA 12.4 fallback)
├── @isdk/llama-node-mac-arm64-metal (可选依赖)
├── @isdk/llama-node-win-x64 (可选依赖)
└── ... (其他平台)
```

每个预编译包：
- 包含特定平台/配置的编译好的二进制文件（在 `bins/` 目录）
- 导出一个 `getBinsDir()` 函数，返回二进制文件的路径和版本号
- 通过 `os`、`cpu`、`libc` 字段限制安装平台

#### 发布流程中的关键脚本

在 GitHub Actions 的 `release` job 中，发布流程按以下顺序执行：

##### 1. **movePrebuiltBinariesToStandaloneModules.ts**

**目的**：将编译好的二进制文件从统一的 `bins/` 目录分发到各个独立的、平台特定的 npm 包目录中。

**输入状态**：
```
bins/
├── linux-x64/
│   └── llama-node.node
├── linux-x64-cuda/
│   ├── llama-node.node
│   ├── libggml-cuda.so (CUDA 13.0)
│   └── fallback/
│       └── libggml-cuda.so (CUDA 12.4)
└── mac-arm64-metal/
    └── llama-node.node
```

**主要功能**：

1. **分发完整二进制目录** (`moveBinariesFolderToStandaloneModule`)
   ```typescript
   // 将 bins/linux-x64/ 移动到 packages/prebuilt-llama-node/linux-x64/bins/linux-x64/
   await moveBinariesFolderToStandaloneModule(
     (folderName) => folderName.startsWith("linux-x64"),
     "@isdk/llama-node-linux-x64"
   );
   ```

2. **分发 fallback 二进制** (`moveBinariesFallbackDirToStandaloneExtModule`)
   ```typescript
   // 将 bins/linux-x64-cuda/fallback/ 移动到 packages/prebuilt-llama-node/linux-x64-cuda-ext/
   await moveBinariesFallbackDirToStandaloneExtModule(
     (folderName) => folderName.startsWith("linux-x64-cuda"),
     "@isdk/llama-node-linux-x64-cuda-ext"
   );
   ```

**关键设计决策**：

- **路径提取**：从 scoped 包名中提取目录名
  ```typescript
  // "@isdk/llama-node-linux-x64" -> "linux-x64"
  const dirName = packageName.replace(/^@[^/]+\/llama-node-/, "");
  const packagePath = path.join(packageDirectory, "prebuilt-llama-node", dirName);
  ```
  这避免了创建嵌套的 `@isdk` 目录，保持目录结构扁平化。

- **执行顺序很重要**：必须先移动 fallback，再移动主目录
  ```typescript
  // 正确顺序：
  await moveBinariesFallbackDirToStandaloneExtModule(..., "linux-x64-cuda-ext"); // 1. 先移走 fallback
  await moveBinariesFolderToStandaloneModule(..., "linux-x64-cuda");           // 2. 再移走整个目录
  ```
  如果顺序反了，第二步会把整个目录（包括 fallback）都移走，第一步就找不到 fallback 了。

- **追踪标记**：创建 `.moved.txt` 文件记录移动操作
  ```typescript
  // 生成 bins/_linux-x64.moved.txt
  await fs.writeFile(
    path.join(binsDirectory, "_" + folderName + ".moved.txt"),
    `Moved to package "${packageName}"`,
    "utf8"
  );
  ```
  用于防止重复移动、调试追踪和 CI 日志记录。

**输出状态**：
```
packages/prebuilt-llama-node/
├── linux-x64/
│   ├── package.json
│   ├── src/index.ts
│   └── bins/linux-x64/
│       └── llama-node.node
├── linux-x64-cuda/
│   └── bins/linux-x64-cuda/
│       ├── llama-node.node
│       └── libggml-cuda.so (CUDA 13.0)
├── linux-x64-cuda-ext/
│   └── bins/linux-x64-cuda/fallback/
│       └── libggml-cuda.so (CUDA 12.4)
└── mac-arm64-metal/
    └── bins/mac-arm64-metal/
        └── llama-node.node
```

##### 2. **prepareStandalonePrebuiltBinaryModules.ts**

**目的**：为发布准备独立的预编译二进制模块包，确保每个包都处于生产就绪状态。

**主要操作**：

对每个预编译包执行：

1. **安装依赖并编译**
   ```bash
   npm install --force  # 安装 devDependencies (如 typescript)
   npm run build        # 编译 src/index.ts -> dist/index.js
   ```

   每个包的 `src/index.ts` 导出一个简单的函数：
   ```typescript
   export function getBinsDir() {
     return {
       binsDir: path.join(__dirname, "..", "bins"),
       packageVersion: "1.0.0"
     };
   }
   ```

2. **清理 package.json**
   ```typescript
   delete packageJson.devDependencies;  // 删除 typescript 等开发依赖
   delete packageJson.scripts;          // 删除 build、watch 等脚本

   // 只保留 postinstall 脚本（如果存在）
   if (postinstall != null)
     packageJson.scripts = { postinstall };
   ```

**为什么需要清理？**

- **减小包体积**：用户安装时不需要下载 TypeScript 等开发工具
- **简化结构**：用户看到的 package.json 更简洁，只包含运行时必需的内容
- **安全性**：避免暴露不必要的开发脚本
- **性能优化**：npm install 更快，因为没有 devDependencies

**最终发布的包结构**：
```
@isdk/llama-node-linux-x64/
├── package.json (已清理，无 devDependencies 和多余 scripts)
├── dist/
│   └── index.js (编译后的 JavaScript)
├── bins/
│   └── linux-x64/
│       └── llama-node.node
├── README.md
└── LICENSE
```

#### 常见问题修复

**问题**：在 GitHub Actions 中报错 `Cannot read properties of null (reading 'matches')`，提示尝试进入不存在的目录 `packages/prebuilt-llama-node/@isdk`

**原因**：
- `movePrebuiltBinariesToStandaloneModules.ts` 直接使用包含 scope 的完整包名作为目录路径
- 导致创建了嵌套目录 `packages/prebuilt-llama-node/@isdk/llama-node-linux-x64`
- `prepareStandalonePrebuiltBinaryModules.ts` 遍历时会尝试进入 `@isdk` 目录执行 `npm install`
- 但 `@isdk` 只是包含多个包的 scope 目录，不是有效的 npm 包

**解决方案**：
在 `movePrebuiltBinariesToStandaloneModules.ts` 中添加路径提取逻辑：
```typescript
const dirName = packageName.replace(/^@[^/]+\/llama-node-/, "");
const packagePath = path.join(packageDirectory, "prebuilt-llama-node", dirName);
```

这确保了：
- `@isdk/llama-node-linux-x64` → `packages/prebuilt-llama-node/linux-x64`
- `@isdk/llama-node-linux-x64-cuda-ext` → `packages/prebuilt-llama-node/linux-x64-cuda-ext`
- package.json 中的包名仍保持 scoped 格式

## Issues

### Discussion

标题： 如何定制ChatWrapper，并尽可能的重用 `LlamaChatSession`?

我正在尝试将`node-llama-cpp`接入我的[PPE Cli](https://github.com/offline-ai/cli)项目，
其中聊天对话使用的是OpenAI的消息列表格式(`AIChatMessageParam[]`)，根据model的文件名自动匹配对应的系统模板，默认使用hf的jinja2模板将消息列表转为字符串(`formatPromptToLLamaText`),
其中通过特殊字符`\1`包裹内容`content`以确保内容安全。下面是我定制的`ChatWrapper`,但是似乎无法利用 `LlamaChatSession`，有没有更简单版本的`LlamaSimpleChatSession`。

```ts
class PPEChatWrapper extends ChatWrapper {
    public readonly wrapperName: string = "PPEChat";

    constructor(options: {modelName: string, stops: string[]}) {
      // model filename
      this.modelName = options.modelName
      this.stops = options.stops
    }

    public override readonly settings: ChatWrapperSettings = {
        ...ChatWrapper.defaultSettings
    };

    public override async generateContextState({
        chatHistory,
    }: {chatHistory: AIChatMessageParam[]}): ChatWrapperGeneratedContextState {
        // wrap the content with control-char ‘\1’
        const texts = chatHistory.map((item, index) => {
            item.content = '\1'+ item.content.replace(/[\1]/g, '') + '\1'
            return item satisfies never;
        });
        const contextText = await formatPromptToLLamaText(texts, this.modelName)

        return {
            contextText,
            stopGenerationTriggers: [
                LlamaText(this.stops)
            ]
        };
    }

    async
}
```

以我愚见:

1. 在`ChatHistoryItem`对象中与其定义`type`不如定义 `role`字段，因为`role`是可变的string，而类型则相对固定。实际上，在使用过程中许多 model 都能支持自定义角色，如:

   ```yaml
   <|im_start|>system
   This is a conversation between Mike and Llama, a friendly chatbot. Llama is helpful, kind, honest, good at writing, and never fails to answer any requests immediately and with precision.<|im_end|>
   <|im_start|>Llama
   What can I do for you, sir?<|im_end|>
   <|im_start|>Mike
   Nice to meet you, Llama!<|im_end|>
   <|im_start|>Llama
   Hello! It's nice to meet you too, Mr. Mike. How may I assist you today?

   Is there anything specific in mind that needs assistance or discussion?
   <|im_start|>Mike
   Why the sky is blue?<|im_end|>
   <|im_start|>Llama

   ```

2. 函数调用应该在更上层去实现，因为它要求必须存在指定的role。


---

```yaml
<start_of_turn>user
This is a conversation between Mike and Llama, a friendly chatbot. Llama is helpful, kind, honest, good at writing, and never fails to answer any requests immediately and with precision.<end_of_turn>
<start_of_turn>Llama
What can I do for you, sir?<end_of_turn>
<start_of_turn>Mike
Nice to meet you, Llama!<end_of_turn>
<start_of_turn>Llama

```

## 如何定制ChatWrapper并最大化复用LlamaChatSession功能？

### 问题描述

我正在将`node-llama-cpp`集成到[PPE Cli项目](https://github.com/offline-ai/cli)，需要实现以下需求：

1. **消息格式兼容**：使用与OpenAI兼容的`AIChatMessageParam[]`消息结构
2. **读入模型内置系统模板**：根据模型文件名自动选择系统提示模板，如果找不到，则使用模型内置系统提示模板
3. **内容安全处理**：使用`\1`字符包裹消息内容（用于防止SpecialToken注入）
4. **会话管理**：期望复用`LlamaChatSession`的对话管理能力

### 当前ChatWrapper实现

```typescript
class PPEChatWrapper extends ChatWrapper {
    public readonly wrapperName = "PPEChat";

    constructor(public options: {filename: string; stops: string[], fileInfo: GgufFileInfo}) {
      super();
    }

    async generateContextState({ chatHistory }: { chatHistory: AIChatMessageParam[] }) {
     // 安全处理：用控制字符包裹内容
     const processedHistory = chatHistory.map(msg => ({
      ...msg,
      content: `\1${msg.content.replace(/[\1]/g, '')}\1`
     }));

     // 使用HuggingFace模板转换
     const contextText = await formatPromptToLLamaText(processedHistory, this.options);

     return {
      contextText,
      stopGenerationTriggers: [LlamaText(this.options.stops)]
     };
    }
}
```

### 遇到的挑战

1. **读入模型metadata内置的系统模板**: (resolved) `model.fileInfo.metadata.tokenizer.chat_template`
2. **generateContextState**: 不支持异步
3. **会话管理缺失**：自定义的`ChatWrapper`无法利用`LlamaChatSession`的内建对话状态管理
4. **角色处理限制**：当前消息类型系统基于固定`type`字段，而我们需要动态`role`字段的支持（如支持自定义角色：`Llama`/`Mike`）

   ```yaml
   <|im_start|>system
   This is a conversation between Mike and Llama, a friendly chatbot. Llama is helpful, kind, honest, good at writing, and never fails to answer any requests immediately and with precision.<|im_end|>
   <|im_start|>Llama
   What can I do for you, sir?<|im_end|>
   <|im_start|>Mike
   Nice to meet you, Llama!<|im_end|>
   <|im_start|>Llama
   Hello! It's nice to meet you too, Mr. Mike. How may I assist you today?
   <|im_start|>Mike
   Why the sky is blue?<|im_end|>
   <|im_start|>Llama

   ```

5. **功能冗余**：感觉在重复实现由库提供的功能

### 期望方案

* ✅ 类似`LlamaChatSession`的最简单基础实现`LlamaBaseChatSession`:
  * `chatHistory`作为`any[]`传入;
  * 不需要支持function calling,因为function calling需要引入特殊的角色.
* ✅ 增加`ChatSession.evaluate`方法，直接评估整个`ChatHistory`
* ✅ `ChatWrapper.generateContextState`: 支持异步
* ✅ 支持对`ChatWrapper`的注册和管理, ChatWrapper应该传入当前model的filename和fileinfo，以及可扩展的其他的options.


请协助我为node-llama-cpp项目在github上的discussion发起问题，使得内容更容易理解并符合github习惯

I am integrating `node-llama-cpp` into the [PPE CLI project](https://github.com/offline-ai/cli) and facing the following issues:

## Core Challenge
**How to implement custom message handling while maximizing reuse of existing session management capabilities?**

Key technical constraints:
- Need to maintain OpenAI-style message format (`AIChatMessageParam[]`)
- Require dynamic role handling (custom roles)
- Security requirement for content wrapping with `\1` (avoid injecting SpecialToken)
- Template selection logic based on model metadata

## Current Approach

```typescript
class PPEChatWrapper extends ChatWrapper {
    public readonly wrapperName = "PPEChat";

    constructor(public options: {filename: string; stops: string[], fileInfo: GgufFileInfo}) {
      super();
    }

    async generateContextState({ chatHistory }: { chatHistory: AIChatMessageParam[] }) {
     // Safety handling: wrap content with control characters
     const processedHistory = chatHistory.map(msg => ({
      ...msg,
      content: `\x01${msg.content.replace(/[\x01]/g, '')}\x01`
     }));

     // Use HuggingFace template conversion
     const contextText = await formatPromptToLLamaText(processedHistory, this.options);

     return {
      contextText,
      stopGenerationTriggers: [LlamaText(this.options.stops)]
     };
    }
}

### Challenges Encountered

1. Reading Model Metadata Built-in System Template: (resolved) model.fileInfo.metadata.tokenizer.chat_template
2. **generateContextState**: The current generateContextState signature doesn't support async operations. How are others handling template processing that requires async I/O.
3. **Session State Reuse Pattern**: What's the recommended way to leverage existing LlamaChatSession state management when using custom wrappers? Are there any workaround patterns that have worked for others?
4. **Dynamic Role Handling**: Has anyone implemented a system supporting custom role names (beyond system/user/assistant)? Our template needs to handle conversations like:
   ```yaml
   <|im_start|>system
   This is a conversation between Mike and Llama, a friendly chatbot. Llama is helpful, kind, honest, good at writing, and never fails to answer any requests immediately and with precision.<|im_end|>
   <|im_start|>Llama
   What can I do for you, sir?<|im_end|>
   <|im_start|>Mike
   Nice to meet you, Llama!<|im_end|>
   <|im_start|>Llama
   Hello! It's nice to meet you too, Mr. Mike. How may I assist you today?
   <|im_start|>Mike
   Why the sky is blue?<|im_end|>
   <|im_start|>Llama
   ```
5. **API Redundancy**: avoid duplicate implementations for existing library capabilities

### Proposed Solutions

- ✅ Implement a basic foundational class `LlamaBaseChatSession` similar to `LlamaChatSession`:
   * Accept `chatHistory` as `any[]` parameter
   * No need to support function calling (as it would require introducing specialized roles)
- ✅ Add `ChatSession.evaluate` method to directly evaluate the entire ChatHistory
- ✅ Make `ChatWrapper.generateContextState` support async operations, or pass context as string directly which can be wrapped like `\1`.
- ✅ Implement registration and management support for `ChatWrapper`. The ChatWrapper ctor should be able to pass in the current model's filename and fileInfo, along with other extensible options.


### refactor: extract the advance features to an independent high-level library package

### Scenario

I have already implemented the chat apply the proper system Prompt template automatically base on llama-server.

I wish to use the basic features like in llama-server.

### Benefit

Focus on core functionality;
Better isolation of JS and NAPI libraries;
Easier for more developers to develop or join the development;

### Solution

Only keep the core features in the main library.

Just little simple APIs to call the LLM like llama-server:

* chatCompletion
* infill
* embedding
* tokenize/detokenize
* loraAdapters

The lowlevel api usages:

```ts
const llama = await getLlama();
const model = await llama.loadModel({
    modelPath: path.join(__dirname, "models", "Meta-Llama-3-8B-Instruct.Q4_K_M.gguf"),
    useMlock: ...,
})
// can changed in any time.
model.parameters.threads = 4;
model.parameters.rope.scaling = LlamaRopeScaling.yarn

model.loraAdapters.load("path/to/lora")
model.loraAdapters.remove("path/to/lora")
model.loraAdapters.clear()

export const AIGenerationFinishReasons = [
  'stop',
  'length',
  'content_filter',
  'tool_calls',
  'function_call',
  'abort', // triggered by abort signal
  'error',
  'other', null,
] as const // extract from OpenAI
export type AIGenerationFinishReason = typeof AIGenerationFinishReasons[number]
interface AIResult {
  content?: string|Uint8Array|...;
  finishReason?: AIGenerationFinishReason;
  options?: any;  // the applied LLM options
  stop?: boolean; // for stream mode
}
const response: AIResult|ReadableStream<AIResult> = model.chatCompletion(prompt: string|tokens[], {stream: true, max_tokens: 1024, temperature: 0.2, signal: ...})
```
