import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class ForthSession: ForthHostAPI {
    let editorWindowDelegate = EditorWindowDelegate()
    
    var openEditorWindow: (() -> Void)?
    var consoleText: String = ""
    var editorText: String = ""
    var statusLine: String = "Ready"
    var editorURL: URL?
    var fromLibArmed = false
    
    var editorSavedText: String = ""

    var isEditorDirty: Bool {
        editorText != editorSavedText
    }

    var editorWindowTitle: String {
        let file = editorURL?.lastPathComponent ?? "untitled.fth"
        let shown = file.count <= 32 ? file : String(file.suffix(32))
        let mark = isEditorDirty ? "*" : ""
        return "Editor / Debugger  \(shown)\(mark)"
    }

    func markEditorSaved() {
        editorSavedText = editorText
    }
    
    var cwd: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
    
    var libraryURL: URL {
        let base = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        return base.appendingPathComponent("Library", isDirectory: true)
    }

    func armFromLib() { fromLibArmed = true }
    func clearFromLib() { fromLibArmed = false }
    
    func pathString(_ path: UnsafePointer<CChar>?, _ n: Int) -> String {
        guard let path, n > 0 else { return "" }
        return String(bytes: UnsafeRawBufferPointer(start: UnsafeRawPointer(path), count: n), encoding: .utf8) ?? ""
    }

    func resolveDir(_ raw: String) -> URL? {
        if raw.isEmpty { return nil }
        if raw.hasPrefix("/") { return URL(fileURLWithPath: raw, isDirectory: true) }
        return cwd.appendingPathComponent(raw, isDirectory: true)
    }

    func applyChdir(_ raw: String) async {
        let url: URL?
        if raw.isEmpty {
            url = await pickFolder(prompt: "Change directory")
        } else {
            url = resolveDir(raw)
        }
        guard let url else {
            type("chdir cancelled")
            cr()
            return
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            type("can't chdir: \(url.path)")
            cr()
            return
        }
        cwd = url.standardizedFileURL
        fromLibArmed = false
    }

    func applyDir(_ raw: String) async {
        let url: URL?
        if raw.isEmpty {
            url = fromLibArmed ? libraryURL : cwd
            fromLibArmed = false
        } else {
            url = resolveDir(raw)
        }
        guard let url else { return }
        do {
            let names = try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
            type(url.path)
            cr()
            for name in names where !name.hasPrefix(".") {
                type(name)
                cr()
            }
        } catch {
            type("can't dir: \(error.localizedDescription)")
            cr()
        }
    }

    func pickFolder(prompt: String) async -> URL? {
        let panel = NSOpenPanel()
        panel.message = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = cwd
        guard await panel.begin() == .OK else { return nil }
        return panel.url
    }
    
    private var inputWaiter: CheckedContinuation<String?, Never>?
    private var unreadLines: [String] = []

    func writeConsole(_ text: String) {
        consoleText.append(text)
    }

    func writeConsoleLine(_ text: String) {
        consoleText.append(text)
        if !text.hasSuffix("\n") { consoleText.append("\n") }
    }

    func requestScreenRefresh() {
        statusLine = "Refreshed"
    }

    func readConsoleLine() async -> String? {
        if !unreadLines.isEmpty {
            return unreadLines.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            inputWaiter = continuation
        }
    }

    func submitConsoleLine(_ line: String) {
        writeConsole(line)
        writeConsole("\n")
        if let waiter = inputWaiter {
            inputWaiter = nil
            waiter.resume(returning: line)
        } else {
            unreadLines.append(line)
        }
    }

    func applyEdit(_ raw: String) async {
        guard UnsavedChanges.confirmOrSave(session: self) else { return }
        let url: URL?
        if raw.isEmpty {
            url = await openFile(
                prompt: fromLibArmed ? "Edit Library file" : "Edit file",
                types: ["fs", "fth", "txt"]
            )
            // openFile already uses fromLibArmed / cwd for the panel
        } else if raw.hasPrefix("/") {
            url = URL(fileURLWithPath: raw)
        } else {
            let base = fromLibArmed ? libraryURL : cwd
            fromLibArmed = false
            url = base.appendingPathComponent(raw)
        }

        guard let url else { return }

        do {
            let text = try loadText(from: url)
            editorText = text
            editorURL = url
            cwd = url.deletingLastPathComponent()
            markEditorSaved()
            statusLine = "Editing \(url.lastPathComponent)"
            openEditorWindow?()
        } catch {
            type("can't edit: \(url.path)")
            cr()
        }
    }
    
    func openFile(prompt: String, types: [String]) async -> URL? {
        let panel = NSOpenPanel()
        panel.message = prompt
        panel.allowedContentTypes = types.compactMap { UTType(filenameExtension: $0) }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = fromLibArmed ? libraryURL : cwd
        let ok = await panel.begin() == .OK
        if fromLibArmed { clearFromLib() }
        guard ok, let url = panel.url else { return nil }
        cwd = url.deletingLastPathComponent()
        return url
    }
    
    func saveFile(prompt: String, suggestedName: String, types: [String]) async -> URL? {
        let panel = NSSavePanel()
        panel.message = prompt
        panel.allowedContentTypes = types.compactMap { UTType(filenameExtension: $0) }
        let base = (suggestedName as NSString).deletingPathExtension
        panel.nameFieldStringValue = base.isEmpty ? suggestedName : base
        guard await panel.begin() == .OK else { return nil }
        return panel.url
    }

    func loadText(from url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func saveText(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private var keyWaiter: CheckedContinuation<UInt8, Never>?
    private var unreadKeys: [UInt8] = []

    // MARK: Forth primitives

    /// EMIT ( x -- )  emit low 8 bits as a character
    func emit(_ x: UInt8) {
        if x == 10 || x == 13 {
            writeConsole("\n")
            return
        }
        if let scalar = UnicodeScalar(UInt32(x)) {
            writeConsole(String(Character(scalar)))
        }
    }

    /// TYPE ( addr u -- )  here: a Swift String
    func type(_ string: String) {
        writeConsole(string)
    }

    /// CR ( -- )
    func cr() {
        writeConsole("\n")
    }

    /// PAGE / REFRESH
    func page() {
        consoleText = ""
        requestScreenRefresh()
    }

    /// ACCEPT ( addr +n1 -- +n2 )  here: returns the line, truncated
    func accept(maxCount: Int) async -> String {
        let line = await readConsoleLine() ?? ""
        if line.count <= maxCount { return line }
        return String(line.prefix(maxCount))
    }

    /// KEY ( -- char )
    func readKey() async -> UInt8 {
        if !unreadKeys.isEmpty {
            return unreadKeys.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            keyWaiter = continuation
        }
    }

    func submitKey(_ byte: UInt8) {
        if let waiter = keyWaiter {
            keyWaiter = nil
            waiter.resume(returning: byte)
        } else {
            unreadKeys.append(byte)
        }
    }

    func submitKey(character: Character) {
        for scalar in character.unicodeScalars {
            let v = scalar.value
            if v <= 0xFF {
                submitKey(UInt8(v))
            }
        }
    }
}
