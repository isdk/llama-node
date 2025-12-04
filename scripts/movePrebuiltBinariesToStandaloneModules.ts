import path from "path";
import { fileURLToPath } from "url";
import fs from "fs-extra";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const packageDirectory = path.join(__dirname, "..", "packages");
const binsDirectory = path.join(__dirname, "..", "bins");

async function moveBinariesFolderToStandaloneModule(folderNameFilter: (folderName: string) => boolean, packageName: string) {
    for (const folderName of await fs.readdir(binsDirectory)) {
        if (!folderNameFilter(folderName))
            continue;

        const packagePath = path.join(packageDirectory, "prebuilt-llama-node", packageName);
        const packageBinsPath = path.join(packagePath, "bins");

        console.info(`Moving "${folderName}" to "${packageName}"`);

        await fs.ensureDir(packageBinsPath);
        await fs.move(path.join(binsDirectory, folderName), path.join(packageBinsPath, folderName));

        await fs.writeFile(
            path.join(binsDirectory, "_" + folderName + ".moved.txt"),
            `Moved to package "${packageName}"`,
            "utf8"
        );
    }
}

async function moveBinariesFallbackDirToStandaloneExtModule(folderNameFilter: (folderName: string) => boolean, packageName: string) {
    for (const folderName of await fs.readdir(binsDirectory)) {
        if (!folderNameFilter(folderName))
            continue;

        const packagePath = path.join(packageDirectory, "prebuilt-llama-node", packageName);
        const packageBinsPath = path.join(packagePath, "bins");
        const fallbackDir = path.join(binsDirectory, folderName, "fallback");

        if (!(await fs.pathExists(fallbackDir))) {
            console.warn(`No fallback directory in "${folderName}"`);
            continue;
        }

        console.info(`Moving "${folderName}/fallback" to "${packageName}"`);

        await fs.ensureDir(path.join(packageBinsPath, folderName));
        await fs.move(fallbackDir, path.join(packageBinsPath, folderName, "fallback"));
    }
}

await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("mac-arm64-metal"), "@isdk/llama-node-mac-arm64-metal");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("mac-x64"), "@isdk/llama-node-mac-x64");

await moveBinariesFallbackDirToStandaloneExtModule((folderName) => folderName.startsWith("linux-x64-cuda"), "@isdk/llama-node-linux-x64-cuda-ext");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("linux-x64-cuda"), "@isdk/llama-node-linux-x64-cuda");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("linux-x64-vulkan"), "@isdk/llama-node-linux-x64-vulkan");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("linux-x64"), "@isdk/llama-node-linux-x64");

await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("linux-arm64"), "@isdk/llama-node-linux-arm64");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("linux-armv7l"), "@isdk/llama-node-linux-armv7l");

await moveBinariesFallbackDirToStandaloneExtModule((folderName) => folderName.startsWith("win-x64-cuda"), "@isdk/llama-node-win-x64-cuda-ext");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("win-x64-cuda"), "@isdk/llama-node-win-x64-cuda");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("win-x64-vulkan"), "@isdk/llama-node-win-x64-vulkan");
await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("win-x64"), "@isdk/llama-node-win-x64");

await moveBinariesFolderToStandaloneModule((folderName) => folderName.startsWith("win-arm64"), "@isdk/llama-node-win-arm64");
