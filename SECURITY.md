# Security Policy

## Supported versions

This project is two standalone scripts with no release train: **the `main` branch is the supported
version.** Fixes land there, and the install commands in the README pull from it.

## What the scripts can touch

Worth stating plainly, because it bounds the risk:

- They read **stdin only** — the JSON payload Claude Code hands to the statusline — plus `.git/HEAD`
  under the directory Claude Code reports, to name the branch.
- They write **stdout only** — one line of text.
- They **never open a network connection and never write to disk**, and they never read your
  transcripts, credentials or `settings.json`.
- The shell version shells out to `jq`, `awk` and `date`. The PowerShell version uses
  `ConvertFrom-Json` and nothing else.

### The optional update check

`hooks/ccsl-update-check` is the one component that reaches the network, and it exists so the status
line does not have to. It is **off unless you turn it on** with `install.sh --enable-update-check`.

| | Status line | Update hook |
|---|---|---|
| Network | never | one request to `api.github.com`, at most once per 24 h |
| Writes | never | one cache file, `~/.claude/.ccsl-update-cache` |
| Runs | every render | once per session, at session start |

The request is an unauthenticated `GET` of the repository's latest release. It sends no identifier of
yours beyond what any HTTP request carries — your IP and a `User-Agent` of `claude-code-statusline`.
The status line only ever *reads* the cache file, so the row above stays true whether or not the check
is enabled.

`install.sh --disable-update-check` removes the marker, the cache and the hook, and no request is ever
made again.

`install.sh` is the one exception: it downloads `statusline-command.sh` over HTTPS and edits
`~/.claude/settings.json`, backing it up first. If piping a script to `bash` isn't for you, the
[manual install](README.md#manual-install) is two commands.

## Reporting a vulnerability

**Please don't open a public issue.**

Use [GitHub's private vulnerability reporting](https://github.com/regisdias/claude-code-statusline/security/advisories/new)
— that's the fastest route and it keeps the details out of the open until there's a fix.

Useful to include:

- What an attacker controls (a crafted payload field? a hostile `settings.json`?) and what they get.
- The exact payload or steps that reproduce it.
- Platform and version: OS, `bash --version` or `$PSVersionTable`, `claude --version`.

You'll get an acknowledgement within **7 days**. Since this is a solo side project, expect a fix within a
couple of weeks for anything genuinely exploitable, and please give me a heads-up before disclosing
publicly so users have a patched `main` to move to.

## Out of scope

- Anything requiring an attacker to already have write access to your `~/.claude` directory — at that
  point they own your Claude Code configuration regardless of this statusline.
- The usage numbers themselves. They come from Claude Code's payload; this project only formats them.
- Terminals that mangle ANSI escapes or UTF-8. That's a display bug — open a regular issue.
