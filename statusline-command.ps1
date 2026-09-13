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
#   ⎇ <branch> → current git branch, when the session is inside a repository
#   ctx      → how much of this conversation's context window is used (not a plan quota)
#   5h       → 5-hour block of your plan, with the time it resets
#   week     → weekly plan limit
#   session  → cost of this conversation, in USD
#   Colors: green up to 60%, yellow up to 85%, red above that.

# Bumped in the same commit that stamps the version in CHANGELOG.md; CI checks
# that this, the .sh and the CHANGELOG agree.
$CCSL_VERSION = '1.3.0'

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

function Get-Inteiro([double]$n) {
    return [int][Math]::Round($n)
}

# First line of a file, without the trailing CR a Windows-written .git/HEAD carries
function Read-PrimeiraLinha($caminho) {
    try { $linhas = [System.IO.File]::ReadAllLines($caminho) } catch { return '' }
    if ($linhas.Count -eq 0) { return '' }
    return ([string]$linhas[0]).TrimEnd("`r")
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
    try { $atual = [System.IO.Path]::GetFullPath($dir) } catch { return '' }

    while ($atual) {
        $marca = [System.IO.Path]::Combine($atual, '.git')
        $head = ''

        if ([System.IO.Directory]::Exists($marca)) {
            $head = [System.IO.Path]::Combine($marca, 'HEAD')
        } elseif ([System.IO.File]::Exists($marca)) {
            # Worktree or submodule: ".git" is a file holding "gitdir: <path>"
            $gitdir = Read-PrimeiraLinha $marca
            if (-not $gitdir.StartsWith('gitdir: ')) { return '' }
            $gitdir = $gitdir.Substring(8)
            if (-not [System.IO.Path]::IsPathRooted($gitdir)) {
                $gitdir = [System.IO.Path]::Combine($atual, $gitdir)
            }
            $head = [System.IO.Path]::Combine($gitdir, 'HEAD')
        }

        if ($head) {
            if (-not [System.IO.File]::Exists($head)) { return '' }
            $cabeca = Read-PrimeiraLinha $head
            if ($cabeca.StartsWith('ref: ')) {
                $ref = $cabeca.Substring(5)
                if ($ref.StartsWith('refs/heads/')) { $ref = $ref.Substring(11) }
                return $ref
            }
            # Detached HEAD: short sha
            if ($cabeca.Length -gt 7) { return $cabeca.Substring(0, 7) }
            return $cabeca
        }

        $pai = [System.IO.Path]::GetDirectoryName($atual)
        if (-not $pai -or $pai -eq $atual) { return '' }
        $atual = $pai
    }
    return ''
}

# Epoch → "06:20" when it is today, "18/09 05:00" otherwise
function Get-Reset($epoch) {
    if ($null -eq $epoch) { return '' }
    try {
        $quando = [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch).ToLocalTime().DateTime
    } catch {
        return ''
    }
    if ($quando.Date -eq (Get-Date).Date) { return $quando.ToString('HH:mm', $INV) }
    return $quando.ToString('dd/MM HH:mm', $INV)
}

$bruto = [Console]::In.ReadToEnd()
$dados = $null
if ($bruto) { $dados = $bruto | ConvertFrom-Json }

$modelo = 'Claude'
if ($dados -and $dados.model -and $dados.model.display_name) { $modelo = $dados.model.display_name }

# ---------------------------------------------------------------------------
# Context window
# ---------------------------------------------------------------------------
$ctxPct = $null
if ($dados -and $dados.context_window) { $ctxPct = $dados.context_window.used_percentage }

if ($null -eq $ctxPct) {
    $partes = @("$modelo  waiting...")
} else {
    $tamanho = $dados.context_window.context_window_size
    $usados = $null
    if ($dados.context_window.current_usage) { $usados = $dados.context_window.current_usage.input_tokens }
    if ($null -ne $usados -and $null -ne $tamanho) {
        $tokens = '{0}k/{1}k' -f (Get-Inteiro ($usados / 1000)), (Get-Inteiro ($tamanho / 1000))
    } else {
        $tokens = '{0}%' -f (Get-Inteiro $ctxPct)
    }
    $partes = @('{0}  ctx {1}[{2}]{3} {4} {5}%' -f $modelo, (Get-Color $ctxPct), (Get-Bar $ctxPct), $RESET, $tokens, (Get-Inteiro $ctxPct))
}

# ---------------------------------------------------------------------------
# Plan limits: 5-hour block and week
# ---------------------------------------------------------------------------
$limites = $null
if ($dados) { $limites = $dados.rate_limits }

if ($limites -and $null -ne $limites.five_hour.used_percentage) {
    $pct = $limites.five_hour.used_percentage
    $quandoReseta = Get-Reset $limites.five_hour.resets_at
    $texto = '5h {0}[{1}]{2} {3}%' -f (Get-Color $pct), (Get-Bar $pct), $RESET, (Get-Inteiro $pct)
    if ($quandoReseta) { $texto += " · resets $quandoReseta" }
    $partes += $texto
}

if ($limites -and $null -ne $limites.seven_day.used_percentage) {
    $pct = $limites.seven_day.used_percentage
    $quandoReseta = Get-Reset $limites.seven_day.resets_at
    $texto = 'week {0}[{1}]{2} {3}%' -f (Get-Color $pct), (Get-Bar $pct), $RESET, (Get-Inteiro $pct)
    if ($quandoReseta) { $texto += " · $quandoReseta" }
    $partes += $texto
}

if ($dados -and $dados.cost -and $dados.cost.total_cost_usd -gt 0) {
    $partes += ('session $' + ([Math]::Round([double]$dados.cost.total_cost_usd, 2)).ToString('0.00', $INV))
}

# Update notice — opt-in, and read-only.
#
# The bar never opens a network connection and never writes to disk. The
# SessionStart hook does both, only when the user turned the check on, and drops
# the result in a cache file. This reads that file and nothing else.
#
# Must stay byte-identical to aviso_update() in the .sh: same marker, same cache
# format, same validation, same comparison.
function Get-NovaVersao($instalada) {
    $base = $env:CLAUDE_CONFIG_DIR
    if (-not $base) { $base = [System.IO.Path]::Combine($HOME, '.claude') }

    if (-not [System.IO.File]::Exists([System.IO.Path]::Combine($base, '.ccsl-update-check'))) { return '' }
    $cache = [System.IO.Path]::Combine($base, '.ccsl-update-cache')
    if (-not [System.IO.File]::Exists($cache)) { return '' }

    $linha = Read-PrimeiraLinha $cache
    if (-not $linha) { return '' }
    # Cache format: "<epoch> <version>". The epoch is the hook's business.
    $campos = $linha.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    if ($campos.Count -lt 2) { return '' }
    $ultima = $campos[1]
    if ($ultima -notmatch '^\d+\.\d+\.\d+$') { return '' }

    try {
        if ([version]$ultima -gt [version]$instalada) { return $ultima }
    } catch {
        return ''
    }
    return ''
}

$dirAtual = ''
if ($dados) {
    if ($dados.workspace -and $dados.workspace.current_dir) { $dirAtual = $dados.workspace.current_dir }
    elseif ($dados.cwd) { $dirAtual = $dados.cwd }
}
$branch = Get-Branch $dirAtual
# U+2387 marks the segment as a branch; it is one column wide, unlike an emoji
# [char] and not "\u{2387}": the \u escape is PowerShell 7+, and this file
# has to parse on Windows PowerShell 5.1
if ($branch) { $partes = ,([string][char]0x2387 + " " + $branch) + $partes }

$nova = Get-NovaVersao $CCSL_VERSION
if ($nova) { $partes += ([string][char]0x2191 + $nova) }

[Console]::Out.Write(($partes -join '  │  '))
