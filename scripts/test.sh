#!/usr/bin/env bash
# Runs every payload through both implementations and checks that they agree
# byte for byte. The PowerShell half is skipped when `pwsh` is not installed, so
# the script still works on a bare Linux box.
#
#   bash scripts/test.sh
#
# Exit code 0 = the two implementations agree on every case.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shell="$root/statusline-command.sh"
ps1="$root/statusline-command.ps1"
payloads="$root/scripts/payloads"

failures=0
has_pwsh=0
command -v pwsh >/dev/null 2>&1 && has_pwsh=1

command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Point the scripts at an empty config dir: whoever runs this may have the update
# check enabled in their real ~/.claude, which would add a segment to every case.
mkdir -p "$tmpdir/config"
export CLAUDE_CONFIG_DIR="$tmpdir/config"

# Wide and pinned: the bar wraps to COLUMNS, and the existing cases assume one
# line. The wrapping section below sets it per case.
export COLUMNS=999

# Compare both implementations on one payload file.
compare() {
    local name=$1 payload=$2 out_sh out_ps

    out_sh=$(bash "$shell" < "$payload" 2>/dev/null)
    if [ -z "$out_sh" ]; then
        echo "FAIL  $name — the shell version printed nothing" >&2
        failures=$((failures + 1))
        return
    fi

    if [ "$has_pwsh" = 0 ]; then
        echo "ok     $name — shell only (PowerShell skipped, pwsh missing)"
        return
    fi

    out_ps=$(pwsh -NoProfile -File "$ps1" < "$payload" 2>/dev/null)
    if [ "$out_sh" = "$out_ps" ]; then
        echo "ok     $name — both implementations agree"
    else
        echo "FAIL  $name — outputs differ:" >&2
        printf '  sh : %q\n  ps1: %q\n' "$out_sh" "$out_ps" >&2
        failures=$((failures + 1))
    fi
}

# ---------------------------------------------------------------------------
# 1. The .ps1 must keep its BOM
# ---------------------------------------------------------------------------
# Without it, Windows PowerShell 5.1 reads the file as ANSI and the block
# characters break the parser before the script ever runs.
if [ "$(head -c3 "$ps1" | od -An -tx1 | tr -d ' \n')" != "efbbbf" ]; then
    echo "FAIL  statusline-command.ps1 lost its UTF-8 BOM" >&2
    failures=$((failures + 1))
else
    echo "ok     statusline-command.ps1 is UTF-8 with BOM"
fi

# ---------------------------------------------------------------------------
# 2. The reference payloads
# ---------------------------------------------------------------------------
for payload in "$payloads"/*.json; do
    compare "$(basename "$payload")" "$payload"
done

# ---------------------------------------------------------------------------
# 3. The git branch, read from .git/HEAD
# ---------------------------------------------------------------------------
# These fixtures are built here instead of living in scripts/payloads/ for two
# reasons: git refuses to track a path containing ".git", and the payload needs
# an absolute path that only exists at run time.
fixture() {
    local path="$tmpdir/$1" content=$2
    mkdir -p "$(dirname "$path")"
    printf '%s' "$content" > "$path"
}

fixture "comum/.git/HEAD"      $'ref: refs/heads/main\n'
fixture "with-slash/.git/HEAD"  $'ref: refs/heads/docs/subject\n'
fixture "solto/.git/HEAD"      $'3b230b4a9f8e7d6c5b4a3928176554433221100f\n'
fixture "crlf/.git/HEAD"       $'ref: refs/heads/feature/x\r\n'
# No trailing newline: `read` returns non-zero but still fills the variable
fixture "no-newline/.git/HEAD"     'ref: refs/heads/no-newline'
mkdir -p "$tmpdir/fundo/a/b/c"
fixture "fundo/.git/HEAD"      $'ref: refs/heads/main\n'
# Worktree/submodule: ".git" is a file pointing at the real git dir
fixture "arvore-real/HEAD"     $'ref: refs/heads/wt-branch\n'
fixture "arvore/.git"          "gitdir: $tmpdir/arvore-real"$'\n'

branch_case() {
    local name=$1 dir=$2 expected=$3
    # Separate statement on purpose: inside a single `local`, bash creates every
    # name before running the assignments, so "$name" would still be unset here.
    local payload="$tmpdir/payload-$name.json" got
    jq --arg d "$dir" '. + {workspace: {current_dir: $d}}' "$payloads/green.json" > "$payload"

    got=$(bash "$shell" < "$payload" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g')
    got=${got%%  │  *}
    got=${got#git }   # the segment carries the `git` label by default
    if [ "$got" != "$expected" ]; then
        echo "FAIL  branch/$name — expected '$expected', got '$got'" >&2
        failures=$((failures + 1))
        return
    fi
    compare "branch/$name" "$payload"
}

branch_case "simple"   "$tmpdir/comum"      "main"
branch_case "with-slash" "$tmpdir/with-slash"  "docs/subject"
branch_case "detached"  "$tmpdir/solto"      "3b230b4"
branch_case "crlf"      "$tmpdir/crlf"       "feature/x"
branch_case "no-newline"    "$tmpdir/no-newline"     "no-newline"
branch_case "walk-up"   "$tmpdir/fundo/a/b/c" "main"
branch_case "worktree"  "$tmpdir/arvore"     "wt-branch"

# Fora de repositório: o trecho some, o resto continua
mkdir -p "$tmpdir/no-repo"
no_repo="$tmpdir/payload-no-repo.json"
jq --arg d "$tmpdir/no-repo" '. + {workspace: {current_dir: $d}}' "$payloads/green.json" > "$no_repo"
if bash "$shell" < "$no_repo" | sed 's/\x1b\[[0-9]*m//g' | grep -q '^Opus 5'; then
    echo "ok     branch/fora-de-repo — segment absent, rest of the bar intact"
    compare "branch/fora-de-repo" "$no_repo"
else
    echo "FAIL  branch/fora-de-repo — the bar should not change outside a repository" >&2
    failures=$((failures + 1))
fi

# ---------------------------------------------------------------------------
# 4. The update notice, read from the cache
# ---------------------------------------------------------------------------
# The bar only ever reads the cache; the hook is what writes it. These cases feed
# the bar a cache directly, which is exactly what it sees in real use.
config="$tmpdir/config"
marker="$config/.ccsl-update-check"
cache="$config/.ccsl-update-cache"

update_case() {
    local name=$1 content=$2 expected=$3
    local payload="$tmpdir/payload-upd-$name.json" got
    cp "$payloads/green.json" "$payload"

    rm -f "$cache"
    [ -n "$content" ] && printf '%s\n' "$content" > "$cache"

    got=$(bash "$shell" < "$payload" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g')
    case $got in
        *"  │  ↑"*) got="↑${got##*  │  ↑}" ;;
        *)          got="—" ;;
    esac
    if [ "$got" != "$expected" ]; then
        echo "FAIL  update/$name — expected '$expected', got '$got'" >&2
        failures=$((failures + 1))
        return
    fi
    compare "update/$name" "$payload"
}

# Sem o marker, nem o cache é lido
printf '0 9.9.9\n' > "$cache"
sem_marcador="$tmpdir/payload-upd-off.json"
cp "$payloads/green.json" "$sem_marcador"
if bash "$shell" < "$sem_marcador" | grep -q '↑'; then
    echo "FAIL  update/desligado — segment appeared without the marker" >&2
    failures=$((failures + 1))
else
    echo "ok     update/desligado — opt-in respected"
    compare "update/desligado" "$sem_marcador"
fi

: > "$marker"
update_case "newer"        "1789204800 9.9.9"   "↑9.9.9"
installed=$(sed -n 's/^CCSL_VERSION="\(.*\)"$/\1/p' "$shell")
update_case "same"       "1789204800 $installed"   "—"
update_case "older"  "1789204800 0.0.1"   "—"
update_case "corrupt"  "garbage here"          "—"
update_case "epoch-only"    "1789204800"         "—"
update_case "four-parts" "1789204800 1.2.3.4" "—"
update_case "empty"       ""                   "—"
rm -f "$marker" "$cache"

# ---------------------------------------------------------------------------
# 5. Segment order, read from settings.json
# ---------------------------------------------------------------------------
order_case() {
    local name=$1 content=$2 expected=$3
    local payload="$tmpdir/payload-ord-$name.json" got
    cp "$payloads/green.json" "$payload"

    rm -f "$config/settings.json"
    [ -n "$content" ] && printf '%s\n' "$content" > "$config/settings.json"

    # Which segments rendered, by name, in order
    got=$(bash "$shell" < "$payload" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g' \
        | awk -F'  │  ' '{for (i=1; i<=NF; i++) {
              if ($i ~ /^ctx /)          printf "%sctx", (i>1?",":"");
              else if ($i ~ /^5h /)      printf "%s5h", (i>1?",":"");
              else if ($i ~ /^week /)    printf "%sweek", (i>1?",":"");
              else if ($i ~ /^session /) printf "%ssession", (i>1?",":"");
              else                       printf "%smodel", (i>1?",":"");
          }}')
    if [ "$got" != "$expected" ]; then
        echo "FAIL  order/$name — expected '$expected', got '$got'" >&2
        failures=$((failures + 1))
        return
    fi
    compare "order/$name" "$payload"
}

# green.json has no workspace, so `branch` never renders here; `update` is off.
order_case "default"     ""                                              "model,ctx,5h,week,session"
order_case "reordered" '{"ccsl":{"order":["session","ctx","model"]}}'  "session,ctx,model"
order_case "no-week"   '{"ccsl":{"order":["model","ctx","5h","session"]}}' "model,ctx,5h,session"
order_case "ctx-only"     '{"ccsl":{"order":["ctx"]}}'                    "ctx"
order_case "bad-name" '{"ccsl":{"order":["ctx","banana","5h"]}}'      "ctx,5h"
order_case "empty-list" '{"ccsl":{"order":[]}}'                        "model,ctx,5h,week,session"
order_case "not-string" '{"ccsl":{"order":[1,true,"ctx"]}}'             "ctx"
order_case "bad-json" '{ this is not json'                             "model,ctx,5h,week,session"
order_case "no-ccsl"   '{"statusLine":{"type":"command"}}'             "model,ctx,5h,week,session"
rm -f "$config/settings.json"

# ---------------------------------------------------------------------------
# 6. Comma-decimal locale
# ---------------------------------------------------------------------------
# JSON numbers use a dot. Under pt_BR, awk read 12.3456 as 12 and bash's printf
# rejected 84.7, so the bar showed "$12,00" and "0%" (issue #27). Fractional
# percentages on purpose: the reference payloads are all integers, which is why
# this went unnoticed. The C render is the reference.
fracionado="$tmpdir/payload-fracionado.json"
jq '.context_window.used_percentage = 64.6
    | .rate_limits.five_hour.used_percentage = 84.7
    | .rate_limits.seven_day.used_percentage = 59.6
    | .cost.total_cost_usd = 12.3456' "$payloads/green.json" > "$fracionado"

referencia=$(LC_ALL=C bash "$shell" < "$fracionado" 2>&1)
case $referencia in
    *'session $12.35'*) ;;
    *) echo "FAIL  locale/C — expected 'session \$12.35', got: $referencia" >&2
       failures=$((failures + 1)) ;;
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
        got=$(env -u LC_ALL -u LC_NUMERIC "$via=$loc" bash "$shell" < "$fracionado" 2>&1)
        if [ "$got" = "$referencia" ]; then
            echo "ok     locale/$loc via $via — igual ao C"
        else
            echo "FAIL  locale/$loc via $via — diverge do C:" >&2
            printf '  C  : %q\n  %s: %q\n' "$referencia" "$loc" "$got" >&2
            failures=$((failures + 1))
        fi
    done
done
[ "$testados" -gt 0 ] || echo "warn  locale — no comma-decimal locale installed, case skipped"

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
visible_width() {
    local s=${1//$'\033'\[*([0-9;])m/}
    s=${s//█/#}; s=${s//░/#}; s=${s//│/#}
    s=${s//↑/#}; s=${s//·/#}
    LV=${#s}
}

width_case() {
    local name=$1 cols=$2
    # Same trap as branch_case: inside one `local`, bash creates every name
    # before running the assignments, so "$name" would still be unset here.
    local payload="$tmpdir/payload-larg-$name.json"
    local out_sh out_ps widest lines
    jq --arg d "$tmpdir/comum" '. + {workspace: {current_dir: $d}}' \
        "$payloads/green.json" > "$payload"

    out_sh=$(COLUMNS=$cols bash "$shell" < "$payload" 2>/dev/null)
    lines=$(printf '%s' "$out_sh" | grep -c '')

    # No line may exceed the width — unless it holds a single segment, which
    # cannot be split without cutting content. A segment wider than the terminal
    # gets its own line and overflows, on purpose.
    widest=0
    local l
    while IFS= read -r l; do
        case $l in
            *"  │  "*) ;;            # more than one segment: must fit
            *) continue ;;           # a lone segment is allowed to overflow
        esac
        visible_width "$l"
        [ "$LV" -gt "$widest" ] && widest=$LV
    done <<< "$out_sh"

    if [ "$cols" -gt 0 ] && [ "$widest" -gt "$cols" ]; then
        echo "FAIL  width/$name — line of $widest columns, with more than one segment, at COLUMNS=$cols" >&2
        failures=$((failures + 1))
        return
    fi
    if ! printf '%s' "$out_sh" | grep -q 'session \$'; then
        echo "FAIL  width/$name — the session segment vanished in the wrap" >&2
        failures=$((failures + 1))
        return
    fi

    if [ "$has_pwsh" = 0 ]; then
        echo "ok     width/$name — $lines line(s), nothing overflowed (PowerShell skipped)"
        return
    fi
    out_ps=$(COLUMNS=$cols pwsh -NoProfile -File "$ps1" < "$payload" 2>/dev/null)
    if [ "$out_sh" = "$out_ps" ]; then
        echo "ok     width/$name — $lines linha(s), both implementations agree"
    else
        echo "FAIL  width/$name — outputs differ at COLUMNS=$cols" >&2
        printf '  sh : %q\n  ps1: %q\n' "$out_sh" "$out_ps" >&2
        failures=$((failures + 1))
    fi
}

width_case "no-columns" 0
width_case "30"          30
width_case "60"          60
width_case "80"          80
width_case "120"         120
width_case "999"         999

# Garbage in COLUMNS must break nothing
lixo="$tmpdir/payload-larg-lixo.json"
cp "$payloads/green.json" "$lixo"
if [ "$(COLUMNS=abc bash "$shell" < "$lixo" 2>/dev/null | grep -c '')" = "1" ]; then
    echo "ok     width/columns-invalido — one line, no wrapping"
else
    echo "FAIL  width/columns-invalido — a non-numeric COLUMNS changed the output" >&2
    failures=$((failures + 1))
fi

# ---------------------------------------------------------------------------
# 8. The branch icon, lido do settings.json
# ---------------------------------------------------------------------------
# `git` by default; `ccsl.branch_icon` replaces it (issue #35). The icons are
# built with printf because bash 3.2 has no \u in $'...'.
PUA=$(printf '\356\202\240')          # U+E0A0, the Powerline branch glyph
EMOJI=$(printf '\360\237\214\277')   # U+1F33F, outside the BMP: two columns

com_branch="$tmpdir/payload-icone.json"
jq --arg d "$tmpdir/comum" '. + {workspace: {current_dir: $d}}' "$payloads/green.json" > "$com_branch"

icon_case() {
    local name=$1 content=$2 expected=$3 got
    rm -f "$config/settings.json"
    [ -n "$content" ] && printf '%s\n' "$content" > "$config/settings.json"

    got=$(bash "$shell" < "$com_branch" 2>/dev/null | sed 's/\x1b\[[0-9]*m//g')
    got=${got%%  │  *}
    if [ "$got" != "$expected" ]; then
        echo "FAIL  icon/$name — expected '$expected', got '$got'" >&2
        failures=$((failures + 1))
        return
    fi
    compare "icon/$name" "$com_branch"
}

icon_case "default"     ""                                          "git main"
icon_case "no-key"  '{"ccsl":{"order":["branch","ctx"]}}'       "git main"
icon_case "nerd-font"  '{"ccsl":{"branch_icon":"\ue0a0"}}'         "$PUA main"
icon_case "antigo"     '{"ccsl":{"branch_icon":"\u2387"}}'         "$(printf '\342\216\207') main"
icon_case "emoji"      '{"ccsl":{"branch_icon":"\ud83c\udf3f"}}'   "$EMOJI main"
icon_case "empty"      '{"ccsl":{"branch_icon":""}}'               "main"
icon_case "number"     '{"ccsl":{"branch_icon":42}}'               "git main"
icon_case "null"       '{"ccsl":{"branch_icon":null}}'             "git main"
icon_case "with-slash"  '{"ccsl":{"branch_icon":"a/b*"}}'           "a/b* main"
# Control characters and backslashes are dropped: no escape can reach the bar
icon_case "control"   '{"ccsl":{"branch_icon":"\u001b[31mX\\n\t"}}' "[31mXn main"
icon_case "bad-json" '{ this is not json'                         "git main"

# The wrap must count the icon in columns, not bytes. branch + model alone:
# "<icon> main" + "  │  " + "Opus 5 (1M context)". Exactly at the limit it is
# one line; counting the icon's bytes would push it to two.
limite_caso() {
    local name=$1 content=$2 cols=$3 lines out_sh out_ps
    printf '%s\n' "$content" > "$config/settings.json"
    out_sh=$(COLUMNS=$cols bash "$shell" < "$com_branch" 2>/dev/null)
    lines=$(printf '%s' "$out_sh" | grep -c '')
    if [ "$lines" != 1 ]; then
        echo "FAIL  icon/$name — $lines lines em COLUMNS=$cols, cabia em uma" >&2
        failures=$((failures + 1))
        return
    fi
    if [ "$(COLUMNS=$((cols - 1)) bash "$shell" < "$com_branch" 2>/dev/null | grep -c '')" != 2 ]; then
        echo "FAIL  icon/$name — em COLUMNS=$((cols - 1)) devia quebrar" >&2
        failures=$((failures + 1))
        return
    fi
    if [ "$has_pwsh" = 0 ]; then
        echo "ok     icon/$name — wraps at the right boundary (PowerShell skipped)"
        return
    fi
    out_ps=$(COLUMNS=$cols pwsh -NoProfile -File "$ps1" < "$com_branch" 2>/dev/null)
    if [ "$out_sh" = "$out_ps" ]; then
        echo "ok     icon/$name — wraps at the right boundary, both implementations agree"
    else
        echo "FAIL  icon/$name — outputs differ at COLUMNS=$cols" >&2
        printf '  sh : %q\n  ps1: %q\n' "$out_sh" "$out_ps" >&2
        failures=$((failures + 1))
    fi
}

# 1 + 5 + 5 + 19 = 30 columns (9 bytes more would be 32)
limite_caso "width-pua"   '{"ccsl":{"order":["branch","model"],"branch_icon":"\ue0a0"}}'       30
# 2 + 5 + 5 + 19 = 31 columns
limite_caso "width-emoji" '{"ccsl":{"order":["branch","model"],"branch_icon":"\ud83c\udf3f"}}' 31
rm -f "$config/settings.json"

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
fi
echo "all good"
