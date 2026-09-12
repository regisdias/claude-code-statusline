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
#   ctx      → how much of this conversation's context window is used (not a plan quota)
#   5h       → 5-hour block of your plan, with the time it resets
#   semana   → weekly plan limit ("week")
#   sessão   → cost of this conversation, in USD ("session")
#   Colors: green up to 60%, yellow up to 85%, red above that.

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
    $partes = @("$modelo  aguardando...")
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
    if ($quandoReseta) { $texto += " · reseta $quandoReseta" }
    $partes += $texto
}

if ($limites -and $null -ne $limites.seven_day.used_percentage) {
    $pct = $limites.seven_day.used_percentage
    $quandoReseta = Get-Reset $limites.seven_day.resets_at
    $texto = 'semana {0}[{1}]{2} {3}%' -f (Get-Color $pct), (Get-Bar $pct), $RESET, (Get-Inteiro $pct)
    if ($quandoReseta) { $texto += " · $quandoReseta" }
    $partes += $texto
}

if ($dados -and $dados.cost -and $dados.cost.total_cost_usd -gt 0) {
    $partes += ('sessão $' + ([Math]::Round([double]$dados.cost.total_cost_usd, 2)).ToString('0.00', $INV))
}

[Console]::Out.Write(($partes -join '  │  '))
