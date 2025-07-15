//
//  SherpaONNX-Bridging-Header.h
//  CapsWriter-mac
//
//  Created for Sherpa-ONNX C API integration
//

#ifndef SherpaONNX_Bridging_Header_h
#define SherpaONNX_Bridging_Header_h

#include <stdio.h>
#include <stdlib.h>

// Forward declarations for sherpa-onnx types
typedef struct SherpaOnnxOnlineRecognizer SherpaOnnxOnlineRecognizer;
typedef struct SherpaOnnxOnlineStream SherpaOnnxOnlineStream;
typedef struct SherpaOnnxOnlineRecognizerResult SherpaOnnxOnlineRecognizerResult;

// Configuration structures
typedef struct {
    const char *encoder;
    const char *decoder;
    const char *joiner;
    const char *tokens;
    int num_threads;
    const char *provider;
    int debug;
    const char *model_type;
    const char *modeling_unit;
    const char *bpe_vocab;
} SherpaOnnxOnlineTransducerModelConfig;

typedef struct {
    const char *encoder;
    const char *decoder;
    const char *joiner;
    const char *tokens;
    int num_threads;
    const char *provider;
    int debug;
    const char *model_type;
    float temperature;
    float repetition_penalty;
    int no_repeat_ngram_size;
} SherpaOnnxOnlineParaformerModelConfig;

typedef struct {
    SherpaOnnxOnlineTransducerModelConfig transducer;
    SherpaOnnxOnlineParaformerModelConfig paraformer;
    const char *tokens;
    int num_threads;
    int debug;
    const char *provider;
    const char *model_type;
} SherpaOnnxOnlineModelConfig;

typedef struct {
    const char *graph;
    float scale;
} SherpaOnnxFeatureConfig;

typedef struct {
    SherpaOnnxOnlineModelConfig model_config;
    SherpaOnnxFeatureConfig feat_config;
    
    const char *decoding_method;
    int max_active_paths;
    int enable_endpoint;
    float rule1_min_trailing_silence;
    float rule2_min_trailing_silence;
    float rule3_min_utterance_length;
    const char *hotwords_file;
    float hotwords_score;
} SherpaOnnxOnlineRecognizerConfig;

// Function declarations (will be linked to actual sherpa-onnx library)

// Create and destroy recognizer
SherpaOnnxOnlineRecognizer* CreateOnlineRecognizer(const SherpaOnnxOnlineRecognizerConfig *config);
void DestroyOnlineRecognizer(SherpaOnnxOnlineRecognizer *recognizer);

// Create and destroy stream
SherpaOnnxOnlineStream* CreateOnlineStream(SherpaOnnxOnlineRecognizer *recognizer);
void DestroyOnlineStream(SherpaOnnxOnlineStream *stream);

// Process audio
void AcceptWaveform(SherpaOnnxOnlineStream *stream, int sample_rate, const float *samples, int n);
int IsReady(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream);
void Decode(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream);
void Reset(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream);

// Get results
SherpaOnnxOnlineRecognizerResult* GetResult(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream);
void DestroyOnlineRecognizerResult(SherpaOnnxOnlineRecognizerResult *result);
const char* GetResultText(SherpaOnnxOnlineRecognizerResult *result);

// Endpoint detection
int IsEndpoint(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream);

#endif /* SherpaONNX_Bridging_Header_h */