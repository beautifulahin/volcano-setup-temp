# 볼케이노 — 처음 설치 (윈도우) · 내려받아 도는 본체
#
#   setup.bat 이 이 파일을 웹에서 받아 부릅니다. 사람이 직접 누르는 파일이 아닙니다.
#   setup.bat 한 개만 있으면 되도록, 필요한 것은 전부 여기서 받습니다
#   (사용자 지시 2026-09-06: 「한 파일로 하게해」·「setup.bat으로 다하게 해」).
#
#  ※ 이 파일은 UTF-8 BOM 으로 저장한다 — powershell -File 로 읽히므로 BOM 이 없으면
#    윈도우 PowerShell 5.1 이 한글을 깨뜨린다.
#  ★ 변수·함수 이름은 ASCII 만. 한국어 윈도우에서 파서가 죽는다(실측 2026-09-05).

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$BASE = 'https://beautifulahin.github.io/volcano-setup-temp'.TrimEnd('/')

function HoldWindow {
  if ($env:VOLCANO_NO_PAUSE -eq '1') { return }
  try { Read-Host '  엔터를 누르면 창이 닫힙니다' | Out-Null } catch {}
}

# 놓을 자리 — 시험은 VOLCANO_DEST 로만 한다.
$vHome = if ($env:VOLCANO_DEST) { Join-Path $env:VOLCANO_DEST 'volcano' } else { Join-Path $env:LOCALAPPDATA 'volcano' }
$setupDir = Join-Path $vHome '설치기'

Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host '  볼케이노 처음 설치'
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host '  이 창에서 전부 끝납니다. 10~20분쯤 걸립니다.'
Write-Host '  관리자 비밀번호는 묻지 않습니다.'
if ($env:VOLCANO_DEST) { Write-Host '  (시험 자리입니다 — 진짜 자리는 건드리지 않습니다)' }
Write-Host ''

try {
  New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
} catch {
  Write-Host ('  ✗ 자리를 만들지 못했습니다 — ' + $_.Exception.Message)
  HoldWindow; exit 1
}

# ★ 있는 것을 쓰지 말고 **늘 새로 받는다.** 옛 파일을 쓰던 탓에 고쳐 올린 판이
#   이미 깐 사람에게 며칠이 지나도 안 갔다(실측 2026-09-05).
Write-Host '  · 최신 설치기를 받습니다...'
$bodyPs1 = Join-Path $setupDir '설치본체.ps1'
$gotBody = $false
foreach ($nm in @('설치본체.ps1','설치마무리.py','점검.py','설정.json','fix-path.ps1')) {
  try {
    $u = $BASE + '/' + [uri]::EscapeDataString($nm)
    $tmpFile = Join-Path $setupDir ($nm + '.내려받는중')
    Invoke-WebRequest -Uri $u -OutFile $tmpFile -UseBasicParsing -TimeoutSec 180
    $target = Join-Path $setupDir $nm
    if (Test-Path $target) { try { (Get-Item $target -Force).Attributes = 'Normal' } catch {} }
    Move-Item -Force $tmpFile $target
    if ($nm -eq '설치본체.ps1') { $gotBody = $true }
  } catch {
    Write-Host ('  ! ' + $nm + ' 을 받지 못했습니다 — 있던 것을 씁니다')
  }
}

if (-not $gotBody -and -not (Test-Path $bodyPs1)) {
  Write-Host ''
  Write-Host '  ✗ 설치기를 받지 못했습니다.'
  Write-Host '    인터넷 연결을 확인하고 setup.bat 을 한 번 더 눌러 주세요.'
  Write-Host ('    받는 곳: ' + $BASE)
  Write-Host ''
  HoldWindow; exit 1
}

# 고침이(fix-path.ps1)를 바탕화면에 놓아 둔다 — 나중에 뭔가 안 될 때 누를 것.
try {
  $fixSrc = Join-Path $setupDir 'fix-path.ps1'
  if (Test-Path $fixSrc) {
    $deskDir = if ($env:VOLCANO_DEST) { Join-Path $env:VOLCANO_DEST 'Desktop' } else { Join-Path $env:USERPROFILE 'Desktop' }
    if (Test-Path $deskDir) {
      $fixDst = Join-Path $deskDir 'volcano-fix.ps1'
      if (Test-Path $fixDst) { try { (Get-Item $fixDst -Force).Attributes = 'Normal' } catch {} }
      Copy-Item -Force $fixSrc $fixDst
    }
  }
} catch {}

$env:VOLCANO_APP = ''      # 이 창이 사람 창이다 — 여기서 묻는다
& $bodyPs1
exit $LASTEXITCODE
