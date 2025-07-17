//
//  AudioState.swift
//  CapsWriter-mac
//
//  Created by CapsWriter on 2025-07-17.
//

import Foundation
import Combine

/// 音频录制相关状态管理
@MainActor
class AudioState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 是否正在录音
    @Published var isRecording: Bool = false
    
    /// 当前录音音量等级 (0.0 - 1.0)
    @Published var audioLevel: Float = 0.0
    
    /// 录音时长（秒）
    @Published var recordingDuration: TimeInterval = 0.0
    
    /// 音频设备状态
    @Published var audioDeviceStatus: AudioDeviceStatus = .unknown
    
    /// 音频质量指标
    @Published var audioQuality: AudioQuality = .good
    
    // MARK: - Private Properties
    
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    
    // MARK: - Enums
    
    enum AudioDeviceStatus {
        case unknown
        case available
        case unavailable
        case permissionDenied
    }
    
    enum AudioQuality {
        case poor
        case fair
        case good
        case excellent
        
        var description: String {
            switch self {
            case .poor: return "音质较差"
            case .fair: return "音质一般"
            case .good: return "音质良好"
            case .excellent: return "音质优秀"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始录音
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0.0
        
        startDurationTimer()
    }
    
    /// 停止录音
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        recordingStartTime = nil
        audioLevel = 0.0
        
        stopDurationTimer()
    }
    
    /// 更新音频等级
    func updateAudioLevel(_ level: Float) {
        audioLevel = max(0.0, min(1.0, level))
        updateAudioQuality(level)
    }
    
    /// 更新音频设备状态
    func updateDeviceStatus(_ status: AudioDeviceStatus) {
        audioDeviceStatus = status
    }
    
    /// 重置状态
    func reset() {
        stopRecording()
        audioLevel = 0.0
        recordingDuration = 0.0
        audioDeviceStatus = .unknown
        audioQuality = .good
    }
    
    // MARK: - Private Methods
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateRecordingDuration()
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }
    
    private func updateAudioQuality(_ level: Float) {
        switch level {
        case 0.0..<0.1:
            audioQuality = .poor
        case 0.1..<0.3:
            audioQuality = .fair
        case 0.3..<0.7:
            audioQuality = .good
        default:
            audioQuality = .excellent
        }
    }
}

// MARK: - Extensions

extension AudioState {
    
    /// 获取格式化的录音时长字符串
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 检查是否可以开始录音
    var canStartRecording: Bool {
        return !isRecording && audioDeviceStatus == .available
    }
    
    /// 获取音频状态描述
    var statusDescription: String {
        if isRecording {
            return "正在录音 - \(formattedDuration)"
        } else {
            switch audioDeviceStatus {
            case .unknown:
                return "音频设备状态未知"
            case .available:
                return "准备就绪"
            case .unavailable:
                return "音频设备不可用"
            case .permissionDenied:
                return "麦克风权限被拒绝"
            }
        }
    }
}