# Claude Code statusline: context window + plan limits (5-hour block and week).
#
# PowerShell version, for Claude Code running natively on Windows. No jq, no external tools:
# only ConvertFrom-Json. Works on Windows PowerShell 5.1 and PowerShell 7+.
#
# INSTALL
#   1. Save this file as $env:USERPROFILE\.claude\statusline-command.ps1
#   2. Add to $env:USERPROFILE\.claude\settings.json:
#
#        "statusLine": {
#          "type": "command",
#          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\\.claude\\statusline-command.ps1"
#        }
#
#      On PowerShell 7 use "pwsh" instead of "powershell".
#   3. The bar shows up on the next render. No restart needed.
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
# that this, the .sh and the CHANGELOG agree.
$CCSL_VERSION = '1.7.0'

$ErrorActionPreference = 'SilentlyContinue'
# The bars are block characters: without UTF-8 the terminal prints garbage
# Swallowing this on purpose: a terminal that refuses the encoding is not a
# reason to stop drawing the bar. PSScriptAnalyzer wants the catch non-empty.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { $null = $_ }

# ${ESC} with braces on purpose: "$ESC[32m" would be parsed as an array index and break the script
$ESC = [char]27
$GREEN = "${ESC}[32m"
$YELLOW = "${ESC}[33m"
$RED = "${ESC}[31m"
$RESET = "${ESC}[0m"
# Numbers are formatted culture-invariant on purpose: "1000k" and "$12.35" in any locale
$INV = [System.Globalization.CultureInfo]::InvariantCulture

function Get-Color([double]$pct) {
    if ($pct -ge 85) { return $RED }
    if ($pct -ge 60) { return $YELLOW }
    return $GREEN
}

function Get-Bar([double]$pct, [int]$width = 10) {
    $filled = [int][Math]::Round(($pct / 100) * $width)
    if ($filled -gt $width) { $filled = $width }
    if ($filled -lt 0) { $filled = 0 }
    return ([string][char]0x2588 * $filled) + ([string][char]0x2591 * ($width - $filled))
}

function Get-Rounded([double]$n) {
    return [int][Math]::Round($n)
}

# First line of a file, without the trailing CR a Windows-written .git/HEAD carries
function Read-FirstLine($path) {
    try { $lines = [System.IO.File]::ReadAllLines($path) } catch { return '' }
    if ($lines.Count -eq 0) { return '' }
    return ([string]$lines[0]).TrimEnd("`r")
}

# Current git branch, read straight from .git/HEAD.
#
# Claude Code does not send the branch in the payload (`worktree.branch` exists only
# inside a worktree session), and the documented way is `git branch --show-current`.
# That spawns git on every render, which is expensive on Windows. The branch is plain
# text in .git/HEAD, so reading it costs a file open and nothing else.
#
# Must stay byte-identical to achar_branch() in the .sh: same walk, same parsing,
# same fallbacks.
function Get-Branch($dir) {
    if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '-') { return '' }
    try { $current = [System.IO.Path]::GetFullPath($dir) } catch { return '' }

    while ($current) {
        $marker = [System.IO.Path]::Combine($current, '.git')
        $head = ''

        if ([System.IO.Directory]::Exists($marker)) {
            $head = [System.IO.Path]::Combine($marker, 'HEAD')
        } elseif ([System.IO.File]::Exists($marker)) {
            # Worktree or submodule: ".git" is a file holding "gitdir: <path>"
            $gitDir = Read-FirstLine $marker
            if (-not $gitDir.StartsWith('gitdir: ')) { return '' }
            $gitDir = $gitDir.Substring(8)
            if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
                $gitDir = [System.IO.Path]::Combine($current, $gitDir)
            }
            $head = [System.IO.Path]::Combine($gitDir, 'HEAD')
        }

        if ($head) {
            if (-not [System.IO.File]::Exists($head)) { return '' }
            $headLine = Read-FirstLine $head
            if ($headLine.StartsWith('ref: ')) {
                $ref = $headLine.Substring(5)
                if ($ref.StartsWith('refs/heads/')) { $ref = $ref.Substring(11) }
                return $ref
            }
            # Detached HEAD: short sha
            if ($headLine.Length -gt 7) { return $headLine.Substring(0, 7) }
            return $headLine
        }

        $parent = [System.IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -eq $current) { return '' }
        $current = $parent
    }
    return ''
}

# When the current pace would take a window to 100% before it resets.
#
# Returns nothing unless that is true: a bar that warns constantly is a bar
# nobody reads. The window length is not in the payload — it is in the field
# name, so five_hour is 18000 seconds and seven_day is 604800.
#
# Must stay identical to projection() in the .sh, silence cases included.
function Get-Projection($used, $resets, $window) {
    if ($null -eq $used -or $null -eq $resets) { return '' }
    try {
        $u = [double]$used
        $r = [double]$resets
    } catch {
        return ''
    }
    $now = [double][System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    $elapsed = $window - ($r - $now)
    if ($elapsed -le 0 -or $u -le 0) { return '' }
    if ($u -ge 100) { return '' }                      # already out; the 100% bar says so
    if (($elapsed / $window) -lt 0.10) { return '' }   # too early to project
    $rate = $u / $elapsed
    $full = $now + (100 - $u) / $rate
    if ($full -ge $r) { return '' }                    # the pace gets there in time
    return (Get-Reset ([long][Math]::Floor($full)))
}

# Epoch → "06:20" when it is today, "18/09 05:00" otherwise
function Get-Reset($epoch) {
    if ($null -eq $epoch) { return '' }
    try {
        $when = [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch).ToLocalTime().DateTime
    } catch {
        return ''
    }
    if ($when.Date -eq (Get-Date).Date) { return $when.ToString('HH:mm', $INV) }
    return $when.ToString('dd/MM HH:mm', $INV)
}

$DEFAULT_ORDER = 'branch,model,ctx,5h,week,session,update'

# The `ccsl` object from settings.json, read once. Anything unreadable or
# malformed is $null, and every setting falls back to its default rather than
# taking the bar down.
function Read-Ccsl {
    $base = $env:CLAUDE_CONFIG_DIR
    if (-not $base) { $base = [System.IO.Path]::Combine($HOME, '.claude') }
    $file = [System.IO.Path]::Combine($base, 'settings.json')
    if (-not [System.IO.File]::Exists($file)) { return $null }
    try {
        $cfg = [System.IO.File]::ReadAllText($file) | ConvertFrom-Json
    } catch {
        return $null
    }
    if (-not $cfg) { return $null }
    return $cfg.ccsl
}

# Which segments to draw, and in what order.
function Get-Order($ccsl) {
    if (-not $ccsl -or -not $ccsl.order) { return $DEFAULT_ORDER }
    $names = @($ccsl.order | Where-Object { $_ -is [string] })
    if ($names.Count -eq 0) { return $DEFAULT_ORDER }
    return ($names -join ',')
}

# What goes before the branch name. Must match the jq query in the .sh: a string
# is used as given, minus control characters and backslashes; anything else means
# the `git` label.
function Get-BranchIcon($ccsl) {
    if (-not $ccsl) { return 'git' }
    $icon = $ccsl.branch_icon
    if ($icon -isnot [string]) { return 'git' }
    $clean = New-Object System.Text.StringBuilder
    foreach ($c in $icon.ToCharArray()) {
        $n = [int]$c
        if ($n -gt 31 -and $n -ne 127 -and $n -ne 92) { [void]$clean.Append($c) }
    }
    return $clean.ToString()
}

$ccsl = Read-Ccsl

$raw = [Console]::In.ReadToEnd()
$data = $null
if ($raw) { $data = $raw | ConvertFrom-Json }

$model = 'Claude'
if ($data -and $data.model -and $data.model.display_name) { $model = $data.model.display_name }

# ---------------------------------------------------------------------------
# Context window
# ---------------------------------------------------------------------------
$ctxPct = $null
if ($data -and $data.context_window) { $ctxPct = $data.context_window.used_percentage }

$modelPart = $model
$ctxPart = ''

if ($null -eq $ctxPct) {
    # Nothing to draw yet: say so where the model name goes, and skip the rest
    $modelPart = "$model  waiting..."
} else {
    $size = $data.context_window.context_window_size
    $used = $null
    if ($data.context_window.current_usage) { $used = $data.context_window.current_usage.input_tokens }
    if ($null -ne $used -and $null -ne $size) {
        $tokens = '{0}k/{1}k' -f (Get-Rounded ($used / 1000)), (Get-Rounded ($size / 1000))
    } else {
        $tokens = '{0}%' -f (Get-Rounded $ctxPct)
    }
    $ctxPart = 'ctx {0}[{1}]{2} {3} {4}%' -f (Get-Color $ctxPct), (Get-Bar $ctxPct), $RESET, $tokens, (Get-Rounded $ctxPct)
}

# ---------------------------------------------------------------------------
# Plan limits: 5-hour block and week
# ---------------------------------------------------------------------------
$blockPart = ''
$weekPart = ''
$costPart = ''

$limits = $null
if ($data) { $limits = $data.rate_limits }

if ($limits -and $null -ne $limits.five_hour.used_percentage) {
    $pct = $limits.five_hour.used_percentage
    $resetsWhen = Get-Reset $limits.five_hour.resets_at
    $text = '5h {0}[{1}]{2} {3}%' -f (Get-Color $pct), (Get-Bar $pct), $RESET, (Get-Rounded $pct)
    $exhausts = Get-Projection $limits.five_hour.used_percentage $limits.five_hour.resets_at 18000
    if ($exhausts) { $text += " · ${RED}full $exhausts${RESET}" }
    if ($resetsWhen) { $text += " · resets $resetsWhen" }
    $blockPart = $text
}

if ($limits -and $null -ne $limits.seven_day.used_percentage) {
    $pct = $limits.seven_day.used_percentage
    $resetsWhen = Get-Reset $limits.seven_day.resets_at
    $text = 'week {0}[{1}]{2} {3}%' -f (Get-Color $pct), (Get-Bar $pct), $RESET, (Get-Rounded $pct)
    $exhausts = Get-Projection $limits.seven_day.used_percentage $limits.seven_day.resets_at 604800
    if ($exhausts) { $text += " · ${RED}full $exhausts${RESET}" }
    if ($resetsWhen) { $text += " · $resetsWhen" }
    $weekPart = $text
}

if ($data -and $data.cost -and $data.cost.total_cost_usd -gt 0) {
    $costPart = 'session $' + ([Math]::Round([double]$data.cost.total_cost_usd, 2)).ToString('0.00', $INV)
}

# Update notice — opt-in, and read-only.
#
# The bar never opens a network connection and never writes to disk. The
# SessionStart hook does both, only when the user turned the check on, and drops
# the result in a cache file. This reads that file and nothing else.
#
# Must stay byte-identical to aviso_update() in the .sh: same marker, same cache
# format, same validation, same comparison.
function Get-NewVersion($installed) {
    $base = $env:CLAUDE_CONFIG_DIR
    if (-not $base) { $base = [System.IO.Path]::Combine($HOME, '.claude') }

    if (-not [System.IO.File]::Exists([System.IO.Path]::Combine($base, '.ccsl-update-check'))) { return '' }
    $cache = [System.IO.Path]::Combine($base, '.ccsl-update-cache')
    if (-not [System.IO.File]::Exists($cache)) { return '' }

    $line = Read-FirstLine $cache
    if (-not $line) { return '' }
    # Cache format: "<epoch> <version>". The epoch is the hook's business.
    $fields = $line.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    if ($fields.Count -lt 2) { return '' }
    $latest = $fields[1]
    if ($latest -notmatch '^\d+\.\d+\.\d+$') { return '' }

    try {
        if ([version]$latest -gt [version]$installed) { return $latest }
    } catch {
        return ''
    }
    return ''
}

$currentDir = ''
if ($data) {
    if ($data.workspace -and $data.workspace.current_dir) { $currentDir = $data.workspace.current_dir }
    elseif ($data.cwd) { $currentDir = $data.cwd }
}
$branch = Get-Branch $currentDir
# A word, not a glyph: U+2387 read as the Option key on macOS, and the real git
# icons need a Nerd Font. `branch_icon` is there for people who have one.
$icon = Get-BranchIcon $ccsl
$branchPart = ''
if ($branch) {
    if ($icon) { $branchPart = $icon + ' ' + $branch } else { $branchPart = $branch }
}

$newer = Get-NewVersion $CCSL_VERSION
$updatePart = ''
if ($newer) { $updatePart = [string][char]0x2191 + $newer }

# Visible width in columns: strip the ANSI codes and count. PowerShell has no
# locale trap here — .Length counts UTF-16 units, one per glyph we emit, and two
# for a branch icon outside the BMP — but it must land on the same number the .sh
# computes.
function Get-Width($s) {
    # [char]27 and not `e: the `e escape is PowerShell 6+, and on 5.1 it would
    # silently fail to match, leaving the ANSI codes in the count and wrapping
    # at the wrong place.
    return ($s -replace ([string][char]27 + '\[[0-9;]*m'), '').Length
}

# Claude Code sets COLUMNS to the terminal width before running this. Anything
# missing or not a number means no wrapping, which is the old behaviour.
$columns = 0
if ($env:COLUMNS -match '^[0-9]+$') { $columns = [int]$env:COLUMNS }

$SEP = '  ' + [string][char]0x2502 + '  '
$sepWidth = $SEP.Length

# Segments are packed greedily into rows of at most $columns, breaking only
# *between* them, so a segment is never cut in half.
$lines = @()
$line = ''
$lineWidth = 0

foreach ($name in (Get-Order $ccsl).Split(',')) {
    $part = switch ($name) {
        'branch'  { $branchPart }
        'model'   { $modelPart }
        'ctx'     { $ctxPart }
        '5h'      { $blockPart }
        'week'    { $weekPart }
        'session' { $costPart }
        'update'  { $updatePart }
        default   { '' }   # a name nobody recognises simply does not render
    }
    if (-not $part) { continue }

    $partWidth = Get-Width $part
    if (-not $line) {
        $line = $part
        $lineWidth = $partWidth
    } elseif ($columns -gt 0 -and ($lineWidth + $sepWidth + $partWidth) -gt $columns) {
        $lines += $line
        $line = $part
        $lineWidth = $partWidth
    } else {
        $line = $line + $SEP + $part
        $lineWidth = $lineWidth + $sepWidth + $partWidth
    }
}
if ($line) { $lines += $line }

[Console]::Out.Write(($lines -join "`n"))
