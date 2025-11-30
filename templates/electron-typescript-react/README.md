# Electron TypeScript React Template

This template demonstrates how to use `@isdk/llama-node` (the low-level core library) in an Electron application with React and TypeScript.

## Features

- ✅ **Low-Level API Usage**: Uses `LlamaCompletion` for text generation
- ✅ **Manual Chat History**: Implements custom chat history management
- ✅ **Streaming Responses**: Real-time token streaming with `onTextChunk`
- ✅ **Electron IPC**: Secure communication between main and renderer processes
- ✅ **React UI**: Modern React interface with TypeScript
- ✅ **Model Loading**: File dialog for selecting GGUF models

## What's Demonstrated

This template shows how to use the core `@isdk/llama-node` APIs in an Electron environment:

1. **Model Loading**: Using `getLlama()` and `llama.loadModel()`
2. **Context Management**: Creating and managing `LlamaContext` and `LlamaContextSequence`
3. **Text Completion**: Using `LlamaCompletion` for generating responses
4. **Streaming**: Implementing real-time token streaming with callbacks
5. **Chat History**: Manual management of conversation history
6. **IPC Communication**: Bridging main process (Node.js) with renderer (React)

## Low-Level API Approach

Unlike high-level chat libraries, this template demonstrates:

- **Manual prompt formatting**: Constructing prompts from chat history
- **Direct completion API**: Using `LlamaCompletion.generateCompletionWithMeta()`
- **Custom streaming**: Implementing `onTextChunk` callbacks for real-time updates
- **State management**: Tracking chat history and generation state manually

## Getting Started

### Prerequisites

- Node.js >= 20.0.0
- A GGUF model file (see recommendations below)

### Installation

```bash
npm install
```

### Running in Development

```bash
npm start
```

### Building for Production

```bash
npm run build
```

This will create platform-specific installers in the `release` directory.

## Recommended Models

For testing, we recommend these models:

- **DeepSeek R1 Distill Qwen 7B** (Q4_K_M) - Good balance of quality and speed
- **Gemma 2 2B** (Q4_K_M) - Fast, lightweight option
- **GPT-OSS 20B** (MXFP4) - Higher quality, requires more resources

Download links are provided in the app interface.

## Project Structure

```
electron/
  ├── state/
  │   └── llmState.ts          # Core LLM state management and low-level API usage
  ├── rpc/
  │   └── llmRpc.ts            # IPC communication between main and renderer
  └── index.ts                 # Electron main process entry point

src/
  ├── App/
  │   ├── components/
  │   │   ├── ChatHistory/     # Chat message display components
  │   │   ├── InputRow/        # User input component
  │   │   └── Header/          # App header with model loading
  │   └── App.tsx              # Main React component
  └── rpc/
      └── llmRpc.ts            # Renderer-side RPC client
```

## Key Implementation Details

### Chat Prompt Formatting

Since `@isdk/llama-node` doesn't include high-level chat abstractions, this template implements simple prompt formatting:

```typescript
function formatChatPrompt(history: ChatMessage[], newMessage?: string): string {
    const messages = newMessage
        ? [...history, { role: "user", content: newMessage }]
        : history;

    let prompt = "";
    for (const msg of messages) {
        if (msg.role === "user") {
            prompt += `User: ${msg.content}\n`;
        } else {
            prompt += `Assistant: ${msg.content}\n`;
        }
    }

    if (newMessage) {
        prompt += "Assistant: ";
    }

    return prompt;
}
```

### Streaming Implementation

Real-time token streaming is implemented using the `onTextChunk` callback:

```typescript
for await (const chunk of completion.generateCompletionWithMeta({
    prompt,
    maxTokens: 512,
    temperature: 0.7,
    signal: abortSignal,
    onTextChunk(text: string) {
        assistantResponse += text;
        // Update UI with partial response
        updateChatHistory([...history, { role: "assistant", content: assistantResponse }]);
    }
})) {
    // Streaming handled by onTextChunk
}
```

## Differences from High-Level Libraries

This template uses the **low-level core API** of `@isdk/llama-node`. If you need high-level features like:

- Automatic chat history management
- Built-in chat templates
- Function calling
- Conversation context management

You should use a higher-level library built on top of `@isdk/llama-node`.

## Learn More

- **@isdk/llama-node Documentation**: [GitHub Repository](https://github.com/isdk/llama-node)
- **llama.cpp**: [Official Repository](https://github.com/ggml-org/llama.cpp)
- **Electron**: [Official Documentation](https://www.electronjs.org/)
- **React**: [Official Documentation](https://react.dev/)

## License

MIT
