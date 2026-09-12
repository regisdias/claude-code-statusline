---
tipo: pendente
status: fazendo
data: 2026-09-12
codigo: CCS-1
---

# Confirmar a versão shell no macOS

O `statusline-command.sh` formata o horário de reset com `date`, e as duas famílias divergem: `date -d`
é GNU (Linux, WSL, Git Bash) e `date -r` é BSD (macOS). A função `fmt_epoch` tenta o GNU e cai no BSD
quando o primeiro falha, mas **esse segundo caminho nunca foi executado num Mac de verdade**.

## Andamento

O job `paridade` do CI roda o `scripts/testar.sh` em `macos-latest`, então o caminho `date -r` passou a
ser exercitado a cada push — veja [[../decisoes/ci-em-push-e-pr]]. Isso cobre a parte que quebraria em
silêncio: horário em branco ou erro de `date`.

**E achou um bug de verdade logo no primeiro push** — mas não no `date`: o `seq` do BSD alargava a barra
cheia para 12 blocos. Corrigido, com a história em
[[../bugs-fixes/2026-09-12-seq-do-bsd-alargava-a-barra-cheia-no-macos]]. O `date -r` passou limpo em
todos os seis payloads.

**Falta ainda:** alguém olhando um terminal de Mac. O runner do GitHub não diz se os blocos `█░` e o
separador `│` desenham direito no Terminal.app e no iTerm2, nem se o `Get-Reset` acerta o fuso de uma
máquina configurada fora do UTC.

## Como confirmar na mão

```bash
bash statusline-command.sh < scripts/payloads/verde.json
```

Esperado, igual ao do Linux:

```
Opus 5 (1M context)  ctx [███░░░░░░░] 330k/1000k 33%  │  5h [████░░░░░░] 41% · resets 06:20  │  week [█░░░░░░░░░] 11% · 18/09 05:00  │  session $12.35
```

O que pode divergir: o horário do reset (fuso da máquina) e a data `18/09 05:00`, que depende de quando
o teste roda. O que **não** pode: barra vazia, horário em branco ou erro de `date`.

Também vale conferir que o `jq` está instalado (`brew install jq`) e que o terminal está em UTF-8, senão
os blocos da barra saem como interrogação.
