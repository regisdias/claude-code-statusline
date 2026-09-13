---
tipo: bug-fix
data: 2026-09-13
---

# Locale com vírgula decimal quebrava os números

Issue #27.

## Sintoma

Num Mac com `LANG=pt_BR.UTF-8`, rodando o [[../guias/validar-no-macos]]:

```
session $12,00      ← o payload mandava 12.3456; o certo é $12.35
```

Com percentual **fracionado** ficava pior — os limites do plano zeravam, e o stderr reclamava:

```
LC_ALL=C          ctx [██████░░░░] 130k/200k 65%  │  5h [████████░░] 85%  │  week [██████░░░░] 60%  │  session $12.35
LANG=pt_BR.UTF-8  ctx [██████░░░░] 130k/200k 64%  │  5h [████████░░] 0%   │  week [██████░░░░] 0%   │  session $12,00

printf: 84.7: invalid number
```

Repare que a **barra** do 5h continua com 8 blocos e só o número zera: são dois caminhos de formatação
diferentes quebrando de jeitos diferentes.

## Causa

JSON sempre usa ponto. O script formata número em dois lugares, e os dois obedecem `LC_NUMERIC`:

| Quem | Onde | Em `pt_BR` |
|---|---|---|
| `awk` | custo, % do ctx, tokens, preenchimento da barra, cor | lê `12.3456` até o ponto → `12`, e imprime com vírgula |
| `printf %.0f` do bash | % do 5h e da semana | recusa `84.7` como número inválido → `0` |

O PowerShell nunca teve o problema: formata com `InvariantCulture` desde o início.

## Por que o CI não pegou

Dois motivos somados. O runner roda no locale padrão, com ponto. E todos os payloads de
`scripts/payloads/` têm percentual **inteiro** — `printf %.0f 41` funciona em qualquer locale, e o custo
só erra na parte decimal, que o `verde.json` até tem, mas nunca rodou num locale com vírgula.

## Correção

Uma linha no topo do `statusline-command.sh`:

```bash
export LC_ALL=C
```

`LC_ALL`, e não `LC_NUMERIC`: quem tem `LC_ALL` definido no próprio shell passaria por cima da variável
mais estreita. Nada no script depende do locale de caractere — os glifos passam como bytes, e o `date`
só formata `%H:%M` e `%d/%m`.

## O teste

A seção 6 do `scripts/testar.sh` monta um payload fracionado a partir do `verde.json`, desenha em C como
referência e compara com `pt_BR.UTF-8` e `de_DE.UTF-8`, via `LC_ALL` e via `LANG`, **incluindo o
stderr**. Confirmado vermelho sem a correção (4 falhas) e verde com ela.

Duas armadilhas no próprio teste:

- **Locale não instalado cai em C calado** e o caso passaria sem testar nada. Por isso a sonda confere
  se o locale imprime vírgula de verdade antes de contar — e avisa quando pula.
- **A sonda precisa de um bash novo com `env -i`.** O bash 3.2 ignora `LC_ALL=x printf …` num builtin, e
  um `LANG` herdado mascararia o locale ausente. E ela formata `1`, não `1.5`: em `pt_BR` o próprio
  `1.5` é número inválido.

O runner Ubuntu não traz `pt_BR`; o CI gera com `locale-gen` antes do `testar.sh`. O macOS já tem.

## Lição

A mesma da [[2026-09-12-seq-do-bsd-alargava-a-barra-cheia-no-macos]]: o payload de teste tem de ter os
extremos — aqui, número fracionado — e o ambiente de teste tem de variar o que a pessoa de fora varia.
Locale é uma dessas coisas.
