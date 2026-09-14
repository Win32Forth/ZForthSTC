import Foundation

@MainActor
final class StubInterpreter {
    private let host: ForthHostAPI
    private var running = false

    init(host: ForthHostAPI) {
        self.host = host
    }

    func start() {
        guard !running else { return }
        running = true
        Task { await run() }
    }

    func stop() {
        running = false
    }

    private func run() async {
        guard let host = host as? ForthSession else { return }
        host.type("ZForth host ready.\n")
        while running {
            host.type("ok> ")
            host.requestScreenRefresh()
            let line = await host.accept(maxCount: 256)
            if line == "bye" {
                host.type("goodbye")
                host.cr()
                running = false
                break
            }
            if line == "key" {
                host.type("press a key: ")
                let c = await host.readKey()
                host.type("got \(c)")
                host.cr()
                continue
            }
            host.type("echo: ")
            host.type(line)
            host.cr()
        }
    }
}

