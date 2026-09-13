---
type: pending
status: resolved
date: 2026-09-12
updated: 2026-09-13
code: CCS-1
---

# Confirm the shell version on macOS

**Resolved on 2026-09-13.** [[../../guides/validating-on-macos]] ran on a real Mac (macOS 15.6,
Terminal.app, bash 3.2.57, BSD `date`, timezone −03): everything passed except the cost — the `pt_BR`
locale, fixed in v1.4.1 (#27). `⎇` was looked at on screen and read as the Option key, which became
[[2026-09-13-branch-glyph-on-macos|CCS-4]] and swapped the glyph for `git` (#35). iTerm2 was not
checked.

`statusline-command.sh` formats the reset time with `date`, and the two families diverge: `date -d` is
GNU (Linux, WSL, Git Bash) and `date -r` is BSD (macOS). `fmt_epoch` tries GNU and falls back to BSD
when the first fails, but **that second path had never run on a real Mac** — only on a GitHub runner.

## Progress

The CI `paridade` job runs `scripts/test.sh` on `macos-latest` on every push. There are **22 cases**
there today, not just the original payloads: the whole branch path (`.git` as a file, detached HEAD,
CRLF, no trailing newline, walking up) and the whole update-notice path. See
[[../../decisions/ci-on-push-and-pull-request]].

**And it found a real bug on the very first push** — but not in `date`: BSD `seq` widened a full bar to
12 blocks. Fixed, with the story in
[[../../bugs-fixes/2026-09-12-bsd-seq-widened-the-full-bar-on-macos]]. `date -r` passes cleanly in
every case.

**2026-09-13 — the guide ran on a real Mac** (macOS 15.6, Terminal.app, bash 3.2.57, BSD `date`,
timezone −03, `LANG=pt_BR.UTF-8`). Passed: both bashes identical, a full bar at 10 blocks, the reset
correct in the local timezone (`resets` +2h, week +3 days), a configured order, `⎇` bytes = `e2 8e 87`.
**Did not pass: the cost came out `$12,00`** — the comma-decimal locale, which no runner had. It became
issue #27 and [[../../bugs-fixes/2026-09-13-comma-locale-broke-the-numbers]].

**Looked at on screen, in Terminal.app:** `⎇` draws, but looks like the Option key symbol rather than a
branch — in WSL the same character looks like a forking arrow. That is the guide's "only the glyph comes
out wrong" case, so this note did **not** close on it: the choice of glyph became
[[2026-09-13-branch-glyph-on-macos|CCS-4]]. iTerm2 was not checked.

## How to confirm by hand

**The full step by step, in one paste, is in [[../../guides/validating-on-macos]].** The rest of this note is
the context for why it matters.

```bash
bash statusline-command.sh < scripts/payloads/green.json
```

That comes out without the branch, because the test payload carries no `workspace`. To exercise the
branch segment, point it at a repository:

```bash
jq --arg d "$PWD" '. + {workspace: {current_dir: $d}}' scripts/payloads/green.json \
  | bash statusline-command.sh
```

What may legitimately differ: the branch name, the reset time (the machine's timezone) and the
`18/09 05:00` date, which depends on when the test runs. What may **not**: an empty bar, a blank time, a
`date` error, or a bar of any width other than 10 blocks.

## The glyphs, in order of risk

This is where a human eye on a Mac still matters:

| Glyph | Where | Font coverage |
|---|---|---|
| `█` `░` U+2588/2591 | the bars | good |
| `│` U+2502 | separators | good |
| `↑` U+2191 | update notice, when enabled | good |

Worth testing in Terminal.app **and** iTerm2: they resolve fonts differently, and Terminal.app tends to
have the poorer fallback.

> Up to v1.5.0 there was a fourth row here: `⎇` U+2387, with **poor** coverage. It was the one that
> failed — not by missing, but by drawing the wrong thing. See
> [[../../decisions/branch-label-as-text]].

## What else only a real Mac answers

- **A timezone outside UTC.** The GitHub runner runs in UTC, so `fmt_epoch`/`Get-Reset` had never been
  seen converting an epoch on a Mac with a local timezone. It is the same class of bug as
  [[../../bugs-fixes/2026-09-12-bsd-seq-widened-the-full-bar-on-macos]]: an implementation
  difference that only appears on the right platform.
- **`jq` installed via Homebrew** (`brew install jq`) and a terminal in UTF-8 — without those the blocks
  come out as question marks and the diagnostic becomes a false positive.
