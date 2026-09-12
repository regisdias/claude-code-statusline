---
tipo: guia
data: 2026-09-12
---

# Testar sem abrir o Claude Code

O script só depende do JSON que chega pela entrada padrão, então qualquer arquivo serve de payload. O
`example-payload.json` do repo cobre o caso completo.

## Shell (Linux, WSL, macOS)

```bash
bash statusline-command.sh < example-payload.json
```

## PowerShell

No Windows:

```powershell
Get-Content example-payload.json | powershell -NoProfile -File .\statusline-command.ps1
```

Do WSL, usando o PowerShell do Windows — é assim que a versão `.ps1` foi validada sem sair do Linux:

```bash
cat example-payload.json | powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w statusline-command.ps1)"
```

## O teste que vale antes de publicar

As duas implementações têm de devolver **exatamente os mesmos bytes**:

```bash
bash statusline-command.sh < example-payload.json > /tmp/sh.txt
cat example-payload.json | powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w statusline-command.ps1)" | tr -d '\r' > /tmp/ps.txt
cmp /tmp/sh.txt /tmp/ps.txt && echo idênticas
```

O `tr -d '\r'` existe porque o PowerShell devolve fim de linha do Windows pela ponte do WSL.

## Casos que não podem quebrar

Vale rodar os quatro antes de publicar mudança:

| Payload | Esperado |
|---|---|
| `example-payload.json` | três barras e o custo da sessão |
| JSON sem `rate_limits` | só a barra `ctx` |
| `{}` | `Claude  aguardando...` |
| Texto que não é JSON | `Claude  aguardando...` |

## Ver os códigos ANSI

```bash
bash statusline-command.sh < example-payload.json | cat -v
```

Útil quando a cor não fecha: `^[[0m` tem de aparecer logo depois de cada barra.
