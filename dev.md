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
