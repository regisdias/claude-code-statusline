---
tipo: guia
data: 2026-09-12
---

# Regenerar as imagens do README

As duas imagens do README (`assets/demo.svg` e `assets/demo-fallback.svg`) **não são desenhadas à mão**:
o `scripts/gerar-svg.py` roda o `statusline-command.sh` com os payloads de `scripts/payloads/`, captura a
saída ANSI de verdade e converte em SVG. O que aparece no README é o que o script imprime.

```bash
python3 scripts/gerar-svg.py
```

Commite os SVGs regerados **no mesmo commit** da mudança de formato.

## Por que SVG, e não PNG

- Fica nítido em qualquer zoom e em telas retina, sem versão @2x.
- É texto: o `git diff` mostra o que mudou na barra, não um blob binário.
- Não depende de tirar print numa máquina específica com um terminal específico.

Cada glifo recebe a sua própria coordenada `x`. Sem isso, um navegador que caia numa fonte não
monoespaçada desalinharia os blocos `█░` e a barra ficaria torta.

## O que o CI confere

```bash
python3 scripts/gerar-svg.py --verificar
```

Renderiza tudo num diretório temporário — nunca escreve em `assets/` — e compara com o que está
commitado, **ignorando a hora do reset e as coordenadas `x`**. Sem essa normalização o teste falharia
toda meia-noite, já que o `resets_at` dos payloads é reposicionado para "daqui a 2 horas" e "daqui a 3
dias" na hora de gerar.

Falhou? É porque o formato da saída mudou e as imagens ficaram para trás. Rode sem o `--verificar`.

## Trocar por print de terminal de verdade

Se um dia valer a pena, é só substituir os arquivos em `assets/` e tirar o job `imagens` do
`.github/workflows/ci.yml`. Enquanto as imagens forem geradas, esse job é o que impede o README de
anunciar uma barra que o script não desenha mais.

Veja também [[testar-local]].
