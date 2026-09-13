---
tipo: bug-fix
data: 2026-09-13
---

# A comma-decimal locale broke the numbers

Issue #27.

## Symptom

On a Mac with `LANG=pt_BR.UTF-8`, running [[../guias/validar-no-macos]]:

```
session $12,00      ← the payload sent 12.3456; the right answer is $12.35
```

With a **fractional** percentage it got worse — the plan limits went to zero, and stderr complained:

```
LC_ALL=C          ctx [██████░░░░] 130k/200k 65%  │  5h [████████░░] 85%  │  week [██████░░░░] 60%  │  session $12.35
LANG=pt_BR.UTF-8  ctx [██████░░░░] 130k/200k 64%  │  5h [████████░░] 0%   │  week [██████░░░░] 0%   │  session $12,00

printf: 84.7: invalid number
```

Note that the 5-hour **bar** still has 8 blocks and only the number zeroes: two different formatting
paths breaking in two different ways.

## Cause

JSON always uses a dot. The script formats numbers in two places, and both obey `LC_NUMERIC`:

| Who | Where | Under `pt_BR` |
|---|---|---|
| `awk` | cost, ctx %, tokens, bar fill, colour | reads `12.3456` up to the dot → `12`, and prints with a comma |
| bash's `printf %.0f` | 5-hour and weekly % | rejects `84.7` as an invalid number → `0` |

PowerShell never had the problem: it has formatted with `InvariantCulture` from the start.

## Why CI did not catch it

Two reasons together. The runner runs in the default locale, with a dot. And every payload in
`scripts/payloads/` has an **integer** percentage — `printf %.0f 41` works in any locale, and the cost
only goes wrong in the decimal part, which `verde.json` does have but which never ran under a
comma locale.

## Fix

One line at the top of `statusline-command.sh`:

```bash
export LC_ALL=C
```

`LC_ALL`, not `LC_NUMERIC`: anyone with `LC_ALL` set in their own shell would override the narrower
variable. Nothing in the script depends on the character locale — the glyphs pass through as bytes, and
`date` only formats `%H:%M` and `%d/%m`.

## The test

Section 6 of `scripts/testar.sh` builds a fractional payload from `verde.json`, renders it under C as
the reference, and compares with `pt_BR.UTF-8` and `de_DE.UTF-8`, via both `LC_ALL` and `LANG`,
**including stderr**. Confirmed red without the fix (4 failures) and green with it.

Two traps inside the test itself:

- **A locale that is not installed falls back to C silently**, and the case would pass without testing
  anything. So the probe checks that the locale really prints a comma before counting — and says so when
  it skips.
- **The probe needs a fresh bash with `env -i`.** Bash 3.2 ignores `LC_ALL=x printf …` on a builtin, and
  an inherited `LANG` would mask the missing locale. And it formats `1`, not `1.5`: under `pt_BR`,
  `1.5` is itself an invalid number.

The Ubuntu runner does not ship `pt_BR`; CI generates it with `locale-gen` before `testar.sh`. macOS
already has it.

## Lesson

The same one as [[2026-09-12-seq-do-bsd-alargava-a-barra-cheia-no-macos]]: the test payload has to carry
the extremes — here, a fractional number — and the test environment has to vary what an outsider varies.
Locale is one of those things.
