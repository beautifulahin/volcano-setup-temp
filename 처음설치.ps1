# 볼케이노 — 처음 설치 (윈도우)
#
#   이 파일은 「처음설치.bat」 이 부릅니다. 직접 두 번 누르지 않으셔도 됩니다.
#
#  ■ 하는 일
#    옆의 volcano-windows.zip 을 풀고 → 「인터넷에서 받음」 표를 떼고(Unblock-File) →
#    사용자 폴더에 놓고 → 엽니다. 나머지 설치는 앱 창 안에서 이어집니다.
#    관리자 권한을 쓰지 않습니다.
#
#  ※ 이 파일은 UTF-8 BOM 으로 저장한다. BOM 이 없으면 윈도우 PowerShell 5.1 이
#    한글을 깨뜨린다. .bat 에는 한글을 한 글자도 넣지 않는다 —
#    cmd 는 배치 파일을 시스템 코드페이지(CP949)로 읽어 UTF-8 한글을 전부 깨뜨린다.

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

function 붙잡기 {
  # 사람이 읽고 나서 닫게 창을 붙잡는다. 사람이 없는 자리(시험)에서는 그냥 지나간다.
  if ($env:VOLCANO_NO_PAUSE -eq '1') { return }
  try { Read-Host '  엔터를 누르면 창이 닫힙니다' | Out-Null } catch {}
}

$여기 = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$꾸러미 = Join-Path $여기 'volcano-windows.zip'

# 놓을 자리 — 평소에는 %LOCALAPPDATA%\Programs\Volcano (install.ps1 과 같은 자리).
# 배포물 안·놓을 자리의 이름은 전부 ASCII 다. 윈도우 PowerShell 5.1 의 Expand-Archive 가
# 한글 이름을 제대로 못 풀어 설치가 통째로 죽었다(실측 2026-09-05). 사람이 보는 말만 한글.
# 시험은 VOLCANO_DEST 로만 한다. %LOCALAPPDATA%\volcano 는 설치본체가 도구·열쇠를 넣는 자리라 쓰지 않는다.
$뿌리 = if ($env:VOLCANO_DEST) { $env:VOLCANO_DEST } else { $env:USERPROFILE }
$윗자리 = if ($env:VOLCANO_DEST) { $env:VOLCANO_DEST } else { $env:LOCALAPPDATA }
$놓을자리 = Join-Path (Join-Path $윗자리 'Programs') 'Volcano'

Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host '  볼케이노 처음 설치'
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host ('  설치 자리 : ' + (Join-Path $놓을자리 'volcano.exe'))
if ($env:VOLCANO_DEST) { Write-Host '  (시험 자리입니다 — 진짜 설치 자리는 건드리지 않습니다)' }
Write-Host ''

if (-not (Test-Path $꾸러미)) {
  Write-Host '  ✗ 이 파일 옆에서 volcano-windows.zip 을 찾지 못했습니다.'
  Write-Host '    받은 파일을 전부 같은 폴더에 두고 다시 두 번 눌러 주세요.'
  Write-Host ('    지금 폴더: ' + $여기)
  Write-Host ''
  붙잡기
  exit 1
}

$일터 = Join-Path ([IO.Path]::GetTempPath()) ('volcano_setup_' + (Get-Random))

try {
  Write-Host '[1/4] 인터넷에서 받음 표를 뗍니다...'
  try { Unblock-File -Path $꾸러미 } catch {}

  Write-Host '[2/4] 압축을 푸는 중...'
  New-Item -ItemType Directory -Force -Path $일터 | Out-Null
  Expand-Archive -Path $꾸러미 -DestinationPath $일터 -Force

  $앱파일 = Get-ChildItem -Path $일터 -Recurse -Filter 'volcano.exe' | Select-Object -First 1
  if (-not $앱파일) { throw '압축 안에서 volcano.exe 를 찾지 못했습니다.' }

  if (Test-Path $놓을자리) {
    # 지우지 않는다 — 날짜를 붙여 옆으로 치워 둔다.
    $치울곳 = Join-Path $뿌리 ('.volcano_prev\' + (Get-Date -Format 'yyyyMMdd_HHmm'))
    New-Item -ItemType Directory -Force -Path $치울곳 | Out-Null
    Move-Item -Force $놓을자리 (Join-Path $치울곳 'Volcano')
    Write-Host ('[3/4] 이미 있던 것은 지우지 않고 옮겨 두었습니다 -> ' + $치울곳)
  } else {
    Write-Host '[3/4] 처음 설치입니다.'
  }

  New-Item -ItemType Directory -Force -Path $놓을자리 | Out-Null
  Copy-Item -Path (Join-Path $앱파일.DirectoryName '*') -Destination $놓을자리 -Recurse -Force
  Get-ChildItem -Path $놓을자리 -Recurse -File | ForEach-Object { try { Unblock-File -Path $_.FullName } catch {} }

  $앱 = Join-Path $놓을자리 'volcano.exe'
  Write-Host ('      넣었습니다 -> ' + $앱)

  if ($env:VOLCANO_NO_RUN -eq '1') {
    Write-Host '[4/4] 놓기만 했습니다 (VOLCANO_NO_RUN=1)'
  } else {
    Write-Host '[4/4] 실행합니다...'
    Start-Process -FilePath $앱 -WorkingDirectory $놓을자리
  }
} catch {
  Write-Host ''
  Write-Host ('  ✗ 설치를 끝내지 못했습니다 — ' + $_.Exception.Message)
  Write-Host '    파일을 다시 받아 같은 폴더에 두고 한 번 더 해 주세요.'
  Write-Host ''
  try { Remove-Item -Recurse -Force $일터 } catch {}
  붙잡기
  exit 1
}

try { Remove-Item -Recurse -Force $일터 } catch {}

Write-Host ''
Write-Host '  ✅ 다 됐습니다. 잠시 뒤 볼케이노 창이 열립니다.'
Write-Host '     나머지 설치는 그 창 안에서 이어집니다 — 단추만 누르시면 됩니다.'
Write-Host ''
Write-Host '     다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다.'
Write-Host ''
붙잡기
exit 0
