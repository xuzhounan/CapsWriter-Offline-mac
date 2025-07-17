//
//  StateManager.swift
//  CapsWriter-mac
//
//  Created by CapsWriter on 2025-07-17.
//

import Foundation
import Combine
import SwiftUI
import AVFoundation

/// 统一状态管理器 - 协调各个状态类并避免职责重叠
@MainActor
class StateManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = StateManager()
    
    // MARK: - State Objects
    
    /// 应用整体状态
    @Published var appState = AppState()
    
    /// 音频录制状态
    @Published var audioState = AudioState()
    
    /// 语音识别状态
    @Published var recognitionState = RecognitionState()
    
    // MARK: - Computed Properties
    
    /// 是否正在录音（来自音频状态）
    var isRecording: Bool {
        audioState.isRecording
    }
    
    /// 权限状态（来自应用状态）
    var permissions: AppState.PermissionStatus {
        appState.permissions
    }
    
    /// 应用是否准备就绪
    var isAppReady: Bool {
        appState.canUseApp && recognitionState.engineStatus.isReady
    }
    
    // MARK: - Legacy Compatibility Properties
    
    /// 为了兼容现有代码，保留一些快捷访问属性
    var hasAccessibilityPermission: Bool {
        appState.permissions.accessibility.isGranted
    }
    
    var hasMicrophonePermission: Bool {
        appState.permissions.microphone.isGranted
    }
    
    var isASRServiceInitialized: Bool {
        recognitionState.engineStatus.isReady
    }
    
    var isASRServiceRunning: Bool {
        if case .initializing = recognitionState.engineStatus { return true }
        return false
    }
    
    var initializationProgress: String {
        switch recognitionState.engineStatus {
        case .uninitialized:
            return "未初始化"
        case .initializing:
            return "正在初始化..."
        case .ready:
            return "已就绪"
        case .error(let message):
            return "错误: \(message)"
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupStateBindings()
    }
    
    // MARK: - Public Methods
    
    /// 开始录音
    func startRecording() {
        guard isAppReady else {
            appState.showError("应用尚未准备就绪")
            return
        }
        
        audioState.startRecording()
        recognitionState.startRecognition()
        
        print("🎤 StateManager: 录音已开始")
    }
    
    /// 停止录音
    func stopRecording() {
        audioState.stopRecording()
        
        print("⏹️ StateManager: 录音已停止")
    }
    
    /// 更新权限状态
    func updatePermissions() {
        // 检查辅助功能权限
        let hasAccessibility = TextInputService.shared.checkAccessibilityPermission()
        appState.updatePermission(\.accessibility, 
                                state: hasAccessibility ? .granted : .denied)
        
        // 检查麦克风权限
        checkMicrophonePermission { [weak self] hasPermission in
            Task { @MainActor in
                self?.appState.updatePermission(\.microphone, 
                                              state: hasPermission ? .granted : .denied)
            }
        }
        
        print("🔄 StateManager: 权限状态已更新")
    }
    
    /// 更新识别引擎状态
    func updateRecognitionEngineStatus(_ status: RecognitionState.EngineStatus) {
        recognitionState.updateEngineStatus(status)
        
        // 更新应用状态
        switch status {
        case .ready:
            if appState.appStatus != .ready {
                appState.updateAppStatus(.ready)
            }
        case .error(let message):
            appState.updateAppStatus(.error(message))
        case .initializing:
            if appState.appStatus == .launching {
                appState.updateAppStatus(.initializing)
            }
        default:
            break
        }
    }
    
    /// 处理识别结果
    func handleRecognitionResult(text: String, confidence: Float, isPartial: Bool = false) {
        if isPartial {
            recognitionState.updateCurrentText(text, confidence: confidence)
        } else {
            let duration = audioState.recordingDuration
            recognitionState.completeRecognition(text: text, confidence: confidence, duration: duration)
        }
    }
    
    /// 处理识别错误
    func handleRecognitionError(_ error: String) {
        recognitionState.handleRecognitionError(error)
        appState.showError("识别错误: \(error)")
    }
    
    /// 重置所有状态
    func resetAllStates() {
        audioState.reset()
        recognitionState.reset()
        appState.reset()
        
        print("🔄 StateManager: 所有状态已重置")
    }
    
    // MARK: - Legacy Compatibility Methods
    
    /// 兼容方法：刷新权限状态
    func refreshPermissionStatus() {
        updatePermissions()
    }
    
    /// 兼容方法：更新键盘监听器状态
    func updateKeyboardMonitorStatus(_ status: String) {
        // 这个信息可以存储在 AppState 中作为通知
        if status.contains("错误") || status.contains("失败") {
            appState.showError("键盘监听器: \(status)")
        } else {
            appState.showNotification("键盘监听器: \(status)", duration: 1.0)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupStateBindings() {
        // 监听音频状态变化
        audioState.$isRecording
            .dropFirst()
            .sink { [weak self] isRecording in
                if !isRecording {
                    // 录音结束时，如果没有最终结果，则标记识别完成
                    if self?.recognitionState.status == .processing {
                        self?.recognitionState.status = .completed
                    }
                }
            }
            .store(in: &cancellables)
        
        // 监听识别状态变化
        recognitionState.$status
            .sink { [weak self] status in
                switch status {
                case .error(let message):
                    self?.appState.showError("识别错误: \(message)")
                case .completed:
                    // 识别完成时的处理
                    break
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }
}

// MARK: - Extensions

extension StateManager {
    
    /// 获取当前录音时长的格式化字符串
    var formattedRecordingDuration: String {
        audioState.formattedDuration
    }
    
    /// 获取当前识别的文本
    var currentRecognitionText: String {
        recognitionState.currentText
    }
    
    /// 获取识别历史
    var recognitionHistory: [RecognitionState.RecognizedText] {
        recognitionState.recognizedTexts
    }
    
    /// 获取应用状态摘要
    var statusSummary: String {
        var components: [String] = []
        
        // 应用状态
        components.append("应用: \(appState.statusSummary)")
        
        // 录音状态
        if audioState.isRecording {
            components.append("录音: \(audioState.statusDescription)")
        }
        
        // 识别状态
        components.append("识别: \(recognitionState.status.description)")
        
        return components.joined(separator: " | ")
    }
}