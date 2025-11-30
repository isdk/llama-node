import { MessageMarkdown } from "../../../MessageMarkdown/MessageMarkdown.js";
import { ChatMessage } from "../../../../../../electron/state/llmState.js";
import { ModelMessageCopyButton } from "./components/ModelMessageCopyButton/ModelMessageCopyButton.js";

import "./ModelMessage.css";

export function ModelMessage({ message, active }: ModelMessageProps) {
    return <div className="message model">
        <MessageMarkdown
            activeDot={active}
            className="text"
        >
            {message.content}
        </MessageMarkdown>
        {
            (message.content === "" && active) &&
            <MessageMarkdown className="text" activeDot />
        }
        <div className="buttons" inert={active}>
            <ModelMessageCopyButton content={message.content} />
        </div>
    </div>;
}

type ModelMessageProps = {
    message: ChatMessage,
    active: boolean
};
