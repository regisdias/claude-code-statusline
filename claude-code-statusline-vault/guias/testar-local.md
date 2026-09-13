---
tipo: guia
data: 2026-09-12
atualizado: 2026-09-13
---

# Testing without opening Claude Code

The script depends only on the JSON arriving on standard input, so any file works as a payload. The
cases that matter are already in `scripts/payloads/`:

| Payload | Covers |
|---|---|
| `verde.json` | the complete case, everything below 60% |
| `amarelo.json` | the yellow band (60–85%) |
| `vermelho.json` | the red band (above 85%) |
| `sem-limites.json` | a plan with no quota, only the `ctx` bar |
| `vazio.json` | `{}` → `Claude  waiting...` |
| `invalido.json` | text that is not JSON → `Claude  waiting...` |

## The shortcut: `scripts/testar.sh`

```bash
bash scripts/testar.sh
```

Runs **every** payload through both implementations, diffs the bytes and checks the `.ps1` still has its
UTF-8 BOM. Without `pwsh` installed it tests the shell side only and says so. It is the same command CI
runs.

## By hand, one payload at a time

```bash
bash statusline-command.sh < scripts/payloads/verde.json
```

On Windows:

```powershell
Get-Content scripts\payloads\verde.json | powershell -NoProfile -File .\statusline-command.ps1
```

From WSL, using Windows' PowerShell — this is how the `.ps1` was validated without leaving Linux:

```bash
cat scripts/payloads/verde.json | powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w statusline-command.ps1)"
```

## Comparing the two by hand

When `testar.sh` reports a difference and you want to see where:

```bash
bash statusline-command.sh < scripts/payloads/verde.json > /tmp/sh.txt
cat scripts/payloads/verde.json | powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w statusline-command.ps1)" | tr -d '\r' > /tmp/ps.txt
cmp /tmp/sh.txt /tmp/ps.txt && echo identical
```

The `tr -d '\r'` is there because PowerShell returns Windows line endings across the WSL bridge.

Environment variables do **not** cross that bridge on their own. To test something that depends on one —
`CLAUDE_CONFIG_DIR`, `COLUMNS` — list it in `WSLENV`:

```bash
WSLENV=COLUMNS COLUMNS=80 powershell.exe -NoProfile -File "$(wslpath -w statusline-command.ps1)"
```

Without that, the variable arrives empty on the Windows side and the comparison silently tests the wrong
thing.

## Seeing the ANSI codes

```bash
bash statusline-command.sh < scripts/payloads/verde.json | cat -v
```

Useful when a colour does not close: `^[[0m` has to appear right after each bar.

## Running the lint the way CI runs it

```bash
shellcheck --severity=warning statusline-command.sh install.sh scripts/testar.sh \
    scripts/testar-instalador.sh hooks/ccsl-update-check.sh
pwsh -c 'Invoke-ScriptAnalyzer -Path statusline-command.ps1 -Severity Error,Warning'
```

## Testing the installer without touching your `~/.claude`

The installer has its own suite, kept apart because it needs the network:

```bash
CCSL_BRANCH=your-branch bash scripts/testar-instalador.sh
```

It installs into a throwaway `HOME`, so `~`, `$HOME` and the absolute path all name the same file —
which is what makes it able to test that the installer recognises its own script however the path is
spelled. It skips itself when there is no network.

For a single manual run, `install.sh` respects `CLAUDE_CONFIG_DIR`:

```bash
CLAUDE_CONFIG_DIR=/tmp/teste-ccsl bash install.sh
```

It downloads the script from GitHub, so that exercises the real path — including whether
`raw.githubusercontent` already has the commit you just pushed.

See also [[regenerar-imagens-do-readme]] and [[validar-no-macos]].
