# 볼케이노 — 윈도우 한 줄 설치
#
#   irm https://volcanoai.io/setup/install.ps1 | iex
#
# ★ 이 파일에는 UTF-8 BOM 을 붙이지 않는다.
#   다른 .ps1 과 반대다. 이것만은 파일로 읽히지 않고 irm 이 받아 iex 로 바로 돈다.
#   BOM 을 붙이면 그 글자가 첫 줄 앞에 그대로 남아
#   「'﻿#' 은(는) 내부 또는 외부 명령이 아닙니다」 라는 빨간 줄이 맨 위에 뜬다 (실측).
#   파일로 읽히는 설치본체.ps1·setup.ps1 은 반대로 BOM 이 꼭 있어야 한다.
#
# 여기서 하는 일은 「앱을 놓고 여는 것」 뿐이다.
# 파이썬·ffmpeg·받아쓰기 같은 나머지 설치는 앱이 제 창 안에서 이어서 한다.
# 관리자 권한을 쓰지 않는다. 전부 사용자 폴더에만 넣는다.

# ★ 이름은 ASCII — 변수·함수 이름에 한글을 쓰지 않는다. 한국어 윈도우에서 파서가 죽는다(실측 2026-09-05).
#   irm | iex 로 받으면 PowerShell 5.1 이 본문을 UTF-8 로 안 읽어 $한글 이름이 깨진 바이트가 되고
#   ParserError 가 화면을 덮는다. 화면에 나가는 **문자열**은 한글 그대로 둔다(깨져도 죽지는 않는다).

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$baseUrl = ('https://beautifulahin.github.io/volcano-setup-temp').TrimEnd('/')
if ($env:VOLCANO_BASE) { $baseUrl = $env:VOLCANO_BASE.TrimEnd('/') }

# 놓을 자리
#   · 평소 : %LOCALAPPDATA%\Programs\Volcano   (배포물·설치 자리 이름은 전부 ASCII)
#   · 시험 : VOLCANO_DEST 를 주면 그 밑에만 놓고 거기 것을 연다 (맥의 $VOLCANO_DEST/Applications 와 같은 자리)
#           VOLCANO_APP_DEST 는 자리를 통째로 지정하는 예전 이름 — 함께 받는다
$isTestDest = $false
if ($env:VOLCANO_APP_DEST)  { $destDir = $env:VOLCANO_APP_DEST; $isTestDest = $true }
elseif ($env:VOLCANO_DEST)  { $destDir = (Join-Path $env:VOLCANO_DEST 'Programs\Volcano'); $isTestDest = $true }
else                        { $destDir = (Join-Path $env:LOCALAPPDATA 'Programs\Volcano') }
# 이미 있던 것을 치워 둘 자리도 시험 자리를 따라간다
$keepRoot = if ($isTestDest) { if ($env:VOLCANO_DEST) { $env:VOLCANO_DEST } else { $destDir } } else { $env:USERPROFILE }
$pkgName   = 'volcano-windows.zip'

function Say($msg) { Write-Host $msg }
function Fail($msg, $todo) {
  Write-Host ""
  Write-Host ("❌ " + $msg) -ForegroundColor Red
  Write-Host ("   " + $todo)
  Read-Host "  엔터를 누르면 창이 닫힙니다"
  exit 1
}

Say ""
Say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Say "  볼케이노 설치"
Say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Say ("  설치 자리 : " + (Join-Path $destDir 'volcano.exe'))
if ($isTestDest) { Say "  (시험 자리입니다 — 진짜 설치 자리는 건드리지 않습니다)" }

$work = Join-Path $env:TEMP ("volcano_" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $work | Out-Null

Say "[1/5] 내려받는 중… (40MB 정도, 10초~1분)"
$dlFile = Join-Path $work $pkgName
try {
  Invoke-WebRequest -Uri ($baseUrl + '/' + $pkgName) -OutFile $dlFile -UseBasicParsing
} catch {
  Fail "내려받지 못했습니다." "인터넷 연결을 확인하고 같은 명령을 한 번 더 붙여넣어 주세요. ($baseUrl/$pkgName)"
}
if (-not (Test-Path $dlFile) -or (Get-Item $dlFile).Length -lt 1000) {
  Fail "받은 파일이 비어 있습니다." "잠시 뒤 같은 명령을 다시 해 주세요."
}

Say "[2/5] 압축을 푸는 중…"
$unzipDir = Join-Path $work 'x'
try { Expand-Archive -Path $dlFile -DestinationPath $unzipDir -Force }
catch { Fail "압축을 풀지 못했습니다." "받다가 끊겼을 수 있습니다. 같은 명령을 한 번 더 해 주세요." }

$exe = Get-ChildItem -Path $unzipDir -Recurse -Filter 'volcano.exe' | Select-Object -First 1
if (-not $exe) { Fail "압축 안에서 volcano.exe 를 찾지 못했습니다." "만든 사람에게 알려 주세요." }

# 이미 있으면 지우지 말고 옮겨 둔다
if (Test-Path $destDir) {
  $moveTo = Join-Path $keepRoot ('.volcano_prev\' + (Get-Date -Format 'yyyyMMdd_HHmm'))
  New-Item -ItemType Directory -Force -Path $moveTo | Out-Null
  try { Move-Item -Force $destDir (Join-Path $moveTo 'Volcano') }
  catch { Fail "이미 있는 앱을 옮기지 못했습니다." "볼케이노가 실행 중이면 먼저 끄고 다시 해 주세요." }
  Say "[3/5] 이미 있던 것은 지우지 않고 옮겨 두었습니다 → $moveTo"
} else {
  Say "[3/5] 처음 설치입니다."
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item -Path (Join-Path $exe.DirectoryName '*') -Destination $destDir -Recurse -Force
$appExe = Join-Path $destDir 'volcano.exe'
Say "[4/5] 넣었습니다 → $appExe"

# 인터넷에서 받았다는 표를 떼어 둔다 (SmartScreen 경고를 줄인다)
try { Unblock-File -Path $appExe } catch {}

Say "[5/5] 실행합니다…"
if ($env:VOLCANO_NO_RUN -eq '1') {
  Say ""
  Say "✅ 놓기만 했습니다 (VOLCANO_NO_RUN=1) → $appExe"
  try { Remove-Item -Recurse -Force $work } catch {}
  exit 0
}
try {
  # 놓은 그 자리의 것을 연다 (지금 창의 환경변수를 그대로 물려받는다)
  Start-Process -FilePath $appExe -WorkingDirectory $destDir
  Say ""
  Say "✅ 여기까지 끝났습니다. 잠시 뒤 볼케이노 창이 열립니다."
  Say "   나머지 설치는 그 창 안에서 이어집니다 — 단추만 누르시면 됩니다."
} catch {
  Say ""
  Say "✅ 앱은 넣었습니다. 다만 자동으로 열리지 않았습니다."
  Say "   이 파일을 두 번 눌러 주세요: $appExe"
}

try { Remove-Item -Recurse -Force $work } catch {}
Say ""
Say "   다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다."
Say ""
