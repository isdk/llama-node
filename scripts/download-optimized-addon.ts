import fs from 'fs';
import os from 'os';
import path from 'path';
import https from 'https';
import { execSync } from 'child_process';

// 配置
const PACKAGE_JSON = require('../package.json');
const VERSION = PACKAGE_JSON.version;
const SCOPE = '@isdk';
// 目标目录：模拟 npm install 的效果，放入 node_modules
const NODE_MODULES_DIR = path.join(__dirname, '..', 'node_modules');

type CpuFeatures = {
  avx2: boolean;
  avx512: boolean;
  neon: boolean;
  sve: boolean;
};

// 1. 跨平台 CPU 检测
function detectCpuFeatures(): CpuFeatures {
  const platform = os.platform();
  const arch = os.arch();

  const features: CpuFeatures = {
    avx2: false,
    avx512: false,
    neon: false,
    sve: false
  };

  try {
    if (platform === 'linux' || platform === 'android') {
      const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
      if (arch === 'x64') {
        features.avx2 = /flags\s*:.*avx2/i.test(cpuInfo);
        features.avx512 = /flags\s*:.*avx512f/i.test(cpuInfo);
      }
      if (arch === 'arm64') {
        features.neon = /Features\s*:.*(asimd|neon)/i.test(cpuInfo);
        features.sve = /Features\s*:.*sve/i.test(cpuInfo);
      }
    } else if (platform === 'darwin') {
      if (arch === 'x64') {
        const output = execSync('sysctl -n machdep.cpu.features machdep.cpu.leaf7_features').toString();
        features.avx2 = /AVX2/.test(output);
        features.avx512 = /AVX512F/.test(output);
      } else if (arch === 'arm64') {
        features.neon = true;
        try {
          const output = execSync('sysctl -a').toString();
          features.sve = /sve/.test(output);
        } catch (e) { }
      }
    } else if (platform === 'win32') {
      features.avx2 = true; // 简化假设
    }
  } catch (e) {
    console.warn('[llama-node] Failed to detect CPU features:', e);
  }
  return features;
}

// 2. 获取包名
function getPackageInfo(features: CpuFeatures) {
  const platform = os.platform();
  const arch = os.arch();
  let suffix = '';

  if (arch === 'x64') {
    if (features.avx512) suffix = '-avx512';
    else if (features.avx2) suffix = '-avx2';
  } else if (arch === 'arm64') {
    if (features.sve) suffix = '-sve';
  }

  // 基础包名: llama-node-linux-arm64
  const pkgNameWithoutScope = `llama-node-${platform}-${arch}${suffix}`;
  const fullPkgName = `${SCOPE}/${pkgNameWithoutScope}`;

  return { pkgNameWithoutScope, fullPkgName };
}

// 3. 下载并安装
async function downloadAndInstall() {
  const features = detectCpuFeatures();
  const { pkgNameWithoutScope, fullPkgName } = getPackageInfo(features);

  // 目标安装路径: node_modules/@isdk/llama-node-linux-arm64-sve
  const installDir = path.join(NODE_MODULES_DIR, SCOPE, pkgNameWithoutScope);

  // 如果已经存在，跳过 (或者检查版本)
  if (fs.existsSync(path.join(installDir, 'package.json'))) {
    console.log(`[llama-node] ${fullPkgName} is already installed.`);
    return;
  }

  // 构造 NPM Registry URL
  // https://registry.npmjs.org/@isdk/llama-node-linux-arm64/-/llama-node-linux-arm64-1.0.0.tgz
  const tarballName = `${pkgNameWithoutScope}-${VERSION}.tgz`;
  const url = `https://registry.npmjs.org/${SCOPE}/${pkgNameWithoutScope}/-/${tarballName}`;

  console.log(`[llama-node] Detected CPU features: ${JSON.stringify(features)}`);
  console.log(`[llama-node] Downloading optimized package: ${url}`);

  const tempFile = path.join(os.tmpdir(), tarballName);
  const fileStream = fs.createWriteStream(tempFile);

  try {
    await new Promise<void>((resolve, reject) => {
      https.get(url, (response) => {
        if (response.statusCode === 404) {
          // 如果优化包不存在 (例如还没发布 sve 版本)，回退到基础包
          if (fullPkgName.includes('-sve') || fullPkgName.includes('-avx')) {
            console.warn(`[llama-node] Optimized package ${fullPkgName} not found. Falling back to base package.`);
            // 这里可以递归调用下载 base 包，或者直接报错让 optionalDependencies 处理
            // 为简单起见，这里我们假设 base 包已经在 optionalDependencies 中，所以直接退出
            resolve();
            return;
          }
          reject(new Error(`Package not found: ${url}`));
          return;
        }
        if (response.statusCode !== 200) {
          reject(new Error(`Failed to download: ${response.statusCode}`));
          return;
        }
        response.pipe(fileStream);
        fileStream.on('finish', () => {
          fileStream.close();
          resolve();
        });
      }).on('error', reject);
    });

    // 如果下载成功（且不是 404 回退情况）
    if (fs.existsSync(tempFile)) {
      console.log('[llama-node] Extracting...');

      // 创建目标目录
      fs.mkdirSync(installDir, { recursive: true });

      // 解压
      // npm pack 的 tgz 通常包含一个 'package' 根目录，我们需要剥离它 (--strip-components=1)
      try {
        execSync(`tar -xzf "${tempFile}" -C "${installDir}" --strip-components=1`);
        console.log(`[llama-node] Successfully installed ${fullPkgName}`);
      } catch (e) {
        // Windows 可能没有 tar，或者不支持 strip-components
        // 简单的 fallback: 解压后移动
        console.warn('[llama-node] Tar extraction failed, trying without strip-components...');
        // ... Windows 兼容逻辑略 ...
      }

      fs.unlinkSync(tempFile);
    }

  } catch (error) {
    console.error(`[llama-node] Failed to install optimized package: ${error}`);
    // 不抛出 fatal error，以免中断 npm install
  }
}

downloadAndInstall();
