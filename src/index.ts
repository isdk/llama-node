import { DisposedError } from "lifecycle-utils";
import { Llama } from "./bindings/Llama.js";
import { getLlama, type LlamaOptions, type LastBuildOptions } from "./bindings/getLlama.js";
import { getLlamaGpuTypes } from "./bindings/utils/getLlamaGpuTypes.js";
import { NoBinaryFoundError } from "./bindings/utils/NoBinaryFoundError.js";
import {
    type LlamaGpuType, type LlamaNuma, LlamaLogLevel, LlamaLogLevelGreaterThan, LlamaLogLevelGreaterThanOrEqual, LlamaVocabularyType
} from "./bindings/types.js";
import { resolveModelFile, type ResolveModelFileOptions } from "./utils/resolveModelFile.js";
import { LlamaModel, LlamaModelInfillTokens, type LlamaModelOptions, LlamaModelTokens } from "./evaluator/LlamaModel/LlamaModel.js";
import { TokenAttributes } from "./evaluator/LlamaModel/utils/TokenAttributes.js";
import { LlamaGrammar, type LlamaGrammarOptions } from "./evaluator/LlamaGrammar.js";
import { LlamaJsonSchemaGrammar } from "./evaluator/LlamaJsonSchemaGrammar.js";
import { LlamaJsonSchemaValidationError } from "./utils/gbnfJson/utils/validateObjectAgainstGbnfSchema.js";
import { LlamaGrammarEvaluationState, LlamaGrammarEvaluationStateOptions } from "./evaluator/LlamaGrammarEvaluationState.js";
import { LlamaContext, LlamaContextSequence } from "./evaluator/LlamaContext/LlamaContext.js";
import { LlamaEmbeddingContext, type LlamaEmbeddingContextOptions } from "./evaluator/LlamaEmbeddingContext.js";
import { LlamaEmbedding, type LlamaEmbeddingOptions, type LlamaEmbeddingJSON } from "./evaluator/LlamaEmbedding.js";
import { LlamaRankingContext, type LlamaRankingContextOptions } from "./evaluator/LlamaRankingContext.js";
import {
    type LlamaContextOptions, type SequenceEvaluateOptions, type BatchingOptions, type LlamaContextSequenceRepeatPenalty,
    type CustomBatchingDispatchSchedule, type CustomBatchingPrioritizationStrategy, type BatchItem, type PrioritizedBatchItem,
    type ContextShiftOptions, type ContextTokensDeleteRange, type EvaluationPriority, type SequenceEvaluateMetadataOptions,
    type SequenceEvaluateOutput, type ControlledEvaluateInputItem, type ControlledEvaluateIndexOutput
} from "./evaluator/LlamaContext/types.js";
import { TokenBias } from "./evaluator/TokenBias.js";

import {
    LlamaCompletion, type LlamaCompletionOptions, type LlamaCompletionGenerationOptions, type LlamaInfillGenerationOptions,
    type LlamaCompletionResponse
} from "./evaluator/LlamaCompletion.js";
import { TokenMeter, type TokenMeterState } from "./evaluator/TokenMeter.js";
import { UnsupportedError } from "./utils/UnsupportedError.js";
import { InsufficientMemoryError } from "./utils/InsufficientMemoryError.js";

import {
    LlamaText, SpecialTokensText, SpecialToken, isLlamaText, tokenizeText, type LlamaTextValue, type LlamaTextInputValue,
    type LlamaTextJSON, type LlamaTextJSONValue, type LlamaTextSpecialTokensTextJSON, type LlamaTextSpecialTokenJSON,
    type BuiltinSpecialTokenValue
} from "./utils/LlamaText.js";

import { TokenPredictor } from "./evaluator/LlamaContext/TokenPredictor.js";
import { DraftSequenceTokenPredictor } from "./evaluator/LlamaContext/tokenPredictors/DraftSequenceTokenPredictor.js";
import { InputLookupTokenPredictor } from "./evaluator/LlamaContext/tokenPredictors/InputLookupTokenPredictor.js";
import { getModuleVersion } from "./utils/getModuleVersion.js";
import { readGgufFileInfo } from "./gguf/readGgufFileInfo.js";
import { GgufInsights, type GgufInsightsResourceRequirements } from "./gguf/insights/GgufInsights.js";
import { GgufInsightsConfigurationResolver } from "./gguf/insights/GgufInsightsConfigurationResolver.js";
import { GgufInsightsTokens } from "./gguf/insights/GgufInsightsTokens.js";
import {
    createModelDownloader, ModelDownloader, type ModelDownloaderOptions, combineModelDownloaders, CombinedModelDownloader,
    type CombinedModelDownloaderOptions
} from "./utils/createModelDownloader.js";


import {
    type Token, type Tokenizer, type Detokenizer,
    type LLamaContextualRepeatPenalty
} from "./types.js";

import {
    type GbnfJsonArraySchema, type GbnfJsonBasicSchema, type GbnfJsonConstSchema, type GbnfJsonEnumSchema, type GbnfJsonStringSchema,
    type GbnfJsonBasicStringSchema, type GbnfJsonFormatStringSchema, type GbnfJsonObjectSchema, type GbnfJsonOneOfSchema,
    type GbnfJsonSchema, type GbnfJsonSchemaImmutableType, type GbnfJsonSchemaToType
} from "./utils/gbnfJson/types.js";
import { type GgufFileInfo } from "./gguf/types/GgufFileInfoTypes.js";
import {
    type GgufMetadata, type GgufMetadataLlmToType, GgufArchitectureType, GgufFileType, GgufMetadataTokenizerTokenType,
    GgufMetadataArchitecturePoolingType, type GgufMetadataGeneral, type GgufMetadataTokenizer, type GgufMetadataDefaultArchitectureType,
    type GgufMetadataLlmLLaMA, type GgufMetadataMPT, type GgufMetadataGPTNeoX, type GgufMetadataGPTJ, type GgufMetadataGPT2,
    type GgufMetadataBloom, type GgufMetadataFalcon, type GgufMetadataMamba, isGgufMetadataOfArchitectureType
} from "./gguf/types/GgufMetadataTypes.js";
import { GgmlType, type GgufTensorInfo } from "./gguf/types/GgufTensorInfoTypes.js";
import { type ModelFileAccessTokens } from "./utils/modelFileAccessTokens.js";
import { type OverridesObject } from "./utils/OverridesObject.js";
import type { LlamaClasses } from "./utils/getLlamaClasses.js";



export {
    type Token, type Tokenizer, type Detokenizer,
    type LLamaContextualRepeatPenalty,
    Llama,
    getLlama,
    getLlamaGpuTypes,
    type LlamaOptions,
    type LastBuildOptions,
    type LlamaGpuType,
    type LlamaNuma,
    type LlamaClasses,
    LlamaLogLevel,
    NoBinaryFoundError,
    resolveModelFile,
    type ResolveModelFileOptions,
    LlamaModel,
    LlamaModelTokens,
    LlamaModelInfillTokens,
    TokenAttributes,
    type LlamaModelOptions,
    LlamaGrammar,
    type LlamaGrammarOptions,
    LlamaJsonSchemaGrammar,
    LlamaJsonSchemaValidationError,
    LlamaGrammarEvaluationState,
    type LlamaGrammarEvaluationStateOptions,
    LlamaContext,
    LlamaContextSequence,
    type LlamaContextOptions,
    type SequenceEvaluateOptions,
    type BatchingOptions,
    type CustomBatchingDispatchSchedule,
    type CustomBatchingPrioritizationStrategy,
    type BatchItem,
    type PrioritizedBatchItem,
    type ContextShiftOptions,
    type ContextTokensDeleteRange,
    type EvaluationPriority,
    type SequenceEvaluateMetadataOptions,
    type SequenceEvaluateOutput,
    type LlamaContextSequenceRepeatPenalty,
    type ControlledEvaluateInputItem,
    type ControlledEvaluateIndexOutput,
    TokenBias,
    LlamaEmbeddingContext,
    type LlamaEmbeddingContextOptions,
    LlamaEmbedding,
    type LlamaEmbeddingOptions,
    type LlamaEmbeddingJSON,
    LlamaRankingContext,
    type LlamaRankingContextOptions,

    LlamaCompletion,
    type LlamaCompletionOptions,
    type LlamaCompletionGenerationOptions,
    type LlamaInfillGenerationOptions,
    type LlamaCompletionResponse,
    TokenMeter,
    type TokenMeterState,
    UnsupportedError,
    InsufficientMemoryError,
    DisposedError,

    LlamaText,
    SpecialTokensText,
    SpecialToken,
    isLlamaText,
    tokenizeText,
    type LlamaTextValue,
    type LlamaTextInputValue,
    type LlamaTextJSON,
    type LlamaTextJSONValue,
    type LlamaTextSpecialTokensTextJSON,
    type LlamaTextSpecialTokenJSON,
    type BuiltinSpecialTokenValue,
    TokenPredictor,
    DraftSequenceTokenPredictor,
    InputLookupTokenPredictor,

    getModuleVersion,

    type GbnfJsonSchema,
    type GbnfJsonSchemaToType,
    type GbnfJsonSchemaImmutableType,
    type GbnfJsonBasicSchema,
    type GbnfJsonConstSchema,
    type GbnfJsonEnumSchema,
    type GbnfJsonBasicStringSchema,
    type GbnfJsonFormatStringSchema,
    type GbnfJsonStringSchema,
    type GbnfJsonOneOfSchema,
    type GbnfJsonObjectSchema,
    type GbnfJsonArraySchema,
    LlamaVocabularyType,
    LlamaLogLevelGreaterThan,
    LlamaLogLevelGreaterThanOrEqual,
    readGgufFileInfo,
    type GgufFileInfo,
    type GgufMetadata,
    type GgufTensorInfo,
    type GgufMetadataLlmToType,
    GgufArchitectureType,
    GgufFileType,
    GgufMetadataTokenizerTokenType,
    GgufMetadataArchitecturePoolingType,
    type GgufMetadataGeneral,
    type GgufMetadataTokenizer,
    type GgufMetadataDefaultArchitectureType,
    type GgufMetadataLlmLLaMA,
    type GgufMetadataMPT,
    type GgufMetadataGPTNeoX,
    type GgufMetadataGPTJ,
    type GgufMetadataGPT2,
    type GgufMetadataBloom,
    type GgufMetadataFalcon,
    type GgufMetadataMamba,
    GgmlType,
    isGgufMetadataOfArchitectureType,
    GgufInsights,
    type GgufInsightsResourceRequirements,
    GgufInsightsTokens,
    GgufInsightsConfigurationResolver,
    createModelDownloader,
    ModelDownloader,
    type ModelDownloaderOptions,
    type ModelFileAccessTokens,
    combineModelDownloaders,
    CombinedModelDownloader,
    type CombinedModelDownloaderOptions,

    type OverridesObject
};
