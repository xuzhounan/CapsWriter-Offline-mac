import Foundation

// 简化的 C API 测试
class SherpaTestBridge {
    static func testTypes() {
        print("🔍 测试 C API 类型...")
        
        // 测试基本配置结构
        var config = SherpaOnnxOnlineRecognizerConfig()
        config.enable_endpoint = 1
        print("✅ 基本配置可用")
        
        // 测试版本函数
        if let version = SherpaOnnxGetVersionStr() {
            let versionStr = String(cString: version)
            print("✅ 版本: \(versionStr)")
        }
        
        print("🎉 测试完成")
    }
}