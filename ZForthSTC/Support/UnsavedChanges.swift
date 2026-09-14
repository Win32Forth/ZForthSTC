import AppKit

enum UnsavedDecision {
    case save, discard, cancel
}

@MainActor
enum UnsavedChanges {
    static func ask(fileName: String) -> UnsavedDecision {
        let alert = NSAlert()
        alert.messageText = "Save changes to \(fileName)?"
        alert.informativeText = "Your edits will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        switch alert.runModal() {
        case .alertFirstButtonReturn:  return .save
        case .alertSecondButtonReturn: return .discard
        default:                       return .cancel
        }
    }

    static func confirmOrSave(session: ForthSession) -> Bool {
        guard session.isEditorDirty else { return true }
        let name = session.editorURL?.lastPathComponent ?? "untitled.fth"
        switch ask(fileName: name) {
        case .cancel:
            return false
        case .discard:
            return true
        case .save:
            do {
                if let url = session.editorURL {
                    try session.saveText(session.editorText, to: url)
                    session.markEditorSaved()
                    session.statusLine = "Saved \(url.lastPathComponent)"
                    return true
                }
                session.statusLine = "Save As required"
                return false
            } catch {
                session.statusLine = "Save failed: \(error.localizedDescription)"
                return false
            }
        }
    }
}

