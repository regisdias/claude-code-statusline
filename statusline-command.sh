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
#   ctx      → how much of this conversation's context window is used (not a plan quota)
#   5h       → 5-hour block of your plan, with the time it resets
#   semana   → weekly plan limit ("week")
#   sessão   → cost of this conversation, in USD ("session")
#   Colors: green up to 60%, yellow up to 85%, red above that.

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

# Single read of the payload; "-" marks a missing field
IFS=$'\t' read -r modelo ctx_pct ctx_size ctx_usados bloco_pct bloco_reset semana_pct semana_reset custo <<EOF
$(printf '%s' "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.context_window.used_percentage // "-"),
    (.context_window.context_window_size // "-"),
    (.context_window.current_usage.input_tokens // "-"),
    (.rate_limits.five_hour.used_percentage // "-"),
    (.rate_limits.five_hour.resets_at // "-"),
    (.rate_limits.seven_day.used_percentage // "-"),
    (.rate_limits.seven_day.resets_at // "-"),
    (.cost.total_cost_usd // "-")
] | @tsv' 2>/dev/null)
EOF

# ---------------------------------------------------------------------------
# Context window
# ---------------------------------------------------------------------------
if [ -z "$ctx_pct" ] || [ "$ctx_pct" = "-" ]; then
    ctx_part=$(printf "%s  aguardando..." "${modelo:-Claude}")
else
    ctx_int=$(echo "$ctx_pct" | awk '{printf "%.0f", $1}')
    if [ "$ctx_usados" != "-" ] && [ "$ctx_size" != "-" ]; then
        tokens=$(echo "$ctx_usados $ctx_size" | awk '{printf "%.0fk/%.0fk", $1/1000, $2/1000}')
    else
        tokens="${ctx_int}%"
    fi
    ctx_part=$(printf "%s  ctx $(pick_color "$ctx_pct")[%s]${RESET} %s %s%%" \
        "$modelo" "$(make_bar "$ctx_pct" 10)" "$tokens" "$ctx_int")
fi

# ---------------------------------------------------------------------------
# Plan limits: 5-hour block and week
# ---------------------------------------------------------------------------
bloco_part=""
if [ "$bloco_pct" != "-" ] && [ -n "$bloco_pct" ]; then
    reset=$(hora_reset "$bloco_reset")
    bloco_part=$(printf "5h $(pick_color "$bloco_pct")[%s]${RESET} %.0f%%%s" \
        "$(make_bar "$bloco_pct" 10)" "$bloco_pct" "${reset:+ · reseta $reset}")
fi

semana_part=""
if [ "$semana_pct" != "-" ] && [ -n "$semana_pct" ]; then
    reset=$(hora_reset "$semana_reset")
    semana_part=$(printf "semana $(pick_color "$semana_pct")[%s]${RESET} %.0f%%%s" \
        "$(make_bar "$semana_pct" 10)" "$semana_pct" "${reset:+ · $reset}")
fi

custo_part=""
if [ "$custo" != "-" ] && [ -n "$custo" ]; then
    custo_part=$(echo "$custo" | awk '{if ($1 > 0) printf "sessão $%.2f", $1}')
fi

# ---------------------------------------------------------------------------
# Join whatever exists, separated by │
# ---------------------------------------------------------------------------
saida="$ctx_part"
for parte in "$bloco_part" "$semana_part" "$custo_part"; do
    [ -n "$parte" ] && saida="$saida  │  $parte"
done
printf "%b" "$saida"
