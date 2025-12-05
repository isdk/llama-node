import path from "path";
import { fileURLToPath } from "url";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import fs from "fs-extra";
import { $, cd } from "zx";
import envVar from "env-var";

const env = envVar.from(process.env);
const GH_RELEASE_REF = env.get("GH_RELEASE_REF")
    .required()
    .asString();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const packageDirectory = path.join(__dirname, "..", "packages");
const prebuiltPackageDir = "prebuilt-llama-node";
const subPackagesDirectory = path.join(packageDirectory, prebuiltPackageDir);

const argv = await yargs(hideBin(process.argv))
    .option("packageVersion", {
        type: "string",
        demandOption: true
    })
    .option("force", {
        type: "boolean",
        default: false,
        description: "Force republish even if version already exists (will unpublish first)"
    })
    .argv;

const { packageVersion, force } = argv;
if (packageVersion === "")
    throw new Error("packageVersion is empty");

const packageNames = (await fs.readdir(subPackagesDirectory))
    .sort((a, b) => {
        if (a.endsWith("-ext"))
            return -1;
        else if (b.endsWith("-ext"))
            return 1;

        return a.localeCompare(b);
    });

/**
 * Check if a specific version of a package already exists on npm registry
 */
async function checkVersionExists(packageJsonName: string, version: string): Promise<boolean> {
    try {
        // Use npm view to check if the version exists
        const result = await $`npm view ${packageJsonName}@${version} version`.quiet();
        const existingVersion = result.stdout.trim();
        return existingVersion === version;
    } catch {
        // If npm view fails, the version doesn't exist
        return false;
    }
}

for (const packageName of packageNames) {
    const packagePath = path.join(subPackagesDirectory, packageName);
    const packagePackageJsonPath = path.join(packagePath, "package.json");

    if ((await fs.stat(packagePath)).isFile())
        continue;

    const packageJson = await fs.readJson(packagePackageJsonPath);
    const packageJsonName = packageJson.name;

    // Check if this version already exists on npm
    const versionExists = await checkVersionExists(packageJsonName, packageVersion);
    if (versionExists) {
        if (force) {
            console.info(`🔄 Force mode: unpublishing "${packageJsonName}@${packageVersion}" before republishing...`);
            try {
                await $`npm unpublish ${packageJsonName}@${packageVersion}`.quiet();
                console.info(`✅ Successfully unpublished "${packageJsonName}@${packageVersion}"`);
            } catch (err) {
                console.warn(`⚠️  Failed to unpublish "${packageJsonName}@${packageVersion}", trying to publish anyway...`);
            }
        } else {
            console.info(`⏭️  Skipping "${packageJsonName}@${packageVersion}" - version already exists on npm`);
            continue;
        }
    }

    packageJson.version = packageVersion;
    await fs.writeJson(packagePackageJsonPath, packageJson, { spaces: 2 });
    console.info(`Updated "${prebuiltPackageDir}/${packageName}/package.json" to version "${packageVersion}"`);

    $.verbose = true;
    cd(packagePath);

    if (GH_RELEASE_REF === "refs/heads/beta") {
        console.info(`Publishing "${prebuiltPackageDir}/${packageName}@${packageVersion}" to "beta" tag`);
        await $`npm publish --access public --tag beta`;
    } else {
        console.info(`Publishing "${prebuiltPackageDir}/${packageName}@${packageVersion}"`);
        await $`npm publish --access public`;
    }
}
