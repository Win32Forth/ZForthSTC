import SwiftUI

@main
struct ForthConsoleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var session = ForthSession()

    var body: some Scene {
        Window("Forth Console", id: "console") {
            ConsoleView(session: session)
                .onAppear { ForthCBridge.attach(session) }
        }
        .defaultSize(width: 720, height: 480)
        .defaultPosition(.topLeading)
        .defaultLaunchBehavior(.presented)

        Window("Editor / Debugger", id: "editor") {
            EditorView(session: session)
        }
        .defaultSize(width: 720, height: 560)
        .defaultPosition(.topTrailing)
        .defaultLaunchBehavior(.suppressed)

        .commands {
            FileCommands(session: session)
        }
    }
}
