//
//  RecognitionState.swift
//  CapsWriter-mac
//
//  Created by CapsWriter on 2025-07-17.
//

import Foundation
import Combine

/// 语音识别相关状态管理
@MainActor
class RecognitionState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 识别状态
    @Published var status: RecognitionStatus = .idle
    
    /// 当前识别的文本
    @Published var currentText: String = ""
    
    /// 已确认的文本历史
    @Published var recognizedTexts: [RecognizedText] = []
    
    /// 识别置信度 (0.0 - 1.0)
    @Published var confidence: Float = 0.0
    
    /// 识别引擎状态
    @Published var engineStatus: EngineStatus = .uninitialized
    
    /// 处理队列中的任务数量
    @Published var queuedTasks: Int = 0
    
    /// 统计信息
    @Published var statistics: RecognitionStatistics = RecognitionStatistics()
    
    // MARK: - Enums
    
    enum RecognitionStatus: Equatable {
        case idle
        case processing
        case completed
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "待机"
            case .processing: return "识别中"
            case .completed: return "完成"
            case .error(let message): return "错误: \(message)"
            }
        }
    }
    
    enum EngineStatus {
        case uninitialized
        case initializing
        case ready
        case error(String)
        
        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }
    
    // MARK: - Data Models
    
    struct RecognizedText {
        let id = UUID()
        let text: String
        let confidence: Float
        let timestamp: Date
        let duration: TimeInterval
        
        init(text: String, confidence: Float, duration: TimeInterval) {
            self.text = text
            self.confidence = confidence
            self.duration = duration
            self.timestamp = Date()
        }
    }
    
    struct RecognitionStatistics {
        var totalRecognitions: Int = 0
        var totalDuration: TimeInterval = 0.0
        var averageConfidence: Float = 0.0
        var successCount: Int = 0
        var errorCount: Int = 0
        
        var averageDuration: TimeInterval {
            return totalRecognitions > 0 ? totalDuration / Double(totalRecognitions) : 0.0
        }
        
        var successRate: Float {
            let total = successCount + errorCount
            return total > 0 ? Float(successCount) / Float(total) : 0.0
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始识别
    func startRecognition() {
        guard engineStatus.isReady else { return }
        status = .processing
        queuedTasks += 1
    }
    
    /// 更新当前识别文本
    func updateCurrentText(_ text: String, confidence: Float) {
        currentText = text
        self.confidence = confidence
    }
    
    /// 完成识别并添加到历史
    func completeRecognition(text: String, confidence: Float, duration: TimeInterval) {
        let recognizedText = RecognizedText(text: text, confidence: confidence, duration: duration)
        recognizedTexts.append(recognizedText)
        
        // 更新统计信息
        updateStatistics(recognizedText: recognizedText, isSuccess: true)
        
        // 重置当前状态
        currentText = ""
        self.confidence = 0.0
        status = .completed
        queuedTasks = max(0, queuedTasks - 1)
    }
    
    /// 处理识别错误
    func handleRecognitionError(_ error: String) {
        status = .error(error)
        currentText = ""
        confidence = 0.0
        queuedTasks = max(0, queuedTasks - 1)
        
        // 更新错误统计
        statistics.errorCount += 1
    }
    
    /// 更新引擎状态
    func updateEngineStatus(_ status: EngineStatus) {
        engineStatus = status
    }
    
    /// 清除识别历史
    func clearHistory() {
        recognizedTexts.removeAll()
    }
    
    /// 重置所有状态
    func reset() {
        status = .idle
        currentText = ""
        confidence = 0.0
        queuedTasks = 0
        recognizedTexts.removeAll()
        statistics = RecognitionStatistics()
    }
    
    /// 删除指定的识别记录
    func removeRecognizedText(id: UUID) {
        recognizedTexts.removeAll { $0.id == id }
    }
    
    /// 获取最近的识别文本
    func getRecentTexts(limit: Int = 10) -> [RecognizedText] {
        return Array(recognizedTexts.suffix(limit))
    }
    
    // MARK: - Private Methods
    
    private func updateStatistics(recognizedText: RecognizedText, isSuccess: Bool) {
        statistics.totalRecognitions += 1
        statistics.totalDuration += recognizedText.duration
        
        if isSuccess {
            statistics.successCount += 1
            
            // 更新平均置信度
            let totalConfidence = statistics.averageConfidence * Float(statistics.successCount - 1)
            statistics.averageConfidence = (totalConfidence + recognizedText.confidence) / Float(statistics.successCount)
        }
    }
}

// MARK: - Extensions

extension RecognitionState {
    
    /// 获取当前状态的颜色表示
    var statusColor: String {
        switch status {
        case .idle:
            return "gray"
        case .processing:
            return "blue"
        case .completed:
            return "green"
        case .error:
            return "red"
        }
    }
    
    /// 检查是否可以开始新的识别
    var canStartRecognition: Bool {
        return engineStatus.isReady && status != .processing
    }
    
    /// 获取统计信息摘要
    var statisticsSummary: String {
        return """
        总识别次数: \(statistics.totalRecognitions)
        成功率: \(String(format: "%.1f", statistics.successRate * 100))%
        平均置信度: \(String(format: "%.2f", statistics.averageConfidence))
        平均耗时: \(String(format: "%.2f", statistics.averageDuration))秒
        """
    }
    
    /// 获取完整识别文本
    var fullRecognizedText: String {
        return recognizedTexts.map { $0.text }.joined(separator: " ")
    }
}