# claude-code-statusline

A statusline for [Claude Code](https://claude.com/claude-code) that shows your **context window** and
your **real plan usage** — the 5-hour block and the weekly limit — straight from the payload Claude Code
hands to the statusline. Same numbers as `/usage`, no estimation, no extra process per render.

```
Opus 5 (1M context)  ctx [███░░░░░░░] 330k/1000k 33%  │  5h [████░░░░░░] 41% · reseta 06:20  │  semana [█░░░░░░░░░] 11% · 18/09 05:00  │  sessão $12.35
```

Two implementations, same output:

| File | For |
|---|---|
| `statusline-command.sh` | Linux, WSL, macOS, Git Bash (needs `jq`) |
| `statusline-command.ps1` | Claude Code running natively on Windows (PowerShell 5.1+, no dependencies) |

| Segment | What it means |
|---|---|
| `ctx` | Context window of the current conversation. Local to the session, unrelated to your plan quota. |
| `5h` | 5-hour block of your plan, and when it resets. |
| `semana` | Weekly plan limit, and when it resets. |
| `sessão` | Cost of this conversation, in USD. |

Colors: green up to 60%, yellow up to 85%, red above that.

## Why not a cost-based bar

Statuslines that shell out to a usage estimator read the local transcript files, price the tokens with
the public API table and divide by a ceiling you calibrate by hand. Two things go wrong:

- **The bar goes past 100%** when the calibrated ceiling is lower than your real allowance. In one
  measured case the bar read 112% while `/usage` reported 41%.
- **Long sessions inflate the estimate.** Cache reads are cheap for your quota but still add up in USD.

Claude Code 2.1.251+ sends `rate_limits.five_hour` and `rate_limits.seven_day` (percentage and
`resets_at`) in the statusline payload, so the real numbers are one JSON read away.

## Requirements

- Claude Code **2.1.251+** (`claude --version`)
- Shell version: `jq`, `awk`, `bash` — Linux: `apt install jq` · macOS: `brew install jq`
- PowerShell version: nothing beyond Windows PowerShell 5.1 (ships with Windows)

## Install — Linux, WSL and macOS

```bash
curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

In `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## Install — Windows (PowerShell)

Use this one when Claude Code runs on Windows itself. If you use Claude Code **inside WSL**, follow the
Linux instructions instead — the WSL side has its own `~/.claude`.

```powershell
iwr https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/statusline-command.ps1 `
  -OutFile "$env:USERPROFILE\.claude\statusline-command.ps1"
```

In `%USERPROFILE%\.claude\settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\\.claude\\statusline-command.ps1"
  }
}
```

On PowerShell 7 use `pwsh` instead of `powershell`. The bar appears on the next render — no restart needed.

> **Keep the file as UTF-8 with BOM.** Windows PowerShell 5.1 reads a BOM-less file as ANSI, and the
> block characters break the script with a parser error. Downloading it as shown preserves the BOM;
> if you edit the file, save it as "UTF-8 with BOM".

## Try it without Claude Code

```bash
bash statusline-command.sh < example-payload.json                          # Linux, WSL, macOS
```

```powershell
Get-Content example-payload.json | powershell -NoProfile -File .\statusline-command.ps1
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| Only the `ctx` bar shows | Claude Code older than 2.1.251, or the plan has no rate limits (API key billing). |
| `aguardando...` | The payload arrived empty, or `jq` is missing (shell version). |
| Blocks show as `?` on Windows | The terminal is not using UTF-8. Windows Terminal handles it; the old console host may not. |
| No colors | Your terminal is stripping ANSI codes. |
| Reset time is wrong | Your machine's timezone. The script formats the epoch with the local clock. |

## License

MIT — see [LICENSE](LICENSE).

---

# Português

Uma statusline para o [Claude Code](https://claude.com/claude-code) que mostra a **janela de contexto** e
o **uso real do plano** — o bloco de 5 horas e o limite semanal — direto do payload que o Claude Code
entrega para a statusline. São os mesmos números do `/usage`: sem estimativa e sem subir um processo a
cada desenho da barra.

Duas implementações, com a mesma saída:

| Arquivo | Para |
|---|---|
| `statusline-command.sh` | Linux, WSL, macOS e Git Bash (precisa do `jq`) |
| `statusline-command.ps1` | Claude Code rodando direto no Windows (PowerShell 5.1+, sem dependência) |

| Trecho | O que é |
|---|---|
| `ctx` | Janela de contexto da conversa atual. É local, não tem relação com a cota do plano. |
| `5h` | Bloco de 5 horas do plano, e a hora em que zera. |
| `semana` | Limite semanal do plano, e quando zera. |
| `sessão` | Custo desta conversa, em dólar. |

Cores: verde até 60%, amarelo até 85%, vermelho acima disso.

## Por que não usar barra baseada em custo

Statuslines que chamam um estimador de uso leem os arquivos de transcrição locais, convertem os tokens
em dólar pela tabela pública da API e dividem por um teto calibrado na mão. Duas coisas dão errado:

- **A barra passa de 100%** quando o teto calibrado está abaixo da cota real. Num caso medido, a barra
  marcava 112% enquanto o `/usage` dizia 41%.
- **Sessão longa infla a estimativa:** leitura de cache pesa pouco na cota e muito na conta em dólar.

O Claude Code 2.1.251+ manda `rate_limits.five_hour` e `rate_limits.seven_day` (porcentagem e
`resets_at`) no payload da statusline — o número real está a uma leitura de JSON de distância.

## Requisitos

- Claude Code **2.1.251+** (`claude --version`)
- Versão shell: `jq`, `awk` e `bash` — Linux: `apt install jq` · macOS: `brew install jq`
- Versão PowerShell: nada além do Windows PowerShell 5.1, que já vem no Windows

## Instalação — Linux, WSL e macOS

```bash
curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

No `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## Instalação — Windows (PowerShell)

Use esta quando o Claude Code roda no próprio Windows. Se você usa o Claude Code **dentro do WSL**, siga
a instalação de Linux: o lado WSL tem o seu próprio `~/.claude`.

```powershell
iwr https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/statusline-command.ps1 `
  -OutFile "$env:USERPROFILE\.claude\statusline-command.ps1"
```

No `%USERPROFILE%\.claude\settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\\.claude\\statusline-command.ps1"
  }
}
```

No PowerShell 7, troque `powershell` por `pwsh`. A barra aparece no próximo desenho, sem reiniciar nada.

> **Mantenha o arquivo em UTF-8 com BOM.** O Windows PowerShell 5.1 lê arquivo sem BOM como ANSI, e os
> caracteres de bloco quebram o script com erro de parser. Baixando como acima, o BOM vem junto; se for
> editar, salve como "UTF-8 com BOM".

## Testar sem abrir o Claude Code

```bash
bash statusline-command.sh < example-payload.json                          # Linux, WSL, macOS
```

```powershell
Get-Content example-payload.json | powershell -NoProfile -File .\statusline-command.ps1
```

## Se algo não aparecer

| Sintoma | Causa |
|---|---|
| Só a barra `ctx` aparece | Claude Code anterior ao 2.1.251, ou plano sem limite de cota (cobrança por API key). |
| `aguardando...` | O payload veio vazio, ou falta o `jq` (versão shell). |
| Os blocos viram `?` no Windows | O terminal não está em UTF-8. O Windows Terminal resolve; o console antigo pode não. |
| Sem cores | O terminal está removendo os códigos ANSI. |
| Hora do reset errada | Fuso do seu computador: o script formata o epoch com o relógio local. |

## Licença

MIT — veja [LICENSE](LICENSE).
