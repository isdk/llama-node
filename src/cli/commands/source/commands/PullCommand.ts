import { CommandModule } from "yargs";
import chalk from "chalk";
import { documentationPageUrls } from "../../../../config.js";
import { pullLlamaCppRepo } from "../../../../bindings/utils/pullLlamaCppRepo.js";
import { withCliCommandDescriptionDocsUrl } from "../../../utils/withCliCommandDescriptionDocsUrl.js";

type PullCommandArgs = {
  // no options for now
};

export const PullCommand: CommandModule<object, PullCommandArgs> = {
  command: "pull",
  describe: withCliCommandDescriptionDocsUrl(
    "Update the local `llama.cpp` source code",
    documentationPageUrls.CLI.Source.Pull
  ),
  builder(yargs) {
    return yargs;
  },
  handler: PullLlamaCppCommand
};

export async function PullLlamaCppCommand(args: PullCommandArgs) {
  console.log(chalk.blue("Pulling llama.cpp..."));
  await pullLlamaCppRepo();
  console.log(chalk.green("Done"));
}
