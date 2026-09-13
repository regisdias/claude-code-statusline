#!/usr/bin/env bash
# SessionStart hook: tells you when a newer claude-code-statusline is out.
#
# Off unless <config>/.ccsl-update-check exists. Enable and disable with:
#
#   bash install.sh --enable-update-check
#   bash install.sh --disable-update-check
#
# This is the only part of the project that touches the network, and it is the
# reason the status line itself does not have to: it writes the result to
# <config>/.ccsl-update-cache, and the bar only ever reads that file.
#
# At most one request per 24 h, with a 3 s timeout. A failed or slow request
# leaves the previous cache alone and prints nothing — never a stack trace at
# the top of your session.
set -uo pipefail

REPO="regisdias/claude-code-statusline"
INSTALADOR="https://raw.githubusercontent.com/$REPO/main/install.sh"
INTERVALO=$((24 * 3600))

base=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
[ -f "$base/.ccsl-update-check" ] || exit 0

cache="$base/.ccsl-update-cache"
script="$base/statusline-command.sh"
[ -r "$script" ] || exit 0

# The installed version is whatever the installed script says it is
instalada=""
while IFS= read -r linha; do
    case $linha in
        CCSL_VERSION=*)
            instalada=${linha#CCSL_VERSION=}
            instalada=${instalada//\"/}
            break
            ;;
    esac
done < "$script"
[ -n "$instalada" ] || exit 0

agora=$(date +%s)
ultima=""
quando=0
if [ -r "$cache" ]; then
    read -r quando ultima < "$cache" 2>/dev/null
    case ${quando:-x} in ''|*[!0-9]*) quando=0 ;; esac
fi

# Only reach out when the cache is stale
if [ $((agora - quando)) -ge "$INTERVALO" ]; then
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        resposta=$(curl -fsS --max-time 3 \
            "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null) || resposta=""
        if [ -n "$resposta" ]; then
            nova=$(printf '%s' "$resposta" | jq -r '.tag_name // empty' 2>/dev/null)
            nova=${nova#v}
            if [[ $nova =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                ultima=$nova
                printf '%s %s\n' "$agora" "$ultima" > "$cache" 2>/dev/null || true
            fi
        fi
    fi
fi

[ -n "${ultima:-}" ] || exit 0
[[ $ultima =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 0

num() {
    local v=$1 a b c
    a=${v%%.*}; v=${v#*.}
    b=${v%%.*}; v=${v#*.}
    c=${v%%.*}
    printf '%d' $(( 10#$a * 1000000 + 10#$b * 1000 + 10#$c ))
}

if [ "$(num "$ultima")" -gt "$(num "$instalada")" ]; then
    printf 'claude-code-statusline %s is available (you have %s)\n' "$ultima" "$instalada"
    printf '  curl -fsSL %s | bash\n' "$INSTALADOR"
fi
exit 0
