import { CommandModule } from "yargs";
import { withCliCommandDescriptionDocsUrl } from "../../utils/withCliCommandDescriptionDocsUrl.js";
import { documentationPageUrls } from "../../../config.js";
import { DownloadCommand } from "./commands/DownloadCommand.js";
import { BuildCommand } from "./commands/BuildCommand.js";
import { ClearCommand } from "./commands/ClearCommand.js";
import { PullCommand } from "./commands/PullCommand.js";

type SourceCommand = {
    // no options for now
};

export const SourceCommand: CommandModule<object, SourceCommand> = {
    command: "source <command>",
    describe: withCliCommandDescriptionDocsUrl(
        "Manage `llama.cpp` source code",
        documentationPageUrls.CLI.Source.index
    ),
    builder(yargs) {
        return yargs
            .command(DownloadCommand)
            .command(PullCommand)
            .command(BuildCommand)
            .command(ClearCommand);
    },
    async handler() {
        // this function must exist, even though we do nothing here
    }
};
