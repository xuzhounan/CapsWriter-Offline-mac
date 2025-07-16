//
//  SherpaONNXCAPI.h
//  CapsWriter-mac
//
//  Minimal C API definitions for sherpa-onnx
//

#ifndef SherpaONNXCAPI_h
#define SherpaONNXCAPI_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct SherpaOnnxOnlineRecognizer SherpaOnnxOnlineRecognizer;
typedef struct SherpaOnnxOnlineStream SherpaOnnxOnlineStream;

// Configuration structures - minimal definitions
typedef struct {
    const char *encoder;
    const char *decoder;
    const char *joiner;
} SherpaOnnxOnlineTransducerModelConfig;

typedef struct {
    const char *encoder;
    const char *decoder;
} SherpaOnnxOnlineParaformerModelConfig;

typedef struct {
    const char *model;
} SherpaOnnxOnlineZipformer2CtcModelConfig;

typedef struct {
    SherpaOnnxOnlineTransducerModelConfig transducer;
    SherpaOnnxOnlineParaformerModelConfig paraformer;
    SherpaOnnxOnlineZipformer2CtcModelConfig zipformer2_ctc;
    const char *tokens;
    int32_t num_threads;
    const char *provider;
    int32_t debug;
    const char *model_type;
    const char *modeling_unit;
    const char *bpe_vocab;
    const char *tokens_buf;
    int32_t tokens_buf_size;
} SherpaOnnxOnlineModelConfig;

typedef struct {
    int32_t sample_rate;
    int32_t feature_dim;
} SherpaOnnxFeatureConfig;

typedef struct {
    const char *graph;
    int32_t max_active;
} SherpaOnnxOnlineCtcFstDecoderConfig;

typedef struct {
    const char *dict_dir;
    const char *lexicon;
    const char *rule_fsts;
} SherpaOnnxHomophoneReplacerConfig;

typedef struct {
    SherpaOnnxFeatureConfig feat_config;
    SherpaOnnxOnlineModelConfig model_config;
    const char *decoding_method;
    int32_t max_active_paths;
    int32_t enable_endpoint;
    float rule1_min_trailing_silence;
    float rule2_min_trailing_silence;
    float rule3_min_utterance_length;
    const char *hotwords_file;
    float hotwords_score;
    SherpaOnnxOnlineCtcFstDecoderConfig ctc_fst_decoder_config;
    const char *rule_fsts;
    const char *rule_fars;
    float blank_penalty;
    const char *hotwords_buf;
    int32_t hotwords_buf_size;
    SherpaOnnxHomophoneReplacerConfig hr;
} SherpaOnnxOnlineRecognizerConfig;

typedef struct {
    const char *text;
    const char *tokens;
    const char *const *tokens_arr;
    float *timestamps;
    int32_t count;
    const char *json;
} SherpaOnnxOnlineRecognizerResult;

// Function declarations
const SherpaOnnxOnlineRecognizer *SherpaOnnxCreateOnlineRecognizer(
    const SherpaOnnxOnlineRecognizerConfig *config);

void SherpaOnnxDestroyOnlineRecognizer(
    const SherpaOnnxOnlineRecognizer *recognizer);

const SherpaOnnxOnlineStream *SherpaOnnxCreateOnlineStream(
    const SherpaOnnxOnlineRecognizer *recognizer);

void SherpaOnnxDestroyOnlineStream(
    const SherpaOnnxOnlineStream *stream);

void SherpaOnnxOnlineStreamAcceptWaveform(
    const SherpaOnnxOnlineStream *stream, int32_t sample_rate,
    const float *samples, int32_t n);

int32_t SherpaOnnxIsOnlineStreamReady(
    const SherpaOnnxOnlineRecognizer *recognizer,
    const SherpaOnnxOnlineStream *stream);

void SherpaOnnxDecodeOnlineStream(
    const SherpaOnnxOnlineRecognizer *recognizer,
    const SherpaOnnxOnlineStream *stream);

const SherpaOnnxOnlineRecognizerResult *SherpaOnnxGetOnlineStreamResult(
    const SherpaOnnxOnlineRecognizer *recognizer,
    const SherpaOnnxOnlineStream *stream);

void SherpaOnnxDestroyOnlineRecognizerResult(
    const SherpaOnnxOnlineRecognizerResult *r);

void SherpaOnnxOnlineStreamReset(
    const SherpaOnnxOnlineRecognizer *recognizer,
    const SherpaOnnxOnlineStream *stream);

int32_t SherpaOnnxOnlineStreamIsEndpoint(
    const SherpaOnnxOnlineRecognizer *recognizer,
    const SherpaOnnxOnlineStream *stream);

#ifdef __cplusplus
}
#endif

#endif /* SherpaONNXCAPI_h */