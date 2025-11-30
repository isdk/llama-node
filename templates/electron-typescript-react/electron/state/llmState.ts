import path from "node:path";
import {
    getLlama, Llama, LlamaCompletion, LlamaContext, LlamaContextSequence, LlamaModel
} from "@isdk/llama-node";
import { withLock, State } from "lifecycle-utils";
import packageJson from "../../package.json";

export const llmState = new State<LlmState>({
    appVersion: packageJson.version,
    llama: {
        loaded: false
    },
    model: {
        loaded: false
    },
    context: {
        loaded: false
    },
    contextSequence: {
        loaded: false
    },
    chatSession: {
        loaded: false,
        generatingResult: false,
        chatHistory: [],
        draftPrompt: ""
    }
});

export type LlmState = {
    appVersion?: string,
    llama: {
        loaded: boolean,
        error?: string
    },
    selectedModelFilePath?: string,
    model: {
        loaded: boolean,
        loadProgress?: number,
        name?: string,
        error?: string
    },
    context: {
        loaded: boolean,
        error?: string
    },
    contextSequence: {
        loaded: boolean,
        error?: string
    },
    chatSession: {
        loaded: boolean,
        generatingResult: boolean,
        chatHistory: ChatMessage[],
        draftPrompt: string
    }
};

export type ChatMessage = {
    role: "user" | "assistant",
    content: string
};

let llama: Llama | null = null;
let model: LlamaModel | null = null;
let context: LlamaContext | null = null;
let contextSequence: LlamaContextSequence | null = null;
let completion: LlamaCompletion | null = null;
let promptAbortController: AbortController | null = null;

// Simple chat template formatting
function formatChatPrompt(history: ChatMessage[], newMessage?: string): string {
    const messages = newMessage
        ? [...history, { role: "user" as const, content: newMessage }]
        : history;

    // Simple chat format - can be customized based on model
    let prompt = "";
    for (const msg of messages) {
        if (msg.role === "user") {
            prompt += `User: ${msg.content}\n`;
        } else {
            prompt += `Assistant: ${msg.content}\n`;
        }
    }

    if (newMessage) {
        prompt += "Assistant: ";
    }

    return prompt;
}

export const llmFunctions = {
    async loadLlama() {
        await withLock([llmFunctions, "llama"], async () => {
            if (llama != null) {
                try {
                    await llama.dispose();
                    llama = null;
                } catch (err) {
                    console.error("Failed to dispose llama", err);
                }
            }

            try {
                llmState.state = {
                    ...llmState.state,
                    llama: { loaded: false }
                };

                llama = await getLlama();
                llmState.state = {
                    ...llmState.state,
                    llama: { loaded: true }
                };

                llama.onDispose.createListener(() => {
                    llmState.state = {
                        ...llmState.state,
                        llama: { loaded: false }
                    };
                });
            } catch (err) {
                console.error("Failed to load llama", err);
                llmState.state = {
                    ...llmState.state,
                    llama: {
                        loaded: false,
                        error: String(err)
                    }
                };
            }
        });
    },
    async loadModel(modelPath: string) {
        await withLock([llmFunctions, "model"], async () => {
            if (llama == null)
                throw new Error("Llama not loaded");

            if (model != null) {
                try {
                    await model.dispose();
                    model = null;
                } catch (err) {
                    console.error("Failed to dispose model", err);
                }
            }

            try {
                llmState.state = {
                    ...llmState.state,
                    model: {
                        loaded: false,
                        loadProgress: 0
                    }
                };

                model = await llama.loadModel({
                    modelPath,
                    onLoadProgress(loadProgress: number) {
                        llmState.state = {
                            ...llmState.state,
                            model: {
                                ...llmState.state.model,
                                loadProgress
                            }
                        };
                    }
                });
                llmState.state = {
                    ...llmState.state,
                    model: {
                        loaded: true,
                        loadProgress: 1,
                        name: path.basename(modelPath)
                    }
                };

                model.onDispose.createListener(() => {
                    llmState.state = {
                        ...llmState.state,
                        model: { loaded: false }
                    };
                });
            } catch (err) {
                console.error("Failed to load model", err);
                llmState.state = {
                    ...llmState.state,
                    model: {
                        loaded: false,
                        error: String(err)
                    }
                };
            }
        });
    },
    async createContext() {
        await withLock([llmFunctions, "context"], async () => {
            if (model == null)
                throw new Error("Model not loaded");

            if (context != null) {
                try {
                    await context.dispose();
                    context = null;
                } catch (err) {
                    console.error("Failed to dispose context", err);
                }
            }

            try {
                llmState.state = {
                    ...llmState.state,
                    context: { loaded: false }
                };

                context = await model.createContext({
                    contextSize: 4096
                });
                llmState.state = {
                    ...llmState.state,
                    context: { loaded: true }
                };

                context.onDispose.createListener(() => {
                    llmState.state = {
                        ...llmState.state,
                        context: { loaded: false }
                    };
                });
            } catch (err) {
                console.error("Failed to create context", err);
                llmState.state = {
                    ...llmState.state,
                    context: {
                        loaded: false,
                        error: String(err)
                    }
                };
            }
        });
    },
    async createContextSequence() {
        await withLock([llmFunctions, "contextSequence"], async () => {
            if (context == null)
                throw new Error("Context not loaded");

            try {
                llmState.state = {
                    ...llmState.state,
                    contextSequence: { loaded: false }
                };

                contextSequence = context.getSequence();
                llmState.state = {
                    ...llmState.state,
                    contextSequence: { loaded: true }
                };

                contextSequence.onDispose.createListener(() => {
                    llmState.state = {
                        ...llmState.state,
                        contextSequence: { loaded: false }
                    };
                });
            } catch (err) {
                console.error("Failed to get context sequence", err);
                llmState.state = {
                    ...llmState.state,
                    contextSequence: {
                        loaded: false,
                        error: String(err)
                    }
                };
            }
        });
    },
    chatSession: {
        async createChatSession() {
            await withLock([llmFunctions, "chatSession"], async () => {
                if (contextSequence == null)
                    throw new Error("Context sequence not loaded");

                try {
                    llmState.state = {
                        ...llmState.state,
                        chatSession: {
                            loaded: false,
                            generatingResult: false,
                            chatHistory: [],
                            draftPrompt: ""
                        }
                    };

                    // Create completion instance
                    completion = new LlamaCompletion({
                        contextSequence
                    });

                    llmState.state = {
                        ...llmState.state,
                        chatSession: {
                            ...llmState.state.chatSession,
                            loaded: true
                        }
                    };
                } catch (err) {
                    console.error("Failed to create chat session", err);
                    llmState.state = {
                        ...llmState.state,
                        chatSession: {
                            loaded: false,
                            generatingResult: false,
                            chatHistory: [],
                            draftPrompt: ""
                        }
                    };
                }
            });
        },
        async prompt(message: string) {
            await withLock([llmFunctions, "chatSession"], async () => {
                if (completion == null)
                    throw new Error("Chat session not loaded");

                llmState.state = {
                    ...llmState.state,
                    chatSession: {
                        ...llmState.state.chatSession,
                        generatingResult: true,
                        draftPrompt: ""
                    }
                };
                promptAbortController = new AbortController();

                // Add user message to history
                const newHistory: ChatMessage[] = [
                    ...llmState.state.chatSession.chatHistory,
                    { role: "user", content: message }
                ];

                llmState.state = {
                    ...llmState.state,
                    chatSession: {
                        ...llmState.state.chatSession,
                        chatHistory: newHistory
                    }
                };

                const abortSignal = promptAbortController.signal;
                let assistantResponse = "";

                try {
                    // Format the prompt with chat history
                    const prompt = formatChatPrompt(llmState.state.chatSession.chatHistory);

                    // Generate completion with streaming
                    for await (const chunk of completion.generateCompletionWithMeta({
                        prompt,
                        maxTokens: 512,
                        temperature: 0.7,
                        signal: abortSignal,
                        onTextChunk(text: string) {
                            assistantResponse += text;

                            // Update state with partial response
                            llmState.state = {
                                ...llmState.state,
                                chatSession: {
                                    ...llmState.state.chatSession,
                                    chatHistory: [
                                        ...newHistory,
                                        { role: "assistant", content: assistantResponse }
                                    ]
                                }
                            };
                        }
                    })) {
                        // Streaming handled by onTextChunk
                    }
                } catch (err) {
                    if (err !== abortSignal.reason) {
                        console.error("Generation error:", err);
                        // Keep partial response if available
                    }
                }

                // Finalize with complete response
                const finalHistory: ChatMessage[] = assistantResponse
                    ? [...newHistory, { role: "assistant", content: assistantResponse }]
                    : newHistory;

                llmState.state = {
                    ...llmState.state,
                    chatSession: {
                        ...llmState.state.chatSession,
                        generatingResult: false,
                        chatHistory: finalHistory,
                        draftPrompt: ""
                    }
                };
            });
        },
        stopActivePrompt() {
            promptAbortController?.abort();
        },
        resetChatHistory() {
            llmState.state = {
                ...llmState.state,
                chatSession: {
                    ...llmState.state.chatSession,
                    chatHistory: [],
                    draftPrompt: ""
                }
            };
        },
        setDraftPrompt(prompt: string) {
            llmState.state = {
                ...llmState.state,
                chatSession: {
                    ...llmState.state.chatSession,
                    draftPrompt: prompt
                }
            };
        }
    }
} as const;
