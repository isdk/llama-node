#include <thread>
#include <sstream>
#include <cmath>
#include <nlohmann/json.hpp>
#include "addonGlobals.h"
#include "globals/addonLog.h"
#include "globals/addonProgress.h"
#include "common/common.h"
#include "llama.h"
#include "json-schema-to-grammar.h"
#include "sampling.h"
#include "AddonModel.h"
#include "AddonModelData.h"
#include "AddonModelLora.h"

using json = nlohmann::ordered_json;

static Napi::Value getNapiToken(const Napi::CallbackInfo& info, const llama_vocab* vocab, llama_token token) {
    if (token < 0 || token == LLAMA_TOKEN_NULL) {
        return Napi::Number::From(info.Env(), -1);
    }

    auto tokenAttributes = llama_vocab_get_attr(vocab, token);

    if (tokenAttributes & LLAMA_TOKEN_ATTR_UNDEFINED || tokenAttributes & LLAMA_TOKEN_ATTR_UNKNOWN) {
        return Napi::Number::From(info.Env(), -1);
    }

    return Napi::Number::From(info.Env(), token);
}

static Napi::Value getNapiControlToken(const Napi::CallbackInfo& info, const llama_vocab* vocab, llama_token token) {
    if (token < 0) {
        return Napi::Number::From(info.Env(), -1);
    }

    auto tokenAttributes = llama_vocab_get_attr(vocab, token);

    if (!(tokenAttributes & LLAMA_TOKEN_ATTR_CONTROL) && !(tokenAttributes & LLAMA_TOKEN_ATTR_UNDEFINED)) {
        return Napi::Number::From(info.Env(), -1);
    }

    return Napi::Number::From(info.Env(), token);
}

static bool llamaModelParamsProgressCallback(float progress, void * user_data) {
    AddonModel* addonModel = (AddonModel *) user_data;
    unsigned percentage = (unsigned) (100 * progress);

    if (percentage > addonModel->modelLoadPercentage) {
        addonModel->modelLoadPercentage = percentage;

        // original llama.cpp logs
        addonLlamaCppLogCallback(GGML_LOG_LEVEL_INFO, ".", nullptr);
        if (percentage >= 100) {
            addonLlamaCppLogCallback(GGML_LOG_LEVEL_INFO, "\n", nullptr);
        }
    }

    if (progress > addonModel->rawModelLoadPercentage) {
        addonModel->rawModelLoadPercentage = progress;

        if (addonModel->onLoadProgressEventCallbackSet) {
            addon_progress_event* data = new addon_progress_event {
                progress
            };

            auto status = addonModel->addonThreadSafeOnLoadProgressEventCallback.NonBlockingCall(data);

            if (status != napi_ok) {
                delete data;
            }
        }
    }

    return !(addonModel->abortModelLoad);
}

class AddonModelLoadModelWorker : public Napi::AsyncWorker {
    public:
        AddonModel* model;

        AddonModelLoadModelWorker(const Napi::Env& env, AddonModel* model)
            : Napi::AsyncWorker(env, "AddonModelLoadModelWorker"),
              model(model),
              deferred(Napi::Promise::Deferred::New(env)) {
            model->Ref();
        }
        ~AddonModelLoadModelWorker() {
            model->Unref();
        }

        Napi::Promise GetPromise() {
            return deferred.Promise();
        }

    protected:
        Napi::Promise::Deferred deferred;

        void Execute() {
            try {
                model->model = llama_model_load_from_file(model->modelPath.c_str(), model->model_params);
                model->vocab = llama_model_get_vocab(model->model);

                model->modelLoaded = model->model != nullptr && model->model != NULL;
            } catch (const std::exception& e) {
                SetError(e.what());
            } catch(...) {
                SetError("Unknown error when calling \"llama_model_load_from_file\"");
            }
        }
        void OnOK() {
            if (model->modelLoaded) {
                uint64_t modelSize = llama_model_size(model->model);
                adjustNapiExternalMemoryAdd(Env(), modelSize);
                model->loadedModelSize = modelSize;
            }

            deferred.Resolve(Napi::Boolean::New(Env(), model->modelLoaded));
            if (model->onLoadProgressEventCallbackSet) {
                model->addonThreadSafeOnLoadProgressEventCallback.Release();
            }
        }
        void OnError(const Napi::Error& err) {
            deferred.Reject(err.Value());
        }
};

class AddonModelUnloadModelWorker : public Napi::AsyncWorker {
    public:
        AddonModel* model;

        AddonModelUnloadModelWorker(const Napi::Env& env, AddonModel* model)
            : Napi::AsyncWorker(env, "AddonModelUnloadModelWorker"),
              model(model),
              deferred(Napi::Promise::Deferred::New(env)) {
            model->Ref();
        }
        ~AddonModelUnloadModelWorker() {
            model->Unref();
        }

        Napi::Promise GetPromise() {
            return deferred.Promise();
        }

    protected:
        Napi::Promise::Deferred deferred;

        void Execute() {
            try {
                llama_model_free(model->model);
                model->modelLoaded = false;

                model->dispose();
            } catch (const std::exception& e) {
                SetError(e.what());
            } catch(...) {
                SetError("Unknown error when calling \"llama_model_free\"");
            }
        }
        void OnOK() {
            adjustNapiExternalMemorySubtract(Env(), model->loadedModelSize);
            model->loadedModelSize = 0;

            deferred.Resolve(Env().Undefined());
        }
        void OnError(const Napi::Error& err) {
            deferred.Reject(err.Value());
        }
};

class AddonModelLoadLoraWorker : public Napi::AsyncWorker {
    public:
        AddonModelLora* modelLora;

        AddonModelLoadLoraWorker(
            const Napi::Env& env,
            AddonModelLora* modelLora
        )
            : Napi::AsyncWorker(env, "AddonModelLoadLoraWorker"),
              modelLora(modelLora),
              deferred(Napi::Promise::Deferred::New(env)) {
            modelLora->model->Ref();
            modelLora->Ref();
        }
        ~AddonModelLoadLoraWorker() {
            modelLora->model->Unref();
            modelLora->Unref();
        }

        Napi::Promise GetPromise() {
            return deferred.Promise();
        }

    protected:
        Napi::Promise::Deferred deferred;

        void Execute() {
            try {
                const auto loraAdapter = llama_adapter_lora_init(modelLora->model->model, modelLora->loraFilePath.c_str());

                if (loraAdapter == nullptr) {
                    SetError(
                        std::string(
                            std::string("Failed to initialize LoRA adapter \"" + modelLora->loraFilePath + "\"")
                        )
                    );
                    return;
                }

                modelLora->lora_adapter = loraAdapter;
                modelLora->model->Ref();

                if (modelLora->model->data != nullptr) {
                    modelLora->model->data->loraAdapters.insert(modelLora);
                } else {
                    modelLora->dispose(true);
                    SetError("Model data is not initialized");
                }
            } catch (const std::exception& e) {
                SetError(e.what());
            } catch(...) {
                SetError("Unknown error when calling \"llama_adapter_lora_init\"");
            }
        }
        void OnOK() {
            deferred.Resolve(Env().Undefined());
        }
        void OnError(const Napi::Error& err) {
            deferred.Reject(err.Value());
        }
};

AddonModel::AddonModel(const Napi::CallbackInfo& info) : Napi::ObjectWrap<AddonModel>(info) {
    data = new AddonModelData();
    model_params = llama_model_default_params();

    // Get the model path
    modelPath = info[0].As<Napi::String>().Utf8Value();

    if (info.Length() > 1 && info[1].IsObject()) {
        Napi::Object options = info[1].As<Napi::Object>();

        if (options.Has("addonExports")) {
            addonExportsRef = Napi::Persistent(options.Get("addonExports").As<Napi::Object>());
            hasAddonExportsRef = true;
        }

        if (options.Has("gpuLayers")) {
            model_params.n_gpu_layers = options.Get("gpuLayers").As<Napi::Number>().Int32Value();
        }

        if (options.Has("vocabOnly")) {
            model_params.vocab_only = options.Get("vocabOnly").As<Napi::Boolean>().Value();
        }

        if (options.Has("useMmap")) {
            model_params.use_mmap = options.Get("useMmap").As<Napi::Boolean>().Value();
        }

        if (options.Has("useMlock")) {
            model_params.use_mlock = options.Get("useMlock").As<Napi::Boolean>().Value();
        }

        if (options.Has("checkTensors")) {
            model_params.check_tensors = options.Get("checkTensors").As<Napi::Boolean>().Value();
        }

        if (options.Has("onLoadProgress")) {
            auto onLoadProgressJSCallback = options.Get("onLoadProgress").As<Napi::Function>();
            if (onLoadProgressJSCallback.IsFunction()) {
                AddonThreadSafeProgressCallbackFunctionContext* context = new Napi::Reference<Napi::Value>(Napi::Persistent(info.This()));
                addonThreadSafeOnLoadProgressEventCallback = AddonThreadSafeProgressEventCallbackFunction::New(
                    info.Env(),
                    onLoadProgressJSCallback,
                    "onLoadProgressCallback",
                    0,
                    1,
                    context,
                    [](Napi::Env, AddonModel* addonModel, AddonThreadSafeProgressCallbackFunctionContext* ctx) {
                        addonModel->onLoadProgressEventCallbackSet = false;

                        delete ctx;
                    },
                    this
                );
                onLoadProgressEventCallbackSet = true;
            }
        }

        if (options.Has("hasLoadAbortSignal")) {
            hasLoadAbortSignal = options.Get("hasLoadAbortSignal").As<Napi::Boolean>().Value();
        }

        if (options.Has("overridesList")) {
            Napi::Array overridesList = options.Get("overridesList").As<Napi::Array>();
            kv_overrides.reserve(overridesList.Length());

            for (uint32_t i = 0; i < overridesList.Length(); i++) {
                Napi::Array overrideItem = overridesList.Get(i).As<Napi::Array>();
                auto key = overrideItem.Get((uint32_t)0).As<Napi::String>().Utf8Value();
                auto value = overrideItem.Get((uint32_t)1);

                if (key.length() > 127) {
                    continue;
                }

                llama_model_kv_override kvo;
                std::strncpy(kvo.key, key.c_str(), key.length());
                kvo.key[key.length()] = 0;

                if (value.IsString()) {
                    auto valueString = value.As<Napi::String>().Utf8Value();
                    if (valueString.length() > 127) {
                        continue;
                    }

                    kvo.tag = LLAMA_KV_OVERRIDE_TYPE_STR;
                    std::strncpy(kvo.val_str, valueString.c_str(), valueString.length());
                    kvo.val_str[valueString.length()] = 0;

                    fputs(std::string("Override: " + key + " = " + valueString + "\n").c_str(), stdout);
                    fflush(stdout);
                } else if (value.IsNumber() || value.IsBigInt()) {
                    auto numberType = overrideItem.Get((uint32_t)2).As<Napi::Number>().Int32Value();
                    if (numberType == 0) {
                        kvo.tag = LLAMA_KV_OVERRIDE_TYPE_INT;
                        kvo.val_i64 = value.As<Napi::Number>().Int64Value();
                    } else {
                        kvo.tag = LLAMA_KV_OVERRIDE_TYPE_FLOAT;
                        kvo.val_f64 = value.As<Napi::Number>().DoubleValue();
                    }

                    continue;
                } else if (value.IsBoolean()) {
                    kvo.tag = LLAMA_KV_OVERRIDE_TYPE_BOOL;
                    kvo.val_bool = value.As<Napi::Boolean>().Value();
                }

                kv_overrides.emplace_back(std::move(kvo));
            }

            if (!kv_overrides.empty()) {
                kv_overrides.emplace_back();
                kv_overrides.back().key[0] = 0;
            }

            model_params.kv_overrides = kv_overrides.data();
        }

        if (onLoadProgressEventCallbackSet || hasLoadAbortSignal) {
            model_params.progress_callback_user_data = &(*this);
            model_params.progress_callback = llamaModelParamsProgressCallback;
        }
    }
}

AddonModel::~AddonModel() {
    dispose();
}
void AddonModel::dispose() {
    if (disposed) {
        return;
    }

    disposed = true;
    if (modelLoaded) {
        modelLoaded = false;
        llama_model_free(model);

        adjustNapiExternalMemorySubtract(Env(), loadedModelSize);
        loadedModelSize = 0;
    }

    if (data != nullptr) {
        auto currentData = data;
        data = nullptr;
        delete currentData;
    }

    if (hasAddonExportsRef) {
        addonExportsRef.Unref();
        hasAddonExportsRef = false;
    }
}

Napi::Value AddonModel::Init(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    AddonModelLoadModelWorker* worker = new AddonModelLoadModelWorker(this->Env(), this);
    worker->Queue();
    return worker->GetPromise();
}
Napi::Value AddonModel::LoadLora(const Napi::CallbackInfo& info) {
    AddonModelLora* modelLora = Napi::ObjectWrap<AddonModelLora>::Unwrap(info[0].As<Napi::Object>());
    AddonModelLoadLoraWorker* worker = new AddonModelLoadLoraWorker(this->Env(), modelLora);
    worker->Queue();
    return worker->GetPromise();
}
Napi::Value AddonModel::AbortActiveModelLoad(const Napi::CallbackInfo& info) {
    abortModelLoad = true;
    return info.Env().Undefined();
}
Napi::Value AddonModel::Dispose(const Napi::CallbackInfo& info) {
    if (disposed) {
        return info.Env().Undefined();
    }

    if (modelLoaded) {
        modelLoaded = false;

        AddonModelUnloadModelWorker* worker = new AddonModelUnloadModelWorker(this->Env(), this);
        worker->Queue();
        return worker->GetPromise();
    } else {
        dispose();

        Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(info.Env());
        deferred.Resolve(info.Env().Undefined());
        return deferred.Promise();
    }
}

Napi::Object SamplingParamsToNapiObject(const Napi::Env& env, const llama_vocab *vocab, const common_params_sampling& sparams) {
    Napi::Object obj = Napi::Object::New(env);

    obj.Set("seed", Napi::Number::New(env, sparams.seed));
    obj.Set("temperature", Napi::Number::New(env, sparams.temp));
    obj.Set("ignoreEOS", Napi::Number::New(env, sparams.ignore_eos));
    obj.Set("topK", Napi::Number::New(env, sparams.top_k));
    obj.Set("topP", Napi::Number::New(env, sparams.top_p));
    obj.Set("minP", Napi::Number::New(env, sparams.min_p));
    obj.Set("topNSigma", Napi::Number::New(env, sparams.top_n_sigma));
    obj.Set("xtcProbability", Napi::Number::New(env, sparams.xtc_probability));
    obj.Set("xtcThreshold", Napi::Number::New(env, sparams.xtc_threshold));
    obj.Set("typicalP", Napi::Number::New(env, sparams.typ_p));
    obj.Set("repeatLastN", Napi::Number::New(env, sparams.penalty_last_n));
    obj.Set("repeatPenalty", Napi::Number::New(env, sparams.penalty_repeat));
    obj.Set("presencePenalty", Napi::Number::New(env, sparams.penalty_present));
    obj.Set("frequencyPenalty", Napi::Number::New(env, sparams.penalty_freq));
    obj.Set("dryMultiplier", Napi::Number::New(env, sparams.dry_multiplier));
    obj.Set("dryBase", Napi::Number::New(env, sparams.dry_base));
    obj.Set("dryAllowedLength", Napi::Number::New(env, sparams.dry_allowed_length));
    obj.Set("dryPenaltyLastN", Napi::Number::New(env, sparams.dry_penalty_last_n));

    Napi::Array drySequenceBreakersArray = Napi::Array::New(env, sparams.dry_sequence_breakers.size());
    for (size_t i = 0; i < sparams.dry_sequence_breakers.size(); ++i) {
        drySequenceBreakersArray.Set(i, Napi::String::New(env, sparams.dry_sequence_breakers[i]));
    }
    obj.Set("drySequenceBreaker", drySequenceBreakersArray);

    obj.Set("dynaTemperatureRange", Napi::Number::New(env, sparams.dynatemp_range));
    obj.Set("dynaTemperatureExponent", Napi::Number::New(env, sparams.dynatemp_exponent));
    obj.Set("mirostat", Napi::Number::New(env, sparams.mirostat));
    obj.Set("mirostatLearningRate", Napi::Number::New(env, sparams.mirostat_eta));
    obj.Set("mirostatTau", Napi::Number::New(env, sparams.mirostat_tau));

    if (sparams.logit_bias.size() > 0) {
        Napi::Array logitBiasArray = Napi::Array::New(env, sparams.logit_bias.size());
        for (size_t i = 0; i < sparams.logit_bias.size(); ++i) {
            Napi::Object logitBiasEntry = Napi::Object::New(env);

            llama_token token = sparams.logit_bias[i].token;
            float bias = sparams.logit_bias[i].bias;

            std::string tokenStr = common_token_to_piece(vocab, token);

            logitBiasEntry.Set("token", Napi::String::New(env, tokenStr));
            logitBiasEntry.Set("bias", Napi::Number::New(env, bias));
            logitBiasArray.Set(i, logitBiasEntry);
        }
        obj.Set("logitBias", logitBiasArray);
    }

    if (sparams.grammar.length() > 0) {
        obj.Set("grammar", Napi::String::New(env, sparams.grammar));
    }

    return obj;
}

Napi::Value AddonModel::CompletionSync(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }
    llama_context_params context_params = llama_context_default_params();
    context_params.n_ctx = 4096;
    context_params.n_threads = std::max(cpu_get_num_math(), 1);
    context_params.n_threads_batch = context_params.n_threads;
    context_params.no_perf = true;

    std::string prompt = info[0].As<Napi::String>().Utf8Value();
    // find the number of tokens in the prompt
    const int n_prompt = -llama_tokenize(vocab, prompt.c_str(), prompt.size(), NULL, 0, true, true);

    // allocate space for the tokens and tokenize the prompt
    std::vector<llama_token> prompt_tokens(n_prompt);
    if (llama_tokenize(vocab, prompt.c_str(), prompt.size(), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        Napi::Error::New(info.Env(), "Failed to tokenize the prompt").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }
    const bool add_bos_token = llama_vocab_get_add_bos(vocab);
    const bool has_eos_token = llama_vocab_eos(vocab) != LLAMA_TOKEN_NULL;

    Napi::Object options;
    if (info.Length() > 1 && info[1].IsObject()) {
        options = info[1].As<Napi::Object>();
    }

    if (options.IsObject()) {
        if (options.Has("contextSize")) {
            context_params.n_ctx = options.Get("contextSize").As<Napi::Number>().Uint32Value();
        }

        if (options.Has("batchSize")) {
            context_params.n_batch = options.Get("batchSize").As<Napi::Number>().Uint32Value();
            // context_params.n_ubatch = context_params.n_batch; // the batch queue is managed in the JS side, so there's no need for managing it on the C++ side
        }

        if (options.Has("sequences")) {
            context_params.n_seq_max = options.Get("sequences").As<Napi::Number>().Uint32Value();
        }

        if (options.Has("embeddings")) {
            context_params.embeddings = options.Get("embeddings").As<Napi::Boolean>().Value();
        }

        if (options.Has("ranking") && options.Get("ranking").As<Napi::Boolean>().Value()) {
            context_params.pooling_type = LLAMA_POOLING_TYPE_RANK;
        }

        if (options.Has("flashAttention")) {
            bool flashAttention = options.Get("flashAttention").As<Napi::Boolean>().Value();
            context_params.flash_attn_type = flashAttention ? LLAMA_FLASH_ATTN_TYPE_ENABLED : LLAMA_FLASH_ATTN_TYPE_DISABLED;
        }

        if (options.Has("threads")) {
            const auto n_threads = options.Get("threads").As<Napi::Number>().Int32Value();
            const auto resolved_n_threads = n_threads == 0 ? std::max((int32_t)std::thread::hardware_concurrency(), context_params.n_threads) : n_threads;

            context_params.n_threads = resolved_n_threads;
            context_params.n_threads_batch = resolved_n_threads;
        }

        if (options.Has("performanceTracking")) {
            context_params.no_perf = !(options.Get("performanceTracking").As<Napi::Boolean>().Value());
        }
    }
    llama_context * ctx = llama_init_from_model(model, context_params);
    if (ctx == NULL) {
        Napi::Error::New(info.Env(), "Failed to create the llama_context").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }
    common_params_sampling sparams;
    if (options.IsObject()) {
        if (options.Has("seed")) {
            sparams.seed = options.Get("seed").As<Napi::Number>().Uint32Value();
        }
        if (options.Has("temperature")) {
            sparams.temp = options.Get("temperature").As<Napi::Number>().FloatValue();
        }
        if (options.Has("ignoreEOS")) {
            sparams.ignore_eos = options.Get("ignoreEOS").As<Napi::Boolean>().Value() && has_eos_token;
            if (sparams.ignore_eos) {
                for (llama_token i = 0; i < llama_vocab_n_tokens(vocab); i++) {
                    if (llama_vocab_is_eog(vocab, i)) {
                        sparams.logit_bias.push_back({i, -INFINITY});
                    }
                }
            }
        }

        if (options.Has("topK")) {
            sparams.top_k = options.Get("topK").As<Napi::Number>().Uint32Value();
        }
        if (options.Has("topP")) {
            sparams.top_p = options.Get("topP").As<Napi::Number>().FloatValue();
        }
        if (options.Has("minP")) {
            sparams.min_p = options.Get("minP").As<Napi::Number>().FloatValue();
        }
        if (options.Has("topNSigma")) {
            sparams.top_n_sigma = options.Get("topNSigma").As<Napi::Number>().FloatValue();
        }
        if (options.Has("xtcProbability")) {
            sparams.xtc_probability = options.Get("xtcProbability").As<Napi::Number>().FloatValue();
        }
        if (options.Has("xtcThreshold")) {
            sparams.xtc_threshold = options.Get("xtcThreshold").As<Napi::Number>().FloatValue();
        }
        if (options.Has("typicalP")) {
            sparams.typ_p = options.Get("typicalP").As<Napi::Number>().FloatValue();
        }
        if (options.Has("repeatLastN")) {
            int value = options.Get("repeatLastN").As<Napi::Number>().Int32Value();
            if (value < -1) {
                value = -1;
            }
            sparams.penalty_last_n = value;
            sparams.n_prev = std::max(sparams.n_prev, value);
        }
        if (options.Has("repeatPenalty")) {
            sparams.penalty_repeat = options.Get("repeatPenalty").As<Napi::Number>().FloatValue();
        }
        if (options.Has("presencePenalty")) {
            sparams.penalty_present = options.Get("presencePenalty").As<Napi::Number>().FloatValue();
        }
        if (options.Has("frequencyPenalty")) {
            sparams.penalty_freq = options.Get("frequencyPenalty").As<Napi::Number>().FloatValue();
        }
        if (options.Has("dryMultiplier")) {
            sparams.dry_multiplier = options.Get("dryMultiplier").As<Napi::Number>().FloatValue();
        }
        if (options.Has("dryBase")) {
            sparams.dry_base = options.Get("dryBase").As<Napi::Number>().FloatValue();
        }
        if (options.Has("dryAllowedLength")) {
            sparams.dry_allowed_length = options.Get("dryAllowedLength").As<Napi::Number>().Uint32Value();
        }
        if (options.Has("dryPenaltyLastN")) {
            sparams.dry_penalty_last_n = options.Get("dryPenaltyLastN").As<Napi::Number>().Uint32Value();
        }
        if (options.Has("drySequenceBreaker")) {
            auto drySequenceBreakerValue = options.Get("drySequenceBreaker");
            if (drySequenceBreakerValue.IsString()) {
                const std::string& drySequenceBreaker = drySequenceBreakerValue.As<Napi::String>().Utf8Value();
                sparams.dry_sequence_breakers.clear();
                if (drySequenceBreaker.length() > 0) {
                    sparams.dry_sequence_breakers.emplace_back(drySequenceBreaker);
                }
            } else if (drySequenceBreakerValue.IsArray()) {
                auto drySequenceBreakerArray = drySequenceBreakerValue.As<Napi::Array>();
                sparams.dry_sequence_breakers.clear();
                for (uint32_t i = 0; i < drySequenceBreakerArray.Length(); i++) {
                    const std::string& drySequenceBreaker = drySequenceBreakerArray.Get(i).As<Napi::String>().Utf8Value();
                    if (drySequenceBreaker.length() > 0) {
                        sparams.dry_sequence_breakers.emplace_back(drySequenceBreaker);
                    }
                }
            } else if (drySequenceBreakerValue.IsNull() || drySequenceBreakerValue.ToBoolean().Value() == false) {
                sparams.dry_sequence_breakers.clear();
            }
        }
        if (options.Has("dynaTemperatureRange")) {
            sparams.dynatemp_range = options.Get("dynaTemperatureRange").As<Napi::Number>().FloatValue();
        }
        if (options.Has("dynaTemperatureExponent")) {
            sparams.dynatemp_exponent = options.Get("dynaTemperatureExponent").As<Napi::Number>().FloatValue();
        }
        if (options.Has("mirostat")) {
            sparams.mirostat = options.Get("mirostat").As<Napi::Number>().Uint32Value();
        }
        if (options.Has("mirostatLearningRate")) {
            sparams.mirostat_eta = options.Get("mirostatLearningRate").As<Napi::Number>().FloatValue();
        }
        if (options.Has("mirostatTau")) {
            sparams.mirostat_tau = options.Get("mirostatTau").As<Napi::Number>().FloatValue();
        }
        if (options.Has("logitBias")) {
            // get the logitBias object: { [tokenString]: number}
            auto logitBiasObj = options.Get("logitBias").As<Napi::Object>();
            if (logitBiasObj.IsArray()) {
                auto logitBiasArray = logitBiasObj.As<Napi::Array>();
                for (uint32_t i = 0; i < logitBiasArray.Length(); i++) {
                    auto logitBiasEntry = logitBiasArray.Get(i).As<Napi::Object>();
                    if (logitBiasEntry.IsObject()) {
                        if (logitBiasEntry.Has("token") && logitBiasEntry.Has("bias")) {
                            auto tokenString = logitBiasEntry.Get("token").As<Napi::String>().Utf8Value();
                            auto logitBiasValue = logitBiasEntry.Get("bias").As<Napi::Number>().FloatValue();
                            const int n_tokens = -llama_tokenize(vocab, tokenString.c_str(), tokenString.size(), NULL, 0, true, true);
                            std::vector<llama_token> bias_tokens = common_tokenize(ctx, tokenString, true, true);

                            for (const auto& bias_token : bias_tokens) {
                                sparams.logit_bias.push_back({bias_token, logitBiasValue});
                            }
                        }
                    }
                }
            } else if (logitBiasObj.IsObject()) {
                auto logitBiasKeys = logitBiasObj.GetPropertyNames();
                for (uint32_t i = 0; i < logitBiasKeys.Length(); i++) {
                    auto tokenString = logitBiasKeys.Get(i).As<Napi::String>().Utf8Value();
                    auto logitBiasValue = logitBiasObj.Get(tokenString).As<Napi::Number>().FloatValue();

                    const int n_tokens = -llama_tokenize(vocab, tokenString.c_str(), tokenString.size(), NULL, 0, true, true);
                    std::vector<llama_token> bias_tokens(n_tokens);
                    if (llama_tokenize(vocab, tokenString.c_str(), tokenString.size(), bias_tokens.data(), bias_tokens.size(), true, true) < 0) {
                        llama_free(ctx);
                        Napi::Error::New(info.Env(), "Failed to tokenize the logitBiasKey" + tokenString).ThrowAsJavaScriptException();
                        return info.Env().Undefined();
                    }

                    for (const auto& bias_token : bias_tokens) {
                        sparams.logit_bias.push_back({bias_token, logitBiasValue});
                    }
                }
            }
        }

        if (options.Has("grammar")) {
            auto grammar = options.Get("grammar").As<Napi::String>().Utf8Value();
            if (grammar.length() > 0) {
                sparams.grammar = grammar;
            }
        }
        if (options.Has("jsonSchema")) {
            auto jsonSchema = options.Get("jsonSchema").As<Napi::String>().Utf8Value();
            if (jsonSchema.length() > 0) {
                sparams.grammar = json_schema_to_grammar(json::parse(jsonSchema));
            }
        }
    }

    auto * smpl = common_sampler_init(model, sparams);
    if (!smpl) {
        llama_free(ctx);
        Napi::Error::New(info.Env(), "Failed to initialize sampling subsystem").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    int32_t n_predict = context_params.n_ctx - n_prompt;
    llama_batch batch = llama_batch_get_one(prompt_tokens.data(), prompt_tokens.size());
    int n_decode = 0;
    llama_token new_token_id;
    std::string _result = "";
    for (int n_pos = 0; n_pos + batch.n_tokens < n_prompt + n_predict; ) {
        // evaluate the current batch with the transformer model
        if (llama_decode(ctx, batch)) {
            Napi::Error::New(info.Env(), "Failed to Decode token").ThrowAsJavaScriptException();
            return info.Env().Undefined();
        }

        n_pos += batch.n_tokens;

        // sample the next token
        {
            new_token_id = common_sampler_sample(smpl, ctx, -1);
            common_sampler_accept(smpl, new_token_id, /* accept_grammar= */ true);

            // is it an end of generation?
            if (llama_vocab_is_eog(vocab, new_token_id)) {
                break;
            }

            char buf[128];
            int n = llama_token_to_piece(vocab, new_token_id, buf, sizeof(buf), 0, true);
            if (n < 0) {
                Napi::Error::New(info.Env(), "Failed to convert token to piece").ThrowAsJavaScriptException();
                return info.Env().Undefined();
            }
            std::string s(buf, n);
            printf("%s", s.c_str());
            fflush(stdout);
            _result += s;

            // prepare the next batch with the sampled token
            batch = llama_batch_get_one(&new_token_id, 1);

            n_decode += 1;
        }
    }
    common_sampler_free(smpl);
    llama_free(ctx);

    Napi::Object result = Napi::Object::New(info.Env());
    result.Set("content", Napi::String::New(info.Env(), _result));
    result.Set("params", SamplingParamsToNapiObject(info.Env(), vocab, sparams));

    return result;
}

Napi::Value AddonModel::Tokenize(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    std::string text = info[0].As<Napi::String>().Utf8Value();
    bool specialTokens = info[1].As<Napi::Boolean>().Value();

    std::vector<llama_token> tokens = common_tokenize(vocab, text, false, specialTokens);

    Napi::Uint32Array result = Napi::Uint32Array::New(info.Env(), tokens.size());
    for (size_t i = 0; i < tokens.size(); ++i) {
        result[i] = static_cast<uint32_t>(tokens[i]);
    }

    return result;
}
Napi::Value AddonModel::Detokenize(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    Napi::Uint32Array tokens = info[0].As<Napi::Uint32Array>();
    bool decodeSpecialTokens = info.Length() > 0
        ? info[1].As<Napi::Boolean>().Value()
        : false;

    std::string result;
    result.resize(std::max(result.capacity(), tokens.ElementLength()));

    int n_chars = llama_detokenize(vocab, (llama_token*)tokens.Data(), tokens.ElementLength(), &result[0], result.size(), false, decodeSpecialTokens);
    if (n_chars < 0) {
        result.resize(-n_chars);
        n_chars = llama_detokenize(vocab, (llama_token*)tokens.Data(), tokens.ElementLength(), &result[0], result.size(), false, decodeSpecialTokens);
        GGML_ASSERT(n_chars <= result.size());  // whitespace trimming is performed after per-token detokenization
    }

    result.resize(n_chars);

    return Napi::String::New(info.Env(), result);
}

Napi::Value AddonModel::DetokenizePiece(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }
    auto token = info[0].As<Napi::Number>().Uint32Value();
    auto result = common_token_to_piece(vocab, token);
    return Napi::String::New(info.Env(), result);
}

Napi::Value AddonModel::GetTrainContextSize(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return Napi::Number::From(info.Env(), llama_model_n_ctx_train(model));
}

Napi::Value AddonModel::GetEmbeddingVectorSize(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return Napi::Number::From(info.Env(), llama_model_n_embd(model));
}

Napi::Value AddonModel::GetTotalSize(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return Napi::Number::From(info.Env(), llama_model_size(model));
}

Napi::Value AddonModel::GetTotalParameters(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return Napi::Number::From(info.Env(), llama_model_n_params(model));
}

Napi::Value AddonModel::GetModelDescription(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    char model_desc[128];
    int actual_length = llama_model_desc(model, model_desc, sizeof(model_desc));

    return Napi::String::New(info.Env(), model_desc, actual_length);
}

Napi::Value AddonModel::TokenBos(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiControlToken(info, vocab, llama_vocab_bos(vocab));
}
Napi::Value AddonModel::TokenEos(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiControlToken(info, vocab, llama_vocab_eos(vocab));
}
Napi::Value AddonModel::TokenNl(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiToken(info, vocab, llama_vocab_nl(vocab));
}
Napi::Value AddonModel::PrefixToken(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiToken(info, vocab, llama_vocab_fim_pre(vocab));
}
Napi::Value AddonModel::MiddleToken(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiToken(info, vocab, llama_vocab_fim_mid(vocab));
}
Napi::Value AddonModel::SuffixToken(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiToken(info, vocab, llama_vocab_fim_suf(vocab));
}
Napi::Value AddonModel::EotToken(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiToken(info, vocab, llama_vocab_eot(vocab));
}
Napi::Value AddonModel::SepToken(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    return getNapiToken(info, vocab, llama_vocab_sep(vocab));
}
Napi::Value AddonModel::GetTokenString(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    int token = info[0].As<Napi::Number>().Int32Value();
    std::stringstream ss;

    const char* str = llama_vocab_get_text(vocab, token);
    if (str == nullptr) {
        return info.Env().Undefined();
    }

    ss << str;

    return Napi::String::New(info.Env(), ss.str());
}

Napi::Value AddonModel::GetTokenAttributes(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    if (info[0].IsNumber() == false) {
        return Napi::Number::From(info.Env(), int32_t(LLAMA_TOKEN_ATTR_UNDEFINED));
    }

    int token = info[0].As<Napi::Number>().Int32Value();
    auto tokenAttributes = llama_vocab_get_attr(vocab, token);

    return Napi::Number::From(info.Env(), int32_t(tokenAttributes));
}
Napi::Value AddonModel::IsEogToken(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    if (info[0].IsNumber() == false) {
        return Napi::Boolean::New(info.Env(), false);
    }

    int token = info[0].As<Napi::Number>().Int32Value();

    return Napi::Boolean::New(info.Env(), llama_vocab_is_eog(vocab, token));
}
Napi::Value AddonModel::GetVocabularyType(const Napi::CallbackInfo& info) {
    if (disposed) {
        Napi::Error::New(info.Env(), "Model is disposed").ThrowAsJavaScriptException();
        return info.Env().Undefined();
    }

    auto vocabularyType = llama_vocab_type(vocab);

    return Napi::Number::From(info.Env(), int32_t(vocabularyType));
}
Napi::Value AddonModel::ShouldPrependBosToken(const Napi::CallbackInfo& info) {
    const bool addBos = llama_vocab_get_add_bos(vocab);

    return Napi::Boolean::New(info.Env(), addBos);
}
Napi::Value AddonModel::ShouldAppendEosToken(const Napi::CallbackInfo& info) {
    const bool addEos = llama_vocab_get_add_eos(vocab);

    return Napi::Boolean::New(info.Env(), addEos);
}

Napi::Value AddonModel::GetModelSize(const Napi::CallbackInfo& info) {
    return Napi::Number::From(info.Env(), llama_model_size(model));
}

void AddonModel::init(Napi::Object exports) {
    exports.Set(
        "AddonModel",
        DefineClass(
            exports.Env(),
            "AddonModel",
            {
                InstanceMethod("init", &AddonModel::Init),
                InstanceMethod("loadLora", &AddonModel::LoadLora),
                InstanceMethod("abortActiveModelLoad", &AddonModel::AbortActiveModelLoad),
                InstanceMethod("completionSync", &AddonModel::CompletionSync),
                InstanceMethod("tokenize", &AddonModel::Tokenize),
                InstanceMethod("detokenize", &AddonModel::Detokenize),
                InstanceMethod("detokenizePiece", &AddonModel::DetokenizePiece),
                InstanceMethod("getTrainContextSize", &AddonModel::GetTrainContextSize),
                InstanceMethod("getEmbeddingVectorSize", &AddonModel::GetEmbeddingVectorSize),
                InstanceMethod("getTotalSize", &AddonModel::GetTotalSize),
                InstanceMethod("getTotalParameters", &AddonModel::GetTotalParameters),
                InstanceMethod("getModelDescription", &AddonModel::GetModelDescription),
                InstanceMethod("tokenBos", &AddonModel::TokenBos),
                InstanceMethod("tokenEos", &AddonModel::TokenEos),
                InstanceMethod("tokenNl", &AddonModel::TokenNl),
                InstanceMethod("prefixToken", &AddonModel::PrefixToken),
                InstanceMethod("middleToken", &AddonModel::MiddleToken),
                InstanceMethod("suffixToken", &AddonModel::SuffixToken),
                InstanceMethod("eotToken", &AddonModel::EotToken),
                InstanceMethod("sepToken", &AddonModel::SepToken),
                InstanceMethod("getTokenString", &AddonModel::GetTokenString),
                InstanceMethod("getTokenAttributes", &AddonModel::GetTokenAttributes),
                InstanceMethod("isEogToken", &AddonModel::IsEogToken),
                InstanceMethod("getVocabularyType", &AddonModel::GetVocabularyType),
                InstanceMethod("shouldPrependBosToken", &AddonModel::ShouldPrependBosToken),
                InstanceMethod("shouldAppendEosToken", &AddonModel::ShouldAppendEosToken),
                InstanceMethod("getModelSize", &AddonModel::GetModelSize),
                InstanceMethod("dispose", &AddonModel::Dispose),
            }
        )
    );
}
