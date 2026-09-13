---
type: decision
date: 2026-09-12
---

# Plan usage comes from the payload, not from estimated cost

**Decision:** the bar reads `rate_limits.five_hour` and `rate_limits.seven_day` from the payload Claude
Code hands to the status line. No estimating consumption from local transcripts.

## Why

The common approach — the one this project replaced — sums the current block's tokens by reading the
transcript files, prices them with the public API table, and divides by a hand-configured ceiling:

```
bar % = estimated cost in USD ÷ calibrated ceiling
```

Three problems, all seen in practice:

1. **The number runs past 100%** when the ceiling sits below the real allowance. That is what motivated
   the project: the bar read 112% while `/usage` showed 41%.
2. **A long session inflates the estimate.** Cache reads weigh little against the quota and a lot in
   dollars: a session with 124 million tokens read from cache estimated US$ 100 of consumption.
3. **The ceiling needs manual recalibration** whenever the mix of models changes.

The payload solves all three: the percentage comes from the server, it is the same one `/usage` shows,
and it depends on neither a price table nor calibration.

## The cost

The `rate_limits` field exists from Claude Code **2.1.251** onwards. On an older version the script
shows only the context bar, without breaking — that is the accepted degradation.

The dollar cost did not disappear: the bar shows `.cost.total_cost_usd`, which is the cost of **this
conversation** and arrives ready in the payload. It is session information, not a quota gauge.
