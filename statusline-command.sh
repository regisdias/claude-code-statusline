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
#   "branch_icon" in the same object replaces the `git` label — "\ue0a0" with a
#   Nerd Font, "" for the bare branch name.
#
#   git <branch> → current git branch, when the session is inside a repository
#   ctx      → how much of this conversation's context window is used (not a plan quota)
#   5h       → 5-hour block of your plan, with the time it resets
#   week     → weekly plan limit
#   session  → cost of this conversation, in USD
#   Colors: green up to 60%, yellow up to 85%, red above that.

# Bumped in the same commit that stamps the version in CHANGELOG.md; CI checks
# that this, the .ps1 and the CHANGELOG agree.
CCSL_VERSION="1.5.0"

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
    local filled empty full blank
    filled=$(echo "$pct $width" | awk '{printf "%d", ($1/100)*$2 + 0.5}')
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0
    empty=$((width - filled))
    full=$(printf "%${filled}s" "")
    blank=$(printf "%${empty}s" "")
    printf "%s%s" "${full// /█}" "${blank// /░}"
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
find_branch() {
    local dir=$1 marker head head_line gitdir
    [ -n "$dir" ] && [ "$dir" != "-" ] || return
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
        marker="$dir/.git"
        head=""
        if [ -d "$marker" ]; then
            head="$marker/HEAD"
        elif [ -f "$marker" ]; then
            # Worktree or submodule: ".git" is a file holding "gitdir: <path>"
            # `read` returns non-zero on a file with no trailing newline but still
            # fills the variable, so check the content instead of the exit code —
            # PowerShell's ReadAllLines has no such quirk, and the two must agree.
            read -r gitdir < "$marker"
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
        read -r head_line < "$head"
        head_line=${head_line%$'\r'}   # .git/HEAD written on Windows carries a CR
        [ -n "$head_line" ] || return
        case $head_line in
            "ref: "*)
                head_line=${head_line#ref: }
                BRANCH=${head_line#refs/heads/}
                ;;
            *) BRANCH=${head_line:0:7} ;;   # detached HEAD: short sha
        esac
        return
    done
}

# Format epoch: `date -d` is GNU (Linux, WSL, Git Bash); `date -r` is BSD (macOS)
fmt_epoch() {
    date -d "@$1" "+$2" 2>/dev/null || date -r "$1" "+$2" 2>/dev/null
}

# Epoch → "06:20" when it is today, "18/09 05:00" otherwise
reset_time() {
    [ "$1" = "-" ] && return
    if [ "$(fmt_epoch "$1" %F)" = "$(date +%F)" ]; then
        fmt_epoch "$1" %H:%M
    else
        fmt_epoch "$1" '%d/%m %H:%M'
    fi
}

DEFAULT_ORDER="branch,model,ctx,5h,week,session,update"

# One jq call reads both the payload (stdin) and settings.json (--slurpfile), so
# the configuration costs no extra process on the render path.
# The default lives inside the query: `read` with IFS=tab treats tab as
# whitespace, so an empty leading field would collapse and shift every other
# field left. This one can never be empty.
#
# The branch icon comes last, as "<width>:<icon>", which is never empty either —
# "" is a valid icon. Its width is computed here because the shell counts bytes
# under LC_ALL=C: one column per code point, two outside the BMP, which is what
# PowerShell's .Length gives. Control characters and backslashes are dropped: the
# bar is printed with %b, and a config value must not be able to inject escapes.
QUERY='[
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
    (.workspace.current_dir // .cwd // "-"),
    ($cfg[0].ccsl.branch_icon
        | if type == "string" then explode | map(select(. > 31 and . != 127 and . != 92)) else "git" | explode end
        | "\(map(if . > 65535 then 2 else 1 end) | add // 0):\(implode)")
] | @tsv'

settings_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
[ -r "$settings_file" ] || settings_file=/dev/null

read_fields=$(printf '%s' "$input" | jq -r --slurpfile cfg "$settings_file" "$QUERY" 2>/dev/null)
# A settings.json someone broke by hand must not take the bar down with it:
# retry without the file, which yields the default order.
[ -n "$read_fields" ] || read_fields=$(printf '%s' "$input" | jq -r --slurpfile cfg /dev/null "$QUERY" 2>/dev/null)

IFS=$'\t' read -r order model ctx_pct ctx_size ctx_used block_pct block_reset week_pct week_reset cost current_dir icone <<EOF
$read_fields
EOF
[ -n "${order:-}" ] || order=$DEFAULT_ORDER
case ${icone:-} in
    *:*) icone_largura=${icone%%:*}; icone=${icone#*:} ;;
    *)   icone_largura=3; icone=git ;;
esac

# ---------------------------------------------------------------------------
# Context window
# ---------------------------------------------------------------------------
model_part=${model:-Claude}

if [ -z "$ctx_pct" ] || [ "$ctx_pct" = "-" ]; then
    # Nothing to draw yet: say so where the model name goes, and skip the rest
    model_part=$(printf "%s  waiting..." "${model:-Claude}")
    ctx_part=""
else
    ctx_int=$(echo "$ctx_pct" | awk '{printf "%.0f", $1}')
    if [ "$ctx_used" != "-" ] && [ "$ctx_size" != "-" ]; then
        tokens=$(echo "$ctx_used $ctx_size" | awk '{printf "%.0fk/%.0fk", $1/1000, $2/1000}')
    else
        tokens="${ctx_int}%"
    fi
    ctx_part=$(printf "ctx $(pick_color "$ctx_pct")[%s]${RESET} %s %s%%" \
        "$(make_bar "$ctx_pct" 10)" "$tokens" "$ctx_int")
fi

# ---------------------------------------------------------------------------
# Plan limits: 5-hour block and week
# ---------------------------------------------------------------------------
block_part=""
if [ "$block_pct" != "-" ] && [ -n "$block_pct" ]; then
    reset=$(reset_time "$block_reset")
    block_part=$(printf "5h $(pick_color "$block_pct")[%s]${RESET} %.0f%%%s" \
        "$(make_bar "$block_pct" 10)" "$block_pct" "${reset:+ · resets $reset}")
fi

week_part=""
if [ "$week_pct" != "-" ] && [ -n "$week_pct" ]; then
    reset=$(reset_time "$week_reset")
    week_part=$(printf "week $(pick_color "$week_pct")[%s]${RESET} %.0f%%%s" \
        "$(make_bar "$week_pct" 10)" "$week_pct" "${reset:+ · $reset}")
fi

cost_part=""
if [ "$cost" != "-" ] && [ -n "$cost" ]; then
    cost_part=$(echo "$cost" | awk '{if ($1 > 0) printf "session $%.2f", $1}')
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
NEW_VERSION=""
update_notice() {
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

    version_num "$ultima";       local nova=$VERSION_NUM
    version_num "$CCSL_VERSION"; local atual=$VERSION_NUM
    [ "$nova" -gt "$atual" ] 2>/dev/null && NEW_VERSION=$ultima
    return 0
}

# "1.12.3" → 1012003, so a plain integer compare orders versions correctly.
# Minor and patch are assumed below 1000, which they are.
VERSION_NUM=0
version_num() {
    local v=$1 a b c
    a=${v%%.*}; v=${v#*.}
    b=${v%%.*}; v=${v#*.}
    c=${v%%.*}
    VERSION_NUM=$(( 10#$a * 1000000 + 10#$b * 1000 + 10#$c ))
}

# Visible width of a string, in columns, regardless of locale.
#
# ${#s} counts bytes when the locale is not UTF-8, and the status line often runs
# with no LANG set: the same line measures 31 under C.UTF-8 and 55 under C,
# because █ is three bytes. Substitution matches the same bytes either way, so
# folding each glyph we emit to one ASCII character makes the count right in
# both. The branch icon is whatever the user configured, so it folds to the
# width jq computed for it. A non-ASCII branch or model name still over-counts,
# which only wraps a little early — it never loses anything.
shopt -s extglob
icone_dobrado=$(printf "%${icone_largura}s" "")
icone_dobrado=${icone_dobrado// /#}
WIDTH=0
visible_width() {
    local s=${1//$'\033'\[*([0-9;])m/}
    s=${s//█/#}; s=${s//░/#}; s=${s//│/#}
    s=${s//↑/#}; s=${s//·/#}
    # Quoted: the icon is a literal, not a pattern. An ASCII icon folds to itself.
    [ -n "$icone" ] && s=${s//"$icone"/$icone_dobrado}
    WIDTH=${#s}
}

# ---------------------------------------------------------------------------
# Emit the configured segments, separated by │
# ---------------------------------------------------------------------------
find_branch "$current_dir"
# A word, not a glyph: U+2387 read as the Option key on macOS, and the real git
# icons need a Nerd Font. `branch_icon` is there for people who have one.
branch_part=""
[ -n "$BRANCH" ] && branch_part="${icone:+$icone }$BRANCH"

update_notice
update_part=""
[ -n "$NEW_VERSION" ] && update_part="↑$NEW_VERSION"

# Claude Code sets COLUMNS to the terminal width before running this. Anything
# missing or not a number means no wrapping, which is the old behaviour.
columns=0
case ${COLUMNS:-} in
    ''|*[!0-9]*) columns=0 ;;
    *)           columns=$COLUMNS ;;
esac

SEP="  │  "
visible_width "$SEP"; sep_width=$WIDTH

# `case` rather than an associative array: macOS still ships bash 3.2, which has none.
# Segments are packed greedily into rows of at most $columns, breaking only
# *between* them, so a segment is never cut in half.
output=""
line=""
line_width=0
IFS=','
for name in $order; do
    case $name in
        branch)  part=$branch_part ;;
        model)   part=$model_part ;;
        ctx)     part=$ctx_part ;;
        5h)      part=$block_part ;;
        week)    part=$week_part ;;
        session) part=$cost_part ;;
        update)  part=$update_part ;;
        *)       part="" ;;   # a name nobody recognises simply does not render
    esac
    [ -n "$part" ] || continue

    visible_width "$part"; part_width=$WIDTH

    if [ -z "$line" ]; then
        line=$part
        line_width=$part_width
    elif [ "$columns" -gt 0 ] \
        && [ $((line_width + sep_width + part_width)) -gt "$columns" ]; then
        output="${output:+$output
}$line"
        line=$part
        line_width=$part_width
    else
        line="$line$SEP$part"
        line_width=$((line_width + sep_width + part_width))
    fi
done
unset IFS
[ -n "$line" ] && output="${output:+$output
}$line"

printf "%b" "$output"
