# ZForthSTC agent channel

Headless load / eval / capture for automation (Grok, CI, scripts). Same kernel as the GUI (`kernel_cold_start` + `kernel_eval`); EMIT goes to **stdout** and an optional transcript file.

## Build

Rebuild **ZForthSTC** in Xcode so the Debug (or Release) `.app` includes `AgentChannel.swift` and `AppMain.swift`.

## Invoke

Prefer the binary inside the bundle (not `open -a`):

```bash
./tools/zforthstc-agent -e '2 2 + .'
./tools/zforthstc-agent -e ': 1+ 1 + ; 5 1+ .'
./tools/zforthstc-agent --help
```

Cold start sets `stc_mode` before loading **`kernel.fth`** and **`ansfile.fth`**, so boot colon words (including File-Access) are **STC**. Colon compile is **STC-only**: immediates (`IF`/`THEN`/…, `LITERAL`, `S"`/`."`/`C"`, `POSTPONE`, `;`, `DOES>`) emit native code only — ITC compile arms are gone. The `ITC` word and `.ITC` / `(ITC?)` diagnostics are removed; `STC` remains as a no-op that re-asserts `stc_mode`.

STC control flow supported: `IF`/`ELSE`/`THEN`, `BEGIN`/`UNTIL`/`WHILE`/`REPEAT`/`AGAIN`, and `DO`/`?DO`/`LOOP`/`+LOOP` (with `I`/`J`/`LEAVE`/`UNLOOP`).

`CREATE` / `DOES>` work under STC (native does-body + `_stc_dodoes`). `EXECUTE` works interpretively and from STC colon. Runtime `'` preserves DSP/RSP around `_word`/`_find`. `LITERAL` compiles `mov`/DPUSH. `S"` / `."` use `blr _stc_slit`; `C"` uses `blr _stc_cstr`. `POSTPONE` is STC-only (imm → `_compile_word`; non-imm → lit xt + `_stc_compile_tos`). Stores into the MAP_JIT dictionary (`!` `C!` `2!` `+!` `CMOVE`, branch patches, and `(READ-FILE)`/`(READ-LINE)` into buffers like `PAD`) temporarily re-enable write protect while an STC body is running — `VARIABLE`/`CREATE` data share that region with code.

Compile policy for STC bodies: user-dict STC and kernel CODE → direct `blr`; `CREATE`/`VARIABLE`/`DOES>` children (DOVAR or `_stc_dodoes`) → `mov xt` + `_stc_create_xt` (re-reads CFA). Interpret and STC share one calling convention: `blr` the CFA code; `STC_TAIL` is plain `ret`. Kernel CODE that uses `bl` must `CODE_SAVE_LR` / `CODE_RESTORE_LR` around the body (ARM64 `ret` uses LR; `bl` clobbers it). `stc_running` is set only while the MAP_JIT dict is RX (user-dict / DOES> via `L_exec_dict_rx`, and nested `_stc_call_itc`); interpret of kernel CODE leaves the dict RW and `stc_running=0` so `_jit_rw_*` does not toggle write-protect on every emit. The old `NEXT` / `restart_cell` / `XRESTART` path is gone. `_stc_call_itc` remains for nested `EXECUTE` from STC. Threading primitives `LIT`/`BRANCH`/`0BRANCH`/`DOCOL`/`DODOES` and ITC `(DO)`/`(S")`/`(C")`/`(DOES>)` are gone. `EXIT` remains only as a named xt so compiling it emits the STC colon epilogue (interpret is a no-op). `SEE`/`HELP` are stubs (tag + help + `(primitive)`); ITC decompiler/`*-ADDR`/`DOCOL?` removed. `_abort` clears `stc_running`. `_jit_rw_*` preserves DSP/RSP around `pthread_jit_write_protect_np`. `XT?` is true for a plausible dict CFA; `STC?` / `STC-COLON?` use that guard so bad xts return false instead of faulting.

Or:

```bash
"$HOME/Library/Developer/Xcode/DerivedData"/ZForthSTC-*/Build/Products/Debug/ZForthSTC.app/Contents/MacOS/ZForthSTC \
  --agent -e '1 2 + .'
```

Environment: `ZFORTHSTC_AGENT=1` is the same as `--agent`.

## Options

| Flag | Meaning |
|------|---------|
| `-e` / `--eval` | Evaluate one Forth line (repeatable; order preserved) |
| `-f` / `--file` | `INCLUDE` a file |
| `-c` / `--cwd` | `chdir` before work (also sets session load base) |
| `-o` / `--out` | Write full transcript to a path (stdout always) |
| `--autoload` | Load `Resources/AutoLoad/autoload.fth` first |
| `--repl` | Read more lines from stdin until EOF or `BYE` |
| `-h` / `--help` | Help |

Exit **0** if every step returns status 0; otherwise **1**.

## Layout

| File | Role |
|------|------|
| `AppMain.swift` | Chooses agent vs GUI |
| `Host/AgentChannel.swift` | Args, cwd, eval/load, transcript |
| `Host/KernelHostGlue.c` | `zforth_agent_start` / `zforth_agent_eval` |
| `Host/ForthCBridge.swift` | Agent emit sink; panels cancelled in agent mode |
| `tools/zforthstc-agent` | Shell wrapper |
