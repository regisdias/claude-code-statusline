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
INSTALLER="https://raw.githubusercontent.com/$REPO/main/install.sh"
INTERVAL=$((24 * 3600))

base=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
[ -f "$base/.ccsl-update-check" ] || exit 0

cache="$base/.ccsl-update-cache"
script="$base/statusline-command.sh"
[ -r "$script" ] || exit 0

# The installed version is whatever the installed script says it is
installed=""
while IFS= read -r line; do
    case $line in
        CCSL_VERSION=*)
            installed=${line#CCSL_VERSION=}
            installed=${installed//\"/}
            break
            ;;
    esac
done < "$script"
[ -n "$installed" ] || exit 0

now=$(date +%s)
latest=""
when=0
if [ -r "$cache" ]; then
    read -r when latest < "$cache" 2>/dev/null
    case ${when:-x} in ''|*[!0-9]*) when=0 ;; esac
fi

# Only reach out when the cache is stale
if [ $((now - when)) -ge "$INTERVAL" ]; then
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        response=$(curl -fsS --max-time 3 \
            "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null) || response=""
        if [ -n "$response" ]; then
            newer=$(printf '%s' "$response" | jq -r '.tag_name // empty' 2>/dev/null)
            newer=${newer#v}
            if [[ $newer =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                latest=$newer
                printf '%s %s\n' "$now" "$latest" > "$cache" 2>/dev/null || true
            fi
        fi
    fi
fi

[ -n "${latest:-}" ] || exit 0
[[ $latest =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 0

as_number() {
    local v=$1 a b c
    a=${v%%.*}; v=${v#*.}
    b=${v%%.*}; v=${v#*.}
    c=${v%%.*}
    printf '%d' $(( 10#$a * 1000000 + 10#$b * 1000 + 10#$c ))
}

if [ "$(as_number "$latest")" -gt "$(as_number "$installed")" ]; then
    printf 'claude-code-statusline %s is available (you have %s)\n' "$latest" "$installed"
    printf '  curl -fsSL %s | bash\n' "$INSTALLER"
fi
exit 0
