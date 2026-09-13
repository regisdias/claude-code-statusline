<div align="center">

<img src="assets/logo.svg" alt="" width="96" height="96">

# claude-code-statusline

**Your real plan usage in the Claude Code statusline.**<br>
The same numbers as `/usage` — not an estimate, not a guess, no extra process per render.

[![CI](https://img.shields.io/github/actions/workflow/status/regisdias/claude-code-statusline/ci.yml?branch=main&label=CI&style=flat-square)](https://github.com/regisdias/claude-code-statusline/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Claude Code 2.1.251+](https://img.shields.io/badge/Claude%20Code-2.1.251%2B-d97757?style=flat-square)](https://claude.com/claude-code)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL%20%7C%20Windows-2b7489?style=flat-square)](#requirements)
[![Stars](https://img.shields.io/github/stars/regisdias/claude-code-statusline?style=flat-square&color=f5c518)](https://github.com/regisdias/claude-code-statusline/stargazers)

🇬🇧 **English** · [🇧🇷 Português](README.pt-BR.md)

<img src="assets/demo.svg" alt="Three statusline renders: context window, 5-hour block, weekly limit and session cost, with the bars turning green, yellow and red as usage climbs." width="100%">

</div>

---

## Install

**Linux · WSL · macOS · Git Bash**

```bash
curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/install.sh | bash
```

The installer drops the script in `~/.claude`, wires up `~/.claude/settings.json` (backing it up first,
and never overwriting a `statusLine` you already have) and prints a preview. Prefer doing it by hand?
See [manual install](#manual-install).

**Windows (PowerShell)**

```powershell
iwr https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/statusline-command.ps1 `
  -OutFile "$env:USERPROFILE\.claude\statusline-command.ps1"
```

Then in `%USERPROFILE%\.claude\settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\\.claude\\statusline-command.ps1"
  }
}
```

On PowerShell 7 use `pwsh` instead of `powershell`. Running Claude Code **inside WSL**? Use the Linux
install — the WSL side has its own `~/.claude`.

> [!IMPORTANT]
> Keep the `.ps1` as **UTF-8 with BOM**. Windows PowerShell 5.1 reads a BOM-less file as ANSI and the
> block characters break the parser. Downloading it as shown preserves the BOM; if you edit the file,
> save it as "UTF-8 with BOM".

The bar shows up on the next render. No restart needed.

## What you get

```
git main  │  Opus 5 (1M context)  │  ctx [███░░░░░░░] 330k/1000k 33%  │  5h [████░░░░░░] 41% · resets 06:20  │  week [█░░░░░░░░░] 11% · 18/09 05:00  │  session $12.35
```

| Segment | What it means |
|---|---|
| `git main` | Current git branch, read live from `.git/HEAD`. Absent outside a git repository. The label [can be an icon](#the-branch-icon). |
| `ctx` | Context window of the current conversation. Local to the session, unrelated to your plan quota. |
| `5h` | 5-hour block of your plan, and the time it resets. |
| `week` | Weekly plan limit, and when it resets. |
| `session` | Cost of this conversation, in USD. |
| `↑1.3.0` | A newer release exists. Only ever shown if you [turned the check on](#update-notice-optional). |

Bars turn **green** up to 60%, **yellow** up to 85% and **red** above that.

## Why not a cost-based bar

Most statuslines shell out to a usage estimator: it reads your local transcript files, prices the tokens
with the public API table and divides by a ceiling you calibrate by hand. Two things go wrong.

**Before** — estimated, and wrong:

```
ctx [███░░░░░░░] 33%   │   plan [███████████] 112%      ← /usage says 41%
```

**After** — straight from the payload:

```
ctx [███░░░░░░░] 33%   │   5h [████░░░░░░] 41%          ← the number the server reports
```

- **The bar runs past 100%** when the hand-calibrated ceiling sits below your real allowance. In one
  measured case it read 112% while `/usage` reported 41%.
- **Long sessions inflate the estimate.** Cache reads are cheap for your quota but still pile up in USD.

Claude Code 2.1.251+ sends `rate_limits.five_hour` and `rate_limits.seven_day` (percentage and
`resets_at`) in the statusline payload, so the real numbers are one JSON read away — no subprocess, no
transcript parsing, no calibration.

## It degrades, it never breaks

A missing field drops its segment and keeps the rest. A malformed payload prints `waiting...` instead
of a stack trace in your terminal.

<div align="center">
<img src="assets/demo-fallback.svg" alt="Statusline falling back gracefully: plan without rate limits shows only the context bar, and an empty payload shows 'waiting...'." width="100%">
</div>

## It fits your terminal

The bar lays itself out to the width of your window, breaking **between** segments so nothing is ever
cut. Nothing to configure — on a wide terminal it is one line, exactly as before.

```
170 columns:
git main  │  Opus 5 (1M context)  │  ctx [███░░░░░░░] 33%  │  5h […] 41%  │  week […] 11%  │  session $12.35

80 columns:
git feat/28-wrap-to-terminal-width  │  Opus 5 (1M context)
ctx [███░░░░░░░] 330k/1000k 33%  │  5h [████░░░░░░] 41% · resets 06:20
week [█░░░░░░░░░] 11% · 18/09 05:00  │  session $12.35
```

Claude Code sets `COLUMNS` before running the command, which is how the script knows. If it is missing
or not a number, you get one line — the old behaviour.

A segment wider than the whole terminal gets a line to itself and overflows: splitting inside a segment
would hide the very thing you are trying to read.

## Choosing the segments, and their order

One list does both jobs: **the order is the configuration.** A segment you leave out does not render.

```bash
bash ~/.claude/ccsl-install.sh --configure
```

It lists the segments as *your* status line draws them, takes the numbers you want in the order you
want them, shows the resulting bar, and saves on confirmation:

```
  1  branch   git main
  2  model    Opus 5 (1M context)
  3  ctx      ctx [███░░░░░░░] 330k/1000k 33%
  4  5h       5h [████░░░░░░] 41% · resets 06:20
  5  week     week [█░░░░░░░░░] 11% · 18/09 05:00
  6  session  session $12.35
  7  update   ↑1.4.0

> 1 3 4 6

It would look like this:

  git main  │  ctx [███░░░░░░░] 330k/1000k 33%  │  5h [████░░░░░░] 41% · resets 06:20  │  session $12.35
```

It lands in Claude Code's own `settings.json`, so you can edit it there directly too:

```json
{
  "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" },
  "ccsl": { "order": ["branch", "ctx", "5h", "session"] }
}
```

No `ccsl` key, an empty list, a name nobody recognises, or a `settings.json` broken by hand — any of
those falls back to the full default order rather than leaving you with a blank bar.

### The branch icon

The branch is labelled `git` by default, because it reads the same in every terminal. If you use a
[Nerd Font](https://www.nerdfonts.com/) or a Powerline font, swap the word for the icon:

```json
{ "ccsl": { "branch_icon": "\ue0a0" } }
```

| `branch_icon` | Renders |
|---|---|
| not set | `git main` |
| `"\ue0a0"` | the Powerline branch icon, then `main` |
| `"⎇"` | `⎇ main` — the look before 1.6.0 |
| `""` | `main` |

Why not a glyph by default: there is no standard Unicode character for git. The real icons live in the
Private Use Area and show as a box without a patched font, and U+2387 `⎇` — the usual fallback — is
drawn as the Option key symbol on macOS. Control characters and backslashes in the value are dropped.

## Update notice (optional)

Off by default, and deliberately so: the status line makes no network call and writes nothing, and that
is a property worth keeping. Turn it on and you get told when a release is out, the way `oh-my-zsh`
does — minus the interactive prompt, which a status line cannot have.

```bash
bash ~/.claude/ccsl-install.sh --enable-update-check     # or re-run the one-liner with the flag
```

At the start of a session:

```
claude-code-statusline 1.3.0 is available (you have 1.2.0)
  curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/install.sh | bash
```

and a segment on the bar until you update:

```
git main  │  Opus 5  │  ctx [███░░░░░░░] 33%  │  …  │  session $12.35  │  ↑1.3.0
```

The work is split so the bar keeps its promise:

| | Status line | Update hook |
|---|---|---|
| Network | never | one request, at most once per 24 h |
| Writes | never | one cache file |
| Runs | every render | once per session |

To stop it completely — marker, cache and hook all removed:

```bash
bash ~/.claude/ccsl-install.sh --disable-update-check
```

## Requirements

| | |
|---|---|
| **Claude Code** | 2.1.251 or newer (`claude --version`) — older versions render the `ctx` bar only |
| **Shell version** | `bash`, `jq`, `awk` — Linux: `apt install jq` · macOS: `brew install jq` |
| **PowerShell version** | nothing beyond Windows PowerShell 5.1, which ships with Windows |

Two implementations, byte-for-byte identical output:

| File | For |
|---|---|
| [`statusline-command.sh`](statusline-command.sh) | Linux, WSL, macOS, Git Bash |
| [`statusline-command.ps1`](statusline-command.ps1) | Claude Code running natively on Windows |

## Manual install

```bash
curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

In `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## Try it without Claude Code

Feed it any of the payloads in [`scripts/payloads/`](scripts/payloads):

```bash
bash statusline-command.sh < scripts/payloads/green.json       # green
bash statusline-command.sh < scripts/payloads/red.json    # red
```

```powershell
Get-Content scripts\payloads\green.json | powershell -NoProfile -File .\statusline-command.ps1
```

To check both implementations still agree, and that the `.ps1` kept its BOM:

```bash
bash scripts/test.sh
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| Only the `ctx` bar shows | Claude Code older than 2.1.251, or a plan with no rate limits (API key billing). |
| `waiting...` | The payload arrived empty, or `jq` is missing (shell version). |
| Blocks show as `?` on Windows | The terminal is not in UTF-8. Windows Terminal handles it; the old console host may not. |
| The branch icon shows as a box or `?` | Your terminal font has no glyph for the `branch_icon` you set — a Nerd Font icon needs a Nerd Font. Display only; the branch name itself is fine. |
| PowerShell parser error | The `.ps1` lost its UTF-8 BOM. Re-download it. |
| No colors | Your terminal is stripping ANSI codes. |
| Reset time looks wrong | Your machine's timezone — the script formats the epoch with the local clock. |
| No branch shown | The session is not inside a git repository, or Claude Code is older than the version that sends `workspace.current_dir`. |

Still stuck? [Open an issue](https://github.com/regisdias/claude-code-statusline/issues/new/choose).

## Contributing

Pull requests welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). The one rule that matters: **both
implementations must print the same bytes for the same payload**, and a format change lands in both in
the same commit.

- [Report a bug](https://github.com/regisdias/claude-code-statusline/issues/new?template=bug_report.yml)
- [Request a feature](https://github.com/regisdias/claude-code-statusline/issues/new?template=feature_request.yml)
- [Security policy](SECURITY.md) · [Code of Conduct](CODE_OF_CONDUCT.md) · [Changelog](CHANGELOG.md)

## License

[MIT](LICENSE) © Regis Dias

<div align="center">
<sub>If this saved you from a surprise rate limit, a ⭐ helps other people find it.</sub>
</div>
