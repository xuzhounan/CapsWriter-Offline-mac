import SwiftUI

@main
struct CapsWriterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Window("CapsWriter-mac", id: "main") {
            ContentView()
        }
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
}