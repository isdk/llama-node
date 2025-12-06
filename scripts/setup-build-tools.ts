import process from "process";
import { $ } from "zx";
import chalk from "chalk";
import which from "which";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

const argv = yargs(hideBin(process.argv))
  .option("check", {
    type: "boolean",
    description: "Only check for missing tools",
    default: false
  })
  .option("install", {
    type: "boolean",
    description: "Install missing tools",
    default: false
  })
  .help()
  .parseSync();

async function main() {
  const platform = process.platform;
  const missingTools: string[] = [];

  console.log(chalk.blue("🔍 Checking build tools..."));

  // 1. Check CMake
  if (!(await checkCommand("cmake"))) {
    missingTools.push("cmake");
  } else {
    // Check version? (Optional, but recommended > 3.19)
  }

  // 2. Check Ninja
  if (!(await checkCommand("ninja"))) {
    missingTools.push("ninja");
  }

  // 3. Check Compiler (Clang default)
  if (!(await checkCommand("clang")) || !(await checkCommand("clang++"))) {
    missingTools.push("clang");
  }

  // 4. Check OpenMP (Platform specific check is hard without compiling,
  //    but we can check for libraries or dev packages)
  //    For now, we assume if we install clang/gcc via our script, we include openmp.
  //    We will add 'openmp' to missingTools if we are in install mode and want to ensure it.

  // 5. Cross-compilation tools (Linux only)
  if (platform === "linux") {
    if (!(await checkCommand("aarch64-linux-gnu-g++"))) {
      missingTools.push("cross-arm64");
    }
    if (!(await checkCommand("arm-linux-gnueabihf-g++"))) {
      missingTools.push("cross-armv7");
    }
  }

  if (missingTools.length === 0) {
    console.log(chalk.green("✅ All core build tools are present!"));
    return;
  }

  console.log(chalk.yellow(`⚠️  Missing tools: ${missingTools.join(", ")}`));

  if (argv.check) {
    console.log("Run with --install to attempt installation.");
    return;
  }

  if (argv.install) {
    await installTools(platform, missingTools);
  }
}

async function checkCommand(command: string) {
  try {
    await which(command);
    console.log(chalk.green(`  ✓ ${command} found`));
    return true;
  } catch {
    console.log(chalk.red(`  ✗ ${command} not found`));
    return false;
  }
}

async function installTools(platform: NodeJS.Platform, tools: string[]) {
  console.log(chalk.blue("\n📦 Installing tools..."));

  if (platform === "win32") {
    await installWindowsTools(tools);
  } else if (platform === "linux") {
    await installLinuxTools(tools);
  } else if (platform === "darwin") {
    await installMacTools(tools);
  } else {
    console.error(chalk.red("Unsupported platform for automatic installation."));
  }
}

async function installWindowsTools(tools: string[]) {
  // Try winget first
  const hasWinget = await checkCommand("winget");

  if (hasWinget) {
    console.log(chalk.blue("Using winget package manager..."));
    try {
      if (tools.includes("cmake")) await $`winget install -e --id Kitware.CMake`;
      if (tools.includes("ninja")) await $`winget install -e --id Ninja-build.Ninja`;
      if (tools.includes("clang")) await $`winget install -e --id LLVM.LLVM`;
      // LLVM package on Windows usually includes clang and openmp libs
      return;
    } catch (e) {
      console.warn(chalk.yellow("Winget installation failed, falling back to choco if available..."));
    }
  }

  // Fallback to Choco
  if (await checkCommand("choco")) {
    console.log(chalk.blue("Using Chocolatey package manager..."));
    if (tools.includes("cmake")) await $`choco install cmake --installargs 'ADD_CMAKE_TO_PATH=System' -y`;
    if (tools.includes("ninja")) await $`choco install ninja -y`;
    if (tools.includes("clang")) await $`choco install llvm -y`;
  } else {
    console.error(chalk.red("Neither winget nor choco found. Please install tools manually."));
  }
}

async function installLinuxTools(tools: string[]) {
  // Check for apt-get
  if (await checkCommand("apt-get")) {
    console.log(chalk.blue("Using apt-get... (requires sudo)"));

    const packages: string[] = [];
    if (tools.includes("ninja")) packages.push("ninja-build");
    if (tools.includes("clang")) packages.push("clang");

    // Always ensure OpenMP and build essentials
    packages.push("libomp-dev", "build-essential");

    // Cross compilation tools
    if (tools.includes("cross-arm64")) packages.push("gcc-aarch64-linux-gnu", "g++-aarch64-linux-gnu");
    if (tools.includes("cross-armv7")) packages.push("gcc-arm-linux-gnueabihf", "g++-arm-linux-gnueabihf");

    // CMake often needs a newer version than apt provides, but for simplicity:
    if (tools.includes("cmake")) packages.push("cmake");

    if (packages.length > 0) {
      const installCmd = `sudo apt-get install -y ${packages.join(" ")}`;
      try {
        await $`sudo apt-get update`;
        await $`sudo apt-get install -y ${packages}`;
      } catch (e) {
        console.error(chalk.red("\n❌ Installation failed."));
        console.error(chalk.yellow("Please run the following command manually to install the required tools:"));
        console.log(chalk.bold(`\n${installCmd}\n`));
        process.exit(1);
      }
    }
  } else {
    console.error(chalk.red("Only apt-get is supported for auto-install on Linux currently."));
  }
}

async function installMacTools(tools: string[]) {
  if (await checkCommand("brew")) {
    console.log(chalk.blue("Using Homebrew..."));
    const packages: string[] = [];
    if (tools.includes("cmake")) packages.push("cmake");
    if (tools.includes("ninja")) packages.push("ninja");
    if (tools.includes("clang")) {
      // macOS usually has clang via Xcode Command Line Tools
      // But we can install llvm from brew if needed
      // packages.push("llvm");
      console.log("Note: Clang is usually provided by Xcode Command Line Tools. Run 'xcode-select --install' if missing.");
    }
    // OpenMP for Mac
    packages.push("libomp");

    if (packages.length > 0) {
      await $`brew install ${packages}`;
    }
  } else {
    console.error(chalk.red("Homebrew not found. Please install tools manually."));
  }
}

main().catch(console.error);
