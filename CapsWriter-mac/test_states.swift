#!/usr/bin/env swift

import Foundation
import SwiftUI
import Combine

// 测试状态管理文件的编译
class TestStateManager {
    let audioState = AudioState()
    let recognitionState = RecognitionState()
    let appState = AppState()
    
    func testStates() {
        print("Testing AudioState...")
        audioState.startRecording()
        audioState.updateAudioLevel(0.5)
        print("AudioState isRecording: \(audioState.isRecording)")
        print("AudioState audioLevel: \(audioState.audioLevel)")
        
        print("\nTesting RecognitionState...")
        recognitionState.startRecognition()
        recognitionState.updateCurrentText("测试文本", confidence: 0.95)
        print("RecognitionState currentText: \(recognitionState.currentText)")
        print("RecognitionState confidence: \(recognitionState.confidence)")
        
        print("\nTesting AppState...")
        appState.updateAppStatus(.ready)
        appState.switchMode(to: .voiceInput)
        print("AppState status: \(appState.appStatus)")
        print("AppState mode: \(appState.activeMode)")
        
        print("\nAll states compiled and initialized successfully!")
    }
}

// 运行测试
let testManager = TestStateManager()
testManager.testStates()