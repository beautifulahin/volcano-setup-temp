# 볼케이노 — 처음 설치 (윈도우)
#
#   이 파일은 「setup.bat」 이 부릅니다. 직접 두 번 누르지 않으셔도 됩니다.
#
#  ■ 하는 일
#    옆의 volcano-windows.zip 을 풀고 → 「인터넷에서 받음」 표를 떼고(Unblock-File) →
#    사용자 폴더에 놓고 → 엽니다. 나머지 설치는 앱 창 안에서 이어집니다.
#    관리자 권한을 쓰지 않습니다.
#
#  ※ 이 파일은 UTF-8 BOM 으로 저장한다. BOM 이 없으면 윈도우 PowerShell 5.1 이
#    한글을 깨뜨린다. .bat 에는 한글을 한 글자도 넣지 않는다 —
#    cmd 는 배치 파일을 시스템 코드페이지(CP949)로 읽어 UTF-8 한글을 전부 깨뜨린다.

# ★ 이름은 ASCII — 변수·함수 이름에 한글을 쓰지 않는다. 한국어 윈도우에서 파서가 죽는다(실측 2026-09-05).
#   irm | iex 로 받으면 PowerShell 5.1 이 본문을 UTF-8 로 안 읽어 $한글 이름이 깨진 바이트가 되고
#   ParserError 가 화면을 덮는다. 화면에 나가는 **문자열**은 한글 그대로 둔다(깨져도 죽지는 않는다).

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

function HoldWindow {
  # 사람이 읽고 나서 닫게 창을 붙잡는다. 사람이 없는 자리(시험)에서는 그냥 지나간다.
  if ($env:VOLCANO_NO_PAUSE -eq '1') { return }
  try { Read-Host '  엔터를 누르면 창이 닫힙니다' | Out-Null } catch {}
}

$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$pkg = Join-Path $here 'volcano-windows.zip'

# 놓을 자리 — 평소에는 %LOCALAPPDATA%\Programs\Volcano (install.ps1 과 같은 자리).
# 배포물 안·놓을 자리의 이름은 전부 ASCII 다. 윈도우 PowerShell 5.1 의 Expand-Archive 가
# 한글 이름을 제대로 못 풀어 설치가 통째로 죽었다(실측 2026-09-05). 사람이 보는 말만 한글.
# 시험은 VOLCANO_DEST 로만 한다. %LOCALAPPDATA%\volcano 는 설치본체가 도구·열쇠를 넣는 자리라 쓰지 않는다.
$root = if ($env:VOLCANO_DEST) { $env:VOLCANO_DEST } else { $env:USERPROFILE }
$baseDir = if ($env:VOLCANO_DEST) { $env:VOLCANO_DEST } else { $env:LOCALAPPDATA }
$destDir = Join-Path (Join-Path $baseDir 'Programs') 'Volcano'

Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host '  볼케이노 처음 설치'
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host ('  설치 자리 : ' + (Join-Path $destDir 'volcano.exe'))
if ($env:VOLCANO_DEST) { Write-Host '  (시험 자리입니다 — 진짜 설치 자리는 건드리지 않습니다)' }
Write-Host ''

if (-not (Test-Path $pkg)) {
  Write-Host '  ✗ 이 파일 옆에서 volcano-windows.zip 을 찾지 못했습니다.'
  Write-Host '    받은 파일을 전부 같은 폴더에 두고 다시 두 번 눌러 주세요.'
  Write-Host ('    지금 폴더: ' + $here)
  Write-Host ''
  HoldWindow
  exit 1
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('volcano_setup_' + (Get-Random))

try {
  Write-Host '[1/4] 인터넷에서 받음 표를 뗍니다...'
  try { Unblock-File -Path $pkg } catch {}

  Write-Host '[2/4] 압축을 푸는 중...'
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  Expand-Archive -Path $pkg -DestinationPath $work -Force

  $exeFile = Get-ChildItem -Path $work -Recurse -Filter 'volcano.exe' | Select-Object -First 1
  if (-not $exeFile) { throw '압축 안에서 volcano.exe 를 찾지 못했습니다.' }

  if (Test-Path $destDir) {
    # 지우지 않는다 — 날짜를 붙여 옆으로 치워 둔다.
    $moveTo = Join-Path $root ('.volcano_prev\' + (Get-Date -Format 'yyyyMMdd_HHmm'))
    New-Item -ItemType Directory -Force -Path $moveTo | Out-Null
    Move-Item -Force $destDir (Join-Path $moveTo 'Volcano')
    Write-Host ('[3/4] 이미 있던 것은 지우지 않고 옮겨 두었습니다 -> ' + $moveTo)
  } else {
    Write-Host '[3/4] 처음 설치입니다.'
  }

  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  Copy-Item -Path (Join-Path $exeFile.DirectoryName '*') -Destination $destDir -Recurse -Force
  Get-ChildItem -Path $destDir -Recurse -File | ForEach-Object { try { Unblock-File -Path $_.FullName } catch {} }

  $appExe = Join-Path $destDir 'volcano.exe'
  Write-Host ('      넣었습니다 -> ' + $appExe)

  if ($env:VOLCANO_NO_RUN -eq '1') {
    Write-Host '[4/4] 놓기만 했습니다 (VOLCANO_NO_RUN=1)'
  } else {
    # ★ 앱 창을 따로 찾아 들어가지 않게, **이 창에서 그대로 이어서** 한다.
    #   (사용자 지시 2026-09-05: 「어플 찾아 들어가야 해서 귀찮다」)
    #   설치본체를 VOLCANO_APP 없이 돌리면 10단계가 이 창에서 로그인·승인·열쇠까지
    #   묻고, 끝나면 클로드코드를 그 자리에서 연다. 앱은 나중에 설정을 볼 때 쓴다.
    Write-Host '[4/4] 이어서 설치합니다...'
    Write-Host ''
    $vHomeDir = if ($env:VOLCANO_DEST) { Join-Path $env:VOLCANO_DEST 'volcano' }
                else { Join-Path $env:LOCALAPPDATA 'volcano' }
    $bodyPs1  = Join-Path $vHomeDir '설치기\설치본체.ps1'
    $bundled  = Join-Path $vHomeDir '앱동봉\설치본체.ps1'
    if (-not (Test-Path $bodyPs1)) { $bodyPs1 = $bundled }
    if (Test-Path $bodyPs1) {
      $env:VOLCANO_APP = ''      # 이 창이 사람 창이다 — 여기서 묻는다
      & $bodyPs1
    } else {
      # 처음이라 설치본체가 없다. 앱을 거치지 말고 여기서 직접 받는다.
      Write-Host '  · 처음이라 준비물을 먼저 받습니다...'
      $setupDir = Join-Path $vHomeDir '설치기'
      New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
      $ok = $false
      foreach ($nm in @('설치본체.ps1','설치마무리.py','점검.py','설정.json')) {
        try {
          $u = 'https://beautifulahin.github.io/volcano-setup-temp'.TrimEnd('/') + '/' + [uri]::EscapeDataString($nm)
          Invoke-WebRequest -Uri $u -OutFile (Join-Path $setupDir $nm) -UseBasicParsing -TimeoutSec 120
          if ($nm -eq '설치본체.ps1') { $ok = $true }
        } catch { Write-Host ('  ! ' + $nm + ' 을 받지 못했습니다') }
      }
      if ($ok) {
        $env:VOLCANO_APP = ''
        & (Join-Path $setupDir '설치본체.ps1')
      } else {
        Write-Host '  ! 준비물을 받지 못해 앱으로 넘깁니다.'
        Start-Process -FilePath $appExe -WorkingDirectory $destDir
      }
    }
  }
} catch {
  Write-Host ''
  Write-Host ('  ✗ 설치를 끝내지 못했습니다 — ' + $_.Exception.Message)
  Write-Host '    파일을 다시 받아 같은 폴더에 두고 한 번 더 해 주세요.'
  Write-Host ''
  try { Remove-Item -Recurse -Force $work } catch {}
  HoldWindow
  exit 1
}

try { Remove-Item -Recurse -Force $work } catch {}

Write-Host ''
Write-Host '  ✅ 다 됐습니다. 잠시 뒤 볼케이노 창이 열립니다.'
Write-Host '     나머지 설치는 그 창 안에서 이어집니다 — 단추만 누르시면 됩니다.'
Write-Host ''
Write-Host '     다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다.'
Write-Host ''
HoldWindow
exit 0
