import { describe, expect, it } from "vitest";
import { getModelFile } from "../utils/modelFiles.js";
import { getTestLlama } from "../utils/getTestLlama.js";
import { GbnfJsonSchema, LlamaCompletion } from "../../src/index.js";

describe("original completionSync vs LlamaCompletion", { timeout: 1000 * 60 * 10 }, async () => {
    const modelPath = await getModelFile("qwen2.5-1.5b-instruct.Q4_0.gguf");
    const llama = await getTestLlama();

    const model = await llama.loadModel({
        modelPath,
    });

    it("should same result", async () => {
        const prompt = "<|im_start|>system\nAccurately Extract THE INPUT CONTENT by the user as a JSON object according to THE JSON FIELDS in json schema format specified by the user:<|im_end|>\n<|im_start|>user\n\nTHE JSON FIELDS IN JSON SCHEMA FORMAT:\n* (array)\n * name: (optional) (string) The language name\n * value: (optional) (string) The ISO 639-1 language code\n---\n\nTHE INPUT CONTENT:\nhere are the language list:\n- English\n- Spanish\n- French\n- German\n- Italian\n- Portuguese\n- Chinese\n- Japanese\n- Korean\n- Russian\n---<|im_end|>\n<|im_start|>assistant\n";
        const schema: GbnfJsonSchema = {
            type: 'array',
            items: {
                type: 'object',
                properties: {
                    name: {
                        type: 'string'
                    },
                    value: {
                        type: 'string'
                    }
                }
            }
        }
        const jsonSchema = JSON.stringify(schema)
        const llamaCppRes: any = model.completionSync(prompt, { temperature: 0, topP: 0.9, jsonSchema });
        expect(llamaCppRes).toHaveProperty('content');
        const params = llamaCppRes.params;
        const llamaCppResult = llamaCppRes.content;

        const context = await model.createContext({
            contextSize: 4096
        });
        const contextSequence = context.getSequence();
        const completion = new LlamaCompletion({
            contextSequence
        });

        const tokens = model.tokenize(prompt, true);

        let res = await completion.generateCompletion(tokens, {
            temperature: 0,
            topP: 0.9,
            seed: params.seed,
            grammar: await llama.createGrammarForJsonSchema(schema),
        });
        expect(res).toBe(llamaCppResult);
        // contextSequence.clearHistory();
        // res = await completion.generateCompletion(prompt, {
        //     temperature: 0,
        //     topP: 0.9,
        //     // seed: params.seed,
        //     grammar: await llama.createGrammarForJsonSchema(schema as any),
        // });
    })
})

describe("LlamaModel", async () => {
    const modelPath = await getModelFile("gemma-2-2b-it.Q4_K_M.gguf");
    const llama = await getTestLlama();

    const model = await llama.loadModel({
        modelPath
    });

    it("should deTokenizePiece", async () => {
        const tokens = model.tokenize('<start_of_turn>', true);
        expect(tokens).toHaveLength(1);
        const result = model.detokenizePiece(tokens[0]);
        expect(result).toBe('<start_of_turn>');
    })

    it("should completionSync", async () => {
        const prompt = `<start_of_turn>user
This is a conversation between Mike and Llama, a friendly chatbot. Llama is helpful, kind, honest, good at writing, and never fails to answer any requests immediately and with precision.<end_of_turn>
<start_of_turn>Llama
What can I do for you, sir?<end_of_turn>
<start_of_turn>Mike
tell me 2+2 result directly, no other words.<end_of_turn>
<start_of_turn>Llama
`;
        const result: any = model.completionSync(prompt, { temperature: 1 });
        expect(result).toHaveProperty('content');
        expect(result.content).toMatch(/4/);
        expect(result).toHaveProperty('params');
        expect(result.params.temperature).toBe(1);
    })
})
