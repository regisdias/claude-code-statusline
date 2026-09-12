---
tipo: decisao
data: 2026-09-12
---

# Duas implementações, com a mesma saída

**Decisão:** manter `statusline-command.sh` e `statusline-command.ps1` como implementações paralelas, em
vez de exigir um ambiente único.

## Por quê

O Claude Code roda o comando da statusline pelo shell do sistema. No Windows nativo isso é o PowerShell,
onde não existem `bash`, `jq` nem `awk`. As saídas possíveis eram:

| Caminho | Problema |
|---|---|
| Só shell, exigindo Git Bash | Afasta justamente quem usa Claude Code no Windows sem WSL |
| Só shell, exigindo WSL | Mesma coisa, com peso maior |
| Reescrever em Node | Traz dependência de runtime e sobe um processo a cada desenho da barra |
| **Duas implementações** | Duplica ~100 linhas, e cada uma usa só o que o sistema já tem |

A duplicação é pequena e o ganho é direto: quem está no Windows copia um arquivo e pronto; quem está em
Linux, WSL ou macOS copia o outro.

## Contrato entre as duas

A saída tem de ser **idêntica byte a byte** para o mesmo payload. É o teste que vale antes de publicar
qualquer mudança — ver [[../guias/testar-local]].

Consequências práticas: nenhuma das duas pode ganhar um campo que a outra não tenha, e mudança de
formato entra nas duas no mesmo commit.

## Dependências aceitas

- Shell: `jq`, `awk`, `bash` — presentes ou triviais de instalar nos três sistemas
- PowerShell: nada além do Windows PowerShell 5.1, que já vem no Windows
