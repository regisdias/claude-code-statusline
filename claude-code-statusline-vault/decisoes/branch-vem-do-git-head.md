---
tipo: decisao
data: 2026-09-12
---

# A branch sai do `.git/HEAD`, não do `git`

## Decisão

Para mostrar a branch na barra, as duas implementações **leem o arquivo `.git/HEAD`** e sobem os
diretórios até achá-lo. Nenhuma chama o `git`.

## Por quê

O Claude Code **não manda a branch no payload**. Confirmado na documentação: existe
`workspace.repo.host/owner/name` (identidade do repositório, vinda do remote `origin`) e
`worktree.branch`, que só aparece dentro de uma sessão de worktree. Para o caso comum — checkout normal
de um repositório — não há campo.

Todos os exemplos da documentação oficial resolvem com `git branch --show-current`. Isso é um `exec` do
git a cada desenho da barra, e a barra é redesenhada o tempo todo. Medido aqui, 20 execuções:

| Forma | Tempo | Processos |
|---|---|---|
| `git branch --show-current` | 27 ms (~1,35 ms cada) | 1 por desenho |
| `read -r linha < .git/HEAD` | 2 ms (~0,1 ms cada) | nenhum |

13x no Linux, e a diferença cresce muito no Windows, onde criar processo é caro. O alvo do projeto é
~50 ms por desenho — ver [[duas-implementacoes-shell-e-powershell]].

O `.git/HEAD` é texto puro:

```
ref: refs/heads/main
```

## O que as duas implementações têm de tratar igual

| Caso | Comportamento |
|---|---|
| `refs/heads/docs/assunto` | branch com barra fica inteira |
| HEAD solto (sha cru) | sha curto, 7 caracteres |
| `.git` como **arquivo** (worktree, submódulo) | segue o `gitdir: <caminho>`, relativo ou absoluto |
| `HEAD` escrito no Windows | tira o `\r` do fim |
| Subdiretório fundo | sobe os pais até achar o `.git` |
| Fora de repositório | o trecho some, o resto da barra continua |

No shell, `achar_branch` define a global `BRANCH` em vez de imprimir: `$(...)` forkaria, que é
exatamente o que a função existe para evitar.

## Fixtures de teste não podem ser versionadas

O git **se recusa a rastrear caminho que contenha `.git`**, então não dá para commitar um
`scripts/payloads/fixture/.git/HEAD`. O `scripts/testar.sh` cria as fixtures num diretório temporário
na hora, e o `scripts/gerar-svg.py` faz o mesmo para a imagem do README ficar determinística — senão
ela mostraria a branch de quem gerou.
