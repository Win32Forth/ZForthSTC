import AppKit

final class EditorWindowDelegate: NSObject, NSWindowDelegate {
    var session: ForthSession?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let session else { return true }
        return UnsavedChanges.confirmOrSave(session: session)
    }
}

