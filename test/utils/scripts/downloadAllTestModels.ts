import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import { downloadAllModels, modelGroups } from "../modelFiles.js";

const argv = await yargs(hideBin(process.argv))
  .option("group", {
    type: "string",
    array: true,
    choices: Object.keys(modelGroups),
    description: "Model groups to download"
  })
  .help()
  .parse();

await downloadAllModels({
  groups: argv.group as any
});
process.exit(0);
