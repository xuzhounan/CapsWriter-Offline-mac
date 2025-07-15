import SwiftUI
import Combine

class RecordingState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingStartTime: Date?
    @Published var keyboardMonitorStatus: String = "未知"
    @Published var hasAccessibilityPermission: Bool = false
    
    static let shared = RecordingState()
    
    private init() {}
    
    func startRecording() {
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStartTime = Date()
        }
    }
    
    func stopRecording() {
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStartTime = nil
        }
    }
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    func updateKeyboardMonitorStatus(_ status: String) {
        DispatchQueue.main.async {
            self.keyboardMonitorStatus = status
        }
    }
    
    func updateAccessibilityPermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = hasPermission
        }
    }
}