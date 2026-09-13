---
tipo: bug-fix
data: 2026-09-12
---

# BSD `seq` widened a full bar on macOS

## Symptom

On macOS, whenever a bar filled up (100% of the blocks), it came out with **12 characters** instead of
10:

```
5h [██████████░░] 96%     ← macOS, wrong
5h [██████████]   96%     ← Linux and PowerShell, right
```

It only happened with a full bar. Below that the two platforms agreed — which is why it went unnoticed:
the example payload has everything below 50%.

## Cause

`make_bar` drew with two loops:

```bash
for i in $(seq 1 "$filled"); do bar="${bar}█"; done
for i in $(seq 1 "$empty");  do bar="${bar}░"; done
```

With a full bar, `empty` is `0`, and that is where the two families of `seq` diverge:

| | `seq 1 0` |
|---|---|
| GNU (Linux, WSL, Git Bash) | prints nothing |
| BSD (macOS) | prints `1` and `0` |

BSD **infers the direction** from the operands: since the last is smaller than the first, it assumes a
step of −1 and counts from 1 down to 0 — two lines, two extra `░`.

## Fix

No `seq`. `printf` pads with spaces and parameter substitution turns each space into a block:

```bash
cheio=$(printf "%${filled}s" "")
vazio=$(printf "%${empty}s" "")
printf "%s%s" "${cheio// /█}" "${vazio// /░}"
```

`%0s` prints an empty string in both families — there is no edge case. As a bonus, one subprocess per
bar disappears: three bars per render, so six fewer `seq`. The time dropped to ~43 ms.

## How it was found

By the CI `paridade` job running on `macos-latest`, on the first push after that job existed
([[../decisoes/ci-em-push-e-pr]]). `vermelho.json` is the payload that takes the 5-hour block to 96% —
with `width` 10, the rounding gives `filled` 10 and `empty` 0, exactly the edge case.

It is the practical answer to [[../pendentes/arquivo/2026-09-12-confirmar-no-macos]]: the BSD path did
have a problem, and it was not the `date -r` everyone suspected.

## Lesson

A test payload has to include the extremes, not just the pretty case. Three of the six payloads in
`scripts/payloads/` exist only for that, and one of them is what caught this.
