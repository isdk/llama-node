#pragma once
#include "llama.h"
#include "common/common.h"
#include "llama-grammar.h"
// fix: there are two unicode.h files, the other in "common/unicode.h" and be found by the include
#include "src/unicode.h"
#include "napi.h"
#include "addonGlobals.h"

class AddonGrammar : public Napi::ObjectWrap<AddonGrammar> {
    public:
        std::string grammarCode = "";
        std::string rootRuleName = "root";
        Napi::Reference<Napi::Object> addonExportsRef;
        bool hasAddonExportsRef = false;

        AddonGrammar(const Napi::CallbackInfo& info);
        ~AddonGrammar();

        Napi::Value isTextCompatible(const Napi::CallbackInfo& info);

        static void init(Napi::Object exports);
};
