---
type: bug-fix
date: 2026-09-12
---

# PowerShell: a file without a BOM, and a variable collision

Two problems that only showed up running the `.ps1` on **real PowerShell 5.1**. Neither is visible when
reading the code.

## 1. Without a BOM, PowerShell 5.1 reads the file as ANSI

**Symptom:** a parser error on the very first run.

```
The string is missing the terminator: '
TerminatorExpectedAtEndOfString
```

**Cause:** Windows PowerShell 5.1 assumes ANSI when the file has no BOM. The UTF-8 bytes of the `│`
separator become loose characters, one of which breaks the single quote, and the whole script stops
compiling. PowerShell 7 reads UTF-8 without a BOM and does not suffer from this.

**Fix:** save the `.ps1` as **UTF-8 with BOM**. With the BOM, both versions of PowerShell work.

**Standing hazard:** an editor that saves without a BOM breaks the script again. The README warns about
it, and it is worth checking after any edit:

```bash
head -c3 statusline-command.ps1 | xxd -p   # must be efbbbf
```

## 2. PowerShell variables are case-insensitive

**Symptom:** the colour did not close and the time leaked into the middle of the line:

```
5h [32m[████░░░░░░]06:20 41% · reseta 06:20
```

**Cause:** `$reset` (the reset time) and `$RESET` (the ANSI code that ends the colour) are **the same
variable**. Assigning the time erased the ANSI code, which was then printed as text in its place.

**Fix:** rename the local to `$quandoReseta`.

**The rule that stays:** in PowerShell, a variable name differing only by case is the same name.
Uppercase constants (`$RESET`, `$GREEN`) need locals that look visibly different, not merely different
in case.

## How both were caught

Running the script through Windows' `powershell.exe` from WSL, with four different payloads — see
[[../guides/testing-locally]]. Code review would have caught neither.
