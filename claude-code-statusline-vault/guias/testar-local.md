---
tipo: guia
data: 2026-09-12
atualizado: 2026-09-12
---

# Testar sem abrir o Claude Code

O script só depende do JSON que chega pela entrada padrão, então qualquer arquivo serve de payload. Os
casos que importam já estão em `scripts/payloads/`:

| Payload | Cobre |
|---|---|
| `verde.json` | caso completo, tudo abaixo de 60% |
| `amarelo.json` | limiar amarelo (60–85%) |
| `vermelho.json` | limiar vermelho (acima de 85%) |
| `sem-limites.json` | plano sem cota, só a barra `ctx` |
| `vazio.json` | `{}` → `Claude  aguardando...` |
| `invalido.json` | texto que não é JSON → `Claude  aguardando...` |

## O atalho: `scripts/testar.sh`

```bash
bash scripts/testar.sh
```

Roda **todos** os payloads nas duas implementações, compara byte a byte e confere se o `.ps1` ainda tem
o BOM UTF-8. Sem `pwsh` instalado, ele testa só o lado shell e avisa. É o mesmo comando que o CI roda.

## Na mão, um payload por vez

```bash
bash statusline-command.sh < scripts/payloads/verde.json
```

No Windows:

```powershell
Get-Content scripts\payloads\verde.json | powershell -NoProfile -File .\statusline-command.ps1
```

Do WSL, usando o PowerShell do Windows — é assim que a versão `.ps1` foi validada sem sair do Linux:

```bash
cat scripts/payloads/verde.json | powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w statusline-command.ps1)"
```

## Comparar as duas na mão

Quando o `testar.sh` acusar diferença e você quiser ver onde:

```bash
bash statusline-command.sh < scripts/payloads/verde.json > /tmp/sh.txt
cat scripts/payloads/verde.json | powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w statusline-command.ps1)" | tr -d '\r' > /tmp/ps.txt
cmp /tmp/sh.txt /tmp/ps.txt && echo idênticas
```

O `tr -d '\r'` existe porque o PowerShell devolve fim de linha do Windows pela ponte do WSL.

## Ver os códigos ANSI

```bash
bash statusline-command.sh < scripts/payloads/verde.json | cat -v
```

Útil quando a cor não fecha: `^[[0m` tem de aparecer logo depois de cada barra.

## Rodar o lint como o CI roda

```bash
shellcheck --severity=warning statusline-command.sh install.sh scripts/testar.sh
pwsh -c 'Invoke-ScriptAnalyzer -Path statusline-command.ps1 -Severity Error,Warning'
```

## Testar o instalador sem mexer no seu `~/.claude`

O `install.sh` respeita `CLAUDE_CONFIG_DIR`, então dá para apontá-lo para uma pasta descartável:

```bash
CLAUDE_CONFIG_DIR=/tmp/teste-ccsl bash install.sh
```

Ele baixa o script do GitHub, então isso testa o caminho real — inclusive se o `raw.githubusercontent`
já tem o commit que você acabou de empurrar.

Veja também [[regenerar-imagens-do-readme]].
