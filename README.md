<div align="center">
    <h1>@isdk/llama-node</h1>
    <p>Low-level Node.js bindings for llama.cpp</p>
    <sub>Core library for running LLM models locally with native performance and hardware acceleration</sub>
    <p></p>
</div>

<div align="center" class="main-badges">

[![License](https://badgen.net/badge/color/MIT/green?label=license)](https://www.npmjs.com/package/@isdk/llama-node)
[![Types](https://badgen.net/badge/color/TypeScript/blue?label=types)](https://www.npmjs.com/package/@isdk/llama-node)
[![Version](https://badgen.net/npm/v/@isdk/llama-node)](https://www.npmjs.com/package/@isdk/llama-node)

</div>

## Overview

`@isdk/llama-node` is a **low-level core library** that provides direct Node.js bindings to [llama.cpp](https://github.com/ggml-org/llama.cpp). This package is designed for developers who need fine-grained control over LLM inference, tokenization, embeddings, and grammar-based generation.

This is the **core foundation** extracted from the original `node-llama-cpp` project, focusing on essential bindings and low-level APIs without high-level abstractions like chat sessions or conversation management.

## Features

* **Native Performance**: Direct C++ bindings to llama.cpp for maximum performance
* **Hardware Acceleration**: Full support for Metal (macOS), CUDA (NVIDIA), and Vulkan (cross-platform GPU)
* **Pre-built Binaries**: Platform-specific binaries included for immediate use
* **Automatic Hardware Detection**: Adapts to your system's capabilities automatically
* **Core Functionality**:
  - Model loading and management
  - Context creation and sequence evaluation
  - Tokenization and detokenization
  - Embeddings and reranking
  - Grammar-based generation (GBNF, JSON Schema)
  - LoRA adapter support
  - GGUF file inspection and metadata reading
* **TypeScript First**: Complete type definitions for excellent developer experience
* **Low-level Control**: Direct access to context sequences, token evaluation, and batching
* **Safe Token Handling**: Protection against special token injection attacks

## Installation

```bash
npm install @isdk/llama-node
```

Pre-built binaries are provided for:
- **macOS**: x64, arm64 (Metal support)
- **Linux**: x64, arm64, armv7l (CUDA, Vulkan variants)
- **Windows**: x64, arm64 (CUDA, Vulkan variants)

If binaries are not available for your platform, the package will automatically build from source using `cmake`.

## Quick Start

### Basic Model Loading and Text Completion

```typescript
import { getLlama, LlamaModel, LlamaContext, LlamaCompletion } from "@isdk/llama-node";
import path from "path";

// Initialize llama.cpp bindings
const llama = await getLlama();

// Load a model
const model = await llama.loadModel({
    modelPath: path.join(__dirname, "models", "llama-2-7b.Q4_K_M.gguf")
});

// Create a context for inference
const context = await model.createContext({
    contextSize: 4096
});

// Create a completion generator
const completion = new LlamaCompletion({
    contextSequence: context.getSequence()
});

// Generate text
const result = await completion.generateCompletion({
    prompt: "The meaning of life is",
    maxTokens: 100
});

console.log(result.text);
```

### Tokenization and Detokenization

```typescript
import { getLlama } from "@isdk/llama-node";

const llama = await getLlama();
const model = await llama.loadModel({ modelPath: "model.gguf" });

// Tokenize text
const tokens = model.tokenize("Hello, world!");
console.log("Tokens:", tokens);

// Detokenize back to text
const text = model.detokenize(tokens);
console.log("Text:", text);
```

### Embeddings

```typescript
import { getLlama, LlamaEmbeddingContext } from "@isdk/llama-node";

const llama = await getLlama();
const model = await llama.loadModel({
    modelPath: "embedding-model.gguf"
});

// Create embedding context
const embeddingContext = await model.createEmbeddingContext();

// Generate embeddings
const embedding = await embeddingContext.getEmbeddingFor("Sample text");
console.log("Embedding vector:", embedding.vector);
```

### Grammar-Based Generation (JSON Schema)

```typescript
import {
    getLlama,
    LlamaJsonSchemaGrammar,
    LlamaCompletion
} from "@isdk/llama-node";

const llama = await getLlama();
const model = await llama.loadModel({ modelPath: "model.gguf" });
const context = await model.createContext();

// Define JSON schema
const schema = {
    type: "object",
    properties: {
        name: { type: "string" },
        age: { type: "number" },
        hobbies: {
            type: "array",
            items: { type: "string" }
        }
    },
    required: ["name", "age"]
} as const;

// Create grammar from schema
const grammar = new LlamaJsonSchemaGrammar(llama, schema);

// Generate with grammar constraints
const completion = new LlamaCompletion({
    contextSequence: context.getSequence()
});

const result = await completion.generateCompletion({
    prompt: "Generate a person profile:",
    grammar,
    maxTokens: 200
});

const parsed = JSON.parse(result.text);
console.log("Structured output:", parsed);
```

### GGUF File Inspection

```typescript
import { readGgufFileInfo, GgufInsights } from "@isdk/llama-node";

// Read GGUF metadata
const fileInfo = await readGgufFileInfo("model.gguf");
console.log("Architecture:", fileInfo.metadata.general.architecture);
console.log("Parameter count:", fileInfo.metadata.general.parameterCount);

// Get resource requirements
const insights = await GgufInsights.from("model.gguf");
const requirements = insights.configurationResolver.resolveAndScoreConfig();
console.log("Recommended context size:", requirements.contextSize);
console.log("Estimated VRAM usage:", requirements.gpuLayers);
```

## Core API Overview

### Main Classes

- **`Llama`**: Main entry point for llama.cpp bindings
- **`LlamaModel`**: Represents a loaded GGUF model
- **`LlamaContext`**: Inference context for text generation
- **`LlamaContextSequence`**: Manages token sequences within a context
- **`LlamaEmbeddingContext`**: Context for generating embeddings
- **`LlamaRankingContext`**: Context for text reranking
- **`LlamaCompletion`**: Text completion generator
- **`LlamaGrammar`**: GBNF grammar for constrained generation
- **`LlamaJsonSchemaGrammar`**: JSON Schema to GBNF converter
- **`TokenBias`**: Control token sampling probabilities
- **`TokenMeter`**: Track token usage and performance

### Utilities

- **`getLlama()`**: Initialize and get Llama instance
- **`readGgufFileInfo()`**: Read GGUF file metadata
- **`GgufInsights`**: Analyze model requirements
- **`resolveModelFile()`**: Resolve and download models
- **`LlamaText`**: Safe text handling with special token support

## CLI Tools

The package includes a CLI for common tasks:

```bash
# Inspect GGUF file
npx llama-node inspect gguf model.gguf

# Download llama.cpp source
npx llama-node source download

# Build from source
npx llama-node source build
```

## Hardware Acceleration

The package automatically detects and uses available hardware acceleration:

- **macOS**: Metal (Apple Silicon and Intel with Metal support)
- **Linux/Windows**: CUDA (NVIDIA GPUs), Vulkan (AMD, Intel, NVIDIA)
- **CPU**: Optimized CPU inference with SIMD support

No configuration needed - the appropriate binary is selected at runtime.

## Environment Variables

- `NODE_LLAMA_CPP_SKIP_DOWNLOAD`: Skip automatic source download/build
- `NODE_LLAMA_CPP_GPU`: Override GPU type selection
- `NODE_LLAMA_CPP_LOG_LEVEL`: Set logging verbosity

## TypeScript Support

Full TypeScript definitions are included. The library is written in TypeScript and provides excellent IntelliSense support.

```typescript
import type {
    Token,
    Tokenizer,
    LlamaContextOptions,
    LlamaModelOptions,
    GgufMetadata
} from "@isdk/llama-node";
```

## Differences from node-llama-cpp

This package is the **low-level core** extracted from `node-llama-cpp`:

**Included:**
- ✅ Native bindings to llama.cpp
- ✅ Model loading and context management
- ✅ Tokenization/detokenization
- ✅ Embeddings and reranking
- ✅ Grammar-based generation
- ✅ GGUF file utilities
- ✅ Low-level completion API

**Not Included (available in higher-level packages):**
- ❌ Chat sessions and conversation management
- ❌ Chat history and message formatting
- ❌ Function calling abstractions
- ❌ High-level prompt templates
- ❌ Interactive chat CLI

## Requirements

- **Node.js**: >= 20.0.0
- **TypeScript**: >= 5.0.0 (optional, for development)

## Building from Source

If pre-built binaries are not available:

```bash
# Download llama.cpp source
npx llama-node source download

# Build with cmake
npx llama-node source build
```

Requirements for building:
- CMake >= 3.26
- C++17 compatible compiler
- CUDA Toolkit (for CUDA support)
- Vulkan SDK (for Vulkan support)

## Development

### Local Manual Release

For developers who need to build and prepare the package locally for publishing (Linux binaries only):

```bash
# Run the automated local release script
./scripts/local-manual-release.sh
```

This script will:
1. ✅ Install dependencies (skipped if `node_modules` exists)
2. ✅ Build the project (skipped if `dist` exists)
3. ✅ Download or update llama.cpp source
4. 🏗️ Build native binaries for your current OS
5. 📦 Organize binaries and prepare standalone modules
6. ✨ Prepare the package for `npm publish`

After running the script, you can publish with:
```bash
npm publish --dry-run  # Test first
npm publish            # Publish to npm
```

**Note**: This workflow only produces binaries for your current platform (e.g., Linux). To build Windows/macOS binaries, use GitHub Actions CI or cross-compilation tools.

### Updating llama.cpp Source

To update the llama.cpp source code to the latest version:

```bash
# Update llama.cpp via git pull
npx llama-node source pull

# Or download a specific release
npx llama-node source download --release latest

# Clear and start fresh
npx llama-node source clear
npx llama-node source download
```

The `source pull` command is particularly useful during development when you want to quickly sync with upstream llama.cpp changes without re-downloading everything.

## Contributing

Contributions are welcome! This is a core library, so we focus on:
- Stability and performance
- Low-level API completeness
- Comprehensive TypeScript types
- Cross-platform compatibility

## Acknowledgements

* **llama.cpp**: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)
* **Original project**: [withcatai/node-llama-cpp](https://github.com/withcatai/node-llama-cpp)

## License

MIT

---

<div align="center">
    <p>
        <i>Built with ❤️ for the Node.js and LLM community</i>
    </p>
</div>
