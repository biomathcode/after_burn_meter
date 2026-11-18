import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        if model.phase.isActive {
            let alert = NSAlert()
            alert.messageText = "End your current session?"
            alert.informativeText = "Camera capture will stop. A recovery in progress will be saved as interrupted."
            alert.addButton(withTitle: "End session and quit")
            alert.addButton(withTitle: "Keep training")
            guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
        }
        model.shutdown()
        return .terminateNow
    }
}

@main
struct AfterburnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Afterburn", id: "main") {
            RootView().environment(model)
                .onAppear { delegate.model = model }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
                    model.interrupt()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 860)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New workout") { model.resetSession(); model.section = .workout }
                    .keyboardShortcut("n").disabled(model.phase.isActive)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.section = .settings }.keyboardShortcut(",")
            }
        }
    }
}
