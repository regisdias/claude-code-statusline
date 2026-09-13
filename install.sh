#!/usr/bin/env bash
# claude-code-statusline installer — Linux, WSL, macOS and Git Bash.
#
#   curl -fsSL https://raw.githubusercontent.com/regisdias/claude-code-statusline/main/install.sh | bash
#
# It downloads statusline-command.sh into ~/.claude and wires it into
# ~/.claude/settings.json. Your settings file is backed up before any change,
# and an existing `statusLine` is never overwritten without asking.
#
# OPTIONAL UPDATE CHECK — off by default, because the status line makes no
# network call and writes nothing, and that is a property worth keeping:
#
#   bash install.sh --enable-update-check    # installs a SessionStart hook
#   bash install.sh --disable-update-check   # removes it, and stops all checks
set -euo pipefail

REPO="regisdias/claude-code-statusline"
RAMO="${CCSL_BRANCH:-main}"
DESTINO="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPT="$DESTINO/statusline-command.sh"
SETTINGS="$DESTINO/settings.json"
URL="https://raw.githubusercontent.com/$REPO/$RAMO/statusline-command.sh"

VERDE=$'\033[32m'; AMARELO=$'\033[33m'; VERMELHO=$'\033[31m'; RESET=$'\033[0m'
ok()    { printf '%s✓%s %s\n' "$VERDE" "$RESET" "$1"; }
aviso() { printf '%s!%s %s\n' "$AMARELO" "$RESET" "$1"; }
erro()  { printf '%s✗%s %s\n' "$VERMELHO" "$RESET" "$1" >&2; exit 1; }

MODO="instalar"
case ${1:-} in
    --enable-update-check)  MODO="ligar-update" ;;
    --disable-update-check) MODO="desligar-update" ;;
    "")                     ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
esac

MARCADOR="$DESTINO/.ccsl-update-check"
CACHE="$DESTINO/.ccsl-update-cache"
HOOK_SH="$DESTINO/ccsl-update-check.sh"
HOOK_CMD="bash ~/.claude/ccsl-update-check.sh"
COMANDO='bash ~/.claude/statusline-command.sh'
TRECHO='{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}'

command -v jq   >/dev/null 2>&1 || erro "jq not found. Linux: apt install jq · macOS: brew install jq"
command -v curl >/dev/null 2>&1 || erro "curl not found."

mkdir -p "$DESTINO"

# ---------------------------------------------------------------------------
# 0. --enable-update-check / --disable-update-check
# ---------------------------------------------------------------------------
# The check lives in a SessionStart hook, never in the status line: the bar keeps
# its promise of no network and no writes either way. The hook drops the result
# in a cache file, and the bar only reads it.
mexer_hook() {   # $1 = adicionar|remover
    [ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
    jq empty "$SETTINGS" >/dev/null 2>&1 || {
        aviso "$SETTINGS is not valid JSON — left untouched."
        return 1
    }
    cp "$SETTINGS" "$SETTINGS.bak"
    if [ "$1" = "adicionar" ]; then
        jq --arg cmd "$HOOK_CMD" '
            .hooks //= {} | .hooks.SessionStart //= []
            | if ([.hooks.SessionStart[] | select(.command == $cmd)] | length) == 0
              then .hooks.SessionStart += [{type: "command", command: $cmd}]
              else . end
        ' "$SETTINGS" > "$SETTINGS.novo"
    else
        jq --arg cmd "$HOOK_CMD" '
            if .hooks.SessionStart
            then .hooks.SessionStart |= map(select(.command != $cmd))
            else . end
            | if (.hooks.SessionStart // null) == [] then del(.hooks.SessionStart) else . end
            | if (.hooks // null) == {} then del(.hooks) else . end
        ' "$SETTINGS" > "$SETTINGS.novo"
    fi
    mv "$SETTINGS.novo" "$SETTINGS"
}

if [ "$MODO" = "ligar-update" ]; then
    curl -fsSL "https://raw.githubusercontent.com/$REPO/$RAMO/hooks/ccsl-update-check.sh" \
        -o "$HOOK_SH" || erro "could not download the hook"
    chmod +x "$HOOK_SH"
    : > "$MARCADOR"
    mexer_hook adicionar && ok "update check on (backup at $SETTINGS.bak)" \
        || aviso "hook downloaded, but add this to $SETTINGS by hand: $HOOK_CMD"
    printf '\n'
    printf 'It asks GitHub for the latest release at most once a day, at session start,\n'
    printf 'and writes only %s. Turn it off with:\n\n' "$CACHE"
    printf '  bash install.sh --disable-update-check\n'
    exit 0
fi

if [ "$MODO" = "desligar-update" ]; then
    rm -f "$MARCADOR" "$CACHE" "$HOOK_SH"
    mexer_hook remover && ok "update check off — no request will be made again" \
        || aviso "marker removed; drop the SessionStart hook from $SETTINGS by hand"
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Download
# ---------------------------------------------------------------------------
temporario=$(mktemp)
trap 'rm -f "$temporario"' EXIT
curl -fsSL "$URL" -o "$temporario" || erro "could not download $URL"
[ -s "$temporario" ] || erro "the download came back empty."
head -n1 "$temporario" | grep -q '^#!' || erro "the download does not look like a script."

mv "$temporario" "$SCRIPT"
chmod +x "$SCRIPT"
trap - EXIT
ok "statusline installed at $SCRIPT"

# ---------------------------------------------------------------------------
# 2. settings.json
# ---------------------------------------------------------------------------
if [ ! -f "$SETTINGS" ]; then
    printf '%s\n' "$TRECHO" > "$SETTINGS"
    ok "settings.json created with the statusline wired in"
else
    cp "$SETTINGS" "$SETTINGS.bak"

    if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
        aviso "$SETTINGS is not valid JSON — left untouched. Add this by hand:"
        printf '\n%s\n\n' "$TRECHO"
        exit 0
    fi

    atual=$(jq -r '.statusLine.command // ""' "$SETTINGS")
    if [ "$atual" = "$COMANDO" ]; then
        ok "settings.json already pointed at the statusline"
    elif [ -n "$atual" ]; then
        aviso "a statusLine is already configured:"
        printf '    %s\n' "$atual"
        aviso "left it alone. To switch, set $SETTINGS to:"
        printf '\n%s\n\n' "$TRECHO"
        rm -f "$SETTINGS.bak"
        exit 0
    else
        jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' \
            "$SETTINGS" > "$SETTINGS.novo" && mv "$SETTINGS.novo" "$SETTINGS"
        ok "settings.json updated (backup at $SETTINGS.bak)"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Version check
# ---------------------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
    versao=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
    if [ -n "$versao" ]; then
        minima="2.1.251"
        if [ "$(printf '%s\n%s\n' "$minima" "$versao" | sort -V | head -n1)" = "$minima" ]; then
            ok "Claude Code $versao — plan limits come through in the payload"
        else
            aviso "Claude Code $versao is older than $minima: only the context bar will show."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 4. Preview, with a payload baked in so this works offline
# ---------------------------------------------------------------------------
printf '\nPreview:\n\n  '
printf '%s' '{"model":{"display_name":"Opus 5 (1M context)"},
  "cost":{"total_cost_usd":12.3456},
  "context_window":{"used_percentage":33,"context_window_size":1000000,
                    "current_usage":{"input_tokens":330000}},
  "rate_limits":{"five_hour":{"used_percentage":41,"resets_at":'"$(( $(date +%s) + 7200 ))"'},
                 "seven_day":{"used_percentage":11,"resets_at":'"$(( $(date +%s) + 259200 ))"'}}}' \
    | bash "$SCRIPT" || true
printf '\n\n'
ok "done — the bar shows up on the next render, no restart needed."
