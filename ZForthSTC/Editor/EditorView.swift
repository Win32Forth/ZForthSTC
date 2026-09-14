import AppKit
import SwiftUI

struct EditorView: View {
    @Bindable var session: ForthSession

    var body: some View {
        TextEditor(text: $session.editorText)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 400, minHeight: 280)
            .onAppear {
                session.editorWindowDelegate.session = session
                if let win = NSApp.windows.first(where: {
                    $0.identifier?.rawValue == "editor" || $0.title.contains("Editor")
                }) {
                    win.delegate = session.editorWindowDelegate
                }
                applyTitle()
            }
            .onChange(of: session.editorWindowTitle) { _, _ in applyTitle() }
    }

    private func applyTitle() {
        if let win = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "editor" || $0.title.contains("Editor")
        }) {
            win.title = session.editorWindowTitle
        }
    }
}

