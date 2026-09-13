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
$INSTALLER = "https://raw.githubusercontent.com/$REPO/main/install.sh"
$INTERVAL = 24 * 3600

$base = $env:CLAUDE_CONFIG_DIR
if (-not $base) { $base = [System.IO.Path]::Combine($HOME, '.claude') }

if (-not [System.IO.File]::Exists([System.IO.Path]::Combine($base, '.ccsl-update-check'))) { exit 0 }

$cache = [System.IO.Path]::Combine($base, '.ccsl-update-cache')
$script = [System.IO.Path]::Combine($base, 'statusline-command.sh')
$scriptPs = [System.IO.Path]::Combine($base, 'statusline-command.ps1')
if (-not [System.IO.File]::Exists($script)) { $script = $scriptPs }
if (-not [System.IO.File]::Exists($script)) { exit 0 }

# The installed version is whatever the installed script says it is
$installed = ''
foreach ($line in [System.IO.File]::ReadAllLines($script)) {
    if ($line -match '^\s*\$?CCSL_VERSION\s*=\s*.?([0-9]+\.[0-9]+\.[0-9]+)') {
        $installed = $Matches[1]
        break
    }
}
if (-not $installed) { exit 0 }

# Not `Get-Date -UFormat %s`: on Windows PowerShell 5.1 that returns local
# time as if it were an epoch — three hours off here — so a cache shared with
# the bash hook would disagree about the 24 h window.
$now = [int][System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$latest = ''
$when = 0
if ([System.IO.File]::Exists($cache)) {
    $lines = [System.IO.File]::ReadAllLines($cache)
    if ($lines.Count -gt 0) {
        $fields = ([string]$lines[0]).Trim().Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        if ($fields.Count -ge 1 -and $fields[0] -match '^[0-9]+$') { $when = [int]$fields[0] }
        if ($fields.Count -ge 2) { $latest = $fields[1] }
    }
}

# Only reach out when the cache is stale
if (($now - $when) -ge $INTERVAL) {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest" `
            -TimeoutSec 3 -UseBasicParsing -Headers @{ 'User-Agent' = 'claude-code-statusline' }
        $newer = [string]$response.tag_name
        if ($newer.StartsWith('v')) { $newer = $newer.Substring(1) }
        if ($newer -match '^[0-9]+\.[0-9]+\.[0-9]+$') {
            $latest = $newer
            [System.IO.File]::WriteAllText($cache, "$now $latest`n")
        }
    } catch {
        $null = $_
    }
}

if (-not $latest) { exit 0 }
if ($latest -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { exit 0 }

try {
    if ([version]$latest -gt [version]$installed) {
        Write-Output "claude-code-statusline $latest is available (you have $installed)"
        Write-Output "  curl -fsSL $INSTALLER | bash"
    }
} catch {
    $null = $_
}
exit 0
