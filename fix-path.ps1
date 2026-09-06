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

# 5. Python - repair it here too, not just report
if (Test-Path $venvPy) { Write-Host '[OK] Python' }
else {
  Write-Host '[..] Python is missing - installing (this takes a few minutes)'
  $env:UV_INSTALL_DIR = $bin
  $env:UV_UNMANAGED_INSTALL = $bin
  $env:UV_PYTHON_INSTALL_DIR = (Join-Path $vHome 'python')
  $env:UV_PYTHON_BIN_DIR = $bin
  $env:UV_TOOL_BIN_DIR = $bin
  $env:UV_NO_MODIFY_PATH = '1'
  $uv = $null
  foreach ($cand in @((Join-Path $bin 'uv.exe'), 'uv')) {
    if ($cand -eq 'uv') { if (Get-Command uv -ErrorAction SilentlyContinue) { $uv = 'uv'; break } }
    elseif (Test-Path $cand) { $uv = $cand; break }
  }
  if (-not $uv) {
    try {
      $b = (Invoke-WebRequest -Uri 'https://astral.sh/uv/install.ps1' -UseBasicParsing).Content
      if ($b -isnot [string]) { $b = [System.Text.Encoding]::UTF8.GetString($b) }
      & ([scriptblock]::Create($b)) 2>&1 | Out-Null
    } catch { }
    if (Test-Path (Join-Path $bin 'uv.exe')) { $uv = (Join-Path $bin 'uv.exe') }
  }
  if ($uv) {
    $before = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
      & $uv python install 3.12 2>&1 | Out-Null
      & $uv venv --seed --python 3.12 (Join-Path $vHome 'venv') 2>&1 | Out-Null
      if (Test-Path $venvPy) {
        & $uv pip install --python $venvPy --quiet pillow numpy opencv-python fonttools brotli 2>&1 | Out-Null
        & $uv pip install --python $venvPy --quiet openai-whisper 2>&1 | Out-Null
      }
    } finally { $ErrorActionPreference = $before }
  }
  if (Test-Path $venvPy) { Write-Host '[FIXED] Python installed'; $fixed += 'Python' }
  else { Write-Host '[X] Could not install Python - run setup.bat again'; $left += 'Python' }
}

Write-Host ''
Write-Host '======================================'
# 6. Git Bash - Claude Code on Windows runs every command through bash.exe.
#    Without it nothing Volcano asks for can run at all.
$gitBash = $null
foreach ($c in @(
    ($env:CLAUDE_CODE_GIT_BASH_PATH),
    (Join-Path $vHome 'git\bin\bash.exe'),
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'))) {
  if ($c -and (Test-Path $c)) { $gitBash = $c; break }
}
if (-not $gitBash) {
  Write-Host 'Installing Git Bash (required by Claude Code)...'
  try {
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest' -UseBasicParsing -TimeoutSec 120
    $asset = $rel.assets | Where-Object { $_.name -like 'PortableGit-*-64-bit.7z.exe' } | Select-Object -First 1
    if ($asset) {
      $tmp = Join-Path $vHome 'PortableGit.exe'
      Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing -TimeoutSec 600
      $gitDir = Join-Path $vHome 'git'
      & $tmp ('-o"' + $gitDir + '"') '-y' | Out-Null
      Remove-Item -Force $tmp -ErrorAction SilentlyContinue
      $maybe = Join-Path $gitDir 'bin\bash.exe'
      if (Test-Path $maybe) { $gitBash = $maybe }
    }
  } catch { }
}
if ($gitBash) {
  if (-not [Environment]::GetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH','User')) {
    [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $gitBash, 'User')
  }
  Write-Host ('[OK] Git Bash: ' + $gitBash)
  $fixed += 'Git Bash'
} else {
  Write-Host '[X] Git Bash missing - install Git for Windows from git-scm.com'
  $left += 'Git Bash'
}

if ($fixed.Count -gt 0) { Write-Host ('Fixed: ' + ($fixed -join ', ')) }
if ($left.Count -gt 0)  { Write-Host ('Still missing: ' + ($left -join ', ')) }
if ($fixed.Count -eq 0 -and $left.Count -eq 0) { Write-Host 'Everything was already fine.' }
Write-Host ''
Write-Host 'Close this window and open a new one.'
Write-Host 'Then in VS Code press the Claude icon on the left (or Ctrl+Esc).'
Write-Host ''
Read-Host 'Press Enter to close'
