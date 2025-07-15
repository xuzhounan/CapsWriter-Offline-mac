//
//  SherpaONNXWrapper.c
//  CapsWriter-mac
//
//  C wrapper for sherpa-onnx C API
//

#include "SherpaONNX-Bridging-Header.h"

// Note: This file provides wrapper functions that will be linked to the actual sherpa-onnx library
// When you compile sherpa-onnx, you'll get libsherpa-onnx-c-api.dylib
// Link this library to your Xcode project and replace these placeholder implementations

// Placeholder implementations - replace with actual sherpa-onnx calls

SherpaOnnxOnlineRecognizer* CreateOnlineRecognizer(const SherpaOnnxOnlineRecognizerConfig *config) {
    // Placeholder: In real implementation, this would call sherpa_onnx_create_online_recognizer
    printf("[SherpaONNX] CreateOnlineRecognizer called\n");
    return (SherpaOnnxOnlineRecognizer*)malloc(sizeof(SherpaOnnxOnlineRecognizer));
}

void DestroyOnlineRecognizer(SherpaOnnxOnlineRecognizer *recognizer) {
    // Placeholder: In real implementation, this would call sherpa_onnx_destroy_online_recognizer
    printf("[SherpaONNX] DestroyOnlineRecognizer called\n");
    if (recognizer) {
        free(recognizer);
    }
}

SherpaOnnxOnlineStream* CreateOnlineStream(SherpaOnnxOnlineRecognizer *recognizer) {
    // Placeholder: In real implementation, this would call sherpa_onnx_create_online_stream
    printf("[SherpaONNX] CreateOnlineStream called\n");
    return (SherpaOnnxOnlineStream*)malloc(sizeof(SherpaOnnxOnlineStream));
}

void DestroyOnlineStream(SherpaOnnxOnlineStream *stream) {
    // Placeholder: In real implementation, this would call sherpa_onnx_destroy_online_stream
    printf("[SherpaONNX] DestroyOnlineStream called\n");
    if (stream) {
        free(stream);
    }
}

void AcceptWaveform(SherpaOnnxOnlineStream *stream, int sample_rate, const float *samples, int n) {
    // Placeholder: In real implementation, this would call sherpa_onnx_accept_waveform
    printf("[SherpaONNX] AcceptWaveform called: sample_rate=%d, n=%d\n", sample_rate, n);
}

int IsReady(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream) {
    // Placeholder: In real implementation, this would call sherpa_onnx_is_ready
    return 1; // Always ready for testing
}

void Decode(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream) {
    // Placeholder: In real implementation, this would call sherpa_onnx_decode_online_stream
    printf("[SherpaONNX] Decode called\n");
}

void Reset(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream) {
    // Placeholder: In real implementation, this would call sherpa_onnx_reset
    printf("[SherpaONNX] Reset called\n");
}

SherpaOnnxOnlineRecognizerResult* GetResult(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream) {
    // Placeholder: In real implementation, this would call sherpa_onnx_get_result
    printf("[SherpaONNX] GetResult called\n");
    return (SherpaOnnxOnlineRecognizerResult*)malloc(sizeof(SherpaOnnxOnlineRecognizerResult));
}

void DestroyOnlineRecognizerResult(SherpaOnnxOnlineRecognizerResult *result) {
    // Placeholder: In real implementation, this would call sherpa_onnx_destroy_online_recognizer_result
    printf("[SherpaONNX] DestroyOnlineRecognizerResult called\n");
    if (result) {
        free(result);
    }
}

const char* GetResultText(SherpaOnnxOnlineRecognizerResult *result) {
    // Placeholder: In real implementation, this would return the actual recognition result
    static const char* test_result = "这是一个测试识别结果";
    printf("[SherpaONNX] GetResultText called\n");
    return test_result;
}

int IsEndpoint(SherpaOnnxOnlineRecognizer *recognizer, SherpaOnnxOnlineStream *stream) {
    // Placeholder: In real implementation, this would call sherpa_onnx_is_endpoint
    return 0; // No endpoint detected for testing
}