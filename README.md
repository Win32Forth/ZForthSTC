# ZForth

**ZForth** is a macOS SwiftUI host and a small ARM64 Forth kernel.

ZForth was started as a console + editor application that embeds the **16Forth** kernel lineage (native ARM64 assembly + high-level Forth). The name ZForth is one of Tom Zimmer's Forths created with the assistance of Grok, and Grok Build.

**Current version:** 0.7  
**Console / kernel banner:** `16Forth 0.7 ready === Sep 12, 2026 10:02 AM ===`

Stamp the date/time only when finishing a change set for a version (same policy as 64Forth). Edit the `banner` string in `ZForth/Kernel/kernel.s`.

Repository: [github.com/Win32Forth/ZForth](https://github.com/Win32Forth/ZForth)

**macOS disk image:** `ZForth/Releases/ZForth-0.7.0-macOS.dmg` (also attached to the [v0.7.0](https://github.com/Win32Forth/ZForth/releases/tag/v0.7.0) GitHub release).

---

## What it is

| Piece | Role |
| --- | --- |
| **ZForth.app** (SwiftUI) | Forth Console window and Editor / Debugger window |
| **Host bridge** | C ABI (`zforth_*`) between Swift and the kernel |
| **Kernel** | ARM64 assembly VM (`kernel.s`) + embedded `kernel.fth` / `ansfile.fth` |
| **Resources** | Bundled `AutoLoad/`, `Library/`, and `Docs/` |

Open the Xcode project (`ZForthSTC.xcodeproj`) and run the **ZForthSTC** scheme on Apple Silicon macOS.

### Agent channel (headless)

For scripts / CI / tooling without the GUI:

```bash
./tools/zforthstc-agent -e '1 2 + .'
./tools/zforthstc-agent -e ': 1+ 1 + ; 5 1+ .'
```

After boot blobs, new `:` definitions are STC by default (no need to type `STC`).

See `ZForthSTC/Docs/Agent-channel.md`.

---

## Progress notes (0.6 → 0.7 era)

Work from project creation through version **0.7** (10–12 Sep 2026).

### 2026-09-10 — Project born

- Initial Xcode / SwiftUI scaffold for the ZForth app.

### 2026-09-11 — Kernel hosted in the app

- Wired the **16Forth** kernel into the macOS host: cold start, `kernel_eval`, and line input via `ACCEPT`.
- Console output from `EMIT` / host write paths appears in the Forth Console window.
- Host ABI and glue: `zforth_host.h`, `KernelHostGlue.c`, `ForthCBridge.swift`, `ForthSession`.
- Fixed file pathing for the bundled tree; checked in **Resources** folders:
  - `Resources/AutoLoad/` (including `autoload.fth`)
  - `Resources/Library/` (smoke loaders)
  - `Resources/Docs/`
- File menu work: Open / Save / **Save As**, correct extensions, and keeping a live reference to the opened editor file so Save writes back to the same path.
- **Dirty detection** for the editor: prompt to save / don’t save / cancel on open, close, and quit.

### 2026-09-12 — EDIT and unified console

- Added Forth word **`EDIT`**: open a path (or bare name) in the Editor / Debugger window via `zforth_edit_hook`.
- Dirty check on `EDIT` so unsaved editor content is not silently discarded.
- Editor window launch behavior set to **suppressed** so it does not appear at app startup (only when opened from the menu or `EDIT`).
- **Unified console input**: removed the separate command line at the bottom. Commands are typed in the same window as output, with normal editing and paste of the input tail before Return submits the line.

### Version 0.7

- Startup banner bumped from `16Forth 0.6 ready` to **`16Forth 0.7 ready`**, with a 64Forth-style date/time stamp:  
  `16Forth 0.7 ready === Sep 12, 2026 10:02 AM ===`
- This README added to capture the above progress.

---

## Layout

```
ZForth/
  Console/          ConsoleView + editable ConsoleTextView
  Editor/           EditorView
  Host/             ForthSession, C bridge, kernel glue
  Kernel/           kernel.s, kernel.fth, ansfile.fth, host_*.c
  Resources/        AutoLoad, Library, Docs (bundled)
  Support/          FileCommands, unsaved-changes, AppDelegate, …
ZForth.xcodeproj/
```

---

## Notable Forth / host features so far

- Interactive REPL in the console (committed output + editable input tail).
- Editor window with Open / Save / Save As and unsaved-change guards.
- `EDIT` from the Forth side to load a file into the editor.
- Working directory and library path helpers on the host session (`chdir`, `fromLib`, etc.).
- Embedded high-level Forth and ANS-style file words loaded at cold start.

---

## Lineage

ZForth continues the YAFOTW thread after earlier experiments (e.g. 16Forth / 16ForthCLI, PickleForth, TZForth). The kernel still identifies as **16Forth** in the sign-on banner; the **app and repo** are named **ZForth**.
