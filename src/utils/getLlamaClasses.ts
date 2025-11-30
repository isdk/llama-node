import { LlamaCompletion } from "../evaluator/LlamaCompletion.js";

export type LlamaClasses = {
    readonly LlamaCompletion: typeof LlamaCompletion
};

let cachedClasses: LlamaClasses | undefined = undefined;

export function getLlamaClasses(): LlamaClasses {
    if (cachedClasses == null)
        cachedClasses = Object.seal({
            LlamaCompletion
        });

    return cachedClasses;
}
