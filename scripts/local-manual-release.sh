#!/bin/bash
set -e

# 1. Install dependencies
if [ -d "node_modules" ]; then
    echo "✅ node_modules exists, skipping install."
else
    echo "📦 Installing dependencies..."
    pnpm install
fi

# 2. Build the project (generates dist/)
if [ -d "dist" ]; then
    echo "✅ dist exists, skipping build."
else
    echo "🔨 Building project..."
    pnpm run build
fi

# 3. Download or Update llama.cpp source
if [ -d "llama/llama.cpp" ]; then
    echo "✅ llama.cpp exists. Attempting to update..."
    # Use the CLI pull command if llama.cpp is a git repo
    if [ -d "llama/llama.cpp/.git" ]; then
        node ./dist/cli/cli.js source pull
    else
        echo "⚠️  llama.cpp is not a git repo, skipping update."
        echo "    Run 'node ./dist/cli/cli.js source clear' and rerun this script to re-download."
    fi
else
    echo "📥 Downloading llama.cpp..."
    node ./dist/cli/cli.js source download --release latest --skipBuild --noBundle --noUsageExample --updateBinariesReleaseMetadataAndSaveGitBundle
fi

# 4. Build Binaries (Native to current OS only)
echo "🏗️  Building binaries for current OS..."
# Note: This only builds for the current platform (e.g., Linux).
# You won't get Windows/macOS binaries here without cross-compilation or separate machines.
node ./dist/cli/cli.js source build --ciMode --noUsageExample

# 5. Organize Binaries (Simulate CI artifact gathering)
echo "📂 Organizing binaries..."
mkdir -p bins

# The CLI build puts artifacts in llama/localBuilds. We need to move them to bins/ like the CI does.
# CI Logic:
# const localBuildsDirectoryPath = path.join(process.cwd(), "llama", "localBuilds");
# const llamaBinsDirectoryPath = path.join(process.cwd(), "bins");
# fs.move(..., ...)

# We can use a small node script or bash to move them. Bash is easier here.
if [ -d "llama/localBuilds" ]; then
    for dir in llama/localBuilds/*; do
        if [ -d "$dir/Release" ]; then
            target_name=$(basename "$dir")
            echo "Moving $target_name to bins/..."
            rm -rf "bins/$target_name"
            mv "$dir/Release" "bins/$target_name"
        fi
    done
else
    echo "⚠️  No local builds found in llama/localBuilds"
fi

# 6. Prepare for Release (Run the scripts that the 'release' job runs)
echo "✨ Preparing standalone modules..."

# Ensure we have the necessary files in place for the scripts to find
# The CI moves artifacts/llama.cpp/llama.cpp/grammars -> llama/grammars.
# Locally, they should already be in llama/grammars if the download step worked?
# Let's verify. The download command populates 'llama' directory.

# Run the preparation scripts
pnpm vite-node ./scripts/movePrebuiltBinariesToStandaloneModules.ts
pnpm vite-node ./scripts/prepareStandalonePrebuiltBinaryModules.ts
pnpm run addPostinstallScript

echo "✅ Ready to publish!"
echo "To publish, run: npm publish"
echo "To dry-run, run: npm publish --dry-run"
