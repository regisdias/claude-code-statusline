---
tipo: decisao
data: 2026-09-12
---

# CI roda em push e PR, e não só por `workflow_dispatch`

## Decisão

O `.github/workflows/ci.yml` dispara em `push` na `main`, em `pull_request` e por `workflow_dispatch`.

## Por quê

A regra geral é ligar CI automático só depois que a `main` estiver em produção, para não travar a fase
de muito commit e push entre devs. Aqui a `main` **já é a produção**: o README manda instalar com

```bash
curl -fsSL .../main/install.sh | bash
```

Todo mundo que instala puxa o `HEAD` da `main` direto. Não existe artefato publicado entre o commit e o
usuário, então um push quebrado é uma instalação quebrada na hora — exatamente o caso em que o CI
automático paga por si.

O projeto também é de uma pessoa só: não há o problema de fila de workflow disputando runner.

## O que o CI cobre

| Job | O que garante |
|---|---|
| `shellcheck` | Lint dos três scripts shell, severidade `warning` |
| `powershell` | PSScriptAnalyzer no `.ps1`, erros e avisos |
| `bom` | O `.ps1` não perdeu o BOM UTF-8 — a armadilha de [[../bugs-fixes/2026-09-12-powershell-bom-e-colisao-de-variavel]] |
| `paridade` | `scripts/testar.sh` no Ubuntu **e no macOS** — é o único lugar onde o caminho `date -r` roda de verdade |
| `windows` | Renderiza todos os payloads no Windows PowerShell 5.1 real |
| `imagens` | As imagens do README ainda batem com a saída atual |

O job `paridade` no macOS é o que fecha a pendência
[[../pendentes/arquivo/2026-09-12-confirmar-no-macos]] parcialmente: cobre o `date -r`, mas não um terminal de
Mac de verdade desenhando os blocos.

## Consequência

Um PR de fora não roda com segredos e não precisa: nenhum job usa credencial. O `permissions` está em
`contents: read`.
