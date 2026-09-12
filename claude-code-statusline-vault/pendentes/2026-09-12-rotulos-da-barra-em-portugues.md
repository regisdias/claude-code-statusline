---
tipo: pendente
status: aberto
data: 2026-09-12
codigo: CCS-2
---

# Rótulos da barra em português, num projeto de README em inglês

A statusline desenha `semana`, `sessão` e `reseta` em português, enquanto o README, o `install.sh` e os
templates de issue estão em inglês — a decisão registrada em
[[decisoes/readme-em-ingles-e-arquivos-de-comunidade]]. Para quem chega de fora, três palavras numa
língua que não lê no meio de uma barra em inglês parecem bug, não escolha.

## As opções

| Opção | Custo |
|---|---|
| Traduzir para `week`, `session`, `resets` | Quebra a saída de quem já instalou; entra nas duas implementações no mesmo commit |
| Deixar como está | Continua estranho para quem não fala português |
| Tornar configurável por variável de ambiente | Dobra os casos de teste de paridade; conflita com "sem dependência, sem custo por desenho" |

## Onde mexeria

- `statusline-command.sh`: os `printf` de `bloco_part`, `semana_part` e `custo_part`
- `statusline-command.ps1`: os blocos equivalentes de `$partes +=`
- `scripts/gerar-svg.py` → regerar `assets/demo*.svg`
- As tabelas "O que aparece" dos dois READMEs e o `CHANGELOG.md`

Se for traduzir, vale fazer antes de o repositório ganhar tração: depois, é mudança que aparece na
barra de todo mundo sem aviso.
