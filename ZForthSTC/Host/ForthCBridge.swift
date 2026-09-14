import AppKit
import Foundation

enum ForthCBridge {
    static weak var session: ForthSession?

    static func attach(_ session: ForthSession) {
        self.session = session
    }

    @MainActor
    static func requireSession() -> ForthSession {
        guard let session else {
            fatalError("ForthCBridge.attach(_:) was not called")
        }
        return session
    }
}

private func onMainSync<T>(_ body: @MainActor () -> T) -> T {
    if Thread.isMainThread {
        return MainActor.assumeIsolated(body)
    }
    return DispatchQueue.main.sync {
        MainActor.assumeIsolated(body)
    }
}

private final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}

@_cdecl("zforth_emit")
public func zforth_emit(_ c: UInt8) {
    onMainSync {
        ForthCBridge.requireSession().emit(c)
    }
}

@_cdecl("zforth_type")
public func zforth_type(_ addr: UnsafePointer<CChar>?, _ u: Int) {
    guard let addr, u > 0 else { return }

    let raw = UnsafeRawBufferPointer(start: UnsafeRawPointer(addr), count: u)
    let string = String(raw.map { byte in
        Character(UnicodeScalar(byte))
    })

    onMainSync {
        ForthCBridge.requireSession().type(string)
    }
}

@_cdecl("zforth_cr")
public func zforth_cr() {
    onMainSync {
        ForthCBridge.requireSession().cr()
    }
}

@_cdecl("zforth_page")
public func zforth_page() {
    onMainSync {
        ForthCBridge.requireSession().page()
    }
}

@_cdecl("zforth_refresh")
public func zforth_refresh() {
    onMainSync {
        ForthCBridge.requireSession().requestScreenRefresh()
    }
}

@_cdecl("zforth_accept")
public func zforth_accept(_ addr: UnsafeMutablePointer<CChar>?, _ maxcount: Int32) -> Int32 {
    precondition(!Thread.isMainThread, "zforth_accept cannot run on the main thread")
    let maxN = max(0, Int(maxcount))
    let box = Box("")
    let sem = DispatchSemaphore(value: 0)

    DispatchQueue.main.async {
        Task { @MainActor in
            box.value = await ForthCBridge.requireSession().accept(maxCount: maxN)
            sem.signal()
        }
    }
    sem.wait()

    guard let addr else { return 0 }
    let bytes = Array(box.value.utf8.prefix(maxN))
    bytes.enumerated().forEach { addr[$0] = CChar(bitPattern: $1) }
    return Int32(bytes.count)
}

@_cdecl("zforth_key")
public func zforth_key() -> Int32 {
    precondition(!Thread.isMainThread, "zforth_key cannot run on the main thread")
    let box = Box<UInt8>(0)
    let sem = DispatchSemaphore(value: 0)

    DispatchQueue.main.async {
        Task { @MainActor in
            box.value = await ForthCBridge.requireSession().readKey()
            sem.signal()
        }
    }
    sem.wait()
    return Int32(box.value)
}

@_cdecl("zforth_fromlib_arm")
public func zforth_fromlib_arm() {
    onMainSync {
        ForthCBridge.requireSession().armFromLib()
    }
}

@_cdecl("zforth_edit_hook")
public func zforth_edit_hook(_ path: UnsafePointer<CChar>?, _ n: Int) {
    precondition(!Thread.isMainThread, "edit hook cannot run on main")
    let raw: String = {
        guard let path, n > 0 else { return "" }
        return String(
            bytes: UnsafeRawBufferPointer(start: UnsafeRawPointer(path), count: n),
            encoding: .utf8
        ) ?? ""
    }()
    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        Task { @MainActor in
            await ForthCBridge.requireSession().applyEdit(raw)
            sem.signal()
        }
    }
    sem.wait()
}

@_cdecl("zforth_chdir_hook")
public func zforth_chdir_hook(_ path: UnsafePointer<CChar>?, _ n: Int) {
    precondition(!Thread.isMainThread)
    let raw: String = {
        guard let path, n > 0 else { return "" }
        return String(bytes: UnsafeRawBufferPointer(start: UnsafeRawPointer(path), count: n), encoding: .utf8) ?? ""
    }()
    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        Task { @MainActor in
            await ForthCBridge.requireSession().applyChdir(raw)
            sem.signal()
        }
    }
    sem.wait()
}

@_cdecl("zforth_pwd_hook")
public func zforth_pwd_hook() {
    onMainSync {
        let session = ForthCBridge.requireSession()
        session.type(session.cwd.path)
        session.cr()
    }
}

@_cdecl("zforth_dir_hook")
public func zforth_dir_hook(_ path: UnsafePointer<CChar>?, _ n: Int) {
    precondition(!Thread.isMainThread)
    let raw: String = {
        guard let path, n > 0 else { return "" }
        return String(bytes: UnsafeRawBufferPointer(start: UnsafeRawPointer(path), count: n), encoding: .utf8) ?? ""
    }()
    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        Task { @MainActor in
            await ForthCBridge.requireSession().applyDir(raw)
            sem.signal()
        }
    }
    sem.wait()
}

@_cdecl("zforth_fromlib_clear")
public func zforth_fromlib_clear() {
    onMainSync {
        ForthCBridge.requireSession().clearFromLib()
    }
}

@_cdecl("zforth_request_quit")
public func zforth_request_quit() {
    DispatchQueue.main.async {
        NSApp.terminate(nil)
    }
}

@_cdecl("zforth_get_load_base")
public func zforth_get_load_base(
    _ out: UnsafeMutablePointer<CChar>?,
    _ maxcount: Int32
) -> Int32 {
    guard let out, maxcount > 0 else { return 0 }
    return onMainSync {
        let session = ForthCBridge.requireSession()
        let base = session.fromLibArmed ? session.libraryURL : session.cwd
        session.clearFromLib()
        return writePath(base.path, to: out, max: Int(maxcount))
    }
}

@_cdecl("zforth_open_panel")
public func zforth_open_panel(_ pathOut: UnsafeMutablePointer<CChar>?, _ maxcount: Int32) -> Int32 {
    precondition(!Thread.isMainThread, "zforth_open_panel cannot run on the main thread")
    let box = Box<URL?>(nil)
    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        Task { @MainActor in
            box.value = await ForthCBridge.requireSession().openFile(
                prompt: "Open",
                types: ["fth", "txt"]
            )
            sem.signal()
        }
    }
    sem.wait()
    guard let url = box.value, let pathOut else { return 0 }
    return writePath(url.path, to: pathOut, max: Int(maxcount))
}

@_cdecl("zforth_save_panel")
public func zforth_save_panel(
    _ pathOut: UnsafeMutablePointer<CChar>?,
    _ maxcount: Int32,
    _ suggested: UnsafePointer<CChar>?
) -> Int32 {
    precondition(!Thread.isMainThread, "zforth_save_panel cannot run on the main thread")
    let name = suggested.map { String(cString: $0) } ?? "Untitled.fth"
    let box = Box<URL?>(nil)
    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        Task { @MainActor in
            box.value = await ForthCBridge.requireSession().saveFile(
                prompt: "Save",
                suggestedName: name,
                types: ["fth", "txt"]
            )
            sem.signal()
        }
    }
    sem.wait()
    guard let url = box.value, let pathOut else { return 0 }
    return writePath(url.path, to: pathOut, max: Int(maxcount))
}

@_cdecl("zforth_load_file")
public func zforth_load_file(
    _ path: UnsafePointer<CChar>?,
    _ addr: UnsafeMutablePointer<CChar>?,
    _ maxcount: Int32
) -> Int32 {
    guard let path, let addr else { return -1 }
    let url = URL(fileURLWithPath: String(cString: path))
    do {
        let text = try String(contentsOf: url, encoding: .utf8)
        let bytes = Array(text.utf8.prefix(Int(max(0, maxcount))))
        bytes.enumerated().forEach { addr[$0] = CChar(bitPattern: $1) }
        return Int32(bytes.count)
    } catch {
        return -1
    }
}

@_cdecl("zforth_save_file")
public func zforth_save_file(
    _ path: UnsafePointer<CChar>?,
    _ addr: UnsafePointer<CChar>?,
    _ count: Int32
) -> Int32 {
    guard let path, let addr, count >= 0 else { return -1 }
    let url = URL(fileURLWithPath: String(cString: path))
    let data = Data(bytes: addr, count: Int(count))
    do {
        try data.write(to: url, options: .atomic)
        return count
    } catch {
        return -1
    }
}

private func writePath(_ path: String, to dest: UnsafeMutablePointer<CChar>, max: Int) -> Int32 {
    let bytes = Array(path.utf8.prefix(max))
    bytes.enumerated().forEach { dest[$0] = CChar(bitPattern: $1) }
    return Int32(bytes.count)
}

enum ForthEvalMailbox {
    private static let lock = NSLock()
    private static var pending: String?

    static func post(_ text: String) {
        lock.lock()
        pending = text
        lock.unlock()
    }

    static func take() -> String? {
        lock.lock()
        defer { lock.unlock() }
        let text = pending
        pending = nil
        return text
    }
}

@_cdecl("zforth_take_source")
public func zforth_take_source(
    _ addr: UnsafeMutablePointer<CChar>?,
    _ maxcount: Int32
) -> Int32 {
    guard let addr, maxcount > 0, let text = ForthEvalMailbox.take() else {
        return 0
    }
    let bytes = Array(text.utf8.prefix(Int(maxcount)))
    bytes.enumerated().forEach { addr[$0] = CChar(bitPattern: $1) }
    return Int32(bytes.count)
}
