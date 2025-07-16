//
//  SherpaONNXTypes.swift
//  CapsWriter-mac
//
//  Swift wrapper for sherpa-onnx C types
//

import Foundation

// 使用 typealias 来定义 C 类型的 Swift 别名
// 这些将在运行时链接到实际的 C 库

typealias SherpaOnnxOnlineRecognizer = OpaquePointer
typealias SherpaOnnxOnlineStream = OpaquePointer
typealias SherpaOnnxOnlineRecognizerResult = OpaquePointer

// C 结构体的 Swift 表示
struct SherpaOnnxOnlineTransducerModelConfig {
    var encoder: UnsafePointer<CChar>?
    var decoder: UnsafePointer<CChar>?
    var joiner: UnsafePointer<CChar>?
    
    init(encoder: UnsafePointer<CChar>? = nil, decoder: UnsafePointer<CChar>? = nil, joiner: UnsafePointer<CChar>? = nil) {
        self.encoder = encoder
        self.decoder = decoder
        self.joiner = joiner
    }
}

struct SherpaOnnxOnlineParaformerModelConfig {
    var encoder: UnsafePointer<CChar>?
    var decoder: UnsafePointer<CChar>?
    
    init(encoder: UnsafePointer<CChar>? = nil, decoder: UnsafePointer<CChar>? = nil) {
        self.encoder = encoder
        self.decoder = decoder
    }
}

struct SherpaOnnxOnlineZipformer2CtcModelConfig {
    var model: UnsafePointer<CChar>?
    
    init(model: UnsafePointer<CChar>? = nil) {
        self.model = model
    }
}

struct SherpaOnnxOnlineModelConfig {
    var transducer: SherpaOnnxOnlineTransducerModelConfig
    var paraformer: SherpaOnnxOnlineParaformerModelConfig
    var zipformer2_ctc: SherpaOnnxOnlineZipformer2CtcModelConfig
    var tokens: UnsafePointer<CChar>?
    var num_threads: Int32
    var provider: UnsafePointer<CChar>?
    var debug: Int32
    var model_type: UnsafePointer<CChar>?
    var modeling_unit: UnsafePointer<CChar>?
    var bpe_vocab: UnsafePointer<CChar>?
    var tokens_buf: UnsafePointer<CChar>?
    var tokens_buf_size: Int32
    
    init() {
        self.transducer = SherpaOnnxOnlineTransducerModelConfig()
        self.paraformer = SherpaOnnxOnlineParaformerModelConfig()
        self.zipformer2_ctc = SherpaOnnxOnlineZipformer2CtcModelConfig()
        self.tokens = nil
        self.num_threads = 2
        self.provider = nil
        self.debug = 0
        self.model_type = nil
        self.modeling_unit = nil
        self.bpe_vocab = nil
        self.tokens_buf = nil
        self.tokens_buf_size = 0
    }
}

struct SherpaOnnxFeatureConfig {
    var sample_rate: Int32
    var feature_dim: Int32
    
    init(sample_rate: Int32 = 16000, feature_dim: Int32 = 80) {
        self.sample_rate = sample_rate
        self.feature_dim = feature_dim
    }
}

struct SherpaOnnxOnlineCtcFstDecoderConfig {
    var graph: UnsafePointer<CChar>?
    var max_active: Int32
    
    init(graph: UnsafePointer<CChar>? = nil, max_active: Int32 = 0) {
        self.graph = graph
        self.max_active = max_active
    }
}

struct SherpaOnnxHomophoneReplacerConfig {
    var dict_dir: UnsafePointer<CChar>?
    var lexicon: UnsafePointer<CChar>?
    var rule_fsts: UnsafePointer<CChar>?
    
    init(dict_dir: UnsafePointer<CChar>? = nil, lexicon: UnsafePointer<CChar>? = nil, rule_fsts: UnsafePointer<CChar>? = nil) {
        self.dict_dir = dict_dir
        self.lexicon = lexicon
        self.rule_fsts = rule_fsts
    }
}

struct SherpaOnnxOnlineRecognizerConfig {
    var feat_config: SherpaOnnxFeatureConfig
    var model_config: SherpaOnnxOnlineModelConfig
    var decoding_method: UnsafePointer<CChar>?
    var max_active_paths: Int32
    var enable_endpoint: Int32
    var rule1_min_trailing_silence: Float
    var rule2_min_trailing_silence: Float
    var rule3_min_utterance_length: Float
    var hotwords_file: UnsafePointer<CChar>?
    var hotwords_score: Float
    var ctc_fst_decoder_config: SherpaOnnxOnlineCtcFstDecoderConfig
    var rule_fsts: UnsafePointer<CChar>?
    var rule_fars: UnsafePointer<CChar>?
    var blank_penalty: Float
    var hotwords_buf: UnsafePointer<CChar>?
    var hotwords_buf_size: Int32
    var hr: SherpaOnnxHomophoneReplacerConfig
    
    init() {
        self.feat_config = SherpaOnnxFeatureConfig()
        self.model_config = SherpaOnnxOnlineModelConfig()
        self.decoding_method = nil
        self.max_active_paths = 4
        self.enable_endpoint = 1
        self.rule1_min_trailing_silence = 2.4
        self.rule2_min_trailing_silence = 1.2
        self.rule3_min_utterance_length = 20.0
        self.hotwords_file = nil
        self.hotwords_score = 0.0
        self.ctc_fst_decoder_config = SherpaOnnxOnlineCtcFstDecoderConfig()
        self.rule_fsts = nil
        self.rule_fars = nil
        self.blank_penalty = 0.0
        self.hotwords_buf = nil
        self.hotwords_buf_size = 0
        self.hr = SherpaOnnxHomophoneReplacerConfig()
    }
}

// C 函数的 Swift 声明
@_silgen_name("SherpaOnnxCreateOnlineRecognizer")
func SherpaOnnxCreateOnlineRecognizer(_ config: UnsafePointer<SherpaOnnxOnlineRecognizerConfig>) -> SherpaOnnxOnlineRecognizer?

@_silgen_name("SherpaOnnxDestroyOnlineRecognizer")
func SherpaOnnxDestroyOnlineRecognizer(_ recognizer: SherpaOnnxOnlineRecognizer?)

@_silgen_name("SherpaOnnxCreateOnlineStream")
func SherpaOnnxCreateOnlineStream(_ recognizer: SherpaOnnxOnlineRecognizer?) -> SherpaOnnxOnlineStream?

@_silgen_name("SherpaOnnxDestroyOnlineStream")
func SherpaOnnxDestroyOnlineStream(_ stream: SherpaOnnxOnlineStream?)

@_silgen_name("SherpaOnnxOnlineStreamAcceptWaveform")
func SherpaOnnxOnlineStreamAcceptWaveform(_ stream: SherpaOnnxOnlineStream?, _ sample_rate: Int32, _ samples: UnsafePointer<Float>, _ n: Int32)

@_silgen_name("SherpaOnnxIsOnlineStreamReady")
func SherpaOnnxIsOnlineStreamReady(_ recognizer: SherpaOnnxOnlineRecognizer?, _ stream: SherpaOnnxOnlineStream?) -> Int32

@_silgen_name("SherpaOnnxDecodeOnlineStream")
func SherpaOnnxDecodeOnlineStream(_ recognizer: SherpaOnnxOnlineRecognizer?, _ stream: SherpaOnnxOnlineStream?)

@_silgen_name("SherpaOnnxGetOnlineStreamResult")
func SherpaOnnxGetOnlineStreamResult(_ recognizer: SherpaOnnxOnlineRecognizer?, _ stream: SherpaOnnxOnlineStream?) -> SherpaOnnxOnlineRecognizerResult?

@_silgen_name("SherpaOnnxDestroyOnlineRecognizerResult")
func SherpaOnnxDestroyOnlineRecognizerResult(_ result: SherpaOnnxOnlineRecognizerResult?)

@_silgen_name("SherpaOnnxOnlineRecognizerResultGetText")
func SherpaOnnxOnlineRecognizerResultGetText(_ result: SherpaOnnxOnlineRecognizerResult?) -> UnsafePointer<CChar>?

@_silgen_name("SherpaOnnxOnlineStreamReset")
func SherpaOnnxOnlineStreamReset(_ recognizer: SherpaOnnxOnlineRecognizer?, _ stream: SherpaOnnxOnlineStream?)

@_silgen_name("SherpaOnnxOnlineStreamIsEndpoint")
func SherpaOnnxOnlineStreamIsEndpoint(_ recognizer: SherpaOnnxOnlineRecognizer?, _ stream: SherpaOnnxOnlineStream?) -> Int32

// 扩展来访问结果文本
extension SherpaOnnxOnlineRecognizerResult {
    var text: String {
        // 在实际使用中，需要从 C 结构体中读取文本
        // 这里返回一个占位符，实际实现需要内存操作
        return ""
    }
}