# 볼케이노 설치기 본체 — 윈도우
# 관리자 권한을 쓰지 않는다. 전부 사용자 폴더에만 설치한다.
# 여러 번 돌려도 안전하다. 이미 있는 것은 건너뛴다.
#
# 볼케이노 앱이 제 창 안에서 이 파일을 자식으로 돌린다($env:VOLCANO_APP = 1).
# 그때는 9단계에서 앱 바로가기를 놓고, 10단계(마무리)는 앱이 이어받으므로 건너뛴다.
# 앱 없이 이 파일만 돌려도 예전 그대로 끝까지 간다.

# ★ 이름은 ASCII — 변수·함수 이름에 한글을 쓰지 않는다. 한국어 윈도우에서 파서가 죽는다(실측 2026-09-05).
#   irm | iex 로 받으면 PowerShell 5.1 이 본문을 UTF-8 로 안 읽어 $한글 이름이 깨진 바이트가 되고
#   ParserError 가 화면을 덮는다. 화면에 나가는 **문자열**은 한글 그대로 둔다(깨져도 죽지는 않는다).

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$baseUrl = ('https://beautifulahin.github.io/volcano-setup-temp').TrimEnd('/')
if ($env:VOLCANO_BASE) { $baseUrl = $env:VOLCANO_BASE.TrimEnd('/') }

$DEST = if ($env:VOLCANO_DEST) { $env:VOLCANO_DEST } else { $env:LOCALAPPDATA }
$vHome    = Join-Path $DEST 'volcano'
$BIN   = Join-Path $vHome 'bin'
$KEYS  = Join-Path $vHome 'keys'
$RUNNER= Join-Path $vHome 'runner'
$setupDir = Join-Path $vHome '설치기'
$VENV  = Join-Path $vHome 'venv'
# 맥·리눅스에서 흉내 낼 때는 venv/bin/python3 에 생긴다. 시험이 여기서 헛되이 죽지 않게 둘 다 본다.
$PY    = Join-Path $VENV 'Scripts\python.exe'
$PYalt = Join-Path $VENV 'bin/python3'
# 작업장. 시험(VOLCANO_DEST)일 때는 진짜 홈이 아니라 시험 자리 밑에 만든다.
$JOBS  = if ($env:VOLCANO_JOBS_DIR) { $env:VOLCANO_JOBS_DIR }
         elseif ($env:VOLCANO_DEST) { Join-Path $DEST 'volcano_jobs' }
         else                       { Join-Path $env:USERPROFILE 'volcano_jobs' }
$LOG   = Join-Path $vHome '설치.log'
$SRC   = $env:VOLCANO_SRC

foreach ($dir in @($vHome,$BIN,$KEYS,$RUNNER,$setupDir,$JOBS)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

function Log($msg) { try { Add-Content -Path $LOG -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding UTF8 } catch {} }
function Say($msg)   { Write-Host $msg; Log $msg }
function Step($num,$msg) { Write-Host ""; Write-Host ("[{0}/11] {1}" -f $num,$msg) -ForegroundColor Cyan; Log "[$num/11] $msg" }
function Ok($msg) { Write-Host ("  OK  " + $msg) -ForegroundColor Green; Log "OK $msg" }
function Skip($msg) { Write-Host ("   ·  " + $msg + " — 이미 있어 건너뜁니다"); Log "SKIP $msg" }
function Warn($msg,$todo) { Write-Host ("  !   " + $msg) -ForegroundColor Yellow; Write-Host ("      -> " + $todo) -ForegroundColor Yellow; Log "WARN $msg :: $todo" }
function Fail($msg,$todo) {
  Write-Host ""; Write-Host ("  X   " + $msg) -ForegroundColor Red
  Write-Host ("      할 일: " + $todo) -ForegroundColor Red
  Write-Host ("  자세한 기록: " + $LOG)
  Log "FAIL $msg :: $todo"
  Hold "  엔터를 누르면 창이 닫힙니다"
  exit 1
}
# 앱이 제 창 안에서 자식으로 돌릴 때는 키보드가 없다.
# 그때 Read-Host 를 하면 그 자리에서 죽고 「코드 1」만 남는다(실측 2026-09-05).
function Hold($msg) {
  if ($env:VOLCANO_APP -eq '1') { return }   # 앱이 돌리는 중 — 기다리지 않는다
  try { Read-Host $msg | Out-Null } catch { }
}

function Fetch($url,$dir) {
  Invoke-WebRequest -Uri $url -OutFile ($dir + '.내려받는중') -UseBasicParsing -TimeoutSec 1800
  Move-Item -Force ($dir + '.내려받는중') $dir
}
function FetchPkg($name,$dir) {
  if ($SRC -and (Test-Path (Join-Path $SRC $name))) { Copy-Item -Force (Join-Path $SRC $name) $dir; return }
  Fetch "$baseUrl/$name" $dir
}
# 있다고 믿지 않는다 — **한 번 돌려 보고** 고른다.
# 뿌리: where/Get-Command 는 확장자 없는 첫 줄을 준다. %APPDATA%\npm\claude 는
# 유닉스용 셸 파일이라 윈도우가 못 돌린다 — 「is not recognized as the name of a cmdlet」.
# 정작 도는 것은 같은 폴더의 claude.cmd 다(실측 2026-09-05, 사장님 화면).
$TestArgs = @{ 'ffmpeg' = @('-version'); 'ffprobe' = @('-version'); 'whisper' = @('--help') }
function FindRunnable($name) {
  $cand = if ([IO.Path]::GetExtension($name)) { @($name) }
          else { @("$name.cmd", "$name.exe", "$name.bat", $name) }
  $ran = $null
  foreach ($c in $cand) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { continue }
    $src = if ($cmd.Source) { $cmd.Source } else { $cmd.Name }
    $ta  = if ($TestArgs.ContainsKey($name)) { $TestArgs[$name] } else { @('--version') }
    try {
      & $src @ta *>$null
      if ($LASTEXITCODE -eq 0) { return $src }   # 잘 돈다 — 이것으로 정한다
      if (-not $ran) { $ran = $src }             # 뜨기는 했다 — 남겨 둔다
    } catch { }                                  # 아예 못 띄웠다 — 이것이 그 사고다
  }
  # --version 을 모르는 멀쩡한 것도 있어(종료코드만으로 자르면 있는 것을 없다고 한다)
  # 「뜨기라도 한 것」 은 살려 둔다. 하나도 못 띄웠으면 없는 것이다.
  return $ran
}
function Have($name) { $null -ne (FindRunnable $name) }

# ★ uv 는 진행 상황을 stderr 로 알린다. PowerShell 은 그것을 **오류로 착각**해
#   NativeCommandError 를 내고, 설치가 멀쩡히 되는 중에 죽는다(실측 2026-09-05 —
#   「Downloading cpython… (21.0MiB)」 가 오류가 됐다). 그래서 이 자리에서만 끈다.
function RunUv($volcanoArgs) {
  $before = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & (UvCmd) @volcanoArgs 2>&1 | ForEach-Object { Log ([string]$_) }
    return ($LASTEXITCODE -eq 0)
  } finally {
    $ErrorActionPreference = $before
  }
}

# ★ 방금 깐 프로그램은 이 창의 PATH 에 아직 없다. 우리 폴더를 직접 봐야 한다.
#   (실측 2026-09-05 — uv 가 "everything's installed!" 로 깔렸는데도 못 찾아 실패했다.)
function OurExe($name) {
  foreach ($ext in @('.exe', '.cmd', '.bat', '')) {
    $p = Join-Path $BIN ($name + $ext)
    if (Test-Path $p) { return $p }
  }
  return $null
}
function HaveUv() { ($null -ne (OurExe 'uv')) -or (Have 'uv') }
# uv 를 부를 때 쓸 이름 — 우리 것이 있으면 그 전체 경로를 쓴다.
function UvCmd() { $u = OurExe 'uv'; if ($u) { return $u } else { return 'uv' } }
function IsEmpty($val) { return (-not $val) -or ($val -eq 'TODO') }
function Quote($msg) { "'" + (([string]$msg) -replace "'", "''") + "'" }

# ── 윈도우 .bat 은 순수 ASCII 로만 쓴다 ──────────────────────
# cmd 는 .bat 을 시스템 코드페이지(한국어 윈도우는 CP949)로 읽는다. UTF-8 한글을 넣으면
# 파일 전체가 깨진 바이트가 되어 「내부 또는 외부 명령이 아닙니다」 만 쏟아진다.
# 파일 안의 chcp 65001 은 이미 읽기 시작한 뒤라 소용이 없다.
# 그래서 .bat 은 껍데기만 두고, 한글과 실제 일은 같은 이름의 .ps1(UTF-8 BOM)에 담는다.
# PowerShell 5.1 은 BOM 없는 UTF-8 한글도 깨뜨리므로 BOM 은 반드시 붙인다.
function WriteUtf8($dir, $msg) {
  [IO.File]::WriteAllText($dir, (($msg -replace "`r?`n", "`r`n")), (New-Object Text.UTF8Encoding $true))
}
function WriteBatPair($batPath, $psText, [switch]$Hidden) {
  $pair = [IO.Path]::ChangeExtension($batPath, '.ps1')
  # ★ 숨김 파일은 그냥 덮어쓸 수 없다 — 두 번째 설치부터 「Access to the path … is denied」
  #   로 죽는다(실측 2026-09-05). 쓰기 전에 숨김·읽기전용 표를 먼저 뗀다.
  foreach ($f in @($pair, $batPath)) {
    if (Test-Path $f) {
      try { (Get-Item $f -Force).Attributes = 'Normal' } catch { }
    }
  }
  WriteUtf8 $pair $psText
  if ($Hidden) { try { (Get-Item $pair -Force).Attributes = 'Hidden' } catch {} }
  $batShell = @'
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
  [IO.File]::WriteAllText($batPath, ($batShell -replace "`r?`n", "`r`n"), (New-Object Text.ASCIIEncoding))
}
function HasSubFilter($dir) {
  if (-not (Test-Path $dir)) { return $false }
  try { $filters = & $dir -hide_banner -filters 2>$null | Out-String } catch { return $false }
  return $filters -match '\sass\s'
}

$env:PATH = "$BIN;" + (Join-Path $env:USERPROFILE '.local\bin') + ";" + $env:PATH

# ── 실행기 받기 (6단계 알맹이) ──────────────────────────────
# 앱도 이것만 따로 부른다($env:VOLCANO_ONLY_STEP=6). 받는 법이 두 벌이 되지 않게 함수 하나로 둔다.
function FetchRunner($url,$sha) {
  if (IsEmpty $url) {
    Warn "실행기 주소가 아직 비어 있습니다" "볼케이노 운영자가 주소를 정하면 앱을 다시 열 때 저절로 받아집니다. 따로 하실 일이 없습니다"
    return
  }
  $pkg = Join-Path $vHome '실행기꾸러미'
  try { Fetch $url $pkg } catch { Fail "실행기를 받지 못했습니다" "인터넷 연결을 확인하고 다시 돌려 주세요" }
  if (-not (IsEmpty $sha)) {
    $gotHash = (Get-FileHash $pkg -Algorithm SHA256).Hash.ToLower()
    if ($gotHash -ne $sha.ToLower()) { Fail "받은 실행기가 원본과 다릅니다" "인터넷이 불안정할 수 있습니다. 설치 명령을 한 번 더 돌려 주세요" }
    Ok "실행기 원본 대조"
  }
  if ($url -match '\.zip$') { Expand-Archive -Path $pkg -DestinationPath $RUNNER -Force }
  else {
    & tar -xzf $pkg -C $RUNNER --strip-components=1 2>$null
    # 폴더 없이 파일만 든 꾸러미는 한 겹 벗기기가 아무것도 못 꺼낸다. 종료코드 말고 나온 것으로 본다.
    if (-not (Test-Path (Join-Path $RUNNER 'volcano_run.py'))) { & tar -xzf $pkg -C $RUNNER }
  }
  Remove-Item -Force $pkg -ErrorAction SilentlyContinue
  if (-not (Test-Path (Join-Path $RUNNER 'volcano_run.py'))) { Fail "실행기 안에 volcano_run.py 가 없습니다" "만든 사람에게 알려 주세요" }
  Ok "실행기 -> $RUNNER"
}

# 한 단계만 돌려 달라고 하면 그것만 돌리고 끝낸다.
# 설정.json 은 이미 있는 것을 그대로 읽는다 — 앱이 방금 받는곳에서 새로 받아 둔 것이다.
if ($env:VOLCANO_ONLY_STEP -eq '6') {
  $cfg6 = @{}
  try { $cfg6 = Get-Content (Join-Path $setupDir '설정.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
  $url6 = if ($cfg6.'실행기_주소') { [string]$cfg6.'실행기_주소' } else { 'TODO' }
  $sha6  = if ($cfg6.'실행기_sha')  { [string]$cfg6.'실행기_sha' }  else { 'TODO' }
  Step 6 "실행기 내려받기"
  FetchRunner $url6 $sha6
  exit 0
}

Write-Host "────────────────────────────────────"
Write-Host " 볼케이노 설치기"
Write-Host " 설치 자리 : $vHome"
Write-Host " 작업장    : $JOBS"
Write-Host " 관리자 권한은 쓰지 않습니다."
Write-Host "────────────────────────────────────"
Log "=== 설치 시작 dest=$vHome ==="

# ── 1. 자리 만들기 ──────────────────────────────────────────
Step 1 "자리 만들기"
Ok "$vHome (도구·열쇠·설정)"
Ok "$JOBS (작업장)"
$cfg = @{}
# 설정.json 만은 **받는곳 것이 먼저**다. 운영자가 실행기 주소를 채워 올리면
# 앱을 다시 굽지 않아도 그 값이 들어와야 하기 때문이다(다른 꾸러미는 앱이 품고 온 것이 먼저).
$cfgPath = Join-Path $setupDir '설정.json'
try { Fetch "$baseUrl/설정.json" $cfgPath; Ok "설정.json 을 받는곳에서 가져왔습니다" }
catch {
  if (Test-Path $cfgPath) { Write-Host "  ·   설정.json - 받는곳에 못 닿아 있던 것을 그대로 씁니다" }
  elseif ($SRC -and (Test-Path (Join-Path $SRC '설정.json'))) {
    Copy-Item (Join-Path $SRC '설정.json') $cfgPath -Force; Ok "설정.json (앱이 품고 온 것)"
  } else {
    Warn "설정.json 을 가져오지 못했습니다" "인터넷 없이 돌리는 중이라면 넘어갑니다. 실행기·가입은 나중에 다시 돌리면 됩니다"
  }
}
try { $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $cfg = @{} }
$runnerUrl = if ($cfg.'실행기_주소') { [string]$cfg.'실행기_주소' } else { 'TODO' }
$runnerSha  = if ($cfg.'실행기_sha')  { [string]$cfg.'실행기_sha' }  else { 'TODO' }

# ── 2. 파이썬 (uv) ──────────────────────────────────────────
Step 2 "파이썬 3.12 준비"
# uv 가 딴 자리(사용자 홈)를 건드리지 않게 전부 우리 폴더로 못박는다.
$env:UV_PYTHON_INSTALL_DIR = Join-Path $vHome 'python'
$env:UV_PYTHON_BIN_DIR     = $BIN
$env:UV_CACHE_DIR          = Join-Path $vHome 'cache'
$env:UV_TOOL_BIN_DIR       = $BIN
$env:UV_INSTALL_DIR        = $BIN
$env:UV_NO_MODIFY_PATH     = '1'
if (HaveUv) { Skip 'uv' }
else {
  try {
    # ★ -UseBasicParsing 을 쓰면 .Content 가 **글자가 아니라 바이트 배열**로 온다.
    #   그대로 scriptblock 에 넣으면 「35 32 76 105 …」 숫자 나열이 코드가 되어 파서가 죽는다
    #   (실측 2026-09-05 — 받는 분 화면이 그 숫자로 가득 찼다). 반드시 글자로 바꿔서 넣는다.
    $uvBody = (Invoke-WebRequest -Uri 'https://astral.sh/uv/install.ps1' -UseBasicParsing).Content
    if ($uvBody -isnot [string]) { $uvBody = [System.Text.Encoding]::UTF8.GetString($uvBody) }
    & ([scriptblock]::Create($uvBody)) *>> $LOG
  } catch {
    # 길이 하나뿐이면 그 길이 막힐 때 통째로 죽는다. 까닭을 남기고 다른 길로 간다.
    Log ("uv 설치 스크립트 실패: " + $_.Exception.Message)
    Write-Host ("      · 첫 번째 길이 막혔습니다 (" + $_.Exception.Message + ")") -ForegroundColor DarkGray
    Write-Host '      · 다른 길로 받아 봅니다...'
  }
  if (-not (HaveUv)) {
    # 두 번째 길 — 깃허브 릴리스에서 실행파일만 곧장 받는다(스크립트를 안 돌린다).
    try {
      $uvZip = Join-Path $VOL 'uv.zip'
      $uvUrl = 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip'
      Invoke-WebRequest -Uri $uvUrl -OutFile $uvZip -UseBasicParsing -TimeoutSec 600
      Expand-Archive -Path $uvZip -DestinationPath $BIN -Force
      Remove-Item $uvZip -ErrorAction SilentlyContinue
      Log 'uv 를 깃허브 릴리스에서 받았다'
    } catch {
      Log ("uv 깃허브 길도 실패: " + $_.Exception.Message)
    }
  }
  if (-not (HaveUv)) {
    Fail "uv 를 받지 못했습니다 (두 길 다 막혔습니다)" ("회사망이나 백신이 astral.sh / github.com 을 막고 있을 수 있습니다. " +
      "자세한 까닭은 이 기록에 있습니다: " + $LOG)
  }
  Ok 'uv'
}
$uvOk = RunUv @('python','install','3.12')
if (-not $uvOk) { Fail "파이썬 3.12 를 받지 못했습니다" "인터넷 연결을 확인하고 다시 돌려 주세요" }
if (Test-Path $PY) { Skip "파이썬 자리 $VENV" }
elseif (Test-Path $PYalt) { $PY = $PYalt; Skip "파이썬 자리 $VENV" }
else {
  RunUv @('venv','--seed','--python','3.12',$VENV) | Out-Null
  if (Test-Path $PYalt) { $PY = $PYalt }
  if (-not (Test-Path $PY)) { Fail "파이썬 자리를 만들지 못했습니다" "$VENV 폴더 이름을 바꾼 뒤 다시 돌려 주세요" }
  Ok "파이썬 자리 $VENV"
}

# ── 3. 파이썬 부품 ──────────────────────────────────────────
Step 3 "파이썬 부품 넣기 (몇 분 걸립니다)"
$pipOk = RunUv @('pip','install','--python',$PY,'--quiet','pillow','numpy','opencv-python','fonttools','brotli')
if (-not $pipOk) { Fail "파이썬 부품을 넣지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요" }
Ok "그림·글꼴·영상 부품"
Say "   ·  받아쓰기(whisper) 를 넣는 중입니다 — 덩치가 커서 오래 걸립니다"
RunUv @('pip','install','--python',$PY,'--quiet','openai-whisper') | Out-Null
if ($LASTEXITCODE -eq 0) { Ok "받아쓰기(whisper)" }
else { Warn "받아쓰기(whisper) 를 넣지 못했습니다" "설치는 계속합니다. 마무리 단계에서 받아쓰기 열쇠를 넣으면 대신 쓸 수 있습니다" }

# ── 4. ffmpeg / ffprobe ─────────────────────────────────────
Step 4 "영상 도구(ffmpeg) 준비"
$foundFfmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue)
if ($foundFfmpeg -and (HasSubFilter $foundFfmpeg.Source) -and (Have 'ffprobe')) {
  Skip ("ffmpeg (" + $foundFfmpeg.Source + " · 자막 기능 있음)")
} else {
  $arch = if ([Environment]::Is64BitOperatingSystem) { 'win64' } else { 'win32' }
  $srcUrls = @(
    "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-$arch-gpl.zip",
    "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
  )
  $gotIt = $false
  foreach ($srcUrl in $srcUrls) {
    Say ("   ·  내려받는 중: " + $srcUrl)
    $zip = Join-Path $vHome 'ffmpeg.zip'
    $unzipDir = Join-Path $vHome ('ffmpeg풀기_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    try {
      Fetch $srcUrl $zip
      Expand-Archive -Path $zip -DestinationPath $unzipDir -Force
      foreach ($name in @('ffmpeg.exe','ffprobe.exe')) {
        $found = Get-ChildItem -Path $unzipDir -Filter $name -Recurse -File | Select-Object -First 1
        if ($found) { Copy-Item -Force $found.FullName (Join-Path $BIN $name) }
      }
      Remove-Item -Recurse -Force $unzipDir -ErrorAction SilentlyContinue
      Remove-Item -Force $zip -ErrorAction SilentlyContinue
    } catch { Log ("ffmpeg 실패: " + $_); continue }
    if (HasSubFilter (Join-Path $BIN 'ffmpeg.exe')) { $gotIt = $true; break }
    Warn "받은 ffmpeg 에 자막 기능이 없습니다" "다른 곳에서 다시 받아 봅니다"
  }
  if (-not $gotIt) { Fail "자막을 얹을 수 있는 ffmpeg 를 구하지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요. 그래도 안 되면 만든 사람에게 알려 주세요" }
  if (-not (Test-Path (Join-Path $BIN 'ffprobe.exe'))) { Fail "ffprobe 가 없습니다" "설치 명령을 한 번 더 돌려 주세요" }
  Ok "ffmpeg · ffprobe (자막 기능 확인함)"
}

# ── 5. yt-dlp ───────────────────────────────────────────────
Step 5 "영상 받는 도구(yt-dlp) 준비"
if (($null -ne (OurExe 'yt-dlp')) -or (Have 'yt-dlp')) { Skip 'yt-dlp' }
else {
  try { Fetch 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' (Join-Path $BIN 'yt-dlp.exe') }
  catch { Fail "yt-dlp 를 받지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요" }
  Ok 'yt-dlp'
}

# ── 6. 실행기 ───────────────────────────────────────────────
Step 6 "실행기 내려받기"
FetchRunner $runnerUrl $runnerSha

# ── 7. Claude Code ──────────────────────────────────────────
$script:claudePath = $null
$script:codePath = $null
Step 7 "Claude Code 준비"
if (Have 'claude') { Skip 'claude' }
else {
  try {
    $ccBody = (Invoke-WebRequest -Uri 'https://claude.ai/install.ps1' -UseBasicParsing).Content
    if ($ccBody -isnot [string]) { $ccBody = [System.Text.Encoding]::UTF8.GetString($ccBody) }
    & ([scriptblock]::Create($ccBody)) *>> $LOG
  } catch { Log ("claude 실패: " + $_) }
  # 방금 깐 claude 도 이 창의 PATH 에 없다. 흔한 자리를 직접 본다.
  $ccPaths = @(
    (Join-Path $env:USERPROFILE '.local\bin\claude.cmd'),
    (Join-Path $env:USERPROFILE '.local\bin\claude.exe'),
    (Join-Path $env:APPDATA 'npm\claude.cmd')
  )
  $ccFound = $ccPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($ccFound) {
    # ★ 찾은 자리를 적어 둔다. 안 적으면 나중에 로그인할 때 또 못 찾는다
    #   (실측 2026-09-05 — 「'claude.cmd' is not recognized」 로 로그인이 막혔다).
    $script:claudePath = $ccFound
    Ok 'claude'
  } elseif (Have 'claude') { Ok 'claude' }
  else { Warn "Claude Code 를 설치하지 못했습니다" "설치는 계속합니다. 나중에 PowerShell 에 이렇게 치세요: irm https://claude.ai/install.ps1 | iex" }
}

# ── 8. 설정 적기 ────────────────────────────────────────────
# ── 7-2. VS Code ────────────────────────────────────────────
# 사용자 지시 2026-09-05: 「다 설치되면 vscode 를 설치되게 해줘」.
# 없어도 볼케이노는 돈다 — 그래서 실패해도 설치를 멈추지 않는다(Warn 으로 넘긴다).
Step 8 "VS Code 준비"
$codeFound = $null
foreach ($c in @(
  (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
  'C:\Program Files\Microsoft VS Code\bin\code.cmd')) {
  if ($c -and (Test-Path $c)) { $codeFound = $c; break }
}
if ($codeFound -or (Have 'code')) { Skip 'VS Code' }
else {
  try {
    $vsUrl = 'https://update.code.visualstudio.com/latest/win32-x64-user/stable'
    $vsExe = Join-Path $vHome 'vscode-setup.exe'
    Invoke-WebRequest -Uri $vsUrl -OutFile $vsExe -UseBasicParsing -TimeoutSec 1800
    # 조용히 깔고, 바로가기·PATH 는 넣되 다 끝나고 저절로 열리지는 않게 한다.
    # desktopicon 을 넣어야 바탕화면에 아이콘이 생긴다. 없으면 껐을 때 못 찾는다
    # (실측 2026-09-05 — 「끄니까 vscode 가 없다」).
    $vsArgs = '/VERYSILENT /NORESTART /MERGETASKS=desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath,!runcode'
    Start-Process -FilePath $vsExe -ArgumentList $vsArgs -Wait
    Remove-Item $vsExe -ErrorAction SilentlyContinue
    foreach ($c in @(
      (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
      'C:\Program Files\Microsoft VS Code\bin\code.cmd')) {
      if ($c -and (Test-Path $c)) { $codeFound = $c; break }
    }
    if ($codeFound -or (Have 'code')) { Ok 'VS Code' }
    else { Warn "VS Code 를 설치하지 못했습니다" "없어도 볼케이노는 돌아갑니다. 나중에 code.visualstudio.com 에서 받으셔도 됩니다" }
  } catch {
    Log ("VS Code 실패: " + $_)
    Warn "VS Code 를 설치하지 못했습니다" "없어도 볼케이노는 돌아갑니다. 나중에 code.visualstudio.com 에서 받으셔도 됩니다"
  }
}

# VS Code 가 있으면 Claude Code 확장을 넣는다 — 그래야 VS Code 안에서 바로 쓴다.
$codeCli = $codeFound
if (-not $codeCli -and (Have 'code')) { $codeCli = 'code' }
if ($codeCli) {
  try {
    & $codeCli --install-extension anthropic.claude-code --force *>> $LOG
    if ($LASTEXITCODE -eq 0) { Ok 'VS Code 의 Claude Code 확장' }
    else { Warn "VS Code 확장을 넣지 못했습니다" "VS Code 를 열고 확장에서 Claude Code 를 검색해 설치하시면 됩니다" }
  } catch {
    Log ("VS Code 확장 실패: " + $_)
    Warn "VS Code 확장을 넣지 못했습니다" "VS Code 를 열고 확장에서 Claude Code 를 검색해 설치하시면 됩니다"
  }
  $script:codePath = $codeCli
}

# 작업 폴더에 VS Code 설정을 놓는다 — 거기 터미널에서 claude 가 바로 되게.
# (실측 2026-09-05 — VS Code 터미널에서 「'claude' 용어가 인식되지 않습니다」가 났다.
#  새로 깐 프로그램은 이미 열린 창의 PATH 에 없다.)
try {
  $vscDir = Join-Path $JOBS '.vscode'
  New-Item -ItemType Directory -Force -Path $vscDir | Out-Null
  $claudeDir = Join-Path $env:USERPROFILE '.local\bin'
  $settings = @{
    'terminal.integrated.env.windows' = @{
      'PATH'           = ($claudeDir + ';' + $BIN + ';${env:PATH}')
      'VOLCANO_HOME'   = $vHome
      'VOLCANO_PY'     = $PY
      'VOLCANO_JOBS'   = $JOBS
      'VOLCANO_RUNNER' = $RUNNER
    }
  } | ConvertTo-Json -Depth 5
  # JSON 에는 BOM 을 넣지 않는다 — 붙이면 VS Code 가 설정을 못 읽는다.
  [IO.File]::WriteAllText((Join-Path $vscDir 'settings.json'),
    ($settings -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding $false))
  Log "VS Code 설정을 놓았다: $vscDir"
} catch { Log ("VS Code 설정 실패: " + $_) }

Step 9 "설정 적기"
# 클로드코드 자리를 적어 둔다 — 로그인 창이 이것을 쓴다.
if (-not $script:claudePath) {
  # 자리마다 밑둥이 비어 있을 수 있다(맥에는 APPDATA 가 없다). 비면 건너뛴다.
  $ccRoots = @()
  if ($env:USERPROFILE) {
    $ccRoots += (Join-Path $env:USERPROFILE '.local\bin\claude.cmd')
    $ccRoots += (Join-Path $env:USERPROFILE '.local\bin\claude.exe')
  }
  if ($env:APPDATA) { $ccRoots += (Join-Path $env:APPDATA 'npm\claude.cmd') }
  foreach ($c in $ccRoots) { if (Test-Path $c) { $script:claudePath = $c; break } }
}
$envFile = Join-Path $vHome 'env'
if (-not (Test-Path $envFile)) { New-Item -ItemType File -Path $envFile | Out-Null }
$envText = Get-Content $envFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
if ($null -eq $envText) { $envText = '' }
function AddEnvLine($needle,$lineToAdd) {
  if ($script:envText -match [regex]::Escape($needle)) { Write-Host ("   ·  " + $needle + " — 이미 적혀 있어 그대로 둡니다") }
  else { Add-Content -Path $script:envFile -Value $lineToAdd -Encoding UTF8; $script:envText += "`n$lineToAdd"; Ok $needle }
}
AddEnvLine 'VOLCANO_HOME'   "VOLCANO_HOME=$vHome"
AddEnvLine 'VOLCANO_PY'     "VOLCANO_PY=$PY"
AddEnvLine 'VOLCANO_RUNNER' "VOLCANO_RUNNER=$RUNNER"
AddEnvLine 'VOLCANO_JOBS'   "VOLCANO_JOBS=$JOBS"
if ($script:claudePath) { AddEnvLine 'VOLCANO_CLAUDE' "VOLCANO_CLAUDE=$($script:claudePath)" }
if ($script:codePath)   { AddEnvLine 'VOLCANO_CODE'   "VOLCANO_CODE=$($script:codePath)" }

foreach ($pair in @(@('VOLCANO_HOME',$vHome), @('VOLCANO_PY',$PY), @('VOLCANO_RUNNER',$RUNNER), @('VOLCANO_JOBS',$JOBS))) {
  if (-not [Environment]::GetEnvironmentVariable($pair[0],'User')) {
    [Environment]::SetEnvironmentVariable($pair[0], $pair[1], 'User')
  }
}
$userPath = [Environment]::GetEnvironmentVariable('PATH','User')
if ($null -eq $userPath) { $userPath = '' }
# ★ 볼케이노 폴더뿐 아니라 **클로드 자리도** 넣어야 한다. 안 넣으면 새 창을 열어도
#   「'claude' 용어가 인식되지 않습니다」가 난다(실측 2026-09-05).
$pathAdds = @($BIN)
$claudeBin = Join-Path $env:USERPROFILE '.local\bin'
if (Test-Path $claudeBin) { $pathAdds += $claudeBin }
elseif ($script:claudePath) { $pathAdds += (Split-Path -Parent $script:claudePath) }
$added = @()
foreach ($one in $pathAdds) {
  if ($one -and ($userPath -notlike ("*" + $one + "*"))) {
    $userPath = ($one + ';' + $userPath).TrimEnd(';')
    $added += $one
  }
}
if ($added.Count -gt 0) {
  [Environment]::SetEnvironmentVariable('PATH', $userPath, 'User')
  foreach ($one in $added) { Ok "PATH 에 $one 넣음" }
} else { Write-Host "   ·  PATH — 이미 들어 있습니다" }

try { FetchPkg '점검.py' (Join-Path $setupDir '점검.py') } catch { Warn "점검.py 를 가져오지 못했습니다" "인터넷이 되면 설치 명령을 한 번 더 돌려 주세요" }
try { FetchPkg '설치마무리.py' (Join-Path $setupDir '설치마무리.py') } catch { Warn "설치마무리.py 를 가져오지 못했습니다" "인터넷이 되면 설치 명령을 한 번 더 돌려 주세요" }

# ── 9. 바탕화면 바로가기 ────────────────────────────────────
Step 10 "바탕화면 바로가기 만들기"
# 바탕화면. 시험(VOLCANO_DEST)일 때는 진짜 바탕화면에 아무것도 놓지 않는다.
if ($env:VOLCANO_DEST) {
  $desktop = Join-Path $DEST 'Desktop'
  New-Item -ItemType Directory -Force -Path $desktop | Out-Null
} else {
  $desktop = [Environment]::GetFolderPath('Desktop')
  if (-not $desktop -or -not (Test-Path $desktop)) { $desktop = $env:USERPROFILE }
}
if ($env:VOLCANO_APP -eq '1' -and $env:VOLCANO_APP_PATH -and (Test-Path $env:VOLCANO_APP_PATH)) {
  # 앱이 부른 것이면 바탕화면에 **앱 바로가기**를 놓는다 (검은 창이 뜨는 .bat 대신).
  $lnkPath = Join-Path $desktop '볼케이노.lnk'
  try {
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $env:VOLCANO_APP_PATH
    $shortcut.WorkingDirectory = Split-Path $env:VOLCANO_APP_PATH
    $shortcut.IconLocation = $env:VOLCANO_APP_PATH + ',0'
    $shortcut.Description = '볼케이노'
    $shortcut.Save()
    Ok $lnkPath
  } catch { Warn "바탕화면에 아이콘을 놓지 못했습니다" "설치한 폴더의 volcano.exe 를 바탕화면으로 끌어다 놓으세요" }
  foreach ($oldFile in @((Join-Path $desktop '볼케이노.bat'), (Join-Path $desktop '볼케이노.ps1'))) {
    if (Test-Path $oldFile) {
      try { Move-Item -Force $oldFile (Join-Path $setupDir ((Split-Path -Leaf $oldFile) + '.예전것')) } catch {}
    }
  }
} else {
# 바로가기가 쓸 VS Code 자리. 없으면 빈 값이라 검은 창에서 그냥 claude 를 연다.
$codeForLauncher = ''
if ($script:codePath) { $codeForLauncher = $script:codePath }
else {
  foreach ($c in @((Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
                   'C:\Program Files\Microsoft VS Code\bin\code.cmd')) {
    if ($c -and (Test-Path $c)) { $codeForLauncher = $c; break }
  }
}
$launcherBat = Join-Path $desktop '볼케이노.bat'
$checkPy = Join-Path $setupDir '점검.py'
# 한글이 든 자리·안내는 짝 .ps1 에 담고, 바탕화면에는 ASCII .bat 만 보이게 한다.
$launcherPs = @"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
`$env:VOLCANO_HOME   = $(Quote $vHome)
`$env:VOLCANO_PY     = $(Quote $PY)
`$env:VOLCANO_RUNNER = $(Quote $RUNNER)
`$env:VOLCANO_JOBS   = $(Quote $JOBS)
`$env:PATH = $(Quote $BIN) + ';' + `$env:PATH
if (Test-Path $(Quote $checkPy)) { & $(Quote $PY) $(Quote $checkPy) }
Set-Location $(Quote $JOBS)
# VS Code 가 있으면 거기서 연다 — 사용자 지시 2026-09-05.
`$codeCli = $(Quote $codeForLauncher)
if (`$codeCli -and (`$codeCli -eq 'code' -or (Test-Path `$codeCli))) {
  Write-Host '  VS Code 로 볼케이노를 엽니다...'
  Write-Host '   · VS Code 가 열리면 Claude Code 를 켜세요 (Ctrl+Esc 또는 왼쪽 Claude 아이콘).'
  try { & `$codeCli $(Quote $JOBS) } catch { Write-Host '  ! VS Code 를 열지 못했습니다.' }
  Write-Host ''
  Write-Host '  이 검은 창에서 바로 쓰시려면 아래처럼 claude 를 치셔도 됩니다.'
}
claude
Write-Host ''
Hold "  엔터를 누르면 창이 닫힙니다"
"@
WriteBatPair $launcherBat $launcherPs -Hidden
Ok $launcherBat
}

# ── 10. 마무리 (이 창에서 그대로) ───────────────────────────
# 새 창을 열지 않는다. 묻는 것은 이 콘솔에서 그대로 받는다.
Step 11 "마무리 — 로그인과 열쇠 넣기"
$finishPy = Join-Path $setupDir '설치마무리.py'
$finishBat = Join-Path $setupDir '마무리.bat'
if ($env:VOLCANO_APP -eq '1') {
  # 앱이 제 창 안에서 마무리 화면을 이어서 띄운다. 여기서 물으면 답할 사람이 없다.
  Say "   ·  마무리는 볼케이노 앱 창에서 이어서 합니다."
} elseif (-not (Test-Path $finishPy)) {
  Warn "마무리 파일이 없어 여기서 멈춥니다" "인터넷이 되면 설치 명령을 한 번 더 돌려 주세요"
} else {
  # 나중에 다시 이어서 할 때 마무리.bat 을 두 번 누르면 된다.
  # .bat 은 ASCII 껍데기, 한글과 자리는 짝 마무리.ps1(UTF-8 BOM)에 있다.
  $finishPs = @"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
`$env:VOLCANO_HOME = $(Quote $vHome)
`$env:PATH = $(Quote $BIN) + ';' + (Join-Path `$env:USERPROFILE '.local\bin') + ';' + `$env:PATH
& $(Quote $PY) $(Quote $finishPy)
Write-Host ''
Hold "  엔터를 누르면 창이 닫힙니다"
"@
  WriteBatPair $finishBat $finishPs
  Say ""
  Say "   ·  여기서 이어서 몇 가지만 물어보겠습니다."
  try { & $PY $finishPy }
  catch { Warn "마무리를 돌리지 못했습니다" ("이 파일을 두 번 눌러 주세요: " + $finishBat) }
}

Write-Host ""
Write-Host "────────────────────────────────────"
Write-Host " 여기까지 끝났습니다."
Write-Host " 1) 못 넣은 것이 있으면 이렇게 이어서 하면 됩니다: $finishBat"
Write-Host " 2) 다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다."
Write-Host " 기록: $LOG"
Write-Host "────────────────────────────────────"
Log "=== 설치 끝 ==="
