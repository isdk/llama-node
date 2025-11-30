# Electron Template - Refactored for Low-Level API

## Status: ✅ Refactored and Updated

This Electron template has been **completely refactored** to use the low-level APIs from `@isdk/llama-node` core library.

## What Changed

### Removed High-Level APIs

The following high-level APIs from the original `node-llama-cpp` have been removed:

- ❌ `LlamaChatSession` - Replaced with manual chat history management
- ❌ `ChatModelFunctions` / `defineChatSessionFunction` - Function calling not in core
- ❌ `LlamaChatSessionPromptCompletionEngine` - Auto-completion removed
- ❌ Segment-based response streaming (thoughts, comments) - Simplified to plain text
- ❌ Automatic chat history management - Now manual

### Added Low-Level Implementation

The template now demonstrates:

- ✅ `LlamaCompletion` - Direct completion API usage
- ✅ Manual chat history management with simple `ChatMessage[]` array
- ✅ Custom prompt formatting function
- ✅ Streaming with `onTextChunk` callbacks
- ✅ Simple role-based chat structure (`user` / `assistant`)

## Architecture Changes

### Before (High-Level)

```typescript
// Old approach with LlamaChatSession
chatSession = new LlamaChatSession({ contextSequence });
await chatSession.prompt(message, {
    functions: modelFunctions,
    onResponseChunk(chunk) {
        // Complex segment handling
    }
});
```

### After (Low-Level)

```typescript
// New approach with LlamaCompletion
completion = new LlamaCompletion({ contextSequence });
const prompt = formatChatPrompt(chatHistory, message);
for await (const chunk of completion.generateCompletionWithMeta({
    prompt,
    onTextChunk(text: string) {
        assistantResponse += text;
        updateUI();
    }
})) {
    // Streaming handled by callback
}
```

## State Structure Changes

### Before

```typescript
chatSession: {
    loaded: boolean,
    generatingResult: boolean,
    simplifiedChat: SimplifiedChatItem[],  // Complex segments
    draftPrompt: {
        prompt: string,
        completion: string  // Auto-completion
    }
}
```

### After

```typescript
chatSession: {
    loaded: boolean,
    generatingResult: boolean,
    chatHistory: ChatMessage[],  // Simple role/content
    draftPrompt: string  // No auto-completion
}

type ChatMessage = {
    role: "user" | "assistant",
    content: string
};
```

## Benefits of Low-Level Approach

1. **Transparency**: You see exactly what's happening with the model
2. **Control**: Full control over prompt formatting and generation parameters
3. **Simplicity**: No hidden abstractions or magic
4. **Learning**: Better understanding of how LLMs work
5. **Customization**: Easy to adapt to specific use cases

## Limitations

Since this uses the core low-level API, the following features are **not available**:

- ❌ Automatic chat template detection
- ❌ Built-in function calling
- ❌ Conversation context management
- ❌ Prompt auto-completion
- ❌ Segment-based streaming (thoughts, comments)

If you need these features, consider building them yourself or using a higher-level library.

## Migration Guide

If you're migrating from the old high-level template:

1. **Chat History**: Replace `simplifiedChat` with `chatHistory` (simple array)
2. **Message Structure**: Use `{ role, content }` instead of complex segments
3. **Prompt Formatting**: Implement your own `formatChatPrompt()` function
4. **Streaming**: Use `onTextChunk` callback instead of segment handlers
5. **State Updates**: Simplify state structure to match new types

## Example: Custom Prompt Formatting

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

You can customize this to match your model's chat template format (e.g., ChatML, Llama 2, etc.).

## Next Steps

- See `README.md` for full documentation
- Check `electron/state/llmState.ts` for implementation details
- Explore `src/App/` for React component examples

## Feedback

This refactoring demonstrates the core capabilities of `@isdk/llama-node`. If you have suggestions for improvements or find issues, please open an issue on GitHub.
