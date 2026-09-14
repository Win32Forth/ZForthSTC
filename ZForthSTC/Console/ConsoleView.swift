import AppKit
import SwiftUI

struct ConsoleView: View {
    @Bindable var session: ForthSession
    @Environment(\.openWindow) private var openWindow
    @State private var vmStarted = false

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTextView(committed: session.consoleText) { line in
                session.submitConsoleLine(line)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(session.statusLine)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(minWidth: 400, minHeight: 240)
        .background(
            KeyCatcher { event in
                if let chars = event.characters, let ch = chars.first {
                    session.submitKey(character: ch)
                }
            }
        )
        .onAppear {
            session.openEditorWindow = { openWindow(id: "editor") }
            ForthCBridge.attach(session)
            guard !vmStarted else { return }
            vmStarted = true
            ForthVMControl.start()
        }
    }
}
