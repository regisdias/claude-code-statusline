#!/usr/bin/env bash
# Claude Code statusline: context window + plan limits (5-hour block and week).
#
# The plan limits come from the payload Claude Code sends to the statusline (`rate_limits`),
# the same numbers you see in /usage. No estimation involved: it is what the server reports.
#
# INSTALL
#   1. Requires `jq` (Linux: apt install jq · macOS: brew install jq · Windows: winget install jqlang.jq)
#      and Claude Code 2.1.251 or newer (`claude --version`).
#   2. Save this file as ~/.claude/statusline-command.sh
#   3. chmod +x ~/.claude/statusline-command.sh
#   4. Add to ~/.claude/settings.json:
#
#        "statusLine": {
#          "type": "command",
#          "command": "bash ~/.claude/statusline-command.sh"
#        }
#
#   5. The bar shows up on the next render. No restart needed.
#
# HOW TO READ IT
#   Which segments appear, and in what order, comes from settings.json:
#
#        "ccsl": { "order": ["branch", "model", "ctx", "5h", "week", "session", "update"] }
#
#   Leave a name out and it does not render. `install.sh --configure` edits this.
#
#   ⎇ <branch> → current git branch, when the session is inside a repository
#   ctx      → how much of this conversation's context window is used (not a plan quota)
#   5h       → 5-hour block of your plan, with the time it resets
#   week     → weekly plan limit
#   session  → cost of this conversation, in USD
#   Colors: green up to 60%, yellow up to 85%, red above that.

# Bumped in the same commit that stamps the version in CHANGELOG.md; CI checks
# that this, the .ps1 and the CHANGELOG agree.
CCSL_VERSION="1.4.1"

# Numbers in the payload always use a dot. awk and bash's builtin printf read and
# write them by LC_NUMERIC, so under pt_BR or de_DE awk took 12.3456 for 12 and
# printf rejected 84.7 outright — a $12,00 cost and a 0% plan limit. LC_ALL, not
# LC_NUMERIC: a user's own LC_ALL would override the narrower one. Nothing here
# depends on the character locale; the glyphs pass through as bytes.
export LC_ALL=C

input=$(cat)

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# Color by percentage (0-100)
pick_color() {
    local pct_int
    pct_int=$(echo "$1" | awk '{printf "%d", $1}')
    if [ "$pct_int" -ge 85 ]; then
        printf "%s" "$RED"
    elif [ "$pct_int" -ge 60 ]; then
        printf "%s" "$YELLOW"
    else
        printf "%s" "$GREEN"
    fi
}

# Progress bar of N blocks (█ / ░)
#
# No `seq` here on purpose. BSD seq (macOS) infers direction from the operands,
# so `seq 1 0` prints "1 0" where GNU seq prints nothing — a full bar came out
# 12 blocks wide on a Mac and 10 on Linux. Padding with printf and substituting
# the spaces has no such edge case, and saves two subprocesses per render.
make_bar() {
    local pct=$1
    local width=${2:-10}
    local filled empty cheio vazio
    filled=$(echo "$pct $width" | awk '{printf "%d", ($1/100)*$2 + 0.5}')
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0
    empty=$((width - filled))
    cheio=$(printf "%${filled}s" "")
    vazio=$(printf "%${empty}s" "")
    printf "%s%s" "${cheio// /█}" "${vazio// /░}"
}

# Current git branch, read straight from .git/HEAD.
#
# Claude Code does not send the branch in the payload (`worktree.branch` exists only
# inside a worktree session), and the documented way is `git branch --show-current`.
# That is an exec of git on every render — measured at ~1.35 ms here and much worse on
# Windows. The branch is plain text in .git/HEAD, and walking up to find it is just
# parameter expansion, so this costs ~0.1 ms and spawns nothing.
#
# Sets BRANCH instead of printing: a command substitution would fork, which is the one
# thing this function exists to avoid.
BRANCH=""
achar_branch() {
    local dir=$1 marca head cabeca gitdir
    [ -n "$dir" ] && [ "$dir" != "-" ] || return
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
        marca="$dir/.git"
        head=""
        if [ -d "$marca" ]; then
            head="$marca/HEAD"
        elif [ -f "$marca" ]; then
            # Worktree or submodule: ".git" is a file holding "gitdir: <path>"
            # `read` returns non-zero on a file with no trailing newline but still
            # fills the variable, so check the content instead of the exit code —
            # PowerShell's ReadAllLines has no such quirk, and the two must agree.
            read -r gitdir < "$marca"
            gitdir=${gitdir%$'\r'}
            [ -n "$gitdir" ] || return
            case $gitdir in
                "gitdir: "*) gitdir=${gitdir#gitdir: } ;;
                *) return ;;
            esac
            case $gitdir in /*) ;; *) gitdir="$dir/$gitdir" ;; esac
            head="$gitdir/HEAD"
        else
            dir=${dir%/*}
            continue
        fi

        [ -r "$head" ] || return
        read -r cabeca < "$head"
        cabeca=${cabeca%$'\r'}   # .git/HEAD written on Windows carries a CR
        [ -n "$cabeca" ] || return
        case $cabeca in
            "ref: "*)
                cabeca=${cabeca#ref: }
                BRANCH=${cabeca#refs/heads/}
                ;;
            *) BRANCH=${cabeca:0:7} ;;   # detached HEAD: short sha
        esac
        return
    done
}

# Format epoch: `date -d` is GNU (Linux, WSL, Git Bash); `date -r` is BSD (macOS)
fmt_epoch() {
    date -d "@$1" "+$2" 2>/dev/null || date -r "$1" "+$2" 2>/dev/null
}

# Epoch → "06:20" when it is today, "18/09 05:00" otherwise
hora_reset() {
    [ "$1" = "-" ] && return
    if [ "$(fmt_epoch "$1" %F)" = "$(date +%F)" ]; then
        fmt_epoch "$1" %H:%M
    else
        fmt_epoch "$1" '%d/%m %H:%M'
    fi
}

ORDEM_PADRAO="branch,model,ctx,5h,week,session,update"

# One jq call reads both the payload (stdin) and settings.json (--slurpfile), so
# the configuration costs no extra process on the render path.
# The default lives inside the query: `read` with IFS=tab treats tab as
# whitespace, so an empty leading field would collapse and shift every other
# field left. This one can never be empty.
CONSULTA='[
    ($cfg[0].ccsl.order // [] | map(select(type == "string")) | join(",")
        | if . == "" then "branch,model,ctx,5h,week,session,update" else . end),
    (.model.display_name // "Claude"),
    (.context_window.used_percentage // "-"),
    (.context_window.context_window_size // "-"),
    (.context_window.current_usage.input_tokens // "-"),
    (.rate_limits.five_hour.used_percentage // "-"),
    (.rate_limits.five_hour.resets_at // "-"),
    (.rate_limits.seven_day.used_percentage // "-"),
    (.rate_limits.seven_day.resets_at // "-"),
    (.cost.total_cost_usd // "-"),
    (.workspace.current_dir // .cwd // "-")
] | @tsv'

settings_json="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
[ -r "$settings_json" ] || settings_json=/dev/null

lido=$(printf '%s' "$input" | jq -r --slurpfile cfg "$settings_json" "$CONSULTA" 2>/dev/null)
# A settings.json someone broke by hand must not take the bar down with it:
# retry without the file, which yields the default order.
[ -n "$lido" ] || lido=$(printf '%s' "$input" | jq -r --slurpfile cfg /dev/null "$CONSULTA" 2>/dev/null)

IFS=$'\t' read -r ordem modelo ctx_pct ctx_size ctx_usados bloco_pct bloco_reset semana_pct semana_reset custo dir_atual <<EOF
$lido
EOF
[ -n "${ordem:-}" ] || ordem=$ORDEM_PADRAO

# ---------------------------------------------------------------------------
# Context window
# ---------------------------------------------------------------------------
model_part=${modelo:-Claude}

if [ -z "$ctx_pct" ] || [ "$ctx_pct" = "-" ]; then
    # Nothing to draw yet: say so where the model name goes, and skip the rest
    model_part=$(printf "%s  waiting..." "${modelo:-Claude}")
    ctx_part=""
else
    ctx_int=$(echo "$ctx_pct" | awk '{printf "%.0f", $1}')
    if [ "$ctx_usados" != "-" ] && [ "$ctx_size" != "-" ]; then
        tokens=$(echo "$ctx_usados $ctx_size" | awk '{printf "%.0fk/%.0fk", $1/1000, $2/1000}')
    else
        tokens="${ctx_int}%"
    fi
    ctx_part=$(printf "ctx $(pick_color "$ctx_pct")[%s]${RESET} %s %s%%" \
        "$(make_bar "$ctx_pct" 10)" "$tokens" "$ctx_int")
fi

# ---------------------------------------------------------------------------
# Plan limits: 5-hour block and week
# ---------------------------------------------------------------------------
bloco_part=""
if [ "$bloco_pct" != "-" ] && [ -n "$bloco_pct" ]; then
    reset=$(hora_reset "$bloco_reset")
    bloco_part=$(printf "5h $(pick_color "$bloco_pct")[%s]${RESET} %.0f%%%s" \
        "$(make_bar "$bloco_pct" 10)" "$bloco_pct" "${reset:+ · resets $reset}")
fi

semana_part=""
if [ "$semana_pct" != "-" ] && [ -n "$semana_pct" ]; then
    reset=$(hora_reset "$semana_reset")
    semana_part=$(printf "week $(pick_color "$semana_pct")[%s]${RESET} %.0f%%%s" \
        "$(make_bar "$semana_pct" 10)" "$semana_pct" "${reset:+ · $reset}")
fi

custo_part=""
if [ "$custo" != "-" ] && [ -n "$custo" ]; then
    custo_part=$(echo "$custo" | awk '{if ($1 > 0) printf "session $%.2f", $1}')
fi

# ---------------------------------------------------------------------------
# Update notice — opt-in, and read-only
# ---------------------------------------------------------------------------
# The bar never opens a network connection and never writes to disk. The
# SessionStart hook does both, only when the user turned the check on, and drops
# the result in a cache file. This reads that file and nothing else.
#
# Anything unexpected — no marker, no cache, a corrupt line, a version that is
# not x.y.z — means no segment and no other change to the bar.
NOVA_VERSAO=""
aviso_update() {
    local base marcador cache ultima
    base=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
    marcador="$base/.ccsl-update-check"
    [ -f "$marcador" ] || return
    cache="$base/.ccsl-update-cache"
    [ -r "$cache" ] || return

    # Cache format: "<epoch> <version>". The epoch is the hook's business — it
    # decides when to refresh; the bar only needs the version.
    read -r _ ultima < "$cache" 2>/dev/null
    [ -n "${ultima:-}" ] || return
    [[ $ultima =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return

    versao_num "$ultima";       local nova=$VERSAO_NUM
    versao_num "$CCSL_VERSION"; local atual=$VERSAO_NUM
    [ "$nova" -gt "$atual" ] 2>/dev/null && NOVA_VERSAO=$ultima
    return 0
}

# "1.12.3" → 1012003, so a plain integer compare orders versions correctly.
# Minor and patch are assumed below 1000, which they are.
VERSAO_NUM=0
versao_num() {
    local v=$1 a b c
    a=${v%%.*}; v=${v#*.}
    b=${v%%.*}; v=${v#*.}
    c=${v%%.*}
    VERSAO_NUM=$(( 10#$a * 1000000 + 10#$b * 1000 + 10#$c ))
}

# ---------------------------------------------------------------------------
# Emit the configured segments, separated by │
# ---------------------------------------------------------------------------
achar_branch "$dir_atual"
# U+2387 marks the segment as a branch; it is one column wide, unlike an emoji
branch_part=""
[ -n "$BRANCH" ] && branch_part="⎇ $BRANCH"

aviso_update
update_part=""
[ -n "$NOVA_VERSAO" ] && update_part="↑$NOVA_VERSAO"

# `case` rather than an associative array: macOS still ships bash 3.2, which has none.
saida=""
IFS=','
for nome in $ordem; do
    case $nome in
        branch)  parte=$branch_part ;;
        model)   parte=$model_part ;;
        ctx)     parte=$ctx_part ;;
        5h)      parte=$bloco_part ;;
        week)    parte=$semana_part ;;
        session) parte=$custo_part ;;
        update)  parte=$update_part ;;
        *)       parte="" ;;   # a name nobody recognises simply does not render
    esac
    [ -n "$parte" ] && saida="${saida:+$saida  │  }$parte"
done
unset IFS

printf "%b" "$saida"
