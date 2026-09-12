---
tipo: bug-fix
data: 2026-09-12
---

# `seq` do BSD alargava a barra cheia no macOS

## Sintoma

No macOS, sempre que uma barra enchia (100% dos blocos), ela saía com **12 caracteres** em vez de 10:

```
5h [██████████░░] 96%     ← macOS, errado
5h [██████████]   96%     ← Linux e PowerShell, certo
```

Só acontecia com a barra cheia. Abaixo disso, as duas plataformas concordavam — por isso passou
despercebido: o payload de exemplo tem tudo abaixo de 50%.

## Causa

O `make_bar` desenhava com dois laços:

```bash
for i in $(seq 1 "$filled"); do bar="${bar}█"; done
for i in $(seq 1 "$empty");  do bar="${bar}░"; done
```

Com a barra cheia, `empty` é `0`, e aí as duas famílias de `seq` divergem:

| | `seq 1 0` |
|---|---|
| GNU (Linux, WSL, Git Bash) | não imprime nada |
| BSD (macOS) | imprime `1` e `0` |

O BSD **infere a direção** pelos operandos: como o último é menor que o primeiro, ele assume passo −1 e
conta de 1 até 0 — duas linhas, dois `░` a mais.

## Correção

Sem `seq`. O `printf` preenche com espaços e a substituição de parâmetro troca cada espaço pelo bloco:

```bash
cheio=$(printf "%${filled}s" "")
vazio=$(printf "%${empty}s" "")
printf "%s%s" "${cheio// /█}" "${vazio// /░}"
```

`%0s` imprime string vazia nas duas famílias — não existe caso de borda. De brinde, some um subprocesso
por barra: são três barras por desenho, então seis `seq` a menos. O tempo caiu para ~43 ms.

## Como foi encontrado

Pelo job `paridade` do CI rodando em `macos-latest`, no primeiro push depois de ele existir
([[../decisoes/ci-em-push-e-pr]]). O `vermelho.json` é o payload que leva o bloco de 5h a 96% — com
`width` 10, o arredondamento dá `filled` 10 e `empty` 0, exatamente o caso de borda.

É a resposta prática para [[../pendentes/2026-09-12-confirmar-no-macos]]: o caminho BSD tinha mesmo um
problema, e não era o `date -r` que se suspeitava.

## Lição

Payload de teste tem de incluir os extremos, não só o caso bonito. Três dos seis payloads de
`scripts/payloads/` existem só para isso, e foi um deles que pegou.
