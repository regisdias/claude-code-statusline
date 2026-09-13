#!/usr/bin/env python3
"""Render the statusline's real output as an SVG terminal window.

It runs `statusline-command.sh` against the payloads in `scripts/payloads/`,
captures the ANSI output byte for byte and turns it into SVG. Nothing here
invents the picture: what you see in `assets/` is what the script prints.

Each glyph gets its own x coordinate, so the bars stay on the monospace grid
even when the reader's browser falls back to a different font.

    python3 scripts/generate-svg.py              # write assets/demo*.svg
    python3 scripts/generate-svg.py --check  # fail if they are out of date

`--check` compares what the script renders now against what is committed,
ignoring the reset clock and the glyph coordinates that move with it — so it
catches a format change nobody regenerated, without failing every day at
midnight.
"""

import datetime
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SHELL = RAIZ / "statusline-command.sh"
PAYLOADS = Path(__file__).resolve().parent / "payloads"
SAIDA = RAIZ / "assets"

# GitHub dark palette, so the image sits well in both README themes
FUNDO = "#0d1117"
BORDA = "#30363d"
BARRA_TITULO = "#161b22"
TEXTO = "#c9d1d9"
ROTULO = "#6e7681"

ANSI = {
    "0": TEXTO,
    "31": "#f85149",  # red
    "32": "#3fb950",  # green
    "33": "#d29922",  # yellow
}

LARGURA_CHAR = 8.4
ALTURA_LINHA = 26
FONTE = 14
PAD_X = 18
PAD_TOPO = 52  # title bar + breathing room
PAD_BAIXO = 18

PADRAO_ANSI = re.compile(r"\033\[([0-9;]*)m")


def run_bar(payload: Path, branch: bool = True) -> str:
    """Run the shell implementation and return its raw output, ANSI included.

    Two things are rewritten so the picture stays honest and reproducible:

    - the fixed epochs are anchored to the local day, so each segment always
      renders in the same form: the 5-hour block lands today (short `06:20`) and
      the weekly one six days out (long `18/09 05:00`). Anchoring to "now + 2h"
      instead would flip the 5-hour block to the long form whenever the run
      happened within two hours of midnight, and six extra characters move the
      image width;
    - `workspace.current_dir` points at a throwaway fixture whose `.git/HEAD`
      always says `main`, so the bar shows a branch without the image depending
      on whichever branch this repo happens to be on.
    """
    try:
        data = json.loads(payload.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = None

    if isinstance(data, dict) and "rate_limits" in data:
        # Midnight today, local time — the anchor both offsets hang off.
        today = datetime.datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        when = {
            "five_hour": today + datetime.timedelta(hours=6, minutes=20),
            "seven_day": today + datetime.timedelta(days=6, hours=5),
        }
        for key, moment in when.items():
            if key in data["rate_limits"]:
                data["rate_limits"][key]["resets_at"] = int(moment.timestamp())
        if branch:
            data["workspace"] = {"current_dir": str(branch_fixture())}
        stdin_bytes = json.dumps(data).encode("utf-8")
    else:
        stdin_bytes = payload.read_bytes()

    # COLUMNS pinned, and high: the bar wraps itself to the terminal width, so
    # without this the picture would depend on the window of whoever generated it.
    ambiente = {**os.environ, "COLUMNS": "999"}
    p = subprocess.run(
        ["bash", str(SHELL)],
        input=stdin_bytes,
        capture_output=True,
        check=True,
        env=ambiente,
    )
    return p.stdout.decode("utf-8")


_FIXTURE = None


def branch_fixture() -> Path:
    """A throwaway directory whose .git/HEAD says `main`, for a stable picture."""
    global _FIXTURE
    if _FIXTURE is None:
        _FIXTURE = Path(tempfile.mkdtemp(prefix="ccsl-demo-"))
        git = _FIXTURE / ".git"
        git.mkdir()
        (git / "HEAD").write_text("ref: refs/heads/main\n", encoding="utf-8")
    return _FIXTURE


def clean_fixture() -> None:
    if _FIXTURE is not None:
        shutil.rmtree(_FIXTURE, ignore_errors=True)


def into_runs(text: str):
    """Split an ANSI string into (text, color) runs."""
    runs = []
    colour = TEXTO
    pos = 0
    for m in PADRAO_ANSI.finditer(text):
        if m.start() > pos:
            runs.append((text[pos : m.start()], colour))
        codigo = m.group(1).split(";")[-1] or "0"
        colour = ANSI.get(codigo, TEXTO)
        pos = m.end()
    if pos < len(text):
        runs.append((text[pos:], colour))
    return runs


def svg_line(runs, y: float, x0: float) -> str:
    """One output line: a <text> per color run, one x per glyph."""
    parts = []
    column = 0
    for text, colour in runs:
        if not text:
            continue
        xs = " ".join(
            f"{x0 + (column + i) * LARGURA_CHAR:.1f}" for i in range(len(text))
        )
        parts.append(
            f'<text x="{xs}" y="{y:.1f}" fill="{colour}">{html.escape(text)}</text>'
        )
        column += len(text)
    return "".join(parts)


def build(frames, target: Path, titulo: str, min_columns: int = 0) -> int:
    """frames: list of (label, ansi_output). Label is the dim caption above.

    Returns the column count used, so sibling images can share a width.
    """
    columns = max(
        min_columns,
        max(len(PADRAO_ANSI.sub("", out)) for _, out in frames),
        max(len(label) for label, _ in frames),
    )
    width = PAD_X * 2 + columns * LARGURA_CHAR
    rows = len(frames) * 3 - 1  # label + output + blank between frames
    height = PAD_TOPO + rows * ALTURA_LINHA + PAD_BAIXO

    body = []
    y = PAD_TOPO
    for i, (label, out) in enumerate(frames):
        if i:
            y += ALTURA_LINHA
        body.append(
            f'<text x="{PAD_X}" y="{y:.1f}" fill="{ROTULO}" '
            f'font-style="italic">{html.escape(label)}</text>'
        )
        y += ALTURA_LINHA
        body.append(svg_line(into_runs(out), y, PAD_X))
        y += ALTURA_LINHA

    dots = "".join(
        f'<circle cx="{cx}" cy="16" r="6" fill="{colour}"/>'
        for cx, colour in ((20, "#ff5f57"), (40, "#febc2e"), (60, "#28c840"))
    )

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{height:.0f}" viewBox="0 0 {width:.0f} {height:.0f}" font-family="ui-monospace, 'SF Mono', 'JetBrains Mono', 'DejaVu Sans Mono', Menlo, Consolas, monospace" font-size="{FONTE}">
  <rect width="{width:.0f}" height="{height:.0f}" rx="10" fill="{FUNDO}" stroke="{BORDA}"/>
  <path d="M0 10a10 10 0 0 1 10-10h{width - 20:.0f}a10 10 0 0 1 10 10v22H0z" fill="{BARRA_TITULO}"/>
  <line x1="0" y1="32" x2="{width:.0f}" y2="32" stroke="{BORDA}"/>
  {dots}
  <text x="{width / 2:.0f}" y="21" fill="{ROTULO}" font-size="12" text-anchor="middle">{html.escape(titulo)}</text>
  {"".join(body)}
</svg>
"""
    target.write_text(svg, encoding="utf-8")
    try:
        name = target.relative_to(RAIZ)
    except ValueError:  # verify mode renders into a temp dir
        name = target.name
    print(f"{name}  ({width:.0f}x{height:.0f})")
    return columns


def normalise(svg: str) -> str:
    """Strip what legitimately changes between runs: the clock and the x grid."""
    svg = re.sub(r'x="[0-9.\s]+"', 'x=""', svg)
    svg = re.sub(r"\b\d{2}/\d{2} \d{2}:\d{2}\b|\b\d{2}:\d{2}\b", "HORA", svg)
    return svg


def main() -> int:
    if not SHELL.exists():
        print(f"could not find {SHELL}", file=sys.stderr)
        return 1

    check = "--check" in sys.argv[1:]

    # In verify mode nothing is written to assets/: the images are rendered into
    # a temp dir and compared, so a failing check never dirties the tree.
    if check:
        committed = {c.name: c for c in sorted(SAIDA.glob("demo*.svg"))}
        if not committed:
            print("no committed assets/demo*.svg to compare against", file=sys.stderr)
            return 1
        tmpdir = tempfile.TemporaryDirectory()
        target = Path(tmpdir.name)
    else:
        SAIDA.mkdir(exist_ok=True)
        target = SAIDA

    columns = build(
        [
            ("# plenty of room left", run_bar(PAYLOADS / "green.json")),
            ("# getting close to the 5-hour limit", run_bar(PAYLOADS / "yellow.json")),
            ("# weekly limit almost gone", run_bar(PAYLOADS / "red.json")),
        ],
        target / "demo.svg",
        "claude-code-statusline",
    )

    build(
        [
            ("# plan without rate limits (API key billing)", run_bar(PAYLOADS / "no-limits.json", branch=False)),
            ("# first render, payload still empty", run_bar(PAYLOADS / "empty.json")),
        ],
        target / "demo-fallback.svg",
        "graceful degradation",
        min_columns=columns,
    )

    if check:
        stale = [
            committed
            for name, committed in committed.items()
            if normalise((target / name).read_text(encoding="utf-8"))
            != normalise(committed.read_text(encoding="utf-8"))
        ]
        tmpdir.cleanup()
        if stale:
            for caminho in stale:
                print(f"out of date: {caminho.relative_to(RAIZ)}", file=sys.stderr)
            print("run: python3 scripts/generate-svg.py", file=sys.stderr)
            return 1
        print("assets/ up to date")

    clean_fixture()
    return 0


if __name__ == "__main__":
    sys.exit(main())
