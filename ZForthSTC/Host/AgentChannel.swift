//
//  AgentChannel.swift
//  ZForthSTC
//
//  Public domain.
//
//  Headless / agent control channel for automation (Grok, CI, scripts).
//  Loads Forth sources, evaluates lines, captures all console EMIT to stdout
//  and an optional transcript file — no GUI required.
//
//  Activation (either):
//    • argv contains `--agent`  (or `-agent`)
//    • environment ZFORTHSTC_AGENT=1  (alias: FORTHSTC_AGENT=1)
//
//  Usage examples:
//    ZForthSTC --agent -e '2 2 + .'
//    ZForthSTC --agent -f /path/to/script.fth -o /tmp/out.txt
//    ZForthSTC --agent --cwd ~/Documents/XCodeProjects/ZForthSTC -e 'STC : 1+ 1 + ; 5 1+ .'
//    ZForthSTC --agent --repl < commands.txt
//    ZFORTHSTC_AGENT=1 ZForthSTC -e 'WORDS'
//
//  Exit status:
//    0  all evaluations returned 0 (ok)
//    1  usage / kernel init / any eval non-zero / I/O error
//

import Foundation
#if os(macOS)
import AppKit
#endif

enum AgentChannel {

    /// True when process should run headless agent instead of the GUI.
    static var isRequested: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["ZFORTHSTC_AGENT"] == "1" || env["FORTHSTC_AGENT"] == "1" {
            return true
        }
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--agent") || args.contains("-agent")
    }

    /// Parse argv and run; does not return (calls Foundation.exit).
    static func runAndExit() -> Never {
        let code = run()
        Foundation.exit(code)
    }

    /// Parse argv, run agent session, return process exit code.
    @discardableResult
    static func run() -> Int32 {
        let parsed = parseArgs(ProcessInfo.processInfo.arguments)
        if parsed.help {
            printHelp()
            return 0
        }

        #if os(macOS)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        #endif

        var transcript = ""
        let transcriptLock = NSLock()
        let appendOut: (String) -> Void = { s in
            guard !s.isEmpty else { return }
            transcriptLock.lock()
            transcript += s
            transcriptLock.unlock()
            if let data = s.data(using: .utf8) {
                FileHandle.standardOutput.write(data)
            }
        }

        ForthCBridge.agentSink = appendOut

        // Session supplies cwd / Library for INCLUDE; emit goes through agentSink.
        // AppMain calls us on the main thread before the SwiftUI run loop.
        precondition(Thread.isMainThread, "AgentChannel.run must start on main")
        let session = MainActor.assumeIsolated { ForthSession() }
        ForthCBridge.attach(session)

        appendOut("[ZForthSTC agent] start\n")

        if let cwd = parsed.cwd {
            let fm = FileManager.default
            if fm.changeCurrentDirectoryPath(cwd) {
                MainActor.assumeIsolated {
                    session.cwd = URL(fileURLWithPath: cwd, isDirectory: true)
                }
                appendOut("[ZForthSTC agent] cwd \(cwd)\n")
            } else {
                appendOut("[ZForthSTC agent] ERROR: cannot chdir \(cwd)\n")
                writeTranscriptIfNeeded(parsed.outPath, transcript)
                ForthCBridge.agentSink = nil
                return 1
            }
        }

        let startSt = zforth_agent_start()
        if startSt != 0 {
            appendOut("[ZForthSTC agent] FATAL: kernel cold start failed (\(startSt))\n")
            writeTranscriptIfNeeded(parsed.outPath, transcript)
            ForthCBridge.agentSink = nil
            return 1
        }

        if parsed.autoload {
            // Colon compile is STC-only; autoload.fth must be STC-clean.
            appendOut("[ZForthSTC agent] AutoLoad…\n")
            if let auto = Bundle.main.resourceURL?
                .appendingPathComponent("AutoLoad/autoload.fth", isDirectory: false),
               FileManager.default.fileExists(atPath: auto.path) {
                _ = evaluateInclude(path: auto.path, appendOut: appendOut)
            } else {
                appendOut("[ZForthSTC agent] AutoLoad file not found in bundle\n")
            }
        }

        var failed = false
        for step in parsed.steps {
            switch step {
            case .eval(let line):
                appendOut("[ZForthSTC agent] eval: \(line)\n")
                let st = evaluateLine(line)
                appendOut("[ZForthSTC agent] status=\(st) depth=\(zforth_agent_depth())\n")
                if st != 0 { failed = true }
            case .file(let path):
                appendOut("[ZForthSTC agent] load: \(path)\n")
                let st = evaluateInclude(path: path, appendOut: appendOut)
                appendOut("[ZForthSTC agent] status=\(st) depth=\(zforth_agent_depth())\n")
                if st != 0 { failed = true }
            }
        }

        if parsed.repl {
            appendOut("[ZForthSTC agent] repl (stdin) — EOF to finish\n")
            while let line = readLine(strippingNewline: true) {
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { continue }
                if t.uppercased() == "BYE" {
                    appendOut("[ZForthSTC agent] BYE\n")
                    break
                }
                let st = evaluateLine(t)
                appendOut("ok(\(zforth_agent_depth()))> ")
                if st != 0 { failed = true }
            }
            appendOut("\n")
        }

        if parsed.dumpLast {
            appendOut("[ZForthSTC agent] dump LAST body (64 bytes):\n")
            // LAST ( -- xt ); xt @ is code address for STC colon words
            _ = evaluateLine("LAST")
            // Depth 1: xt on stack. Read via kernel_data_depth + peek from Forth DSP — use LAST @ in C.
            // Evaluate leaves xt; fetch CFA cell with a small helper word is awkward — use HERE of last_cfa.
            dumpLastBody(appendOut: appendOut)
        }

        if parsed.steps.isEmpty && !parsed.repl && !parsed.autoload && !parsed.dumpLast {
            appendOut("[ZForthSTC agent] nothing to do (use -e, -f, --repl, or --autoload)\n")
            appendOut("Try: ZForthSTC --agent --help\n")
            failed = true
        }

        appendOut(failed
            ? "[ZForthSTC agent] DONE (failed)\n"
            : "[ZForthSTC agent] DONE (ok)\n")

        if !writeTranscriptIfNeeded(parsed.outPath, transcript) {
            failed = true
        }

        ForthCBridge.agentSink = nil
        return failed ? 1 : 0
    }

    // MARK: - Eval helpers

    private static func evaluateLine(_ line: String) -> Int32 {
        line.withCString { ptr in
            zforth_agent_eval(ptr, line.utf8.count)
        }
    }

    /// Hex-dump machine code at LAST's CFA (STC body pointer).
    private static func dumpLastBody(appendOut: (String) -> Void) {
        _ = evaluateLine("LAST")
        // After LAST, TOS is xt (CFA addr). Pull via a C helper that reads vm DSP.
        let n = zforth_agent_dump_tos_cfa(64)
        if n != 0 {
            appendOut("[ZForthSTC agent] dump failed (\(n))\n")
        }
    }

    @discardableResult
    private static func evaluateInclude(path: String, appendOut: (String) -> Void) -> Int32 {
        let spec = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spec.isEmpty else {
            appendOut("[ZForthSTC agent] ERROR: empty -f path\n")
            return 1
        }
        let abs: String
        if spec.hasPrefix("/") {
            abs = spec
        } else {
            let base = ForthCBridge.session?.cwd.path
                ?? FileManager.default.currentDirectoryPath
            abs = URL(fileURLWithPath: base).appendingPathComponent(spec).path
        }
        let escaped = abs
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return evaluateLine("INCLUDE \"\(escaped)\"")
    }

    // MARK: - Args

    private enum Step {
        case eval(String)
        case file(String)
    }

    private struct Parsed {
        var help = false
        var autoload = false
        var repl = false
        var dumpLast = false
        var cwd: String?
        var outPath: String?
        var steps: [Step] = []
    }

    private static func parseArgs(_ argv: [String]) -> Parsed {
        var p = Parsed()
        var i = 1
        while i < argv.count {
            let a = argv[i]
            switch a {
            case "--agent", "-agent":
                i += 1
            case "-h", "--help", "-help":
                p.help = true
                i += 1
            case "--no-autoload":
                p.autoload = false
                i += 1
            case "--autoload":
                p.autoload = true
                i += 1
            case "--repl":
                p.repl = true
                i += 1
            case "--dump-last":
                p.dumpLast = true
                i += 1
            case "-e", "--eval":
                i += 1
                guard i < argv.count else {
                    p.help = true
                    break
                }
                p.steps.append(.eval(argv[i]))
                i += 1
            case "-f", "--file", "--fload", "--include":
                i += 1
                guard i < argv.count else {
                    p.help = true
                    break
                }
                p.steps.append(.file(argv[i]))
                i += 1
            case "-c", "--cwd":
                i += 1
                guard i < argv.count else {
                    p.help = true
                    break
                }
                p.cwd = (argv[i] as NSString).expandingTildeInPath
                i += 1
            case "-o", "--out", "--transcript":
                i += 1
                guard i < argv.count else {
                    p.help = true
                    break
                }
                p.outPath = (argv[i] as NSString).expandingTildeInPath
                i += 1
            default:
                if a.hasPrefix("-") {
                    FileHandle.standardError.write(
                        Data("[ZForthSTC agent] unknown option: \(a)\n".utf8)
                    )
                }
                i += 1
            }
        }
        return p
    }

    @discardableResult
    private static func writeTranscriptIfNeeded(_ path: String?, _ text: String) -> Bool {
        guard let path, !path.isEmpty else { return true }
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(to: url, atomically: true, encoding: .utf8)
            let note = "[ZForthSTC agent] transcript → \(path)\n"
            FileHandle.standardOutput.write(Data(note.utf8))
            return true
        } catch {
            let msg = "[ZForthSTC agent] ERROR writing transcript \(path): \(error)\n"
            FileHandle.standardError.write(Data(msg.utf8))
            return false
        }
    }

    private static func printHelp() {
        let help = """
        ZForthSTC agent channel — headless load / eval / capture

        ZForthSTC --agent [options]

        Options:
          -e, --eval <line>       Evaluate a Forth line
          -f, --file <path>       INCLUDE file (also --fload / --include)
          -c, --cwd <path>        Change directory before work
          -o, --out <path>        Write full transcript to path (stdout always)
          --autoload              Run Resources/AutoLoad/autoload.fth first
          --no-autoload           Skip AutoLoad (default in agent mode)
          --repl                  Read further lines from stdin until EOF or BYE
          -h, --help              This help

        Environment:
          ZFORTHSTC_AGENT=1       Same as --agent (shell-safe name)

        Examples:
          ZForthSTC --agent -e '2 2 + .'
          ZForthSTC --agent -e 'STC : 1+ 1 + ; 5 1+ .'
          ZForthSTC --agent -c ~/proj -f smoke.fth -o /tmp/out.txt
          ZForthSTC --agent --repl < session.txt

        Notes:
          • Prefer the binary inside the .app bundle, not `open -a`.
          • GUI instance (if already open) is separate; agent is a new process.
          • Exit 0 = all steps status 0; exit 1 = any failure.

        """
        print(help, terminator: "")
    }
}
