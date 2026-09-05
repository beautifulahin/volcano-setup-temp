# Volcano - diagnose and repair. Run:  irm <base>/fix-path.ps1 | iex
# NOTE: runs through irm|iex, so every message here is ENGLISH.
#       PowerShell 5.1 does not read it as UTF-8; Korean would break.
$ErrorActionPreference = 'Continue'
$vHome = Join-Path $env:LOCALAPPDATA 'volcano'
$bin = Join-Path $vHome 'bin'
$venvPy = Join-Path $vHome 'venv\Scripts\python.exe'
$jobs = Join-Path $env:USERPROFILE 'volcano_jobs'
$claudeBin = Join-Path $env:USERPROFILE '.local\bin'
$claudeExe = Join-Path $claudeBin 'claude.exe'
$fixed = @()
$left = @()

function Have($n) { $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

Write-Host ''
Write-Host '=== Volcano: checking and repairing ==='
Write-Host ''

# 1. Claude Code
if (Test-Path $claudeExe) { Write-Host '[OK] Claude Code' }
elseif (Have 'claude')    { Write-Host '[OK] Claude Code (on PATH)' }
else {
  Write-Host '[..] Claude Code missing - installing'
  try {
    $b = (Invoke-WebRequest -Uri 'https://claude.ai/install.ps1' -UseBasicParsing).Content
    if ($b -isnot [string]) { $b = [System.Text.Encoding]::UTF8.GetString($b) }
    & ([scriptblock]::Create($b)) | Out-Null
    if (Test-Path $claudeExe) { Write-Host '[FIXED] Claude Code installed'; $fixed += 'Claude Code' }
    else { Write-Host '[X] Could not install Claude Code'; $left += 'Claude Code' }
  } catch { Write-Host '[X] Could not install Claude Code'; $left += 'Claude Code' }
}

# 2. PATH (user) + PowerShell profile
$userPath = [Environment]::GetEnvironmentVariable('PATH','User')
if ($null -eq $userPath) { $userPath = '' }
$adds = @()
foreach ($one in @($claudeBin, $bin)) {
  if ((Test-Path $one) -and ($userPath -notlike ('*' + $one + '*'))) {
    $userPath = ($one + ';' + $userPath).TrimEnd(';'); $adds += $one
  }
}
if ($adds.Count -gt 0) {
  [Environment]::SetEnvironmentVariable('PATH', $userPath, 'User')
  Write-Host '[FIXED] PATH updated'; $fixed += 'PATH'
} else { Write-Host '[OK] PATH' }

try {
  $marker = '# volcano-path'
  $line = ('$env:PATH = "' + $claudeBin + ';' + $bin + ';$env:PATH"  ' + $marker)
  $docs = Join-Path $env:USERPROFILE 'Documents'
  $plantedAny = $false
  foreach ($pf in @((Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
                    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'))) {
    $dir = Split-Path -Parent $pf
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $cur = ''
    if (Test-Path $pf) {
      try { (Get-Item $pf -Force).Attributes = 'Normal' } catch {}
      $cur = Get-Content $pf -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($null -eq $cur) { $cur = '' }
    }
    if ($cur -notlike ('*' + $marker + '*')) { Add-Content -Path $pf -Value $line -Encoding UTF8; $plantedAny = $true }
  }
  if ($plantedAny) { Write-Host '[FIXED] PowerShell profile'; $fixed += 'profile' }
  else { Write-Host '[OK] PowerShell profile' }
} catch { Write-Host '[!] Profile not updated (not fatal)' }

# 3. VS Code + extension
$codeCli = $null
foreach ($c in @((Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
                 'C:\Program Files\Microsoft VS Code\bin\code.cmd')) {
  if (Test-Path $c) { $codeCli = $c; break }
}
if (-not $codeCli -and (Have 'code')) { $codeCli = 'code' }
if ($codeCli) {
  Write-Host '[OK] VS Code'
  try {
    $exts = & $codeCli --list-extensions 2>$null
    if ($exts -match 'anthropic.claude-code') { Write-Host '[OK] Claude Code extension' }
    else {
      Write-Host '[..] Installing the Claude Code extension'
      & $codeCli --install-extension anthropic.claude-code --force 2>&1 | Out-Null
      Write-Host '[FIXED] Claude Code extension'; $fixed += 'VS Code extension'
    }
  } catch { Write-Host '[!] Could not check the extension'; $left += 'VS Code extension' }
} else { Write-Host '[!] VS Code not found (optional)'; $left += 'VS Code' }

# 4. Workspace settings so the VS Code terminal finds claude
try {
  if (-not (Test-Path $jobs)) { New-Item -ItemType Directory -Force -Path $jobs | Out-Null }
  $vsc = Join-Path $jobs '.vscode'
  if (-not (Test-Path $vsc)) { New-Item -ItemType Directory -Force -Path $vsc | Out-Null }
  $st = @{
    'security.workspace.trust.enabled' = $false
    'terminal.integrated.env.windows'  = @{ 'PATH' = ($claudeBin + ';' + $bin + ';${env:PATH}') }
  } | ConvertTo-Json -Depth 5
  [IO.File]::WriteAllText((Join-Path $vsc 'settings.json'), ($st -replace "`r?`n", "`r`n"),
                          (New-Object Text.UTF8Encoding $false))
  Write-Host '[OK] Workspace settings'
} catch { Write-Host '[!] Workspace settings not written' }

# 5. Python side (only report - repair needs the full installer)
if (Test-Path $venvPy) { Write-Host '[OK] Python' }
else { Write-Host '[X] Python is missing - run setup.bat again'; $left += 'Python' }

Write-Host ''
Write-Host '======================================'
if ($fixed.Count -gt 0) { Write-Host ('Fixed: ' + ($fixed -join ', ')) }
if ($left.Count -gt 0)  { Write-Host ('Still missing: ' + ($left -join ', ')) }
if ($fixed.Count -eq 0 -and $left.Count -eq 0) { Write-Host 'Everything was already fine.' }
Write-Host ''
Write-Host 'Close this window and open a new one.'
Write-Host 'Then in VS Code press the Claude icon on the left (or Ctrl+Esc).'
Write-Host ''
Read-Host 'Press Enter to close'
