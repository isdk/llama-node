import { MessageMarkdown } from "../../../MessageMarkdown/MessageMarkdown.js";
import { ChatMessage } from "../../../../../../electron/state/llmState.js";

import "./UserMessage.css";

export function UserMessage({ message }: UserMessageProps) {
    return <MessageMarkdown className="message user">
        {message.content}
    </MessageMarkdown>;
}

type UserMessageProps = {
    message: ChatMessage
};
