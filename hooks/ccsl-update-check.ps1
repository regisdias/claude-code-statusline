# SessionStart hook: tells you when a newer claude-code-statusline is out.
#
# PowerShell version, for Claude Code running natively on Windows.
#
# Off unless <config>\.ccsl-update-check exists. Enable and disable with the
# installer's --enable-update-check / --disable-update-check.
#
# This is the only part of the project that touches the network, and it is the
# reason the status line itself does not have to: it writes the result to
# <config>\.ccsl-update-cache, and the bar only ever reads that file.
#
# At most one request per 24 h, with a 3 s timeout. A failed or slow request
# leaves the previous cache alone and prints nothing.

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { $null = $_ }

$REPO = 'regisdias/claude-code-statusline'
$INSTALADOR = "https://raw.githubusercontent.com/$REPO/main/install.sh"
$INTERVALO = 24 * 3600

$base = $env:CLAUDE_CONFIG_DIR
if (-not $base) { $base = [System.IO.Path]::Combine($HOME, '.claude') }

if (-not [System.IO.File]::Exists([System.IO.Path]::Combine($base, '.ccsl-update-check'))) { exit 0 }

$cache = [System.IO.Path]::Combine($base, '.ccsl-update-cache')
$script = [System.IO.Path]::Combine($base, 'statusline-command.sh')
$scriptPs = [System.IO.Path]::Combine($base, 'statusline-command.ps1')
if (-not [System.IO.File]::Exists($script)) { $script = $scriptPs }
if (-not [System.IO.File]::Exists($script)) { exit 0 }

# The installed version is whatever the installed script says it is
$instalada = ''
foreach ($linha in [System.IO.File]::ReadAllLines($script)) {
    if ($linha -match '^\s*\$?CCSL_VERSION\s*=\s*.?([0-9]+\.[0-9]+\.[0-9]+)') {
        $instalada = $Matches[1]
        break
    }
}
if (-not $instalada) { exit 0 }

# Not `Get-Date -UFormat %s`: on Windows PowerShell 5.1 that returns local
# time as if it were an epoch — three hours off here — so a cache shared with
# the bash hook would disagree about the 24 h window.
$agora = [int][System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$ultima = ''
$quando = 0
if ([System.IO.File]::Exists($cache)) {
    $linhas = [System.IO.File]::ReadAllLines($cache)
    if ($linhas.Count -gt 0) {
        $campos = ([string]$linhas[0]).Trim().Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        if ($campos.Count -ge 1 -and $campos[0] -match '^[0-9]+$') { $quando = [int]$campos[0] }
        if ($campos.Count -ge 2) { $ultima = $campos[1] }
    }
}

# Only reach out when the cache is stale
if (($agora - $quando) -ge $INTERVALO) {
    try {
        $resposta = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest" `
            -TimeoutSec 3 -UseBasicParsing -Headers @{ 'User-Agent' = 'claude-code-statusline' }
        $nova = [string]$resposta.tag_name
        if ($nova.StartsWith('v')) { $nova = $nova.Substring(1) }
        if ($nova -match '^[0-9]+\.[0-9]+\.[0-9]+$') {
            $ultima = $nova
            [System.IO.File]::WriteAllText($cache, "$agora $ultima`n")
        }
    } catch {
        $null = $_
    }
}

if (-not $ultima) { exit 0 }
if ($ultima -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { exit 0 }

try {
    if ([version]$ultima -gt [version]$instalada) {
        Write-Output "claude-code-statusline $ultima is available (you have $instalada)"
        Write-Output "  curl -fsSL $INSTALADOR | bash"
    }
} catch {
    $null = $_
}
exit 0
