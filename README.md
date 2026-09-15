# ZForthSTC

**ZForthSTC** is a macOS SwiftUI host and an ARM64 **subroutine-threaded (STC)** Forth kernel.

It continues Tom Zimmer’s ZForth / 16Forth lineage with Grok Build assistance. Colon definitions compile to native ARM64 (`blr` / `ret`); the old ITC / `NEXT` path is gone.

**Current version:** 0.8  
**Console / kernel banner:** `ZForthSTC 0.8 ready === Sep 14, 2026 8:21 PM ===`

Stamp the date/time only when finishing a change set for a version (same policy as 64Forth). Edit the `banner` string in `ZForthSTC/Kernel/kernel.s`.

Repository: this project tree (`ZForthSTC.xcodeproj`).

---

## What it is

| Piece | Role |
| --- | --- |
| **ZForthSTC.app** (SwiftUI) | Forth Console window and Editor / Debugger window |
| **Host bridge** | C ABI (`zforth_*`) between Swift and the kernel |
| **Kernel** | ARM64 STC (`kernel.s`) + embedded `kernel.fth` / `ansfile.fth` |
| **Resources** | Bundled `AutoLoad/`, `Library/`, and `Docs/` |

Open the Xcode project (`ZForthSTC.xcodeproj`) and run the **ZForthSTC** scheme on Apple Silicon macOS.

### Agent channel (headless)

For scripts / CI / tooling without the GUI:

```bash
./tools/zforthstc-agent -e '1 2 + .'
./tools/zforthstc-agent -e ': 1+ 1 + ; 5 1+ .'
./tools/zforthstc-agent --repl < session.txt
```

After boot, `:` always compiles native (STC) code.

See `ZForthSTC/Docs/Agent-channel.md`.

---

## Progress notes

### 2026-09-10 — Project born

- Initial Xcode / SwiftUI scaffold (ZForth host).

### 2026-09-11 — Kernel hosted in the app

- Wired the kernel into the macOS host: cold start, `kernel_eval`, and line input via `ACCEPT`.
- Console output from `EMIT` / host write paths appears in the Forth Console window.
- Host ABI and glue: `zforth_host.h`, `KernelHostGlue.c`, `ForthCBridge.swift`, `ForthSession`.
- Bundled **Resources**: `AutoLoad/`, `Library/`, `Docs/`.
- File menu: Open / Save / **Save As**, dirty detection for the editor.

### 2026-09-12 — EDIT and unified console

- Forth word **`EDIT`**; suppressed editor window at launch.
- Unified console input (no separate command line).
- Version **0.7** banner era (pre-STC fork naming).

### 2026-09-13…14 — STC migration (toward 0.8)

- MAP_JIT dictionary; colon bodies as native ARM64; interpret via `blr` / `ret`.
- Control flow, `CREATE`/`DOES>`, `S"`/`C"`, File-Access, `EXECUTE` under STC.
- ITC / `NEXT` / threaded `LIT`/`BRANCH`/`0BRANCH` removed.

### Version 0.8

- Startup banner: **`ZForthSTC 0.8 ready === Sep 14, 2026 8:21 PM ===`**
- ANS locals (64Forth-adapted for STC): `{: … :}`, `LOCALS|`, `TO`, frame exit on `;`/`EXIT`.
- Forth **`SEE` / `HELP` / `LOCATE`**: STC decompiler (calls→names, lit, strings, `IF`/`ELSE`/`THEN`, mid-body `EXIT` vs `;`).
- Body end = nearest later HFA across `WORDLISTS`; `CODE>XT` walks all registered wordlists.
- **`SYSVOC`** + `FORTH>SYSVOC` / `FORTH>VOC` (64Forth vocsys style) to hide SEE helpers.
- Docs and product naming aligned on **ZForthSTC** (was mixed 16Forth / 16ForthSTC).

---

## Layout

```
ZForthSTC/
  Console/          ConsoleView + editable ConsoleTextView
  Editor/           EditorView
  Host/             ForthSession, agent channel, C bridge, kernel glue
  Kernel/           kernel.s, kernel.fth, ansfile.fth, host_*.c
  Resources/        AutoLoad, Library, Docs (bundled)
  Docs/             Agent-channel.md and related notes
  Support/          FileCommands, unsaved-changes, AppDelegate, …
ZForthSTC.xcodeproj/
tools/zforthstc-agent
```

---

## Notable Forth / host features

- Interactive REPL in the console (committed output + editable input tail).
- Editor window with Open / Save / Save As and unsaved-change guards.
- `EDIT` from the Forth side; headless **agent channel** for automation.
- Native STC colon compile; ANS File-Access words at cold start.
- ANS locals; intelligent `SEE` over STC bodies; `SYSVOC` for support words.

---

## Lineage

ZForthSTC continues the YAFOTW thread after earlier experiments (16Forth / 16ForthCLI, PickleForth, TZForth, ZForth). The sign-on banner and app identify as **ZForthSTC**.
