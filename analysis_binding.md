# Node-Llama.cpp Binding Analysis

This document analyzes the binding architecture, runtime hardware checks, and dynamic compilation mechanisms of the `node-llama.node` project.

## 1. Project Overview

The project is currently structured as a single main package with a `packages` directory containing prebuilt binaries and templates. It is **not** a full monorepo in the traditional sense (e.g., using workspaces for all code), but it uses `optionalDependencies` to pull in platform-specific prebuilt binaries.

## 2. Binding Architecture

The binding connects Node.js to `llama.cpp` using `node-addon-api` (N-API).

### 2.1 C++ Layer (`llama/addon`)
The C++ source code for the binding is located in `llama/addon`.
-   **Entry Point**: `addon.cpp` initializes the module and exports functions and classes.
-   **Core Classes**:
    -   `AddonModel`: Wraps `llama_model`.
    -   `AddonContext`: Wraps `llama_context`.
    -   `AddonGrammar`: Handles GBNF grammars.
    -   `AddonSampler`: Handles sampling.
-   **Build System**: Uses `cmake-js`. The configuration is in `llama/CMakeLists.txt`.

### 2.2 TypeScript Layer (`src/bindings`)
The TypeScript layer wraps the C++ addon to provide a high-level API.
-   **`Llama.ts`**: The main class that interacts with the loaded binding.
-   **`getLlama.ts`**: The factory function responsible for loading the correct binary (prebuilt or local build).
-   **`AddonTypes.ts`**: Type definitions for the C++ addon exports.

## 3. Runtime Hardware Check

The project performs runtime checks to detect available hardware (GPU) and select the best configuration.

### 3.1 Detection Logic
The core detection logic is in `src/bindings/utils/detectAvailableComputeLayers.ts`.
-   **CUDA**: Checks for NVIDIA drivers (`nvml.dll`/`libnvidia-ml.so`) and CUDA runtime libraries (`cudart`, `cublas`) in standard paths and environment variables (`CUDA_PATH`, `LD_LIBRARY_PATH`).
-   **Vulkan**: Checks for Vulkan libraries (`vulkan-1.dll`, `libvulkan.so`).
-   **Metal**: Checks if the platform is macOS (`mac`).

### 3.2 Selection Logic
`src/bindings/utils/getGpuTypesToUseForOption.ts` determines which GPU backend to use.
-   It takes user preferences (`gpu: "auto" | "cuda" | "vulkan" | "metal"`) and system capabilities.
-   If `auto`, it prioritizes: Metal (on Mac) > CUDA > Vulkan > CPU.

### 3.3 Verification (`testBindingBinary.ts`)
Before using a binary (especially a prebuilt one), the system verifies it using `src/bindings/utils/testBindingBinary.ts`.
-   **Mechanism**: Spawns a child process (Node.js or Electron utility process) to load the binary.
-   **Checks**:
    -   Can the binary be `require`d?
    -   Does the binary's reported GPU type match the expected type?
    -   Can it initialize the backend?
-   **Isolation**: This prevents the main process from crashing if the binary is incompatible (e.g., missing shared libraries).

## 4. Dynamic Compilation

If no compatible prebuilt binary is found, or if the user requests it, the project can build `llama.cpp` from source at runtime.

### 4.1 Build Process (`compileLLamaCpp.ts`)
-   **Source Management**: Downloads `llama.cpp` source code if not present (using `ipull`).
-   **Compilation**: Uses `cmake-js` to compile the C++ addon.
    -   Command: `npm run cmake-js-llama -- compile ...`
-   **Configuration**:
    -   Sets CMake flags based on the selected GPU backend (e.g., `GGML_CUDA=ON`, `GGML_METAL=ON`).
    -   Handles platform-specific toolchains and workarounds (e.g., Windows MSVC vs LLVM).

### 4.2 Prebuilt Binaries
-   Prebuilt binaries are distributed as separate npm packages (e.g., `@isdk/llama-node-linux-x64-cuda`).
-   `getLlama.ts` checks for these packages in `node_modules` and verifies them using `testBindingBinary.ts`.

## 5. Tests

### 5.1 Binding Tests
-   **Runtime Verification**: As mentioned, `testBindingBinary.ts` is used at runtime.
-   **Functional Tests**: Located in `test/`.
    -   `test/standalone`: Tests that run against the built binding (e.g., `LlamaGrammar.test.ts`).
    -   `test/modelDependent`: Tests that require a model file.

## 6. Recommendations for Extraction

To extract core features to a low-level library (`@isdk/llama-node`):

1.  **Move C++ Code**: Move `llama/addon` and `llama/CMakeLists.txt` to the new package.
2.  **Move Binding Logic**: Move `src/bindings` (excluding high-level abstractions if any) to the new package.
3.  **Preserve Runtime Checks**: The hardware detection and dynamic compilation logic (`src/bindings/utils`) are critical and should be part of the low-level library or a dedicated "loader" package.

## 7. Dependencies and Helpers

To successfully extract the binding logic, the following dependencies must also be migrated or replicated.

### 7.1 C++ Dependencies
The C++ code in `llama/addon` depends on files in `llama/addon/globals`. These files provide logging, progress reporting, and system info retrieval.
-   `llama/addon/globals/addonLog.h/cpp`
-   `llama/addon/globals/addonProgress.h/cpp`
-   `llama/addon/globals/getGpuInfo.h/cpp`
-   `llama/addon/globals/getMemoryInfo.h/cpp`
-   `llama/addon/globals/getSwapInfo.h/cpp`

### 7.2 TypeScript Dependencies
The TypeScript code in `src/bindings` heavily relies on helper functions in `src/utils` and configuration in `src/config.ts`.

#### Shared Configuration
-   `src/config.ts`: Contains default values, paths, and environment variable handling.

#### Utility Modules (`src/utils`)
The following utility modules are imported by `src/bindings`:
-   **System & Runtime**:
    -   `getConsoleLogPrefix.ts`
    -   `runtime.ts` (Electron/Bun detection)
    -   `getPlatform.ts` (Platform detection)
    -   `getModuleVersion.ts`
    -   `spawnCommand.ts`
    -   `withLockfile.ts`, `waitForLockfileRelease.ts`, `isLockfileActive.ts`
    -   `clearTempFolder.ts`
-   **Build & CMake**:
    -   `cmake.ts`
    -   `hashString.ts`
    -   `removeNullFields.ts`
-   **GitHub & Downloads**:
    -   `gitReleaseBundles.ts`
    -   `resolveGithubRelease.ts`
    -   `withStatusLogs.ts`
    -   `withProgressLog.ts`
-   **Formatting**:
    -   `prettyPrintObject.ts`

### 7.3 Extraction Strategy
When extracting to `@isdk/llama-node`:
1.  **Copy `llama/addon/globals`**: These are tightly coupled with the addon and should be moved alongside `llama/addon`.
2.  **Migrate `src/utils`**: The used utilities should be moved to a `src/utils` directory in the new package. If they are generic enough, they could potentially be in a shared `core` package, but for now, copying them is safer to maintain self-containment.

### 7.4 Test Dependencies
The relevant unit tests (e.g., `test/standalone/llamaEvaluator`) also have dependencies that need to be considered:
-   **Test Utilities**:
    -   `test/utils/getTestLlama.ts`: Helper to initialize `Llama` instance.
    -   `test/utils/modelFiles.ts`: Helper to download/locate test models.
-   **Dependencies of Test Utilities**:
    -   `src/utils/withStatusLogs.ts`
    -   `src/utils/withLockfile.ts`
    -   `src/config.ts`
-   **GGUF Handling**: Some tests rely on GGUF parsing utilities (`src/gguf`), which might need to be extracted if GGUF parsing is considered a core low-level feature.
