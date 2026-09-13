---
type: decision
date: 2026-09-12
---

# Two implementations, with identical output

**Decision:** keep `statusline-command.sh` and `statusline-command.ps1` as parallel implementations
rather than requiring a single environment.

## Why

Claude Code runs the status line command through the system shell. On native Windows that is PowerShell,
where `bash`, `jq` and `awk` do not exist. The options were:

| Path | Problem |
|---|---|
| Shell only, requiring Git Bash | Pushes away exactly the people running Claude Code on Windows without WSL |
| Shell only, requiring WSL | The same, with more weight |
| Rewrite in Node | Adds a runtime dependency and spawns a process on every render |
| **Two implementations** | Duplicates ~100 lines, and each uses only what the system already has |

The duplication is small and the gain is direct: someone on Windows copies one file and is done; someone
on Linux, WSL or macOS copies the other.

## The contract between them

The output has to be **byte-for-byte identical** for the same payload. That is the test that matters
before publishing any change — see [[../guides/testing-locally]].

Practical consequences: neither may gain a field the other lacks, and a format change lands in both in
the same commit.

## Accepted dependencies

- Shell: `jq`, `awk`, `bash` — present or trivial to install on all three systems
- PowerShell: nothing beyond the Windows PowerShell 5.1 that ships with Windows
