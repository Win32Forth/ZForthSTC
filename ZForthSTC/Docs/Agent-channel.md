# ZForthSTC agent channel

Headless load / eval / capture for automation (Grok, CI, scripts). Same kernel as the GUI (`kernel_cold_start` + `kernel_eval`); EMIT goes to **stdout** and an optional transcript file.

## Build

Rebuild **ZForthSTC** in Xcode so the Debug (or Release) `.app` includes `AgentChannel.swift` and `AppMain.swift`.

## Invoke

Prefer the binary inside the bundle (not `open -a`):

```bash
./tools/zforthstc-agent -e '2 2 + .'
./tools/zforthstc-agent -e 'STC : 1+ 1 + ; 5 1+ .'
./tools/zforthstc-agent --help
```

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
