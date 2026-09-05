# 볼케이노 설치기 본체 — 윈도우
# 관리자 권한을 쓰지 않는다. 전부 사용자 폴더에만 설치한다.
# 여러 번 돌려도 안전하다. 이미 있는 것은 건너뛴다.
#
# 볼케이노 앱이 제 창 안에서 이 파일을 자식으로 돌린다($env:VOLCANO_APP = 1).
# 그때는 9단계에서 앱 바로가기를 놓고, 10단계(마무리)는 앱이 이어받으므로 건너뛴다.
# 앱 없이 이 파일만 돌려도 예전 그대로 끝까지 간다.

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$받는곳 = ('https://beautifulahin.github.io/volcano-setup-temp').TrimEnd('/')
if ($env:VOLCANO_BASE) { $받는곳 = $env:VOLCANO_BASE.TrimEnd('/') }

$DEST = if ($env:VOLCANO_DEST) { $env:VOLCANO_DEST } else { $env:LOCALAPPDATA }
$집    = Join-Path $DEST 'volcano'
$BIN   = Join-Path $집 'bin'
$KEYS  = Join-Path $집 'keys'
$RUNNER= Join-Path $집 'runner'
$설치기 = Join-Path $집 '설치기'
$VENV  = Join-Path $집 'venv'
$PY    = Join-Path $VENV 'Scripts\python.exe'
# 작업장. 시험(VOLCANO_DEST)일 때는 진짜 홈이 아니라 시험 자리 밑에 만든다.
$JOBS  = if ($env:VOLCANO_JOBS_DIR) { $env:VOLCANO_JOBS_DIR }
         elseif ($env:VOLCANO_DEST) { Join-Path $DEST 'volcano_jobs' }
         else                       { Join-Path $env:USERPROFILE 'volcano_jobs' }
$LOG   = Join-Path $집 '설치.log'
$SRC   = $env:VOLCANO_SRC

foreach ($자리 in @($집,$BIN,$KEYS,$RUNNER,$설치기,$JOBS)) { New-Item -ItemType Directory -Force -Path $자리 | Out-Null }

function 기록($글) { try { Add-Content -Path $LOG -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $글) -Encoding UTF8 } catch {} }
function 말($글)   { Write-Host $글; 기록 $글 }
function 단계($번,$글) { Write-Host ""; Write-Host ("[{0}/10] {1}" -f $번,$글) -ForegroundColor Cyan; 기록 "[$번/10] $글" }
function 좋음($글) { Write-Host ("  OK  " + $글) -ForegroundColor Green; 기록 "OK $글" }
function 넘김($글) { Write-Host ("   ·  " + $글 + " — 이미 있어 건너뜁니다"); 기록 "SKIP $글" }
function 경고($글,$할일) { Write-Host ("  !   " + $글) -ForegroundColor Yellow; Write-Host ("      -> " + $할일) -ForegroundColor Yellow; 기록 "WARN $글 :: $할일" }
function 실패($글,$할일) {
  Write-Host ""; Write-Host ("  X   " + $글) -ForegroundColor Red
  Write-Host ("      할 일: " + $할일) -ForegroundColor Red
  Write-Host ("  자세한 기록: " + $LOG)
  기록 "FAIL $글 :: $할일"
  Read-Host "  엔터를 누르면 창이 닫힙니다"
  exit 1
}
function 받기($주소,$자리) {
  Invoke-WebRequest -Uri $주소 -OutFile ($자리 + '.내려받는중') -UseBasicParsing -TimeoutSec 1800
  Move-Item -Force ($자리 + '.내려받는중') $자리
}
function 꾸러미받기($이름,$자리) {
  if ($SRC -and (Test-Path (Join-Path $SRC $이름))) { Copy-Item -Force (Join-Path $SRC $이름) $자리; return }
  받기 "$받는곳/$이름" $자리
}
function 있나($이름) { $null -ne (Get-Command $이름 -ErrorAction SilentlyContinue) }
function 비었나($값) { return (-not $값) -or ($값 -eq 'TODO') }
function 홑($글) { "'" + (([string]$글) -replace "'", "''") + "'" }

# ── 윈도우 .bat 은 순수 ASCII 로만 쓴다 ──────────────────────
# cmd 는 .bat 을 시스템 코드페이지(한국어 윈도우는 CP949)로 읽는다. UTF-8 한글을 넣으면
# 파일 전체가 깨진 바이트가 되어 「내부 또는 외부 명령이 아닙니다」 만 쏟아진다.
# 파일 안의 chcp 65001 은 이미 읽기 시작한 뒤라 소용이 없다.
# 그래서 .bat 은 껍데기만 두고, 한글과 실제 일은 같은 이름의 .ps1(UTF-8 BOM)에 담는다.
# PowerShell 5.1 은 BOM 없는 UTF-8 한글도 깨뜨리므로 BOM 은 반드시 붙인다.
function 유티에프팔쓰기($자리, $글) {
  [IO.File]::WriteAllText($자리, (($글 -replace "`r?`n", "`r`n")), (New-Object Text.UTF8Encoding $true))
}
function 배치쌍쓰기($배치자리, $파워셸글, [switch]$숨김) {
  $짝 = [IO.Path]::ChangeExtension($배치자리, '.ps1')
  유티에프팔쓰기 $짝 $파워셸글
  if ($숨김) { try { (Get-Item $짝 -Force).Attributes = 'Hidden' } catch {} }
  $껍데기 = @'
@echo off
rem ============================================================
rem  Volcano launcher shell. KEEP THIS FILE PURE ASCII.
rem  cmd.exe reads a .bat with the system code page (CP949 on a
rem  Korean Windows), so UTF-8 Korean text here breaks every line.
rem  All Korean text lives in the sibling UTF-8-BOM .ps1 that has
rem  the same base name ("%~dpn0.ps1").
rem ============================================================
chcp 65001 >nul 2>nul
set "VOLCANO_PS1=%~dpn0.ps1"
if not exist "%VOLCANO_PS1%" (
  echo   [X] Missing helper file: "%VOLCANO_PS1%"
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%VOLCANO_PS1%"
exit /b %errorlevel%
'@
  [IO.File]::WriteAllText($배치자리, ($껍데기 -replace "`r?`n", "`r`n"), (New-Object Text.ASCIIEncoding))
}
function 자막필터되나($자리) {
  if (-not (Test-Path $자리)) { return $false }
  try { $목록 = & $자리 -hide_banner -filters 2>$null | Out-String } catch { return $false }
  return $목록 -match '\sass\s'
}

$env:PATH = "$BIN;" + (Join-Path $env:USERPROFILE '.local\bin') + ";" + $env:PATH

# ── 실행기 받기 (6단계 알맹이) ──────────────────────────────
# 앱도 이것만 따로 부른다($env:VOLCANO_ONLY_STEP=6). 받는 법이 두 벌이 되지 않게 함수 하나로 둔다.
function 실행기받기($주소,$sha) {
  if (비었나 $주소) {
    경고 "실행기 주소가 아직 비어 있습니다" "볼케이노 운영자가 주소를 정하면 앱을 다시 열 때 저절로 받아집니다. 따로 하실 일이 없습니다"
    return
  }
  $꾸러미 = Join-Path $집 '실행기꾸러미'
  try { 받기 $주소 $꾸러미 } catch { 실패 "실행기를 받지 못했습니다" "인터넷 연결을 확인하고 다시 돌려 주세요" }
  if (-not (비었나 $sha)) {
    $잰값 = (Get-FileHash $꾸러미 -Algorithm SHA256).Hash.ToLower()
    if ($잰값 -ne $sha.ToLower()) { 실패 "받은 실행기가 원본과 다릅니다" "인터넷이 불안정할 수 있습니다. 설치 명령을 한 번 더 돌려 주세요" }
    좋음 "실행기 원본 대조"
  }
  if ($주소 -match '\.zip$') { Expand-Archive -Path $꾸러미 -DestinationPath $RUNNER -Force }
  else {
    & tar -xzf $꾸러미 -C $RUNNER --strip-components=1 2>$null
    # 폴더 없이 파일만 든 꾸러미는 한 겹 벗기기가 아무것도 못 꺼낸다. 종료코드 말고 나온 것으로 본다.
    if (-not (Test-Path (Join-Path $RUNNER 'volcano_run.py'))) { & tar -xzf $꾸러미 -C $RUNNER }
  }
  Remove-Item -Force $꾸러미 -ErrorAction SilentlyContinue
  if (-not (Test-Path (Join-Path $RUNNER 'volcano_run.py'))) { 실패 "실행기 안에 volcano_run.py 가 없습니다" "만든 사람에게 알려 주세요" }
  좋음 "실행기 -> $RUNNER"
}

# 한 단계만 돌려 달라고 하면 그것만 돌리고 끝낸다.
# 설정.json 은 이미 있는 것을 그대로 읽는다 — 앱이 방금 받는곳에서 새로 받아 둔 것이다.
if ($env:VOLCANO_ONLY_STEP -eq '6') {
  $설정6 = @{}
  try { $설정6 = Get-Content (Join-Path $설치기 '설정.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
  $주소6 = if ($설정6.실행기_주소) { [string]$설정6.실행기_주소 } else { 'TODO' }
  $sha6  = if ($설정6.실행기_sha)  { [string]$설정6.실행기_sha }  else { 'TODO' }
  단계 6 "실행기 내려받기"
  실행기받기 $주소6 $sha6
  exit 0
}

Write-Host "────────────────────────────────────"
Write-Host " 볼케이노 설치기"
Write-Host " 설치 자리 : $집"
Write-Host " 작업장    : $JOBS"
Write-Host " 관리자 권한은 쓰지 않습니다."
Write-Host "────────────────────────────────────"
기록 "=== 설치 시작 dest=$집 ==="

# ── 1. 자리 만들기 ──────────────────────────────────────────
단계 1 "자리 만들기"
좋음 "$집 (도구·열쇠·설정)"
좋음 "$JOBS (작업장)"
$설정 = @{}
# 설정.json 만은 **받는곳 것이 먼저**다. 운영자가 실행기 주소를 채워 올리면
# 앱을 다시 굽지 않아도 그 값이 들어와야 하기 때문이다(다른 꾸러미는 앱이 품고 온 것이 먼저).
$설정자리 = Join-Path $설치기 '설정.json'
try { 받기 "$받는곳/설정.json" $설정자리; 좋음 "설정.json 을 받는곳에서 가져왔습니다" }
catch {
  if (Test-Path $설정자리) { Write-Host "  ·   설정.json - 받는곳에 못 닿아 있던 것을 그대로 씁니다" }
  elseif ($SRC -and (Test-Path (Join-Path $SRC '설정.json'))) {
    Copy-Item (Join-Path $SRC '설정.json') $설정자리 -Force; 좋음 "설정.json (앱이 품고 온 것)"
  } else {
    경고 "설정.json 을 가져오지 못했습니다" "인터넷 없이 돌리는 중이라면 넘어갑니다. 실행기·가입은 나중에 다시 돌리면 됩니다"
  }
}
try { $설정 = Get-Content $설정자리 -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $설정 = @{} }
$실행기_주소 = if ($설정.실행기_주소) { [string]$설정.실행기_주소 } else { 'TODO' }
$실행기_sha  = if ($설정.실행기_sha)  { [string]$설정.실행기_sha }  else { 'TODO' }

# ── 2. 파이썬 (uv) ──────────────────────────────────────────
단계 2 "파이썬 3.12 준비"
# uv 가 딴 자리(사용자 홈)를 건드리지 않게 전부 우리 폴더로 못박는다.
$env:UV_PYTHON_INSTALL_DIR = Join-Path $집 'python'
$env:UV_PYTHON_BIN_DIR     = $BIN
$env:UV_CACHE_DIR          = Join-Path $집 'cache'
$env:UV_TOOL_BIN_DIR       = $BIN
$env:UV_INSTALL_DIR        = $BIN
$env:UV_NO_MODIFY_PATH     = '1'
if (있나 'uv') { 넘김 'uv' }
else {
  try {
    & ([scriptblock]::Create((Invoke-WebRequest -Uri 'https://astral.sh/uv/install.ps1' -UseBasicParsing).Content)) *>> $LOG
  } catch { 실패 "uv 를 설치하지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요" }
  if (-not (있나 'uv')) { 실패 "uv 를 찾지 못합니다" "PowerShell 을 닫았다 열고 설치 명령을 한 번 더 돌려 주세요" }
  좋음 'uv'
}
& uv python install 3.12 *>> $LOG
if ($LASTEXITCODE -ne 0) { 실패 "파이썬 3.12 를 받지 못했습니다" "인터넷 연결을 확인하고 다시 돌려 주세요" }
if (Test-Path $PY) { 넘김 "파이썬 자리 $VENV" }
else {
  & uv venv --seed --python 3.12 $VENV *>> $LOG
  if (-not (Test-Path $PY)) { 실패 "파이썬 자리를 만들지 못했습니다" "$VENV 폴더 이름을 바꾼 뒤 다시 돌려 주세요" }
  좋음 "파이썬 자리 $VENV"
}

# ── 3. 파이썬 부품 ──────────────────────────────────────────
단계 3 "파이썬 부품 넣기 (몇 분 걸립니다)"
& uv pip install --python $PY --quiet pillow numpy opencv-python fonttools brotli *>> $LOG
if ($LASTEXITCODE -ne 0) { 실패 "파이썬 부품을 넣지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요" }
좋음 "그림·글꼴·영상 부품"
말 "   ·  받아쓰기(whisper) 를 넣는 중입니다 — 덩치가 커서 오래 걸립니다"
& uv pip install --python $PY --quiet openai-whisper *>> $LOG
if ($LASTEXITCODE -eq 0) { 좋음 "받아쓰기(whisper)" }
else { 경고 "받아쓰기(whisper) 를 넣지 못했습니다" "설치는 계속합니다. 마무리 단계에서 받아쓰기 열쇠를 넣으면 대신 쓸 수 있습니다" }

# ── 4. ffmpeg / ffprobe ─────────────────────────────────────
단계 4 "영상 도구(ffmpeg) 준비"
$있는ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue)
if ($있는ffmpeg -and (자막필터되나 $있는ffmpeg.Source) -and (있나 'ffprobe')) {
  넘김 ("ffmpeg (" + $있는ffmpeg.Source + " · 자막 기능 있음)")
} else {
  $칩 = if ([Environment]::Is64BitOperatingSystem) { 'win64' } else { 'win32' }
  $곳들 = @(
    "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-$칩-gpl.zip",
    "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
  )
  $됐나 = $false
  foreach ($곳 in $곳들) {
    말 ("   ·  내려받는 중: " + $곳)
    $zip = Join-Path $집 'ffmpeg.zip'
    $푼자리 = Join-Path $집 ('ffmpeg풀기_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    try {
      받기 $곳 $zip
      Expand-Archive -Path $zip -DestinationPath $푼자리 -Force
      foreach ($이름 in @('ffmpeg.exe','ffprobe.exe')) {
        $찾음 = Get-ChildItem -Path $푼자리 -Filter $이름 -Recurse -File | Select-Object -First 1
        if ($찾음) { Copy-Item -Force $찾음.FullName (Join-Path $BIN $이름) }
      }
      Remove-Item -Recurse -Force $푼자리 -ErrorAction SilentlyContinue
      Remove-Item -Force $zip -ErrorAction SilentlyContinue
    } catch { 기록 ("ffmpeg 실패: " + $_); continue }
    if (자막필터되나 (Join-Path $BIN 'ffmpeg.exe')) { $됐나 = $true; break }
    경고 "받은 ffmpeg 에 자막 기능이 없습니다" "다른 곳에서 다시 받아 봅니다"
  }
  if (-not $됐나) { 실패 "자막을 얹을 수 있는 ffmpeg 를 구하지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요. 그래도 안 되면 만든 사람에게 알려 주세요" }
  if (-not (Test-Path (Join-Path $BIN 'ffprobe.exe'))) { 실패 "ffprobe 가 없습니다" "설치 명령을 한 번 더 돌려 주세요" }
  좋음 "ffmpeg · ffprobe (자막 기능 확인함)"
}

# ── 5. yt-dlp ───────────────────────────────────────────────
단계 5 "영상 받는 도구(yt-dlp) 준비"
if (있나 'yt-dlp') { 넘김 'yt-dlp' }
else {
  try { 받기 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' (Join-Path $BIN 'yt-dlp.exe') }
  catch { 실패 "yt-dlp 를 받지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요" }
  좋음 'yt-dlp'
}

# ── 6. 실행기 ───────────────────────────────────────────────
단계 6 "실행기 내려받기"
실행기받기 $실행기_주소 $실행기_sha

# ── 7. Claude Code ──────────────────────────────────────────
단계 7 "Claude Code 준비"
if (있나 'claude') { 넘김 'claude' }
else {
  try { & ([scriptblock]::Create((Invoke-WebRequest -Uri 'https://claude.ai/install.ps1' -UseBasicParsing).Content)) *>> $LOG } catch { 기록 ("claude 실패: " + $_) }
  if (있나 'claude') { 좋음 'claude' }
  else { 경고 "Claude Code 를 설치하지 못했습니다" "설치는 계속합니다. 나중에 PowerShell 에 이렇게 치세요: irm https://claude.ai/install.ps1 | iex" }
}

# ── 8. 설정 적기 ────────────────────────────────────────────
단계 8 "설정 적기"
$env파일 = Join-Path $집 'env'
if (-not (Test-Path $env파일)) { New-Item -ItemType File -Path $env파일 | Out-Null }
$있는줄 = Get-Content $env파일 -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
if ($null -eq $있는줄) { $있는줄 = '' }
function 줄넣기($찾을것,$넣을줄) {
  if ($script:있는줄 -match [regex]::Escape($찾을것)) { Write-Host ("   ·  " + $찾을것 + " — 이미 적혀 있어 그대로 둡니다") }
  else { Add-Content -Path $script:env파일 -Value $넣을줄 -Encoding UTF8; $script:있는줄 += "`n$넣을줄"; 좋음 $찾을것 }
}
줄넣기 'VOLCANO_HOME'   "VOLCANO_HOME=$집"
줄넣기 'VOLCANO_PY'     "VOLCANO_PY=$PY"
줄넣기 'VOLCANO_RUNNER' "VOLCANO_RUNNER=$RUNNER"
줄넣기 'VOLCANO_JOBS'   "VOLCANO_JOBS=$JOBS"

foreach ($짝 in @(@('VOLCANO_HOME',$집), @('VOLCANO_PY',$PY), @('VOLCANO_RUNNER',$RUNNER), @('VOLCANO_JOBS',$JOBS))) {
  if (-not [Environment]::GetEnvironmentVariable($짝[0],'User')) {
    [Environment]::SetEnvironmentVariable($짝[0], $짝[1], 'User')
  }
}
$사용자PATH = [Environment]::GetEnvironmentVariable('PATH','User')
if ($null -eq $사용자PATH) { $사용자PATH = '' }
if ($사용자PATH -notlike "*$BIN*") {
  [Environment]::SetEnvironmentVariable('PATH', ($BIN + ';' + $사용자PATH).TrimEnd(';'), 'User')
  좋음 "PATH 에 $BIN 넣음"
} else { Write-Host "   ·  PATH — 이미 들어 있습니다" }

try { 꾸러미받기 '점검.py' (Join-Path $설치기 '점검.py') } catch { 경고 "점검.py 를 가져오지 못했습니다" "인터넷이 되면 설치 명령을 한 번 더 돌려 주세요" }
try { 꾸러미받기 '설치마무리.py' (Join-Path $설치기 '설치마무리.py') } catch { 경고 "설치마무리.py 를 가져오지 못했습니다" "인터넷이 되면 설치 명령을 한 번 더 돌려 주세요" }

# ── 9. 바탕화면 바로가기 ────────────────────────────────────
단계 9 "바탕화면 바로가기 만들기"
# 바탕화면. 시험(VOLCANO_DEST)일 때는 진짜 바탕화면에 아무것도 놓지 않는다.
if ($env:VOLCANO_DEST) {
  $바탕 = Join-Path $DEST 'Desktop'
  New-Item -ItemType Directory -Force -Path $바탕 | Out-Null
} else {
  $바탕 = [Environment]::GetFolderPath('Desktop')
  if (-not $바탕 -or -not (Test-Path $바탕)) { $바탕 = $env:USERPROFILE }
}
if ($env:VOLCANO_APP -eq '1' -and $env:VOLCANO_APP_PATH -and (Test-Path $env:VOLCANO_APP_PATH)) {
  # 앱이 부른 것이면 바탕화면에 **앱 바로가기**를 놓는다 (검은 창이 뜨는 .bat 대신).
  $링크 = Join-Path $바탕 '볼케이노.lnk'
  try {
    $셸 = New-Object -ComObject WScript.Shell
    $바로 = $셸.CreateShortcut($링크)
    $바로.TargetPath = $env:VOLCANO_APP_PATH
    $바로.WorkingDirectory = Split-Path $env:VOLCANO_APP_PATH
    $바로.IconLocation = $env:VOLCANO_APP_PATH + ',0'
    $바로.Description = '볼케이노'
    $바로.Save()
    좋음 $링크
  } catch { 경고 "바탕화면에 아이콘을 놓지 못했습니다" "설치한 폴더의 volcano.exe 를 바탕화면으로 끌어다 놓으세요" }
  foreach ($옛것 in @((Join-Path $바탕 '볼케이노.bat'), (Join-Path $바탕 '볼케이노.ps1'))) {
    if (Test-Path $옛것) {
      try { Move-Item -Force $옛것 (Join-Path $설치기 ((Split-Path -Leaf $옛것) + '.예전것')) } catch {}
    }
  }
} else {
$바로가기 = Join-Path $바탕 '볼케이노.bat'
$점검py = Join-Path $설치기 '점검.py'
# 한글이 든 자리·안내는 짝 .ps1 에 담고, 바탕화면에는 ASCII .bat 만 보이게 한다.
$내용 = @"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
`$env:VOLCANO_HOME   = $(홑 $집)
`$env:VOLCANO_PY     = $(홑 $PY)
`$env:VOLCANO_RUNNER = $(홑 $RUNNER)
`$env:VOLCANO_JOBS   = $(홑 $JOBS)
`$env:PATH = $(홑 $BIN) + ';' + `$env:PATH
if (Test-Path $(홑 $점검py)) { & $(홑 $PY) $(홑 $점검py) }
Set-Location $(홑 $JOBS)
claude
Write-Host ''
try { Read-Host '  엔터를 누르면 창이 닫힙니다' | Out-Null } catch {}
"@
배치쌍쓰기 $바로가기 $내용 -숨김
좋음 $바로가기
}

# ── 10. 마무리 (이 창에서 그대로) ───────────────────────────
# 새 창을 열지 않는다. 묻는 것은 이 콘솔에서 그대로 받는다.
단계 10 "마무리 — 로그인과 열쇠 넣기"
$마무리py = Join-Path $설치기 '설치마무리.py'
$마무리bat = Join-Path $설치기 '마무리.bat'
if ($env:VOLCANO_APP -eq '1') {
  # 앱이 제 창 안에서 마무리 화면을 이어서 띄운다. 여기서 물으면 답할 사람이 없다.
  말 "   ·  마무리는 볼케이노 앱 창에서 이어서 합니다."
} elseif (-not (Test-Path $마무리py)) {
  경고 "마무리 파일이 없어 여기서 멈춥니다" "인터넷이 되면 설치 명령을 한 번 더 돌려 주세요"
} else {
  # 나중에 다시 이어서 할 때 마무리.bat 을 두 번 누르면 된다.
  # .bat 은 ASCII 껍데기, 한글과 자리는 짝 마무리.ps1(UTF-8 BOM)에 있다.
  $마무리내용 = @"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
`$env:VOLCANO_HOME = $(홑 $집)
`$env:PATH = $(홑 $BIN) + ';' + (Join-Path `$env:USERPROFILE '.local\bin') + ';' + `$env:PATH
& $(홑 $PY) $(홑 $마무리py)
Write-Host ''
try { Read-Host '  엔터를 누르면 창이 닫힙니다' | Out-Null } catch {}
"@
  배치쌍쓰기 $마무리bat $마무리내용
  말 ""
  말 "   ·  여기서 이어서 몇 가지만 물어보겠습니다."
  try { & $PY $마무리py }
  catch { 경고 "마무리를 돌리지 못했습니다" ("이 파일을 두 번 눌러 주세요: " + $마무리bat) }
}

Write-Host ""
Write-Host "────────────────────────────────────"
Write-Host " 여기까지 끝났습니다."
Write-Host " 1) 못 넣은 것이 있으면 이렇게 이어서 하면 됩니다: $마무리bat"
Write-Host " 2) 다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다."
Write-Host " 기록: $LOG"
Write-Host "────────────────────────────────────"
기록 "=== 설치 끝 ==="
