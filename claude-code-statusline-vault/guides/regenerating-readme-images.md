---
type: guide
date: 2026-09-12
---

# Regenerating the README images

The two README images (`assets/demo.svg` and `assets/demo-fallback.svg`) are **not drawn by hand**:
`scripts/generate-svg.py` runs `statusline-command.sh` against the payloads in `scripts/payloads/`,
captures the real ANSI output and converts it to SVG. What appears in the README is what the script
prints.

```bash
python3 scripts/generate-svg.py
```

Commit the regenerated SVGs **in the same commit** as the format change.

## Why SVG rather than PNG

- Sharp at any zoom and on retina screens, with no @2x version.
- It is text: `git diff` shows what changed in the bar, not a binary blob.
- It does not depend on taking a screenshot on one specific machine with one specific terminal.

Each glyph gets its own `x` coordinate. Without that, a browser falling back to a non-monospaced font
would misalign the `█░` blocks and the bar would come out crooked.

Two things are pinned so the picture does not depend on the machine that generated it: `COLUMNS=999`,
since the bar wraps itself to the terminal width, and the fixtures' reset times, anchored to local
midnight.

## What CI checks

```bash
python3 scripts/generate-svg.py --check
```

It renders everything into a temporary directory — never writing to `assets/` — and compares against
what is committed, **ignoring the reset clock and the `x` coordinates**. Without that normalisation the
check would fail every midnight.

Failed? That means the output format changed and the images fell behind. Run it without `--check`.

## Swapping for a real terminal screenshot

If it is ever worth it, replace the files in `assets/` and drop the `imagens` job from
`.github/workflows/ci.yml`. As long as the images are generated, that job is what stops the README from
advertising a bar the script no longer draws.

See also [[testing-locally]].
