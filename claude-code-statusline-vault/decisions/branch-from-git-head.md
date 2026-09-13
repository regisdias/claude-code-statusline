---
type: decision
date: 2026-09-12
---

# The branch comes from `.git/HEAD`, not from `git`

## Decision

To show the branch in the bar, both implementations **read the `.git/HEAD` file** and walk up the
directories until they find it. Neither calls `git`.

## Why

Claude Code **does not send the branch in the payload**. Confirmed in the documentation: there is
`workspace.repo.host/owner/name` (the repository identity, from the `origin` remote) and
`worktree.branch`, which only appears inside a worktree session. For the ordinary case — a normal
checkout of a repository — there is no field.

Every example in the official documentation solves it with `git branch --show-current`. That is an
`exec` of git on every render, and the bar is redrawn constantly. Measured here, 20 runs:

| Approach | Time | Processes |
|---|---|---|
| `git branch --show-current` | 27 ms (~1.35 ms each) | 1 per render |
| `read -r line < .git/HEAD` | 2 ms (~0.1 ms each) | none |

13x on Linux, and the gap widens considerably on Windows, where spawning a process is expensive. The
project's target is ~50 ms per render — see [[two-implementations-shell-and-powershell]].

`.git/HEAD` is plain text:

```
ref: refs/heads/main
```

## What both implementations must handle identically

| Case | Behaviour |
|---|---|
| `refs/heads/docs/subject` | a branch name with a slash stays whole |
| Detached HEAD (raw sha) | short sha, 7 characters |
| `.git` as a **file** (worktree, submodule) | follows `gitdir: <path>`, relative or absolute |
| `HEAD` written on Windows | strips the trailing `\r` |
| Deep subdirectory | walks up the parents until it finds `.git` |
| Outside a repository | the segment disappears, the rest of the bar stays |

In the shell, `achar_branch` sets the global `BRANCH` instead of printing: `$(...)` would fork, which is
exactly what the function exists to avoid.

## Test fixtures cannot be versioned

Git **refuses to track a path containing `.git`**, so there is no committing a
`scripts/payloads/fixture/.git/HEAD`. `scripts/test.sh` builds the fixtures in a temporary directory
at run time, and `scripts/generate-svg.py` does the same so the README image stays deterministic —
otherwise it would show whichever branch the person generating it happened to be on.
