---
tipo: arquitetura
data: 2026-09-12
---

# Como a statusline funciona

O Claude Code executa o comando configurado em `statusLine` a cada desenho da barra e **passa um JSON
pela entrada padrão**. O script lê esse JSON, monta uma linha de texto com códigos ANSI e escreve na
saída padrão. Não há estado, arquivo temporário nem chamada de rede.

## O que o payload traz

Os campos usados, todos opcionais na leitura (campo ausente vira `-` no shell e `$null` no PowerShell):

| Campo | Vira |
|---|---|
| `model.display_name` | nome do modelo no começo da linha |
| `context_window.used_percentage` | barra `ctx` |
| `context_window.context_window_size` e `current_usage.input_tokens` | `330k/1000k` |
| `rate_limits.five_hour.used_percentage` e `.resets_at` | barra `5h` e a hora do reset |
| `rate_limits.seven_day.used_percentage` e `.resets_at` | barra `week` |
| `cost.total_cost_usd` | `session $12.35` |
| `workspace.current_dir` (ou `cwd`) | ponto de partida para achar o `.git/HEAD` → trecho da branch |

`resets_at` é epoch em segundos, formatado com o relógio local: só a hora quando o reset é hoje, dia e
hora quando é outro dia.

## Montagem da linha

1. Uma única leitura do JSON (`jq` com `@tsv` no shell; `ConvertFrom-Json` no PowerShell).
2. Cada trecho vira uma barra de 10 blocos (`█` e `░`) com cor pela faixa: verde até 60%, amarelo até
   85%, vermelho acima disso.
3. Os trechos existentes são unidos por `│`. Trecho sem dado simplesmente não aparece.

## Degradação

- Sem `rate_limits` (Claude Code anterior ao 2.1.251, ou cobrança por API key): sai só a barra `ctx`.
- Payload vazio, inválido, ou `jq` ausente: sai `<modelo>  waiting...`.

Nenhum caminho de erro imprime stack trace: a statusline é uma linha do terminal, e barulho ali atrapalha
quem está trabalhando.

## Desempenho

A barra é redesenhada com frequência, então o custo por execução importa: a implementação atual fica em
torno de 50 ms. É o motivo de haver uma leitura só do JSON e nenhuma dependência que precise subir um
runtime — ver [[../decisoes/uso-do-plano-vem-do-payload]].
