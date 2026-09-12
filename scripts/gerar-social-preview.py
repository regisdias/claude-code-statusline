#!/usr/bin/env python3
"""Build assets/social-preview.png — the card GitHub shows when the repo is shared.

1280x640 is what GitHub asks for. The bars and percentages come from the real
payload in scripts/payloads/verde.json, laid out large enough to survive the
~600px the card is usually displayed at; this is a poster, not a screenshot of
the line (that one is assets/demo.svg).

    python3 scripts/gerar-social-preview.py

Needs `npx` — it shells out to sharp-cli to rasterise. GitHub only takes
PNG/JPG/GIF here, and it is a Settings → General upload: there is no API for it.
"""

import html
import json
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PAYLOAD = RAIZ / "scripts" / "payloads" / "verde.json"
SVG = RAIZ / "assets" / "social-preview.svg"
PNG = RAIZ / "assets" / "social-preview.png"

L, A = 1280, 640
FUNDO = "#0d1117"
BORDA = "#30363d"
CARTAO = "#161b22"
TEXTO = "#e6edf3"
SUAVE = "#8b949e"
VERDE = "#3fb950"
VERDE_VAZIO = "#1c3b28"  # the ░ half, dimmed: at 30px the raw glyph reads as noise
LARANJA = "#d97757"  # the Claude accent

MONO = "'DejaVu Sans Mono', ui-monospace, 'SF Mono', Menlo, Consolas, monospace"
SANS = "'DejaVu Sans', -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif"


def barra(pct: float, largura: int = 10) -> str:
    """The bar as two spans: the ░ half is dimmed so it does not read as noise."""
    cheios = max(0, min(largura, int(pct / 100 * largura + 0.5)))
    return (
        f'<tspan fill="{VERDE}">[{"█" * cheios}</tspan>'
        f'<tspan fill="{VERDE_VAZIO}">{"░" * (largura - cheios)}</tspan>'
        f'<tspan fill="{VERDE}">]</tspan>'
    )


def main() -> int:
    dados = json.loads(PAYLOAD.read_text(encoding="utf-8"))
    ctx = dados["context_window"]
    limites = dados["rate_limits"]

    linhas = [
        ("ctx", ctx["used_percentage"], "330k/1000k"),
        ("5h", limites["five_hour"]["used_percentage"], "resets 06:20"),
        ("week", limites["seven_day"]["used_percentage"], "18/09 05:00"),
    ]

    corpo = []
    y = 356
    for rotulo, pct, nota in linhas:
        corpo.append(
            f'<text x="150" y="{y}" font-family="{MONO}" font-size="30" fill="{SUAVE}">{rotulo}</text>'
            f'<text x="330" y="{y}" font-family="{MONO}" font-size="30">{barra(pct)}</text>'
            f'<text x="700" y="{y}" font-family="{MONO}" font-size="30" fill="{TEXTO}" text-anchor="end">{pct:.0f}%</text>'
            f'<text x="750" y="{y}" font-family="{MONO}" font-size="26" fill="{SUAVE}">{html.escape(nota)}</text>'
        )
        y += 56

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{L}" height="{A}" viewBox="0 0 {L} {A}">
  <rect width="{L}" height="{A}" fill="{FUNDO}"/>
  <rect x="0" y="0" width="{L}" height="6" fill="{LARANJA}"/>

  <text x="{L//2}" y="130" text-anchor="middle" font-family="{MONO}" font-size="54"
        font-weight="bold" fill="{TEXTO}">claude-code-statusline</text>
  <text x="{L//2}" y="182" text-anchor="middle" font-family="{SANS}" font-size="27" fill="{SUAVE}">
    Your real plan usage in the Claude Code statusline
  </text>

  <rect x="110" y="250" width="{L - 220}" height="230" rx="14" fill="{CARTAO}" stroke="{BORDA}" stroke-width="2"/>
  <text x="150" y="300" font-family="{SANS}" font-size="20" fill="{SUAVE}">
    the same numbers as /usage — no estimation
  </text>
  {"".join(corpo)}

  <text x="{L//2}" y="562" text-anchor="middle" font-family="{SANS}" font-size="22" fill="{SUAVE}">
    bash + PowerShell · Linux · WSL · macOS · Windows · MIT
  </text>
</svg>
"""
    SVG.write_text(svg, encoding="utf-8")
    print(f"assets/{SVG.name}")

    try:
        subprocess.run(
            ["npx", "-y", "sharp-cli", "--input", str(SVG), "--output", str(PNG)],
            check=True,
            capture_output=True,
            timeout=300,
        )
    except FileNotFoundError:
        print("npx não encontrado — o PNG não foi gerado", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print(e.stderr.decode(errors="replace"), file=sys.stderr)
        return 1

    print(f"assets/{PNG.name}  ({PNG.stat().st_size // 1024} KB)")
    print("\nGitHub não tem API para isso: suba em")
    print("  Settings → General → Social preview → Upload an image")
    return 0


if __name__ == "__main__":
    sys.exit(main())
