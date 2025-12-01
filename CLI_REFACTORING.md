# CLI Refactoring - Core Package

## Overview

This package is designed as a **low-level core library** for `node-llama-cpp`. As such, the CLI has been streamlined to include only **development tools and low-level management commands**, removing all high-level user-facing features.

## Retained CLI Commands

### Source Management Commands
Essential for building and managing the native bindings:

- `node-llama-cpp source download` - Download llama.cpp source code
- `node-llama-cpp source build` - Build native bindings from source
- `node-llama-cpp source clear` - Clear build artifacts

### Inspection Commands
Useful development and debugging tools:

- `node-llama-cpp inspect gpu` - Display GPU information
- `node-llama-cpp inspect gguf` - Inspect GGUF model files
- `node-llama-cpp inspect estimate` - Estimate memory requirements
- `node-llama-cpp inspect measure` - Measure model performance

### Internal Commands
- `postinstall` - Post-installation setup (internal use)
- `debug` - Debug information (internal use)

## Removed CLI Commands

The following high-level commands have been removed from the core package. These should be implemented in a higher-level wrapper package:

- ❌ `chat` - Interactive chat sessions
- ❌ `complete` - Text completion
- ❌ `infill` - Code infilling
- ❌ `init` - Project initialization
- ❌ `pull` - Model downloading

## Rationale

### Core Package Responsibilities
The core package (`@isdk/llama-node`) focuses on:
- Native bindings to llama.cpp
- Low-level API for model operations
- Build and compilation tools
- Development utilities

### High-Level Package Responsibilities
A separate high-level package should provide:
- User-friendly CLI commands
- Chat session management
- Template and prompt handling
- Model downloading and management
- Project scaffolding

## File Changes

### Removed Files
- `docs/cli/chat.md`
- `docs/cli/complete.md`
- `docs/cli/infill.md`
- `docs/cli/init.md`
- `docs/cli/pull.md`

### Modified Files
- `docs/cli/cli.data.ts` - Removed references to high-level commands
- `src/cli/cli.ts` - Already contained only core commands

### Unchanged Structure
- `src/cli/commands/source/` - Source management commands
- `src/cli/commands/inspect/` - Inspection commands
- `src/cli/commands/DebugCommand.ts` - Debug command
- `src/cli/commands/OnPostInstallCommand.ts` - Post-install command

## Core API Design

The core package should expose simple, callable APIs similar to `llama-server`:

```typescript
const llama = await getLlama();
const model = await llama.loadModel({
    modelPath: "path/to/model.gguf",
    useMlock: true,
});

// Low-level operations
const response = await model.chatCompletion(prompt, {
    stream: true,
    max_tokens: 1024,
    temperature: 0.2,
});

const tokens = await model.tokenize(text);
const text = await model.detokenize(tokens);

const embedding = await model.embedding(text);

// LoRA adapter management
await model.loraAdapters.load("path/to/lora");
await model.loraAdapters.remove("path/to/lora");
await model.loraAdapters.clear();
```

## Next Steps

1. ✅ Remove high-level CLI commands from documentation
2. ✅ Verify TypeScript compilation
3. ⏳ Implement simplified core APIs
4. ⏳ Create high-level wrapper package for removed features
5. ⏳ Update README to reflect core package focus
