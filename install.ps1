# 볼케이노 — 윈도우 한 줄 설치
#
#   irm https://volcanoai.io/setup/install.ps1 | iex
#
# ★ 이 파일은 irm | iex 로 도므로 **화면에 나가는 글은 영문**이다.
#   한글 안내는 파일로 읽히는 설치본체.ps1 과 볼케이노 앱 창이 한다.
#   뿌리: 윈도우 PowerShell 5.1 의 Invoke-RestMethod 는 응답에 charset 이 없으면 본문을
#   UTF-8 로 안 읽는다. 그래서 문자열 속 한글이 통째로 깨져 나온다
#   (실측 2026-09-05 · 사장님 화면 — 코드는 멀쩡히 도는데 안내 글자만 âââ… 로 나왔다).
#   BOM 으로는 못 고친다 — BOM 을 붙이면 그 글자가 첫 줄 앞에 그대로 남아
#   「'#' 은(는) 내부 또는 외부 명령이 아닙니다」 라는 빨간 줄이 맨 위에 뜬다(실측).
#   그래서 이 파일만 「BOM 없음 + 화면 출력 영문」 이다.
#   주석은 화면에 안 나가므로 한글 그대로 둔다.
#   파일로 읽히는 설치본체.ps1·setup.ps1 은 반대로 BOM 이 꼭 있어야 하고 한글 그대로다.
#   검사: 앱/릴리스.sh → 이름점검.py 가 이 파일의 출력 문자열에 비ASCII 가 있으면 멈춘다.
#
# 여기서 하는 일은 「앱을 놓고 여는 것」 뿐이다.
# 파이썬·ffmpeg·받아쓰기 같은 나머지 설치는 앱이 제 창 안에서 이어서 한다.
# 관리자 권한을 쓰지 않는다. 전부 사용자 폴더에만 넣는다.

# ★ 이름도 ASCII — 변수·함수 이름에 한글을 쓰지 않는다. 한국어 윈도우에서 파서가 죽는다(실측 2026-09-05).
#   irm | iex 로 받으면 $한글 이름이 깨진 바이트가 되어 ParserError 가 화면을 덮는다.

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
  Write-Host ("[X] " + $msg) -ForegroundColor Red
  Write-Host ("    " + $todo)
  Read-Host "  Press Enter to close this window"
  exit 1
}

Say ""
Say "===================================="
Say "  Volcano installer"
Say "===================================="
Say ("  Install to : " + (Join-Path $destDir 'volcano.exe'))
if ($isTestDest) { Say "  (Test location - your real install is not touched.)" }

$work = Join-Path $env:TEMP ("volcano_" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $work | Out-Null

Say "[1/5] Downloading... (about 40MB, 10 sec - 1 min)"
$dlFile = Join-Path $work $pkgName
try {
  Invoke-WebRequest -Uri ($baseUrl + '/' + $pkgName) -OutFile $dlFile -UseBasicParsing
} catch {
  Fail "Could not download." "Check your internet connection and paste the same command once more. ($baseUrl/$pkgName)"
}
if (-not (Test-Path $dlFile) -or (Get-Item $dlFile).Length -lt 1000) {
  Fail "The downloaded file is empty." "Please run the same command again in a moment."
}

Say "[2/5] Unpacking..."
$unzipDir = Join-Path $work 'x'
try { Expand-Archive -Path $dlFile -DestinationPath $unzipDir -Force }
catch { Fail "Could not unpack the file." "The download may have been cut off. Please run the same command once more." }

$exe = Get-ChildItem -Path $unzipDir -Recurse -Filter 'volcano.exe' | Select-Object -First 1
if (-not $exe) { Fail "volcano.exe was not found inside the package." "Please tell the developer." }

# 이미 있으면 지우지 말고 옮겨 둔다
if (Test-Path $destDir) {
  # 도는 볼케이노가 있으면 파일을 못 옮긴다. 먼저 곱게 끈다.
  # (실측 2026-09-05 — 「이미 있는 앱을 옮기지 못했습니다」로 멈췄다.)
  try {
    Get-Process -Name 'volcano' -ErrorAction SilentlyContinue | ForEach-Object {
      $_.CloseMainWindow() | Out-Null
    }
    Start-Sleep -Seconds 2
    Get-Process -Name 'volcano' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
  } catch { }
  $moveTo = Join-Path $keepRoot ('.volcano_prev\' + (Get-Date -Format 'yyyyMMdd_HHmm'))
  New-Item -ItemType Directory -Force -Path $moveTo | Out-Null
  try { Move-Item -Force $destDir (Join-Path $moveTo 'Volcano') }
  catch { Fail "Could not move the app that is already installed. (Cannot replace running app)" "Close all Volcano windows and try again." }
  Say "[3/5] The old version was kept, not deleted -> $moveTo"
} else {
  Say "[3/5] This is a first install."
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item -Path (Join-Path $exe.DirectoryName '*') -Destination $destDir -Recurse -Force
$appExe = Join-Path $destDir 'volcano.exe'
Say "[4/5] Installed -> $appExe"

# 인터넷에서 받았다는 표를 떼어 둔다 (SmartScreen 경고를 줄인다)
try { Unblock-File -Path $appExe } catch {}

Say "[5/5] Starting..."
if ($env:VOLCANO_NO_RUN -eq '1') {
  Say ""
  Say "[OK] Files are in place only (VOLCANO_NO_RUN=1) -> $appExe"
  try { Remove-Item -Recurse -Force $work } catch {}
  exit 0
}
try {
  # 놓은 그 자리의 것을 연다 (지금 창의 환경변수를 그대로 물려받는다)
  Start-Process -FilePath $appExe -WorkingDirectory $destDir
  Say ""
  Say "[OK] Done here. The Volcano window opens in a moment."
  Say "     The rest of the setup continues in that window - just click the buttons."
} catch {
  Say ""
  Say "[OK] The app is installed, but it did not open by itself."
  Say "     Please double-click this file: $appExe"
}

try { Remove-Item -Recurse -Force $work } catch {}
Say ""
Say "   Next time, just double-click the Volcano icon on your desktop."
Say "   Note: this installer speaks English, but the Volcano window will be in Korean."
Say ""
