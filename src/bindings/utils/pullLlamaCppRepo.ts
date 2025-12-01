import simpleGit from "simple-git";
import fs from "fs-extra";
import { llamaCppDirectory } from "../../config.js";
import { getConsoleLogPrefix } from "../../utils/getConsoleLogPrefix.js";

export async function pullLlamaCppRepo() {
  if (!await fs.pathExists(llamaCppDirectory)) {
    throw new Error("llama.cpp directory does not exist. Please run `download` first.");
  }

  const git = simpleGit(llamaCppDirectory);

  // Check if it is a git repo
  if (!await git.checkIsRepo()) {
    throw new Error("llama.cpp directory is not a git repository.");
  }

  console.log(getConsoleLogPrefix() + "Pulling changes...");
  await git.pull();
}
