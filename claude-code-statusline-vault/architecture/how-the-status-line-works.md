---
type: architecture
date: 2026-09-12
---

# How the status line works

Claude Code runs the command configured under `statusLine` on every render and **passes JSON on standard
input**. The script reads that JSON, assembles a line of text with ANSI codes, and writes it to standard
output. There is no state, no temporary file and no network call.

## What the payload carries

The fields used, all optional on read (a missing field becomes `-` in the shell and `$null` in
PowerShell):

| Field | Becomes |
|---|---|
| `model.display_name` | the model name at the head of the line |
| `context_window.used_percentage` | the `ctx` bar |
| `context_window.context_window_size` and `current_usage.input_tokens` | `330k/1000k` |
| `rate_limits.five_hour.used_percentage` and `.resets_at` | the `5h` bar and its reset time |
| `rate_limits.seven_day.used_percentage` and `.resets_at` | the `week` bar |
| `cost.total_cost_usd` | `session $12.35` |
| `workspace.current_dir` (or `cwd`) | the starting point for finding `.git/HEAD` → the branch segment |

`resets_at` is epoch seconds, formatted against the local clock: the time alone when the reset is today,
day and time otherwise.

## Assembling the line

1. A single read of the JSON (`jq` with `@tsv` in the shell; `ConvertFrom-Json` in PowerShell), which
   also picks up `ccsl.order` from `settings.json` in the same call.
2. Each segment becomes a 10-block bar (`█` and `░`) coloured by band: green to 60%, yellow to 85%, red
   above that.
3. The segments that exist are joined by `│`, in the configured order, and packed into as many rows as
   `$COLUMNS` allows. A segment with no data simply does not appear.

## Degradation

- No `rate_limits` (Claude Code older than 2.1.251, or API key billing): only the `ctx` bar.
- Empty or invalid payload, or `jq` missing: `<model>  waiting...`.

No error path prints a stack trace: the status line is one row of the terminal, and noise there gets in
the way of whoever is working.

## Performance

The bar is redrawn constantly, so the cost per execution matters: the current implementation sits around
50 ms. That is why there is a single read of the JSON and no dependency that has to boot a runtime — see
[[../decisions/plan-usage-comes-from-the-payload]].
