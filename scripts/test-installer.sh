#!/usr/bin/env bash
# Exercises install.sh against a throwaway config dir.
#
#   bash scripts/test-installer.sh
#
# Kept apart from test.sh, which compares the two implementations and needs no
# network. This one downloads, so it skips cleanly when there is none.
#
# CCSL_BRANCH selects which branch the installer pulls from; CI points it at the
# branch under test so a fix is exercised before it merges, not after.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
installer="$root/install.sh"
branch=${CCSL_BRANCH:-main}
failures=0

command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

if ! curl -fsS --max-time 10 -o /dev/null \
    "https://raw.githubusercontent.com/regisdias/claude-code-statusline/$branch/statusline-command.sh" 2>/dev/null; then
    echo "aviso  no access to raw.githubusercontent ($branch) — installer suite skipped"
    exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Run the installer with a fake HOME, so ~, $HOME and the absolute path all name
# the same file — which is the whole point of what is being tested. %DIR% in the
# settings string is replaced by the config dir, for the absolute spelling.
rodar() {
    local settings=$1 home_dir cfg
    home_dir=$(mktemp -d "$tmpdir/home_dir.XXXXXX")
    cfg="$home_dir/.claude"
    mkdir -p "$cfg"
    [ -n "$settings" ] && printf '%s\n' "${settings//%DIR%/$cfg}" > "$cfg/settings.json"
    env -u CLAUDE_CONFIG_DIR HOME="$home_dir" CCSL_BRANCH="$branch" \
        bash "$installer" 2>&1 | sed 's/\x1b\[[0-9]*m//g'
    printf '\n__DIR__%s\n' "$cfg"
}

# $1 = name, $2 = settings.json, $3 = expected (reconhece|configura|avisa)
caso() {
    local name=$1 settings=$2 expected=$3 out dir got
    out=$(rodar "$settings")
    dir=${out##*__DIR__}
    out=${out%%$'\n'__DIR__*}

    if printf '%s' "$out" | grep -q 'already pointed at the statusline'; then
        got=reconhece
    elif printf '%s' "$out" | grep -q 'a statusLine is already configured'; then
        got=avisa
    elif printf '%s' "$out" | grep -qE 'settings.json (created|updated)'; then
        got=configura
    elif printf '%s' "$out" | grep -q 'is not valid JSON'; then
        got=json-invalido
    else
        got="?"
    fi

    if [ "$got" != "$expected" ]; then
        echo "FALHA  $name — expected '$expected', got '$got'" >&2
        printf '%s\n' "$out" | sed 's/^/       /' >&2
        failures=$((failures + 1))
        return
    fi

    # Recognising our own script must not cut the run short: the version check
    # and the preview live after it, and the early exit was the real damage.
    if [ "$expected" = "reconhece" ] && ! printf '%s' "$out" | grep -q 'Preview:'; then
        echo "FALHA  $name — exited before the preview" >&2
        failures=$((failures + 1))
        return
    fi

    # Whatever happens, the installer leaves valid JSON behind — except when it
    # was handed invalid JSON and deliberately refused to touch it.
    if [ "$got" != "json-invalido" ] \
        && [ -f "$dir/settings.json" ] && ! jq empty "$dir/settings.json" 2>/dev/null; then
        echo "FALHA  $name — settings.json was left invalid" >&2
        failures=$((failures + 1))
        return
    fi
    echo "ok     $name — $got"
}

caso "sem-settings"     ""  configura
caso "sem-statusline"   '{"env":{"FOO":"bar"}}'  configura
caso "til"              '{"statusLine":{"type":"command","command":"bash ~/.claude/statusline-command.sh"}}'  reconhece
caso "home-var"         '{"statusLine":{"type":"command","command":"bash $HOME/.claude/statusline-command.sh"}}'  reconhece
# The spelling that regressed: settings.json written by hand carries the
# absolute path, and the installer was comparing it against the tilde form.
caso "path-absoluto" '{"statusLine":{"type":"command","command":"bash %DIR%/statusline-command.sh"}}'  reconhece
caso "outra-de-verdade" '{"statusLine":{"type":"command","command":"~/bin/minha-barra.sh"}}'  avisa
caso "json-quebrado"    '{ isso nao e json'  json-invalido

# ---------------------------------------------------------------------------
# --enable-update-check / --disable-update-check
# ---------------------------------------------------------------------------
upd_home=$(mktemp -d "$tmpdir/larup.XXXXXX")
upd_dir="$upd_home/.claude"
mkdir -p "$upd_dir"
printf '{"env":{"FOO":"bar"}}\n' > "$upd_dir/settings.json"
install_upd() { env -u CLAUDE_CONFIG_DIR HOME="$upd_home" CCSL_BRANCH="$branch" bash "$installer" "$@" >/dev/null 2>&1; }
install_upd
install_upd --enable-update-check
install_upd --enable-update-check   # twice: must not duplicate the hook

n=$(jq '(.hooks.SessionStart // []) | length' "$upd_dir/settings.json" 2>/dev/null)
if [ "$n" = "1" ] && [ -f "$upd_dir/.ccsl-update-check" ] \
    && [ "$(jq -r '.env.FOO' "$upd_dir/settings.json")" = "bar" ]; then
    echo "ok     update/ligar — one hook, marker created, env preserved"
else
    echo "FALHA  update/ligar — hooks=$n, marker=$([ -f "$upd_dir/.ccsl-update-check" ] && echo sim || echo nao)" >&2
    failures=$((failures + 1))
fi

install_upd --disable-update-check
if [ ! -f "$upd_dir/.ccsl-update-check" ] \
    && [ "$(jq -r '.hooks // "ausente"' "$upd_dir/settings.json")" = "ausente" ] \
    && [ "$(jq -r '.env.FOO' "$upd_dir/settings.json")" = "bar" ]; then
    echo "ok     update/desligar — marker, cache and hook removed, env intact"
else
    echo "FALHA  update/desligar — state left behind" >&2
    jq . "$upd_dir/settings.json" | sed 's/^/       /' >&2
    failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
fi
echo "all good"
