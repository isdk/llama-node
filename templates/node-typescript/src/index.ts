import { fileURLToPath } from "url";
import path from "path";
import chalk from "chalk";
import { getLlama, LlamaCompletion, LlamaJsonSchemaGrammar, resolveModelFile } from "@isdk/llama-node";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const modelsDirectory = path.join(__dirname, "..", "models");


const llama = await getLlama();

console.log(chalk.yellow("Resolving model file..."));
const modelPath = await resolveModelFile(
    "{{modelUriOrFilename|escape}}",
    modelsDirectory
);

console.log(chalk.yellow("Loading model..."));
const model = await llama.loadModel({ modelPath });

console.log(chalk.yellow("Creating context..."));
const context = await model.createContext({
    contextSize: 8096 // adjust based on your model and memory
});

// Create a completion instance for text generation
const completion = new LlamaCompletion({
    contextSequence: context.getSequence()
});
console.log();


// Example 1: Basic text completion
console.log(chalk.bold.cyan("=== Example 1: Basic Text Completion ==="));
const prompt1 = "The meaning of life is";
console.log(chalk.yellow("Prompt: ") + prompt1);

process.stdout.write(chalk.yellow("AI: "));
const result1 = await completion.generateCompletion({
    prompt: prompt1,
    maxTokens: 100,
    onToken(chunk) {
        // Stream the response token by token
        process.stdout.write(chunk);
    }
});
process.stdout.write("\n\n");


// Example 2: Grammar-based JSON generation
console.log(chalk.bold.cyan("=== Example 2: Grammar-based JSON Generation ==="));
const prompt2 = "List the primary colors and their RGB values";
console.log(chalk.yellow("Prompt: ") + prompt2);

// Define a JSON schema for structured output
const colorSchema = {
    type: "object",
    properties: {
        colors: {
            type: "array",
            items: {
                type: "object",
                properties: {
                    name: { type: "string" },
                    rgb: {
                        type: "object",
                        properties: {
                            r: { type: "number" },
                            g: { type: "number" },
                            b: { type: "number" }
                        },
                        required: ["r", "g", "b"]
                    }
                },
                required: ["name", "rgb"]
            }
        }
    },
    required: ["colors"]
} as const;

const grammar = new LlamaJsonSchemaGrammar(llama, colorSchema);

const result2 = await completion.generateCompletion({
    prompt: prompt2,
    grammar,
    maxTokens: 300
});

console.log(chalk.yellow("AI (JSON): "));
const parsed = JSON.parse(result2.text);
console.log(JSON.stringify(parsed, null, 2));
console.log();


// Example 3: Tokenization
console.log(chalk.bold.cyan("=== Example 3: Tokenization ==="));
const text = "Hello, world! This is a test.";
console.log(chalk.yellow("Text: ") + text);

const tokens = model.tokenize(text);
console.log(chalk.yellow("Tokens: ") + JSON.stringify(tokens));
console.log(chalk.yellow("Token count: ") + tokens.length);

const detokenized = model.detokenize(tokens);
console.log(chalk.yellow("Detokenized: ") + detokenized);
console.log();


// Example 4: Embeddings (if model supports it)
console.log(chalk.bold.cyan("=== Example 4: Model Info ==="));
console.log(chalk.yellow("Model path: ") + modelPath);
console.log(chalk.yellow("Context size: ") + context.contextSize);
console.log(chalk.yellow("Vocabulary size: ") + model.tokenize("").length);
console.log();

console.log(chalk.green("✓ All examples completed!"));

