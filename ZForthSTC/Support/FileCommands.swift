import AppKit
import SwiftUI

struct FileCommands: Commands {
    var session: ForthSession
    @Environment(\.openWindow) private var openWindow
    
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open into Editor…") {
                Task { await openIntoEditor() }
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Button("Save Editor") {
                Task { await saveEditor() }
            }
            .keyboardShortcut("s", modifiers: .command)
            
            Button("Save Editor As…") {
                Task { await saveEditorAs() }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        CommandMenu("Forth") {
            Button("Evaluate Editor") {
                ForthEvalMailbox.post(session.editorText)
                session.submitConsoleLine("")   // wake zforth_accept
                session.statusLine = "Editor queued for evaluate"
            }
            .keyboardShortcut("e", modifiers: [.command])
        }
    }
    
    @MainActor
    private func openIntoEditor() async {
        guard UnsavedChanges.confirmOrSave(session: session) else { return }
        guard let url = await session.openFile(
            prompt: "Open Forth source",
            types: ["fth", "txt"]
        ) else { return }

        do {
            session.editorText = try session.loadText(from: url)
            session.editorURL = url
            session.cwd = url.deletingLastPathComponent()
            session.statusLine = "Loaded \(url.lastPathComponent)"
            session.openEditorWindow?()
            session.markEditorSaved()
        } catch {
            session.statusLine = "Load failed: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func showEditorWindow() {
        if let win = NSApp.windows.first(where: { window in
            window.identifier?.rawValue == "editor"
            || window.title.contains("Editor")
        }) {
            if windowIsMiniaturized(win) { win.deminiaturize(nil) }
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Window was closed: ask SwiftUI to recreate the "editor" scene.
    }
    
    private func windowIsMiniaturized(_ win: NSWindow) -> Bool {
        win.isMiniaturized
    }
    
    @MainActor
    private func saveEditor() async {
        if let url = session.editorURL {
            do {
                try session.saveText(session.editorText, to: url)
                session.statusLine = "Saved \(url.lastPathComponent)"
                session.markEditorSaved()
            } catch {
                session.statusLine = "Save failed: \(error.localizedDescription)"
            }
            return
        }
        await saveEditorAs()
    }
    
    @MainActor
    private func saveEditorAs() async {
        guard let url = await session.saveFile(
            prompt: "Save Forth source",
            suggestedName: session.editorURL?.lastPathComponent ?? "Untitled.fth",
            types: ["fth", "txt"]
        ) else { return }
        
        do {
            try session.saveText(session.editorText, to: url)
            session.editorURL = url
            session.cwd = url.deletingLastPathComponent()
            session.statusLine = "Saved \(url.lastPathComponent)"
            session.markEditorSaved()
        } catch {
            session.statusLine = "Save failed: \(error.localizedDescription)"
        }
    }
}
