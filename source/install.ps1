# Installs turing (AI line attribution -> WD: commit trailer) for every AI agent found, plus OTel telemetry for Claude Code / OpenCode.
# Windows. Usage: powershell -ExecutionPolicy Bypass -File install.ps1 [-Agents claude,opencode,cursor,gemini,copilot,droid,codex]
#                [-NoOtel] [-Uninstall | -Diagnose] [-Path <dir>]
# Non-interactive OTel: set TURING_CLAUDE_TOKEN / TURING_OPENCODE_TOKEN (optional: TURING_OTEL_URL, and TURING_EMAIL to use one email for every repo).
param(
  [string]$Agents = '',
  [switch]$NoOtel,
  [switch]$Uninstall,
  [switch]$Diagnose,
  [string]$Path = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'

foreach ($c in 'node', 'git') {
  if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Write-Error "$c is required but not on PATH" }
}

$dest = Join-Path $HOME '.waydev\turing.js'
$defaultUrl = 'https://api-ai.waydev.co'

if ($Diagnose) {
  $script = if (Test-Path $dest) { $dest } else { Join-Path $PSScriptRoot 'turing.js' }
  node $script diagnose $Path
  exit $LASTEXITCODE
}

if ($Uninstall) {
  if (-not (Test-Path $dest)) { Write-Host 'turing is not installed.'; exit 0 }
  Write-Host "Removing git hooks and OTel settings from repos under ${Path}:"
  node $dest disable $Path
  node $dest teardown
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $HOME '.waydev\turing'), $dest
  Write-Host 'Done.'
  exit 0
}

$src = Join-Path $PSScriptRoot 'turing.js'
if (-not $Agents) { $Agents = ((node $src agents) -join ' ').Trim() -replace '\s+', ',' }
if (-not $Agents) { Write-Error 'no supported AI agent found; pass -Agents to choose' }
$list = $Agents -split ','
$flags = $list | ForEach-Object { "--$_" }
Write-Host "Agents: $($list -join ', ')"
if (-not ($list -contains 'claude' -or $list -contains 'opencode')) { $NoOtel = $true }
Write-Host "Repositories under ${Path}:"
$repos = node $src repos $Path
if (-not $repos) { Write-Host '  none found'; exit 1 }
$repos | ForEach-Object { Write-Host $_ }

$entireRepos = @(node $src entire-repos $Path)
$entire = ''
if ($entireRepos) {
  Write-Host ''
  Write-Host 'Entire is set up in:'
  $entireRepos | ForEach-Object { Write-Host $_ }
  Write-Host 'Both tools write a WD: trailer. Removing Entire runs its uninstall (its .entire/ folder, session data and shadow'
  Write-Host "branches go too) and removes install-wd's wd_commit_hook. Keeping it puts turing in compare mode (WD-Turing: trailer)."
  $reply = Read-Host 'Remove Entire from these repos? [y/N]'
  $entire = if ($reply -match '^[yY]') { 'remove' } else { 'keep' }
}

function Read-Token([string]$label, [string]$var) {
  $tok = [Environment]::GetEnvironmentVariable($var)
  while (-not $tok) {
    $secure = Read-Host "$label ingest token" -AsSecureString
    $tok = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  }
  [Environment]::SetEnvironmentVariable($var, $tok, 'Process')
}

if (-not $NoOtel) {
  Write-Host ''
  Write-Host 'OTel telemetry sends usage, tokens and cost to Waydev (skip with -NoOtel).'
  if (-not $env:TURING_OTEL_URL) {
    $url = Read-Host "Ingest URL [$defaultUrl]"
    $env:TURING_OTEL_URL = if ($url) { $url } else { $defaultUrl }
  }
  if ($list -contains 'claude') { Read-Token 'Claude Code' 'TURING_CLAUDE_TOKEN' }
  if ($list -contains 'opencode') { Read-Token 'OpenCode' 'TURING_OPENCODE_TOKEN' }
  if (-not $env:TURING_EMAIL) {
    $gitEmail = git config --global user.email
    $prompt = if ($gitEmail) { "Email for OTel (Enter = each repo's git user.email, e.g. $gitEmail)" } else { 'Email for OTel' }
    do { $email = Read-Host $prompt } until ($email -match '^[^@\s]+@[^@\s]+\.[^@\s]+$' -or (-not $email -and $gitEmail))
    if ($email) { $env:TURING_EMAIL = $email }
  }
} else {
  Remove-Item Env:TURING_CLAUDE_TOKEN, Env:TURING_OPENCODE_TOKEN -ErrorAction SilentlyContinue
}

Write-Host ''
$withOtel = if ($NoOtel) { '' } else { ' with OTel' }
$reply = Read-Host "Install turing$withOtel in these repos? [Y/n]"
if ($reply -match '^[nN]') { Write-Host 'Aborted.'; exit 0 }

node $src setup @flags
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($entire -eq 'remove') {
  Write-Host 'Removing Entire:'
  node $dest remove-entire $Path
} elseif ($entire -eq 'keep') {
  $entireRepos | ForEach-Object { node $dest enable --compare $_.Trim() | Out-Null }
}
node $dest enable $Path
Write-Host "Done. Check the install with: install.ps1 -Diagnose -Path `"$Path`""
