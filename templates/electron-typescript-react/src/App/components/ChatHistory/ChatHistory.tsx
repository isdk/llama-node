import { useMemo } from "react";
import classNames from "classnames";
import { ChatMessage } from "../../../../electron/state/llmState.ts";
import { UserMessage } from "./components/UserMessage/UserMessage.js";
import { ModelMessage } from "./components/ModelMessage/ModelMessage.js";

import "./ChatHistory.css";


export function ChatHistory({ chatHistory, generatingResult, className }: ChatHistoryProps) {
    const renderChatItems = useMemo(() => {
        if (chatHistory.length > 0 &&
            chatHistory.at(-1)!.role !== "assistant" &&
            generatingResult
        )
            return [...chatHistory, emptyAssistantMessage];

        return chatHistory;
    }, [chatHistory, generatingResult]);

    return <div className={classNames("appChatHistory", className)}>
        {
            renderChatItems
                .map((item, index) => {
                    if (item.role === "assistant")
                        return <ModelMessage
                            key={index}
                            message={item}
                            active={index === renderChatItems.length - 1 && generatingResult}
                        />;
                    else if (item.role === "user")
                        return <UserMessage key={index} message={item} />;

                    return null;
                })
        }
    </div>;
}

type ChatHistoryProps = {
    chatHistory: ChatMessage[],
    generatingResult: boolean,
    className?: string
};

const emptyAssistantMessage: ChatMessage = {
    role: "assistant",
    content: ""
};
