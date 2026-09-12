#!/usr/bin/env python3
"""Render the statusline's real output as an SVG terminal window.

It runs `statusline-command.sh` against the payloads in `scripts/payloads/`,
captures the ANSI output byte for byte and turns it into SVG. Nothing here
invents the picture: what you see in `assets/` is what the script prints.

Each glyph gets its own x coordinate, so the bars stay on the monospace grid
even when the reader's browser falls back to a different font.

    python3 scripts/gerar-svg.py              # write assets/demo*.svg
    python3 scripts/gerar-svg.py --verificar  # fail if they are out of date

`--verificar` compares what the script renders now against what is committed,
ignoring the reset clock and the glyph coordinates that move with it — so it
catches a format change nobody regenerated, without failing every day at
midnight.
"""

import html
import json
import re
import subprocess
import sys
import tempfile
import time
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


def rodar(payload: Path) -> str:
    """Run the shell implementation and return its raw output, ANSI included.

    The payloads carry fixed epochs so the test suite stays deterministic; here
    they are pushed to "in 2 hours" and "in 3 days" so the picture shows the two
    reset formats the script produces (`06:20` for today, `18/09 05:00` beyond).
    """
    try:
        dados = json.loads(payload.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        dados = None

    if isinstance(dados, dict) and "rate_limits" in dados:
        agora = int(time.time())
        for chave, adiante in (("five_hour", 2 * 3600), ("seven_day", 3 * 86400)):
            if chave in dados["rate_limits"]:
                dados["rate_limits"][chave]["resets_at"] = agora + adiante
        entrada = json.dumps(dados).encode("utf-8")
    else:
        entrada = payload.read_bytes()

    p = subprocess.run(
        ["bash", str(SHELL)], input=entrada, capture_output=True, check=True
    )
    return p.stdout.decode("utf-8")


def em_trechos(texto: str):
    """Split an ANSI string into (text, color) runs."""
    trechos = []
    cor = TEXTO
    pos = 0
    for m in PADRAO_ANSI.finditer(texto):
        if m.start() > pos:
            trechos.append((texto[pos : m.start()], cor))
        codigo = m.group(1).split(";")[-1] or "0"
        cor = ANSI.get(codigo, TEXTO)
        pos = m.end()
    if pos < len(texto):
        trechos.append((texto[pos:], cor))
    return trechos


def linha_svg(trechos, y: float, x0: float) -> str:
    """One output line: a <text> per color run, one x per glyph."""
    partes = []
    coluna = 0
    for texto, cor in trechos:
        if not texto:
            continue
        xs = " ".join(
            f"{x0 + (coluna + i) * LARGURA_CHAR:.1f}" for i in range(len(texto))
        )
        partes.append(
            f'<text x="{xs}" y="{y:.1f}" fill="{cor}">{html.escape(texto)}</text>'
        )
        coluna += len(texto)
    return "".join(partes)


def montar(quadros, destino: Path, titulo: str, colunas_min: int = 0) -> int:
    """quadros: list of (label, ansi_output). Label is the dim caption above.

    Returns the column count used, so sibling images can share a width.
    """
    colunas = max(
        colunas_min,
        max(len(PADRAO_ANSI.sub("", saida)) for _, saida in quadros),
        max(len(rotulo) for rotulo, _ in quadros),
    )
    largura = PAD_X * 2 + colunas * LARGURA_CHAR
    linhas = len(quadros) * 3 - 1  # label + output + blank between frames
    altura = PAD_TOPO + linhas * ALTURA_LINHA + PAD_BAIXO

    corpo = []
    y = PAD_TOPO
    for i, (rotulo, saida) in enumerate(quadros):
        if i:
            y += ALTURA_LINHA
        corpo.append(
            f'<text x="{PAD_X}" y="{y:.1f}" fill="{ROTULO}" '
            f'font-style="italic">{html.escape(rotulo)}</text>'
        )
        y += ALTURA_LINHA
        corpo.append(linha_svg(em_trechos(saida), y, PAD_X))
        y += ALTURA_LINHA

    pontos = "".join(
        f'<circle cx="{cx}" cy="16" r="6" fill="{cor}"/>'
        for cx, cor in ((20, "#ff5f57"), (40, "#febc2e"), (60, "#28c840"))
    )

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{largura:.0f}" height="{altura:.0f}" viewBox="0 0 {largura:.0f} {altura:.0f}" font-family="ui-monospace, 'SF Mono', 'JetBrains Mono', 'DejaVu Sans Mono', Menlo, Consolas, monospace" font-size="{FONTE}">
  <rect width="{largura:.0f}" height="{altura:.0f}" rx="10" fill="{FUNDO}" stroke="{BORDA}"/>
  <path d="M0 10a10 10 0 0 1 10-10h{largura - 20:.0f}a10 10 0 0 1 10 10v22H0z" fill="{BARRA_TITULO}"/>
  <line x1="0" y1="32" x2="{largura:.0f}" y2="32" stroke="{BORDA}"/>
  {pontos}
  <text x="{largura / 2:.0f}" y="21" fill="{ROTULO}" font-size="12" text-anchor="middle">{html.escape(titulo)}</text>
  {"".join(corpo)}
</svg>
"""
    destino.write_text(svg, encoding="utf-8")
    try:
        nome = destino.relative_to(RAIZ)
    except ValueError:  # verify mode renders into a temp dir
        nome = destino.name
    print(f"{nome}  ({largura:.0f}x{altura:.0f})")
    return colunas


def normalizar(svg: str) -> str:
    """Strip what legitimately changes between runs: the clock and the x grid."""
    svg = re.sub(r'x="[0-9.\s]+"', 'x=""', svg)
    svg = re.sub(r"\b\d{2}/\d{2} \d{2}:\d{2}\b|\b\d{2}:\d{2}\b", "HORA", svg)
    return svg


def main() -> int:
    if not SHELL.exists():
        print(f"não achei {SHELL}", file=sys.stderr)
        return 1

    verificar = "--verificar" in sys.argv[1:]

    # In verify mode nothing is written to assets/: the images are rendered into
    # a temp dir and compared, so a failing check never dirties the tree.
    if verificar:
        comitados = {c.name: c for c in sorted(SAIDA.glob("demo*.svg"))}
        if not comitados:
            print("nenhum assets/demo*.svg commitado para comparar", file=sys.stderr)
            return 1
        temporario = tempfile.TemporaryDirectory()
        destino = Path(temporario.name)
    else:
        SAIDA.mkdir(exist_ok=True)
        destino = SAIDA

    colunas = montar(
        [
            ("# plenty of room left", rodar(PAYLOADS / "verde.json")),
            ("# getting close to the 5-hour limit", rodar(PAYLOADS / "amarelo.json")),
            ("# weekly limit almost gone", rodar(PAYLOADS / "vermelho.json")),
        ],
        destino / "demo.svg",
        "claude-code-statusline",
    )

    montar(
        [
            ("# plan without rate limits (API key billing)", rodar(PAYLOADS / "sem-limites.json")),
            ("# first render, payload still empty", rodar(PAYLOADS / "vazio.json")),
        ],
        destino / "demo-fallback.svg",
        "graceful degradation",
        colunas_min=colunas,
    )

    if verificar:
        desatualizados = [
            comitado
            for nome, comitado in comitados.items()
            if normalizar((destino / nome).read_text(encoding="utf-8"))
            != normalizar(comitado.read_text(encoding="utf-8"))
        ]
        temporario.cleanup()
        if desatualizados:
            for caminho in desatualizados:
                print(f"desatualizado: {caminho.relative_to(RAIZ)}", file=sys.stderr)
            print("rode: python3 scripts/gerar-svg.py", file=sys.stderr)
            return 1
        print("assets/ em dia")
    return 0


if __name__ == "__main__":
    sys.exit(main())
