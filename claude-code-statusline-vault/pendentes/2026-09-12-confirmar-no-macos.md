---
tipo: pendente
status: fazendo
data: 2026-09-12
atualizado: 2026-09-12
codigo: CCS-1
---

# Confirmar a versão shell no macOS

O `statusline-command.sh` formata o horário de reset com `date`, e as duas famílias divergem: `date -d`
é GNU (Linux, WSL, Git Bash) e `date -r` é BSD (macOS). A função `fmt_epoch` tenta o GNU e cai no BSD
quando o primeiro falha, mas **esse segundo caminho nunca foi executado num Mac de verdade** — só em
runner do GitHub.

## Andamento

O job `paridade` do CI roda o `scripts/testar.sh` em `macos-latest` a cada push. Hoje são **22 casos**
lá, não só os payloads originais: todo o caminho da branch (`.git` como arquivo, HEAD solto, CRLF, sem
newline final, walk-up) e todo o do aviso de atualização. Veja [[../decisoes/ci-em-push-e-pr]].

**E achou um bug de verdade logo no primeiro push** — mas não no `date`: o `seq` do BSD alargava a barra
cheia para 12 blocos. Corrigido, com a história em
[[../bugs-fixes/2026-09-12-seq-do-bsd-alargava-a-barra-cheia-no-macos]]. O `date -r` passa limpo em
todos os casos.

**Falta ainda** o que runner nenhum resolve: alguém olhando um terminal de Mac.

## Como confirmar na mão

```bash
bash statusline-command.sh < scripts/payloads/verde.json
```

Isso sai sem a branch, porque o payload de teste não traz `workspace`. Para exercitar o trecho da
branch, aponte para um repositório:

```bash
jq --arg d "$PWD" '. + {workspace: {current_dir: $d}}' scripts/payloads/verde.json \
  | bash statusline-command.sh
```

Esperado a partir da v1.3.0, igual ao do Linux:

```
⎇ main  │  Opus 5 (1M context)  ctx [███░░░░░░░] 330k/1000k 33%  │  5h [████░░░░░░] 41% · resets 06:20  │  week [█░░░░░░░░░] 11% · 18/09 05:00  │  session $12.35
```

O que pode divergir legitimamente: o nome da branch, o horário do reset (fuso da máquina) e a data
`18/09 05:00`, que depende de quando o teste roda. O que **não** pode: barra vazia, horário em branco,
erro de `date` ou barra com largura diferente de 10 blocos.

## Os glifos, em ordem de risco

É aqui que o olho humano num Mac ainda importa:

| Glifo | Onde | Cobertura de fonte |
|---|---|---|
| `⎇` U+2387 | antes da branch | **ruim — é o candidato a virar `?`** |
| `█` `░` U+2588/2591 | as barras | boa |
| `│` U+2502 | separadores | boa |
| `↑` U+2191 | aviso de update, se ligado | boa |

Vale testar no Terminal.app **e** no iTerm2: eles resolvem fonte de formas diferentes, e o Terminal.app
costuma ser o mais pobre em fallback.

## O que mais só um Mac de verdade responde

- **Fuso fora do UTC.** O runner do GitHub roda em UTC, então o `fmt_epoch`/`Get-Reset` nunca foi visto
  convertendo epoch num Mac com fuso local. É o mesmo tipo de bug que o
  [[../bugs-fixes/2026-09-12-seq-do-bsd-alargava-a-barra-cheia-no-macos]] era: diferença de
  implementação que só aparece na plataforma certa.
- **`jq` instalado via Homebrew** (`brew install jq`) e terminal em UTF-8 — sem isso os blocos saem como
  interrogação e o diagnóstico vira falso positivo de bug.

## Para resolver esta nota

Rodar o comando acima num Mac, conferir os quatro glifos e o horário do reset, e então `status:
resolvido` com `git mv` para `pendentes/arquivo/`. Se o `⎇` sair errado, isso **não** resolve a nota —
vira pendência própria, porque a decisão de qual glifo usar volta à mesa.
