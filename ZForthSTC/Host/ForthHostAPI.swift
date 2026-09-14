import Foundation

@MainActor
protocol ForthHostAPI: AnyObject {
    func writeConsole(_ text: String)
    func writeConsoleLine(_ text: String)
    func readConsoleLine() async -> String?
    func readKey() async -> UInt8
    func requestScreenRefresh()

    func openFile(prompt: String, types: [String]) async -> URL?
    func saveFile(prompt: String, suggestedName: String, types: [String]) async -> URL?
    func loadText(from url: URL) throws -> String
    func saveText(_ text: String, to url: URL) throws
}

