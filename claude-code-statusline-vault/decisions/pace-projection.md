---
type: decision
date: 2026-09-13
---

# The bar warns about pace, and stays quiet otherwise

## Decision

When the current rate of consumption would take a window to 100% **before it resets**, the bar says at
what time that happens:

```
5h [███████░░░] 74% · full 04:10 · resets 06:20
```

The rest of the time it prints nothing extra.

## The problem it solves

`5h [████░░░░░░] 41% · resets 06:20` reads identically at the start and at the end of a window, and
those are opposite situations. With four hours left, 41% is comfortable. With twenty minutes left, the
window is nearly spent and the bar never said so.

For a tool whose whole purpose is quota awareness, that was the question it did not answer.

## Why no state was needed

The window length is not in the payload — it is in the **field name**. `five_hour` is 18000 seconds,
`seven_day` is 604800. With `resets_at`, everything else follows:

```
elapsed = window - (resets_at - now)
rate    = used% / elapsed
full_at = now + (100 - used%) / rate
```

No history, no cache, no extra field, no subprocess beyond the single `date +%s` that both windows share.

The alternative considered was sampling usage over time in the update hook and storing a trend. It was
dropped: it needs the opt-in machinery, writes to disk, and answers a worse question — the instantaneous
rate is noisier than the window average, and the window average is exactly what this computes.

## Why "full 04:10" and not a multiplier

`↑2.0x` says you are going twice as fast as sustainable. `full 04:10` says you stop working at 04:10.
The second is a decision; the first is a statistic.

And the distance between `full` and `resets` is the number that matters most: it is how long you would
sit blocked.

## The silence is the feature

A bar that warns constantly stops being read. Three cases print nothing:

| Case | Why |
|---|---|
| The pace reaches the reset | There is nothing to do |
| Under 10% of the window elapsed | One large request in the first minutes projects catastrophically and means nothing |
| Nothing used, no `resets_at`, or a stale payload | No basis to project from |

The 10% floor is 30 minutes on the 5-hour block and about 17 hours on the week.

## Where it lives

It attaches to the existing `5h` and `week` segments rather than becoming a segment of its own, so
hiding those with `ccsl.order` hides it too. That also keeps it out of the configurator menu, which
lists segments.

See also [[wrap-to-terminal-width]] and [[plan-usage-comes-from-the-payload]].
