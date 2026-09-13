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
#   bash ~/.claude/ccsl-install.sh --enable-update-check
#   bash ~/.claude/ccsl-install.sh --disable-update-check
#
# WHICH SEGMENTS, AND IN WHAT ORDER
#
#   bash ~/.claude/ccsl-install.sh --configure
#
# A normal install keeps a copy of this script at ~/.claude/ccsl-install.sh, so
# those flags are one command away afterwards.
set -euo pipefail

REPO="regisdias/claude-code-statusline"
BRANCH="${CCSL_BRANCH:-main}"
TARGET="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPT="$TARGET/statusline-command.sh"
SETTINGS="$TARGET/settings.json"
URL="https://raw.githubusercontent.com/$REPO/$BRANCH/statusline-command.sh"

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
ok()    { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }

MODE="install"
case ${1:-} in
    --enable-update-check)  MODE="enable-update" ;;
    --disable-update-check) MODE="disable-update" ;;
    --configure)            MODE="configure" ;;
    "")                     ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
esac

SELF="$TARGET/ccsl-install.sh"
SEGMENTS="branch model ctx 5h week session update"

MARKER="$TARGET/.ccsl-update-check"
CACHE="$TARGET/.ccsl-update-cache"
HOOK_SH="$TARGET/ccsl-update-check.sh"
HOOK_CMD="bash ~/.claude/ccsl-update-check.sh"
SNIPPET='{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}'

# Does this command already point at the status line we just installed?
#
# Compare the resolved path, not the string. settings.json written by hand — or
# copied from the manual-install section and then expanded — spells the path
# absolutely, while the command we write uses `~`. They are the same file, and
# treating them as different told people their own status line was a stranger's,
# then exited early and skipped the version check and the preview.
is_our_script() {
    local cmd=$1 token
    for token in $cmd; do
        case $token in
            *statusline-command.sh|*statusline-command.ps1)
                token=${token/#\~\//$HOME/}
                token=${token//\$HOME/$HOME}
                [ "$token" = "$SCRIPT" ] && return 0
                ;;
        esac
    done
    return 1
}

command -v jq   >/dev/null 2>&1 || fail "jq not found. Linux: apt install jq · macOS: brew install jq"
command -v curl >/dev/null 2>&1 || fail "curl not found."

mkdir -p "$TARGET"

# ---------------------------------------------------------------------------
# 0. --enable-update-check / --disable-update-check
# ---------------------------------------------------------------------------
# The check lives in a SessionStart hook, never in the status line: the bar keeps
# its promise of no network and no writes either way. The hook drops the result
# in a cache file, and the bar only reads it.
edit_hook() {   # $1 = add|remove
    [ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
    jq empty "$SETTINGS" >/dev/null 2>&1 || {
        warn "$SETTINGS is not valid JSON — left untouched."
        return 1
    }
    cp "$SETTINGS" "$SETTINGS.bak"
    if [ "$1" = "add" ]; then
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

# ---------------------------------------------------------------------------
# --configure: which segments, and in what order
# ---------------------------------------------------------------------------
# The menu and the preview are rendered by the installed status line itself, not
# by strings kept in here — so what you approve is what you will get.
configure() {
    local script="$SCRIPT"
    [ -x "$script" ] || fail "install the status line first: no $script"

    # Global, not local: the EXIT trap runs after this function has returned
    WORKSHOP=$(mktemp -d) || fail "could not create a temp dir"
    trap 'rm -rf "$WORKSHOP"' EXIT

    local repo cfg payload
    repo="$WORKSHOP/repo"; cfg="$WORKSHOP/cfg"
    mkdir -p "$repo/.git" "$cfg"
    printf 'ref: refs/heads/main\n' > "$repo/.git/HEAD"
    # So the `update` segment has something to show in the menu
    : > "$cfg/.ccsl-update-check"
    printf '0 9.9.9\n' > "$cfg/.ccsl-update-cache"

    payload=$(printf '{"model":{"display_name":"Opus 5 (1M context)"},
      "cost":{"total_cost_usd":12.3456},
      "workspace":{"current_dir":"%s"},
      "context_window":{"used_percentage":33,"context_window_size":1000000,
                        "current_usage":{"input_tokens":330000}},
      "rate_limits":{"five_hour":{"used_percentage":41,"resets_at":%s},
                     "seven_day":{"used_percentage":11,"resets_at":%s}}}' \
        "$repo" "$(( $(date +%s) + 7200 ))" "$(( $(date +%s) + 259200 ))")

    # The person's own branch icon, if they set one, so the preview shows their
    # branch segment and not the default `git` label
    local extra
    extra=$(jq -c '.ccsl | if type == "object" and has("branch_icon")
                           then {branch_icon} else {} end' "$SETTINGS" 2>/dev/null) || true
    [ -n "$extra" ] || extra='{}'

    render() {   # $1 = comma-separated order
        jq -nc --arg o "$1" --argjson extra "$extra" \
            '{ccsl: ({order: ($o | split(","))} + $extra)}' > "$cfg/settings.json"
        printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$cfg" bash "$script"
    }

    local current
    # `|| true`: under set -e a missing or broken settings.json would end the
    # script right here, silently, instead of falling back to the default order
    current=$(jq -r '(.ccsl.order // []) | join(",")' "$SETTINGS" 2>/dev/null) || true
    [ -n "$current" ] || current=$(printf '%s' "$SEGMENTS" | tr ' ' ',')

    printf '\nSegments, as your status line renders them:\n\n'
    local i=1 name
    for name in $SEGMENTS; do
        printf '  %d  %-8s %s\n' "$i" "$name" "$(render "$name")"
        i=$((i + 1))
    done

    printf '\nCurrent order: %s\n' "$current"
    printf '\nType the numbers you want, in the order you want them.\n'
    printf 'Leave any out to hide it. Empty line keeps what you have.\n> '

    # Read from the terminal when there is one, so this works even when the
    # installer arrived through `curl | bash` and stdin is the script itself.
    # Falls back to stdin, which also makes the whole thing scriptable.
    local input_fd=0
    # Braces on purpose: without them the shell prints its own error before
    # the redirection to /dev/null takes effect.
    if { exec 3</dev/tty; } 2>/dev/null; then input_fd=3; fi

    local answer
    read -r answer <&$input_fd || answer=""
    [ -n "$answer" ] || { ok "nothing changed"; return 0; }

    local new_order="" n
    for n in $answer; do
        case $n in
            ''|*[!0-9]*) fail "not a number: $n" ;;
        esac
        name=$(printf '%s' "$SEGMENTS" | cut -d' ' -f"$n")
        [ -n "$name" ] || fail "there is no segment $n"
        new_order="${new_order:+$new_order,}$name"
    done

    printf '\nIt would look like this:\n\n  %s\n\n' "$(render "$new_order")"
    printf 'Save? [Y/n] '
    read -r answer <&$input_fd || answer=""
    case $answer in
        [Nn]*) ok "left alone"; return 0 ;;
    esac

    [ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
    jq empty "$SETTINGS" >/dev/null 2>&1 || fail "$SETTINGS is not valid JSON"
    cp "$SETTINGS" "$SETTINGS.bak"
    jq --arg o "$new_order" '.ccsl.order = ($o | split(","))' "$SETTINGS" > "$SETTINGS.novo" \
        && mv "$SETTINGS.novo" "$SETTINGS"
    ok "saved to $SETTINGS (backup at $SETTINGS.bak)"
    printf '  the bar picks it up on the next render, no restart needed\n'
}

if [ "$MODE" = "configure" ]; then
    configure
    exit $?
fi

if [ "$MODE" = "enable-update" ]; then
    curl -fsSL "https://raw.githubusercontent.com/$REPO/$BRANCH/hooks/ccsl-update-check.sh" \
        -o "$HOOK_SH" || fail "could not download the hook"
    chmod +x "$HOOK_SH"
    : > "$MARKER"
    edit_hook add && ok "update check on (backup at $SETTINGS.bak)" \
        || warn "hook downloaded, but add this to $SETTINGS by hand: $HOOK_CMD"
    printf '\n'
    printf 'It asks GitHub for the latest release at most once a day, at session start,\n'
    printf 'and writes only %s. Turn it off with:\n\n' "$CACHE"
    printf '  bash install.sh --disable-update-check\n'
    exit 0
fi

if [ "$MODE" = "disable-update" ]; then
    rm -f "$MARKER" "$CACHE" "$HOOK_SH"
    edit_hook remove && ok "update check off — no request will be made again" \
        || warn "marker removed; drop the SessionStart hook from $SETTINGS by hand"
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Download
# ---------------------------------------------------------------------------
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
curl -fsSL "$URL" -o "$tmpfile" || fail "could not download $URL"
[ -s "$tmpfile" ] || fail "the download came back empty."
head -n1 "$tmpfile" | grep -q '^#!' || fail "the download does not look like a script."

mv "$tmpfile" "$SCRIPT"
chmod +x "$SCRIPT"
trap - EXIT
ok "statusline installed at $SCRIPT"

# Keep a copy of this installer, so --configure and the update flags are one
# command away later instead of another curl
curl -fsSL "https://raw.githubusercontent.com/$REPO/$BRANCH/install.sh" -o "$SELF" 2>/dev/null \
    && chmod +x "$SELF" \
    && ok "installer kept at $SELF (--configure, --enable-update-check)"

# ---------------------------------------------------------------------------
# 2. settings.json
# ---------------------------------------------------------------------------
if [ ! -f "$SETTINGS" ]; then
    printf '%s\n' "$SNIPPET" > "$SETTINGS"
    ok "settings.json created with the statusline wired in"
else
    cp "$SETTINGS" "$SETTINGS.bak"

    if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
        warn "$SETTINGS is not valid JSON — left untouched. Add this by hand:"
        printf '\n%s\n\n' "$SNIPPET"
        exit 0
    fi

    current=$(jq -r '.statusLine.command // ""' "$SETTINGS")
    if is_our_script "$current"; then
        ok "settings.json already pointed at the statusline"
    elif [ -n "$current" ]; then
        warn "a statusLine is already configured:"
        printf '    %s\n' "$current"
        warn "left it alone. To switch, set $SETTINGS to:"
        printf '\n%s\n\n' "$SNIPPET"
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
    version=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
    if [ -n "$version" ]; then
        minimum="2.1.251"
        if [ "$(printf '%s\n%s\n' "$minimum" "$version" | sort -V | head -n1)" = "$minimum" ]; then
            ok "Claude Code $version — plan limits come through in the payload"
        else
            warn "Claude Code $version is older than $minimum: only the context bar will show."
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
