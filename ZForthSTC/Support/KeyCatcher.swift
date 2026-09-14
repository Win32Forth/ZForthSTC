import AppKit
import SwiftUI

struct KeyCatcher: NSViewRepresentable {
    var onKey: (NSEvent) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onKey = onKey
    }

    final class MonitorView: NSView {
        var onKey: ((NSEvent) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.onKey?(event)
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
