---
tipo: pendente
status: aberto
data: 2026-09-12
codigo: CCS-1
---

# Confirmar a versão shell no macOS

O `statusline-command.sh` formata o horário de reset com `date`, e as duas famílias divergem: `date -d`
é GNU (Linux, WSL, Git Bash) e `date -r` é BSD (macOS). A função `fmt_epoch` tenta o GNU e cai no BSD
quando o primeiro falha, mas **esse segundo caminho nunca foi executado num Mac**.

## Como confirmar

```bash
bash statusline-command.sh < example-payload.json
```

Esperado, igual ao do Linux:

```
Opus 5 (1M context)  ctx [███░░░░░░░] 330k/1000k 33%  │  5h [████░░░░░░] 41% · reseta 06:20  │  semana [█░░░░░░░░░] 11% · 18/09 05:00  │  sessão $12.35
```

O que pode divergir: o horário do reset (fuso da máquina) e a data `18/09 05:00`, que depende de quando
o teste roda. O que **não** pode: barra vazia, horário em branco ou erro de `date`.

Também vale conferir que o `jq` está instalado (`brew install jq`) e que o terminal está em UTF-8, senão
os blocos da barra saem como interrogação.
