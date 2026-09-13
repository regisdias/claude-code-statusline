#!/usr/bin/env bash
# Exercises install.sh against a throwaway config dir.
#
#   bash scripts/testar-instalador.sh
#
# Kept apart from testar.sh, which compares the two implementations and needs no
# network. This one downloads, so it skips cleanly when there is none.
#
# CCSL_BRANCH selects which branch the installer pulls from; CI points it at the
# branch under test so a fix is exercised before it merges, not after.
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
instalador="$raiz/install.sh"
ramo=${CCSL_BRANCH:-main}
falhas=0

command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

if ! curl -fsS --max-time 10 -o /dev/null \
    "https://raw.githubusercontent.com/regisdias/claude-code-statusline/$ramo/statusline-command.sh" 2>/dev/null; then
    echo "aviso  no access to raw.githubusercontent ($ramo) — installer suite skipped"
    exit 0
fi

temporario=$(mktemp -d)
trap 'rm -rf "$temporario"' EXIT

# Run the installer with a fake HOME, so ~, $HOME and the absolute path all name
# the same file — which is the whole point of what is being tested. %DIR% in the
# settings string is replaced by the config dir, for the absolute spelling.
rodar() {
    local settings=$1 lar cfg
    lar=$(mktemp -d "$temporario/lar.XXXXXX")
    cfg="$lar/.claude"
    mkdir -p "$cfg"
    [ -n "$settings" ] && printf '%s\n' "${settings//%DIR%/$cfg}" > "$cfg/settings.json"
    env -u CLAUDE_CONFIG_DIR HOME="$lar" CCSL_BRANCH="$ramo" \
        bash "$instalador" 2>&1 | sed 's/\x1b\[[0-9]*m//g'
    printf '\n__DIR__%s\n' "$cfg"
}

# $1 = nome, $2 = settings.json, $3 = esperado (reconhece|configura|avisa)
caso() {
    local nome=$1 settings=$2 esperado=$3 saida dir obtido
    saida=$(rodar "$settings")
    dir=${saida##*__DIR__}
    saida=${saida%%$'\n'__DIR__*}

    if printf '%s' "$saida" | grep -q 'already pointed at the statusline'; then
        obtido=reconhece
    elif printf '%s' "$saida" | grep -q 'a statusLine is already configured'; then
        obtido=avisa
    elif printf '%s' "$saida" | grep -qE 'settings.json (created|updated)'; then
        obtido=configura
    elif printf '%s' "$saida" | grep -q 'is not valid JSON'; then
        obtido=json-invalido
    else
        obtido="?"
    fi

    if [ "$obtido" != "$esperado" ]; then
        echo "FALHA  $nome — expected '$esperado', got '$obtido'" >&2
        printf '%s\n' "$saida" | sed 's/^/       /' >&2
        falhas=$((falhas + 1))
        return
    fi

    # Recognising our own script must not cut the run short: the version check
    # and the preview live after it, and the early exit was the real damage.
    if [ "$esperado" = "reconhece" ] && ! printf '%s' "$saida" | grep -q 'Preview:'; then
        echo "FALHA  $nome — exited before the preview" >&2
        falhas=$((falhas + 1))
        return
    fi

    # Whatever happens, the installer leaves valid JSON behind — except when it
    # was handed invalid JSON and deliberately refused to touch it.
    if [ "$obtido" != "json-invalido" ] \
        && [ -f "$dir/settings.json" ] && ! jq empty "$dir/settings.json" 2>/dev/null; then
        echo "FALHA  $nome — settings.json was left invalid" >&2
        falhas=$((falhas + 1))
        return
    fi
    echo "ok     $nome — $obtido"
}

caso "sem-settings"     ""  configura
caso "sem-statusline"   '{"env":{"FOO":"bar"}}'  configura
caso "til"              '{"statusLine":{"type":"command","command":"bash ~/.claude/statusline-command.sh"}}'  reconhece
caso "home-var"         '{"statusLine":{"type":"command","command":"bash $HOME/.claude/statusline-command.sh"}}'  reconhece
# The spelling that regressed: settings.json written by hand carries the
# absolute path, and the installer was comparing it against the tilde form.
caso "caminho-absoluto" '{"statusLine":{"type":"command","command":"bash %DIR%/statusline-command.sh"}}'  reconhece
caso "outra-de-verdade" '{"statusLine":{"type":"command","command":"~/bin/minha-barra.sh"}}'  avisa
caso "json-quebrado"    '{ isso nao e json'  json-invalido

# ---------------------------------------------------------------------------
# --enable-update-check / --disable-update-check
# ---------------------------------------------------------------------------
lar_up=$(mktemp -d "$temporario/larup.XXXXXX")
dir_up="$lar_up/.claude"
mkdir -p "$dir_up"
printf '{"env":{"FOO":"bar"}}\n' > "$dir_up/settings.json"
instalar_up() { env -u CLAUDE_CONFIG_DIR HOME="$lar_up" CCSL_BRANCH="$ramo" bash "$instalador" "$@" >/dev/null 2>&1; }
instalar_up
instalar_up --enable-update-check
instalar_up --enable-update-check   # twice: must not duplicate the hook

n=$(jq '(.hooks.SessionStart // []) | length' "$dir_up/settings.json" 2>/dev/null)
if [ "$n" = "1" ] && [ -f "$dir_up/.ccsl-update-check" ] \
    && [ "$(jq -r '.env.FOO' "$dir_up/settings.json")" = "bar" ]; then
    echo "ok     update/ligar — one hook, marker created, env preserved"
else
    echo "FALHA  update/ligar — hooks=$n, marker=$([ -f "$dir_up/.ccsl-update-check" ] && echo sim || echo nao)" >&2
    falhas=$((falhas + 1))
fi

instalar_up --disable-update-check
if [ ! -f "$dir_up/.ccsl-update-check" ] \
    && [ "$(jq -r '.hooks // "ausente"' "$dir_up/settings.json")" = "ausente" ] \
    && [ "$(jq -r '.env.FOO' "$dir_up/settings.json")" = "bar" ]; then
    echo "ok     update/desligar — marker, cache and hook removed, env intact"
else
    echo "FALHA  update/desligar — state left behind" >&2
    jq . "$dir_up/settings.json" | sed 's/^/       /' >&2
    falhas=$((falhas + 1))
fi

if [ "$falhas" -gt 0 ]; then
    echo "$falhas failure(s)" >&2
    exit 1
fi
echo "all good"
