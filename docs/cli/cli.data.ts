import { CommandModule } from "yargs";
import { InspectCommand } from "../../src/cli/commands/inspect/InspectCommand.js";
import { InspectGpuCommand } from "../../src/cli/commands/inspect/commands/InspectGpuCommand.js";
import { InspectGgufCommand } from "../../src/cli/commands/inspect/commands/InspectGgufCommand.js";
import { SourceCommand } from "../../src/cli/commands/source/SourceCommand.js";
import { DownloadCommand } from "../../src/cli/commands/source/commands/DownloadCommand.js";
import { BuildCommand } from "../../src/cli/commands/source/commands/BuildCommand.js";
import { ClearCommand } from "../../src/cli/commands/source/commands/ClearCommand.js";
import { InspectMeasureCommand } from "../../src/cli/commands/inspect/commands/InspectMeasureCommand.js";
import { InspectEstimateCommand } from "../../src/cli/commands/inspect/commands/InspectEstimateCommand.js";
import { cliBinName, npxRunPrefix } from "../../src/config.js";
import { htmlEscape } from "../../.vitepress/utils/htmlEscape.js";
import { getCommandHtmlDoc } from "../../.vitepress/utils/getCommandHtmlDoc.js";
import { buildHtmlHeading } from "../../.vitepress/utils/buildHtmlHeading.js";
import { buildHtmlTable } from "../../.vitepress/utils/buildHtmlTable.js";
import { setIsInDocumentationMode } from "../../src/state.js";
import { htmlEscapeWithCodeMarkdown } from "../../.vitepress/utils/htmlEscapeWithCodeMarkdown.js";
import { getInlineCodeBlockHtml } from "../../.vitepress/utils/getInlineCodeBlockHtml.js";
import { getMarkdownRenderer } from "../../.vitepress/utils/getMarkdownRenderer.js";
import { withoutCliCommandDescriptionDocsUrl } from "../../src/cli/utils/withCliCommandDescriptionDocsUrl.js";

export default {
    async load() {
        setIsInDocumentationMode(true);

        return {
            index: await buildIndexTable([
                ["inspect", InspectCommand],
                ["source", SourceCommand]
            ]),

            inspect: {
                index: await getCommandHtmlDoc(InspectCommand, {
                    subCommandsParentPageLink: "inspect"
                }),
                gpu: await getCommandHtmlDoc(InspectGpuCommand, {
                    parentCommand: InspectCommand
                }),
                gguf: await getCommandHtmlDoc(InspectGgufCommand, {
                    parentCommand: InspectCommand
                }),
                measure: await getCommandHtmlDoc(InspectMeasureCommand, {
                    parentCommand: InspectCommand
                }),
                estimate: await getCommandHtmlDoc(InspectEstimateCommand, {
                    parentCommand: InspectCommand
                })
            },
            source: {
                index: await getCommandHtmlDoc(SourceCommand, {
                    subCommandsParentPageLink: "source"
                }),
                download: await getCommandHtmlDoc(DownloadCommand, {
                    parentCommand: SourceCommand
                }),
                build: await getCommandHtmlDoc(BuildCommand, {
                    parentCommand: SourceCommand
                }),
                clear: await getCommandHtmlDoc(ClearCommand, {
                    parentCommand: SourceCommand
                })
            }
        };
    }
};

async function buildIndexTable(commands: [pageLink: string, command: CommandModule<any, any>][], cliName: string = cliBinName) {
    let res = "";
    const markdownRenderer = await getMarkdownRenderer();

    res += buildHtmlHeading("h2", htmlEscape("Commands"), "commands");
    res += buildHtmlTable(
        [
            "Command",
            "Description"
        ].map(htmlEscape),
        commands
            .map(([pageLink, command]) => {
                if (command.describe === false)
                    return null;

                return [
                    getInlineCodeBlockHtml(markdownRenderer, cliName + " " + command.command, "shell", pageLink),
                    htmlEscapeWithCodeMarkdown(withoutCliCommandDescriptionDocsUrl(String(command.describe ?? "")))
                ];
            })
            .filter((row): row is string[] => row != null)
    );

    res += buildHtmlHeading("h2", htmlEscape("Options"), "options");
    res += buildHtmlTable(
        [
            "Command",
            "Description"
        ].map(htmlEscape),
        [
            [
                `<code style="white-space: nowrap">${htmlEscape("-h")}</code>` +
                `${htmlEscape(", ")}` +
                `<code style="white-space: nowrap">${htmlEscape("--help")}</code>`,

                htmlEscape("Show help")
            ],
            [
                `<code style="white-space: nowrap">${htmlEscape("-v")}</code>` +
                `${htmlEscape(", ")}` +
                `<code style="white-space: nowrap">${htmlEscape("--version")}</code>`,

                htmlEscape("Show version number")
            ]
        ]
    );

    const usage = npxRunPrefix + cliName + " <command> [options]";

    return {
        title: "CLI",
        description: null,
        usage,
        usageHtml: markdownRenderer.render("```shell\n" + usage + "\n```"),
        options: res
    };
}
