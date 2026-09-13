---
tipo: decisao
data: 2026-09-13
---

# The bar wraps itself, to the terminal's width

## Decision

The bar spreads its segments across as many rows as the terminal needs, breaking **only between
segments**. No configuration: on a wide window it stays one line.

The width comes from `COLUMNS`, which Claude Code sets before running the command — it is in the
documentation:

> Claude Code captures your script's output instead of connecting it directly to the terminal, so
> `tput cols` and language-level width detection cannot read the terminal size from inside the script.
> Read the `COLUMNS` and `LINES` environment variables instead.

Each `\n` in the output becomes a row on screen. `COLUMNS` missing or non-numeric: one line, the old
behaviour.

## Why not manual configuration

The alternative was extending `ccsl.order` with nested lists, one per row. It was dropped: whoever
configures them does not know the width of the window reading them — nor of their own window ten minutes
later. A fixed layout still wraps badly in a narrow terminal, which was the original problem.

Truncating the branch name was dropped too. The request was triggered by a long branch name in the first
place: hiding the end of it would fix the look and destroy the information.

## The expensive trap: `${#s}` counts bytes

Outside a UTF-8 locale, bash's `${#s}` counts **bytes**, and the status line frequently runs with no
`LANG`. Measured:

| Locale | `${#s}` of the same line |
|---|---|
| `C.UTF-8` | 31 |
| `C`, or no `LANG` | **55** |

`█` is 3 bytes. Wrapping on that number would get the whole calculation wrong.

The way out was folding every glyph the bar emits (`█ ░ │ ↑ ·`) to one ASCII character before counting.
The branch icon, which is configurable, folds to the width `jq` computes — see
[[rotulo-da-branch-em-texto]]. Substitution matches the same bytes in either locale, so the count is
right in both — and with no subprocess. A branch or model name with an accent still over-counts, which
only wraps slightly early; it never hides anything.

PowerShell does not have this problem: `.Length` counts UTF-16 units, one per glyph.

## The other trap: `` `e `` is PowerShell 6+

Measuring means stripping the ANSI codes first. The regex `` "`e\[[0-9;]*m" `` **matches nothing on
PowerShell 5.1** — the `` `e `` escape only exists from 6 onwards, and it fails silently. The result:
the codes stayed in the count and the two implementations wrapped at different points. `[char]27` fixes
it.

Same family as the `"\u{2387}"` bug that had already bitten. **New PowerShell syntax is always suspect
in this project**, because the target is the 5.1 that ships with Windows.

## And a third: macOS `awk` counts bytes

The test measured line width with `awk '{ ... length($0) ... }'`. Linux's `gawk`, in a UTF-8 locale,
counts characters; **the `awk` macOS ships counts bytes, always**. A 76-column line was reported as 124,
and the suite claimed an overflow on every Mac.

It was not even an implementation bug: the `macos-latest` CI job failed the **test**, not the code. The
measurement moved into bash, using the same glyph folding the implementation uses — so the test cannot
drift from what it tests.

It is the second bug the macOS job caught on its own, after BSD `seq`.

## A segment wider than the terminal

It gets a row to itself and overflows. Breaking inside a segment would hide precisely what someone is
trying to read. The test covers this explicitly: a line may exceed the width **if** it holds a single
segment.

## Consequence for the README images

`scripts/gerar-svg.py` pins `COLUMNS=999`. Without it the image would come out differently depending on
the window of whoever generated it, and the `README images are current` job would report a difference on
every machine.

See also [[ordem-dos-trechos-configuravel]].
