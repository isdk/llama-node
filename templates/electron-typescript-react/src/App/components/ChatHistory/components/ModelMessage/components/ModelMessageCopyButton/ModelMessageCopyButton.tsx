import classNames from "classnames";
import { useCallback, useState } from "react";
import { CopyIconSVG } from "../../../../../../../icons/CopyIconSVG.js";
import { CheckIconSVG } from "../../../../../../../icons/CheckIconSVG.js";

import "./ModelMessageCopyButton.css";

const showCopiedTime = 1000 * 2;

export function ModelMessageCopyButton({ content }: ModelMessageCopyButtonProps) {
    const [copies, setCopies] = useState(0);

    const onClick = useCallback(() => {
        navigator.clipboard.writeText(content.trim())
            .then(() => {
                setCopies(copies + 1);

                setTimeout(() => {
                    setCopies(copies - 1);
                }, showCopiedTime);
            })
            .catch((error) => {
                console.error("Failed to copy text to clipboard", error);
            });
    }, [content]);

    return <button
        onClick={onClick}
        className={classNames("copyButton", copies > 0 && "copied")}
    >
        <CopyIconSVG className="icon copy" />
        <CheckIconSVG className="icon check" />
    </button>;
}

type ModelMessageCopyButtonProps = {
    content: string
};
