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

command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

temporario=$(mktemp -d)
trap 'rm -rf "$temporario"' EXIT

# Point the scripts at an empty config dir: whoever runs this may have the update
# check enabled in their real ~/.claude, which would add a segment to every case.
mkdir -p "$temporario/config"
export CLAUDE_CONFIG_DIR="$temporario/config"

# Wide and pinned: the bar wraps to COLUMNS, and the existing cases assume one
# line. The wrapping section below sets it per case.
export COLUMNS=999

# Compare both implementations on one payload file.
comparar() {
    local nome=$1 payload=$2 saida_sh saida_ps

    saida_sh=$(bash "$shell" < "$payload" 2>/dev/null)
    if [ -z "$saida_sh" ]; then
        echo "FALHA  $nome — the shell version printed nothing" >&2
        falhas=$((falhas + 1))
        return
    fi

    if [ "$tem_pwsh" = 0 ]; then
        echo "ok     $nome — shell only (PowerShell skipped, pwsh missing)"
        return
    fi

    saida_ps=$(pwsh -NoProfile -File "$ps1" < "$payload" 2>/dev/null)
    if [ "$saida_sh" = "$saida_ps" ]; then
        echo "ok     $nome — both implementations agree"
    else
        echo "FALHA  $nome — outputs differ:" >&2
        printf '  sh : %q\n  ps1: %q\n' "$saida_sh" "$saida_ps" >&2
        falhas=$((falhas + 1))
    fi
}

# ---------------------------------------------------------------------------
# 1. The .ps1 must keep its BOM
# ---------------------------------------------------------------------------
# Without it, Windows PowerShell 5.1 reads the file as ANSI and the block
# characters break the parser before the script ever runs.
if [ "$(head -c3 "$ps1" | od -An -tx1 | tr -d ' \n')" != "efbbbf" ]; then
    echo "FALHA  statusline-command.ps1 lost its UTF-8 BOM" >&2
    falhas=$((falhas + 1))
else
    echo "ok     statusline-command.ps1 is UTF-8 with BOM"
fi

# ---------------------------------------------------------------------------
# 2. The reference payloads
# ---------------------------------------------------------------------------
for payload in "$payloads"/*.json; do
    comparar "$(basename "$payload")" "$payload"
done

# ---------------------------------------------------------------------------
# 3. The git branch, read from .git/HEAD
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
fixture "with-slash/.git/HEAD"  $'ref: refs/heads/docs/subject\n'
fixture "solto/.git/HEAD"      $'3b230b4a9f8e7d6c5b4a3928176554433221100f\n'
fixture "crlf/.git/HEAD"       $'ref: refs/heads/feature/x\r\n'
# No trailing newline: `read` returns non-zero but still fills the variable
fixture "no-newline/.git/HEAD"     'ref: refs/heads/no-newline'
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
    obtido=${obtido#git }   # the segment carries the `git` label by default
    if [ "$obtido" != "$esperado" ]; then
        echo "FALHA  branch/$nome — expected '$esperado', got '$obtido'" >&2
        falhas=$((falhas + 1))
        return
    fi
    comparar "branch/$nome" "$payload"
}

branch_caso "simple"   "$temporario/comum"      "main"
branch_caso "with-slash" "$temporario/with-slash"  "docs/subject"
branch_caso "detached"  "$temporario/solto"      "3b230b4"
branch_caso "crlf"      "$temporario/crlf"       "feature/x"
branch_caso "no-newline"    "$temporario/no-newline"     "no-newline"
branch_caso "walk-up"   "$temporario/fundo/a/b/c" "main"
branch_caso "worktree"  "$temporario/arvore"     "wt-branch"

# Fora de repositório: o trecho some, o resto continua
mkdir -p "$temporario/no-repo"
sem_repo="$temporario/payload-no-repo.json"
jq --arg d "$temporario/no-repo" '. + {workspace: {current_dir: $d}}' "$payloads/verde.json" > "$sem_repo"
if bash "$shell" < "$sem_repo" | sed 's/\x1b\[[0-9]*m//g' | grep -q '^Opus 5'; then
    echo "ok     branch/fora-de-repo — segment absent, rest of the bar intact"
    comparar "branch/fora-de-repo" "$sem_repo"
else
    echo "FALHA  branch/fora-de-repo — the bar should not change outside a repository" >&2
    falhas=$((falhas + 1))
fi

# ---------------------------------------------------------------------------
# 4. The update notice, read from the cache
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
        echo "FALHA  update/$nome — expected '$esperado', got '$obtido'" >&2
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
    echo "FALHA  update/desligado — segment appeared without the marker" >&2
    falhas=$((falhas + 1))
else
    echo "ok     update/desligado — opt-in respected"
    comparar "update/desligado" "$sem_marcador"
fi

: > "$marcador"
update_caso "newer"        "1789204800 9.9.9"   "↑9.9.9"
instalada=$(sed -n 's/^CCSL_VERSION="\(.*\)"$/\1/p' "$shell")
update_caso "same"       "1789204800 $instalada"   "—"
update_caso "older"  "1789204800 0.0.1"   "—"
update_caso "corrupt"  "garbage here"          "—"
update_caso "epoch-only"    "1789204800"         "—"
update_caso "four-parts" "1789204800 1.2.3.4" "—"
update_caso "empty"       ""                   "—"
rm -f "$marcador" "$cache"

# ---------------------------------------------------------------------------
# 5. Segment order, read from settings.json
# ---------------------------------------------------------------------------
ordem_caso() {
    local nome=$1 conteudo=$2 esperado=$3
    local payload="$temporario/payload-ord-$nome.json" obtido
    cp "$payloads/verde.json" "$payload"

    rm -f "$config/settings.json"
    [ -n "$conteudo" ] && printf '%s\n' "$conteudo" > "$config/settings.json"

    # Which segments rendered, by name, in order
    obtido=$(bash "$shell" < "$payload" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g' \
        | awk -F'  │  ' '{for (i=1; i<=NF; i++) {
              if ($i ~ /^ctx /)          printf "%sctx", (i>1?",":"");
              else if ($i ~ /^5h /)      printf "%s5h", (i>1?",":"");
              else if ($i ~ /^week /)    printf "%sweek", (i>1?",":"");
              else if ($i ~ /^session /) printf "%ssession", (i>1?",":"");
              else                       printf "%smodel", (i>1?",":"");
          }}')
    if [ "$obtido" != "$esperado" ]; then
        echo "FALHA  ordem/$nome — expected '$esperado', got '$obtido'" >&2
        falhas=$((falhas + 1))
        return
    fi
    comparar "ordem/$nome" "$payload"
}

# verde.json has no workspace, so `branch` never renders here; `update` is off.
ordem_caso "default"     ""                                              "model,ctx,5h,week,session"
ordem_caso "reordered" '{"ccsl":{"order":["session","ctx","model"]}}'  "session,ctx,model"
ordem_caso "no-week"   '{"ccsl":{"order":["model","ctx","5h","session"]}}' "model,ctx,5h,session"
ordem_caso "ctx-only"     '{"ccsl":{"order":["ctx"]}}'                    "ctx"
ordem_caso "bad-name" '{"ccsl":{"order":["ctx","banana","5h"]}}'      "ctx,5h"
ordem_caso "empty-list" '{"ccsl":{"order":[]}}'                        "model,ctx,5h,week,session"
ordem_caso "not-string" '{"ccsl":{"order":[1,true,"ctx"]}}'             "ctx"
ordem_caso "bad-json" '{ this is not json'                             "model,ctx,5h,week,session"
ordem_caso "no-ccsl"   '{"statusLine":{"type":"command"}}'             "model,ctx,5h,week,session"
rm -f "$config/settings.json"

# ---------------------------------------------------------------------------
# 6. Comma-decimal locale
# ---------------------------------------------------------------------------
# JSON numbers use a dot. Under pt_BR, awk read 12.3456 as 12 and bash's printf
# rejected 84.7, so the bar showed "$12,00" and "0%" (issue #27). Fractional
# percentages on purpose: the reference payloads are all integers, which is why
# this went unnoticed. The C render is the reference.
fracionado="$temporario/payload-fracionado.json"
jq '.context_window.used_percentage = 64.6
    | .rate_limits.five_hour.used_percentage = 84.7
    | .rate_limits.seven_day.used_percentage = 59.6
    | .cost.total_cost_usd = 12.3456' "$payloads/verde.json" > "$fracionado"

referencia=$(LC_ALL=C bash "$shell" < "$fracionado" 2>&1)
case $referencia in
    *'session $12.35'*) ;;
    *) echo "FALHA  locale/C — expected 'session \$12.35', got: $referencia" >&2
       falhas=$((falhas + 1)) ;;
esac

testados=0
for loc in pt_BR.UTF-8 de_DE.UTF-8; do
    # A locale that is not installed silently falls back to C and would pass
    # without testing anything: only count it when it really uses a comma.
    # Fresh bash with a clean env: bash 3.2 ignores a temporary LC_ALL on a
    # builtin, and an inherited LANG would mask a missing locale.
    [ "$(env -i LC_ALL="$loc" bash -c 'printf "%.1f" 1' 2>/dev/null)" = "1,0" ] || continue
    testados=$((testados + 1))
    for via in LC_ALL LANG; do
        # stderr included: a "printf: invalid number" is a failure even if
        # the bar still came out
        obtido=$(env -u LC_ALL -u LC_NUMERIC "$via=$loc" bash "$shell" < "$fracionado" 2>&1)
        if [ "$obtido" = "$referencia" ]; then
            echo "ok     locale/$loc via $via — igual ao C"
        else
            echo "FALHA  locale/$loc via $via — diverge do C:" >&2
            printf '  C  : %q\n  %s: %q\n' "$referencia" "$loc" "$obtido" >&2
            falhas=$((falhas + 1))
        fi
    done
done
[ "$testados" -gt 0 ] || echo "aviso  locale — no comma-decimal locale installed, case skipped"

# ---------------------------------------------------------------------------
# 7. Wrapping to the terminal width
# ---------------------------------------------------------------------------
# Visible width, measured the way statusline-command.sh measures it.
#
# Not awk: `length()` counts bytes in the awk macOS ships, and characters in
# gawk — a 57-column line reports 60 there and the assertion below lied on every
# Mac. Folding the glyphs to ASCII is byte-safe in either.
shopt -s extglob
LV=0
largura_visivel() {
    local s=${1//$'\033'\[*([0-9;])m/}
    s=${s//█/#}; s=${s//░/#}; s=${s//│/#}
    s=${s//↑/#}; s=${s//·/#}
    LV=${#s}
}

largura_caso() {
    local nome=$1 cols=$2
    # Same trap as branch_caso: inside one `local`, bash creates every name
    # before running the assignments, so "$nome" would still be unset here.
    local payload="$temporario/payload-larg-$nome.json"
    local saida_sh saida_ps maior linhas
    jq --arg d "$temporario/comum" '. + {workspace: {current_dir: $d}}' \
        "$payloads/verde.json" > "$payload"

    saida_sh=$(COLUMNS=$cols bash "$shell" < "$payload" 2>/dev/null)
    linhas=$(printf '%s' "$saida_sh" | grep -c '')

    # No line may exceed the width — unless it holds a single segment, which
    # cannot be split without cutting content. A segment wider than the terminal
    # gets its own line and overflows, on purpose.
    maior=0
    local l
    while IFS= read -r l; do
        case $l in
            *"  │  "*) ;;            # more than one segment: must fit
            *) continue ;;           # a lone segment is allowed to overflow
        esac
        largura_visivel "$l"
        [ "$LV" -gt "$maior" ] && maior=$LV
    done <<< "$saida_sh"

    if [ "$cols" -gt 0 ] && [ "$maior" -gt "$cols" ]; then
        echo "FALHA  largura/$nome — line of $maior columns, with more than one segment, at COLUMNS=$cols" >&2
        falhas=$((falhas + 1))
        return
    fi
    if ! printf '%s' "$saida_sh" | grep -q 'session \$'; then
        echo "FALHA  largura/$nome — the session segment vanished in the wrap" >&2
        falhas=$((falhas + 1))
        return
    fi

    if [ "$tem_pwsh" = 0 ]; then
        echo "ok     largura/$nome — $linhas line(s), nothing overflowed (PowerShell skipped)"
        return
    fi
    saida_ps=$(COLUMNS=$cols pwsh -NoProfile -File "$ps1" < "$payload" 2>/dev/null)
    if [ "$saida_sh" = "$saida_ps" ]; then
        echo "ok     largura/$nome — $linhas linha(s), both implementations agree"
    else
        echo "FALHA  largura/$nome — outputs differ com COLUMNS=$cols" >&2
        printf '  sh : %q\n  ps1: %q\n' "$saida_sh" "$saida_ps" >&2
        falhas=$((falhas + 1))
    fi
}

largura_caso "no-columns" 0
largura_caso "30"          30
largura_caso "60"          60
largura_caso "80"          80
largura_caso "120"         120
largura_caso "999"         999

# COLUMNS com lixo não pode quebrar nada
lixo="$temporario/payload-larg-lixo.json"
cp "$payloads/verde.json" "$lixo"
if [ "$(COLUMNS=abc bash "$shell" < "$lixo" 2>/dev/null | grep -c '')" = "1" ]; then
    echo "ok     largura/columns-invalido — one line, no wrapping"
else
    echo "FALHA  largura/columns-invalido — a non-numeric COLUMNS changed the output" >&2
    falhas=$((falhas + 1))
fi

# ---------------------------------------------------------------------------
# 8. The branch icon, lido do settings.json
# ---------------------------------------------------------------------------
# `git` by default; `ccsl.branch_icon` replaces it (issue #35). The icons are
# built with printf because bash 3.2 has no \u in $'...'.
PUA=$(printf '\356\202\240')          # U+E0A0, the Powerline branch glyph
EMOJI=$(printf '\360\237\214\277')   # U+1F33F, outside the BMP: two columns

com_branch="$temporario/payload-icone.json"
jq --arg d "$temporario/comum" '. + {workspace: {current_dir: $d}}' "$payloads/verde.json" > "$com_branch"

icone_caso() {
    local nome=$1 conteudo=$2 esperado=$3 obtido
    rm -f "$config/settings.json"
    [ -n "$conteudo" ] && printf '%s\n' "$conteudo" > "$config/settings.json"

    obtido=$(bash "$shell" < "$com_branch" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g')
    obtido=${obtido%%  │  *}
    if [ "$obtido" != "$esperado" ]; then
        echo "FALHA  icone/$nome — expected '$esperado', got '$obtido'" >&2
        falhas=$((falhas + 1))
        return
    fi
    comparar "icone/$nome" "$com_branch"
}

icone_caso "default"     ""                                          "git main"
icone_caso "sem-chave"  '{"ccsl":{"order":["branch","ctx"]}}'       "git main"
icone_caso "nerd-font"  '{"ccsl":{"branch_icon":"\ue0a0"}}'         "$PUA main"
icone_caso "antigo"     '{"ccsl":{"branch_icon":"\u2387"}}'         "$(printf '\342\216\207') main"
icone_caso "emoji"      '{"ccsl":{"branch_icon":"\ud83c\udf3f"}}'   "$EMOJI main"
icone_caso "empty"      '{"ccsl":{"branch_icon":""}}'               "main"
icone_caso "numero"     '{"ccsl":{"branch_icon":42}}'               "git main"
icone_caso "null"       '{"ccsl":{"branch_icon":null}}'             "git main"
icone_caso "with-slash"  '{"ccsl":{"branch_icon":"a/b*"}}'           "a/b* main"
# Control characters and backslashes are dropped: no escape can reach the bar
icone_caso "controle"   '{"ccsl":{"branch_icon":"\u001b[31mX\\n\t"}}' "[31mXn main"
icone_caso "bad-json" '{ this is not json'                         "git main"

# The wrap must count the icon in columns, not bytes. branch + model alone:
# "<icon> main" + "  │  " + "Opus 5 (1M context)". Exactly at the limit it is
# one line; counting the icon's bytes would push it to two.
limite_caso() {
    local nome=$1 conteudo=$2 cols=$3 linhas saida_sh saida_ps
    printf '%s\n' "$conteudo" > "$config/settings.json"
    saida_sh=$(COLUMNS=$cols bash "$shell" < "$com_branch" 2>/dev/null)
    linhas=$(printf '%s' "$saida_sh" | grep -c '')
    if [ "$linhas" != 1 ]; then
        echo "FALHA  icone/$nome — $linhas linhas em COLUMNS=$cols, cabia em uma" >&2
        falhas=$((falhas + 1))
        return
    fi
    if [ "$(COLUMNS=$((cols - 1)) bash "$shell" < "$com_branch" 2>/dev/null | grep -c '')" != 2 ]; then
        echo "FALHA  icone/$nome — em COLUMNS=$((cols - 1)) devia quebrar" >&2
        falhas=$((falhas + 1))
        return
    fi
    if [ "$tem_pwsh" = 0 ]; then
        echo "ok     icone/$nome — wraps at the right boundary (PowerShell skipped)"
        return
    fi
    saida_ps=$(COLUMNS=$cols pwsh -NoProfile -File "$ps1" < "$com_branch" 2>/dev/null)
    if [ "$saida_sh" = "$saida_ps" ]; then
        echo "ok     icone/$nome — wraps at the right boundary, both implementations agree"
    else
        echo "FALHA  icone/$nome — outputs differ com COLUMNS=$cols" >&2
        printf '  sh : %q\n  ps1: %q\n' "$saida_sh" "$saida_ps" >&2
        falhas=$((falhas + 1))
    fi
}

# 1 + 5 + 5 + 19 = 30 columns (9 bytes more would be 32)
limite_caso "largura-pua"   '{"ccsl":{"order":["branch","model"],"branch_icon":"\ue0a0"}}'       30
# 2 + 5 + 5 + 19 = 31 columns
limite_caso "largura-emoji" '{"ccsl":{"order":["branch","model"],"branch_icon":"\ud83c\udf3f"}}' 31
rm -f "$config/settings.json"

if [ "$falhas" -gt 0 ]; then
    echo "$falhas failure(s)" >&2
    exit 1
fi
echo "all good"
