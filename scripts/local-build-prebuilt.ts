import path from "path";
import { fileURLToPath } from "url";
import process from "process";
import fs from "fs-extra";
import { $ } from "zx";
import chalk from "chalk";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.join(__dirname, "..");

const argv = yargs(hideBin(process.argv))
  .option("target", {
    type: "string",
    description: "Build target (e.g., current, all)",
    default: "current"
  })
  .option("gpu", {
    type: "string",
    description: "GPU support (auto, cuda, vulkan, metal, false)",
    default: "auto"
  })
  .option("dry-run", {
    type: "boolean",
    description: "Print commands without executing",
    default: false
  })
  .option("compiler", {
    type: "string",
    choices: ["clang", "gcc", "msvc", "auto"],
    default: "clang",
    description: "Compiler to use"
  })
  .help()
  .parseSync();

interface BuildConfig {
  name: string;
  arch: string;
  gpu: string | false;
  platform: NodeJS.Platform;
  crossCompile: boolean;
}

async function main() {
  const platform = process.platform;
  const arch = process.arch;

  console.log(chalk.blue(`🚀 Starting local prebuilt binary build`));
  console.log(`Host: ${platform}-${arch}`);

  const configs = getBuildConfigs(platform, arch);
  const targetsToBuild = filterConfigs(configs, argv.target, argv.gpu);

  if (targetsToBuild.length === 0) {
    console.log(chalk.yellow("No matching build targets found."));
    return;
  }

  console.log(chalk.blue("\n📋 Build Plan:"));
  for (const config of targetsToBuild) {
    console.log(`  - ${config.name} (Arch: ${config.arch}, GPU: ${config.gpu})`);
  }

  if (argv.dryRun) {
    console.log(chalk.yellow("\nDry run completed."));
    return;
  }

  // Ensure dist/cli/cli.js exists
  if (!(await fs.pathExists(path.join(rootDir, "dist", "cli", "cli.js")))) {
    console.log(chalk.blue("Building CLI first..."));
    await $`pnpm run build`;
  }

  for (const config of targetsToBuild) {
    console.log(chalk.blue(`\n🔨 Building ${config.name}...`));

    try {
      const gpuFlag = config.gpu === false ? "false" : config.gpu;

      // Use --compiler option
      await $`node ./dist/cli/cli.js source build --ciMode --noUsageExample --arch ${config.arch} --gpu ${gpuFlag} --compiler ${argv.compiler}`;

      // Move binaries
      await organizeBinaries(config.name);

    } catch (err) {
      console.error(chalk.red(`Failed to build ${config.name}`), err);
      // Continue with other targets? Or fail fast?
      // Let's fail fast for now to match CI behavior usually
      process.exit(1);
    }
  }

  console.log(chalk.green("\n✅ Build sequence completed!"));
  console.log("Run 'pnpm vite-node ./scripts/prepareStandalonePrebuiltBinaryModules.ts' to finalize packages.");
}

function getBuildConfigs(platform: NodeJS.Platform, hostArch: string): BuildConfig[] {
  const configs: BuildConfig[] = [];

  if (platform === "darwin") {
    // macOS Native
    if (hostArch === "arm64") {
      configs.push({ name: "mac-arm64-metal", arch: "arm64", gpu: "metal", platform, crossCompile: false });
    } else {
      configs.push({ name: "mac-x64", arch: "x64", gpu: false, platform, crossCompile: false });
    }
  } else if (platform === "linux") {
    // Linux Native x64
    if (hostArch === "x64") {
      configs.push({ name: "linux-x64", arch: "x64", gpu: false, platform, crossCompile: false });
      configs.push({ name: "linux-x64-vulkan", arch: "x64", gpu: "vulkan", platform, crossCompile: false });
      // CUDA check? For now add it, build will fail if missing SDK, which is expected
      configs.push({ name: "linux-x64-cuda", arch: "x64", gpu: "cuda", platform, crossCompile: false });
    }

    // Linux Cross Compile (ARM)
    // Only if tools are present? For now add them, user can filter or fail
    configs.push({ name: "linux-arm64", arch: "arm64", gpu: false, platform, crossCompile: true });
    configs.push({ name: "linux-armv7l", arch: "arm", gpu: false, platform, crossCompile: true });

  } else if (platform === "win32") {
    // Windows Native x64
    if (hostArch === "x64") {
      configs.push({ name: "win-x64", arch: "x64", gpu: false, platform, crossCompile: false });
      configs.push({ name: "win-x64-vulkan", arch: "x64", gpu: "vulkan", platform, crossCompile: false });
      configs.push({ name: "win-x64-cuda", arch: "x64", gpu: "cuda", platform, crossCompile: false });
    }

    // Windows Cross Compile (ARM64)
    configs.push({ name: "win-arm64", arch: "arm64", gpu: false, platform, crossCompile: true });
  }

  return configs;
}

function filterConfigs(configs: BuildConfig[], target: string, gpu: string): BuildConfig[] {
  let filtered = configs;

  if (target === "current") {
    // Filter out cross-compile targets
    filtered = filtered.filter(c => !c.crossCompile);
  } else if (target !== "all") {
    // Specific target name match
    filtered = filtered.filter(c => c.name === target);
  }

  if (gpu !== "auto") {
    if (gpu === "false") {
      filtered = filtered.filter(c => c.gpu === false);
    } else {
      filtered = filtered.filter(c => c.gpu === gpu);
    }
  }

  return filtered;
}

async function organizeBinaries(targetName: string) {
  const binsDir = path.join(rootDir, "bins");
  const localBuildsDir = path.join(rootDir, "llama", "localBuilds");

  await fs.ensureDir(binsDir);

  // Find the build in localBuilds
  // The folder name in localBuilds depends on options.
  // We can look for the most recently modified folder or match patterns.
  // But since we build one by one, we can check what's there.

  // Actually, `cli.js source build` creates a folder name based on options.
  // Let's iterate localBuilds and move any "Release" folder we find that matches our target expectations.
  // This is a bit tricky because the folder name is complex.

  // Simplified approach: Move ALL builds from localBuilds to bins/<targetName>
  // CAUTION: This assumes we clear localBuilds or only build one thing at a time.
  // The script builds sequentially, so we can try to find the new folder.

  const folders = await fs.readdir(localBuildsDir);
  for (const folder of folders) {
    const releasePath = path.join(localBuildsDir, folder, "Release");
    if (await fs.pathExists(releasePath)) {
      const targetBinDir = path.join(binsDir, targetName);

      // Clean previous
      await fs.remove(targetBinDir);
      await fs.ensureDir(targetBinDir);

      console.log(`Moving binaries from ${folder} to bins/${targetName}`);
      await fs.copy(releasePath, targetBinDir);

      // Cleanup local build to avoid confusion for next step
      await fs.remove(path.join(localBuildsDir, folder));
    }
  }
}

main().catch(console.error);
