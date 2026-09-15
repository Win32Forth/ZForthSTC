import AppKit
import SwiftUI

struct ConsoleTextView: NSViewRepresentable {
    var committed: String
    var onSubmit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.autohidesScrollers = true

        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        // Forth needs ASCII ' and -; macOS smart quotes/dashes break TICK etc.
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textColor = .labelColor
        tv.backgroundColor = .textBackgroundColor
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainerInset = NSSize(width: 6, height: 6)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        context.coordinator.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onSubmit = onSubmit
        guard let tv = scroll.documentView as? NSTextView else { return }
        context.coordinator.applyCommitted(committed, in: tv)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onSubmit: (String) -> Void
        weak var textView: NSTextView?
        private var committedUTF16 = 0
        private var lastCommitted = ""
        private var keepTail = true

        init(onSubmit: @escaping (String) -> Void) {
            self.onSubmit = onSubmit
        }

        func applyCommitted(_ committed: String, in tv: NSTextView) {
            if committed == lastCommitted { return }
            let tail = keepTail ? currentTail(in: tv) : ""
            keepTail = true
            lastCommitted = committed
            committedUTF16 = (committed as NSString).length
            tv.string = committed + tail
            let end = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: end, length: 0))
            scrollToCaret(tv)
        }

        private func currentTail(in tv: NSTextView) -> String {
            let s = tv.string as NSString
            if s.length <= committedUTF16 { return "" }
            return s.substring(from: committedUTF16)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let line = currentTail(in: textView)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\n\r"))
                keepTail = false
                onSubmit(line)
                return true
            }
            return false
        }
        
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            scrollToCaret(tv)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            scrollToCaret(tv)
        }

        private func scrollToCaret(_ tv: NSTextView) {
            let r = tv.selectedRange()
            let loc = min(r.location, (tv.string as NSString).length)
            tv.scrollRangeToVisible(NSRange(location: loc, length: 0))
        }
    }
}
