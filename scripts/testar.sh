#!/usr/bin/env bash
# Runs every payload through both implementations and checks that they agree
# byte for byte. The PowerShell half is skipped when `pwsh` is not installed, so
# the script still works on a bare Linux box.
#
#   bash scripts/testar.sh
#
# Exit code 0 = the two implementations agree on every case.
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shell="$raiz/statusline-command.sh"
ps1="$raiz/statusline-command.ps1"
payloads="$raiz/scripts/payloads"

falhas=0
tem_pwsh=0
command -v pwsh >/dev/null 2>&1 && tem_pwsh=1

command -v jq >/dev/null 2>&1 || { echo "jq não encontrado" >&2; exit 1; }

temporario=$(mktemp -d)
trap 'rm -rf "$temporario"' EXIT

# Point the scripts at an empty config dir: whoever runs this may have the update
# check enabled in their real ~/.claude, which would add a segment to every case.
mkdir -p "$temporario/config"
export CLAUDE_CONFIG_DIR="$temporario/config"

# Compare both implementations on one payload file.
comparar() {
    local nome=$1 payload=$2 saida_sh saida_ps

    saida_sh=$(bash "$shell" < "$payload" 2>/dev/null)
    if [ -z "$saida_sh" ]; then
        echo "FALHA  $nome — a versão shell não imprimiu nada" >&2
        falhas=$((falhas + 1))
        return
    fi

    if [ "$tem_pwsh" = 0 ]; then
        echo "ok     $nome — shell (PowerShell pulado, pwsh ausente)"
        return
    fi

    saida_ps=$(pwsh -NoProfile -File "$ps1" < "$payload" 2>/dev/null)
    if [ "$saida_sh" = "$saida_ps" ]; then
        echo "ok     $nome — as duas implementações batem"
    else
        echo "FALHA  $nome — saídas diferentes:" >&2
        printf '  sh : %q\n  ps1: %q\n' "$saida_sh" "$saida_ps" >&2
        falhas=$((falhas + 1))
    fi
}

# ---------------------------------------------------------------------------
# 1. O .ps1 tem de manter o BOM
# ---------------------------------------------------------------------------
# Without it, Windows PowerShell 5.1 reads the file as ANSI and the block
# characters break the parser before the script ever runs.
if [ "$(head -c3 "$ps1" | od -An -tx1 | tr -d ' \n')" != "efbbbf" ]; then
    echo "FALHA  statusline-command.ps1 perdeu o BOM UTF-8" >&2
    falhas=$((falhas + 1))
else
    echo "ok     statusline-command.ps1 está em UTF-8 com BOM"
fi

# ---------------------------------------------------------------------------
# 2. Os payloads de referência
# ---------------------------------------------------------------------------
for payload in "$payloads"/*.json; do
    comparar "$(basename "$payload")" "$payload"
done

# ---------------------------------------------------------------------------
# 3. A branch do git, lida do .git/HEAD
# ---------------------------------------------------------------------------
# These fixtures are built here instead of living in scripts/payloads/ for two
# reasons: git refuses to track a path containing ".git", and the payload needs
# an absolute path that only exists at run time.
fixture() {
    local caminho="$temporario/$1" conteudo=$2
    mkdir -p "$(dirname "$caminho")"
    printf '%s' "$conteudo" > "$caminho"
}

fixture "comum/.git/HEAD"      $'ref: refs/heads/main\n'
fixture "com-barra/.git/HEAD"  $'ref: refs/heads/docs/assunto\n'
fixture "solto/.git/HEAD"      $'3b230b4a9f8e7d6c5b4a3928176554433221100f\n'
fixture "crlf/.git/HEAD"       $'ref: refs/heads/feature/x\r\n'
# Sem newline final: `read` devolve não-zero mas preenche a variável
fixture "sem-nl/.git/HEAD"     'ref: refs/heads/sem-newline'
mkdir -p "$temporario/fundo/a/b/c"
fixture "fundo/.git/HEAD"      $'ref: refs/heads/main\n'
# Worktree/submodule: ".git" is a file pointing at the real git dir
fixture "arvore-real/HEAD"     $'ref: refs/heads/wt-branch\n'
fixture "arvore/.git"          "gitdir: $temporario/arvore-real"$'\n'

branch_caso() {
    local nome=$1 dir=$2 esperado=$3
    # Separate statement on purpose: inside a single `local`, bash creates every
    # name before running the assignments, so "$nome" would still be unset here.
    local payload="$temporario/payload-$nome.json" obtido
    jq --arg d "$dir" '. + {workspace: {current_dir: $d}}' "$payloads/verde.json" > "$payload"

    obtido=$(bash "$shell" < "$payload" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g')
    obtido=${obtido%%  │  *}
    obtido=${obtido#⎇ }   # the segment carries the U+2387 marker
    if [ "$obtido" != "$esperado" ]; then
        echo "FALHA  branch/$nome — esperava '$esperado', veio '$obtido'" >&2
        falhas=$((falhas + 1))
        return
    fi
    comparar "branch/$nome" "$payload"
}

branch_caso "simples"   "$temporario/comum"      "main"
branch_caso "com-barra" "$temporario/com-barra"  "docs/assunto"
branch_caso "detached"  "$temporario/solto"      "3b230b4"
branch_caso "crlf"      "$temporario/crlf"       "feature/x"
branch_caso "sem-nl"    "$temporario/sem-nl"     "sem-newline"
branch_caso "walk-up"   "$temporario/fundo/a/b/c" "main"
branch_caso "worktree"  "$temporario/arvore"     "wt-branch"

# Fora de repositório: o trecho some, o resto continua
mkdir -p "$temporario/sem-repo"
sem_repo="$temporario/payload-sem-repo.json"
jq --arg d "$temporario/sem-repo" '. + {workspace: {current_dir: $d}}' "$payloads/verde.json" > "$sem_repo"
if bash "$shell" < "$sem_repo" | sed 's/\x1b\[[0-9]*m//g' | grep -q '^Opus 5'; then
    echo "ok     branch/fora-de-repo — trecho ausente, barra intacta"
    comparar "branch/fora-de-repo" "$sem_repo"
else
    echo "FALHA  branch/fora-de-repo — a barra não deveria mudar fora de um repo" >&2
    falhas=$((falhas + 1))
fi

# ---------------------------------------------------------------------------
# 4. O aviso de atualização, lido do cache
# ---------------------------------------------------------------------------
# The bar only ever reads the cache; the hook is what writes it. These cases feed
# the bar a cache directly, which is exactly what it sees in real use.
config="$temporario/config"
marcador="$config/.ccsl-update-check"
cache="$config/.ccsl-update-cache"

update_caso() {
    local nome=$1 conteudo=$2 esperado=$3
    local payload="$temporario/payload-upd-$nome.json" obtido
    cp "$payloads/verde.json" "$payload"

    rm -f "$cache"
    [ -n "$conteudo" ] && printf '%s\n' "$conteudo" > "$cache"

    obtido=$(bash "$shell" < "$payload" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g')
    case $obtido in
        *"  │  ↑"*) obtido="↑${obtido##*  │  ↑}" ;;
        *)          obtido="—" ;;
    esac
    if [ "$obtido" != "$esperado" ]; then
        echo "FALHA  update/$nome — esperava '$esperado', veio '$obtido'" >&2
        falhas=$((falhas + 1))
        return
    fi
    comparar "update/$nome" "$payload"
}

# Sem o marcador, nem o cache é lido
printf '0 9.9.9\n' > "$cache"
sem_marcador="$temporario/payload-upd-off.json"
cp "$payloads/verde.json" "$sem_marcador"
if bash "$shell" < "$sem_marcador" | grep -q '↑'; then
    echo "FALHA  update/desligado — segmento apareceu sem o marcador" >&2
    falhas=$((falhas + 1))
else
    echo "ok     update/desligado — opt-in respeitado"
    comparar "update/desligado" "$sem_marcador"
fi

: > "$marcador"
update_caso "nova"        "1789204800 9.9.9"   "↑9.9.9"
instalada=$(sed -n 's/^CCSL_VERSION="\(.*\)"$/\1/p' "$shell")
update_caso "mesma"       "1789204800 $instalada"   "—"
update_caso "mais-velha"  "1789204800 0.0.1"   "—"
update_caso "corrompido"  "lixo aqui"          "—"
update_caso "so-epoch"    "1789204800"         "—"
update_caso "quatro-partes" "1789204800 1.2.3.4" "—"
update_caso "vazio"       ""                   "—"
rm -f "$marcador" "$cache"

if [ "$falhas" -gt 0 ]; then
    echo "$falhas falha(s)" >&2
    exit 1
fi
echo "tudo certo"
