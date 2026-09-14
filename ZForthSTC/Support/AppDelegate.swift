import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        ForthVMControl.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let session = ForthCBridge.session else {
            return .terminateNow
        }
        return UnsavedChanges.confirmOrSave(session: session) ? .terminateNow : .terminateCancel
    }
}

