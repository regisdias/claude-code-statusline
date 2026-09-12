#!/usr/bin/env bash
# Runs every payload in scripts/payloads/ through both implementations and
# checks that they agree byte for byte. The PowerShell half is skipped when
# `pwsh` is not installed, so the script still works on a bare Linux box.
#
#   bash scripts/testar.sh
#
# Exit code 0 = the two implementations agree on every payload.
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shell="$raiz/statusline-command.sh"
ps1="$raiz/statusline-command.ps1"
payloads="$raiz/scripts/payloads"

falhas=0
tem_pwsh=0
command -v pwsh >/dev/null 2>&1 && tem_pwsh=1

if ! command -v jq >/dev/null 2>&1; then
    echo "jq não encontrado — a versão shell precisa dele" >&2
    exit 1
fi

# The .ps1 must keep its UTF-8 BOM: without it PowerShell 5.1 reads the file as
# ANSI and the block characters break the parser.
if [ "$(head -c3 "$ps1" | od -An -tx1 | tr -d ' \n')" != "efbbbf" ]; then
    echo "FALHA  statusline-command.ps1 perdeu o BOM UTF-8" >&2
    falhas=$((falhas + 1))
else
    echo "ok     statusline-command.ps1 está em UTF-8 com BOM"
fi

for payload in "$payloads"/*.json; do
    nome=$(basename "$payload")

    saida_sh=$(bash "$shell" < "$payload" 2>/dev/null)
    if [ -z "$saida_sh" ]; then
        echo "FALHA  $nome — a versão shell não imprimiu nada" >&2
        falhas=$((falhas + 1))
        continue
    fi

    if [ "$tem_pwsh" = 0 ]; then
        echo "ok     $nome — shell (PowerShell pulado, pwsh ausente)"
        continue
    fi

    saida_ps=$(pwsh -NoProfile -File "$ps1" < "$payload" 2>/dev/null)
    if [ "$saida_sh" = "$saida_ps" ]; then
        echo "ok     $nome — as duas implementações batem"
    else
        echo "FALHA  $nome — saídas diferentes:" >&2
        printf '  sh : %q\n  ps1: %q\n' "$saida_sh" "$saida_ps" >&2
        falhas=$((falhas + 1))
    fi
done

if [ "$falhas" -gt 0 ]; then
    echo "$falhas falha(s)" >&2
    exit 1
fi
echo "tudo certo"
