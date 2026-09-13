---
tipo: decisao
data: 2026-09-12
---

# The update notice is opt-in, and lives outside the bar

## Decision

There is a notice for new versions, but it is **off until someone turns it on**, and the check lives in
a `SessionStart` hook — never in the bar's script.

| | Status line | Update hook |
|---|---|---|
| Network | never | one request, at most once per 24 h |
| Writes to disk | never | one cache file |
| Runs | every render | once per session |

The bar only ever **reads** the cache. The hook is what fetches and writes.

## Why it cannot work like `oh-my-zsh`

The original request was "tell me like ZSH does, where you press Y and it updates". **That is not
possible**, for two separate reasons:

1. **A status line is not interactive.** It is a command whose stdout is drawn. There is no keyboard
   input.
2. **Neither is a hook.** Confirmed in the Claude Code documentation: no hook event accepts user input.
   `SessionStart` prints and that is all.

The honest nearest thing is to say so and hand over the line to copy. That is what was built.

## Why opt-in rather than on by default

`SECURITY.md` said, in those words, that the scripts **never open a network connection and never write
to disk**. That is not a detail: it is what lets someone install a stranger's script into `~/.claude`
without auditing much.

Enabling the check by default would mean making a request on the machine of everyone who installs,
without asking — and rewriting that promise. Opt-in keeps the sentence true for anyone who asked for
nothing.

The bar/hook split is what keeps the promise true **even for those who did turn it on**: the status line
itself still makes no request and writes nothing, either way. `SECURITY.md` gained a section describing
exactly what the hook does.

## Details that cost time

**`Get-Date -UFormat %s` is wrong on PowerShell 5.1.** It returns local time as if it were an epoch —
three hours off here. Both hooks write the same cache file, and anyone running Claude Code on Windows
*and* in WSL shares `~/.claude`: the two would disagree about the 24-hour window. Using
`[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()` fixes it and works on both 5.1 and 7.

**The marker is a file, not an environment variable.** The environment the status line receives is not
reliably the person's shell. A file is deterministic and behaves identically in both implementations.

**`CCSL_VERSION` in both implementations**, bumped together with the `CHANGELOG` stamp. A CI job fails
if the three disagree — otherwise the notice lies about what is installed.

See also [[branch-vem-do-git-head]] and [[duas-implementacoes-shell-e-powershell]].
