#!/usr/bin/env bash
# 볼케이노 설치기 본체 — 맥 · 리눅스
# 관리자 비밀번호를 묻지 않는다. 전부 사용자 폴더에만 설치한다.
# 여러 번 돌려도 안전하다. 이미 있는 것은 건너뛴다.
#
# ■ 누가 부르나
#   ① 볼케이노 앱이 제 창 안에서 자식으로 돌린다(VOLCANO_APP=1). 평소에는 이쪽이다.
#      그때는 9단계에서 앱 아이콘을 바탕화면에 놓고, 10단계(마무리)는 앱이 이어받으므로 건너뛴다.
#   ② 앱 없이 이 파일만 받아 돌려도 예전 그대로 끝까지 간다(.command 바로가기 + 같은 창 마무리).
# (bash 3.2 에서도 돌아야 해서 안에서 쓰는 이름은 영문이다. 사람이 보는 말은 한글.)
set -euo pipefail

BASE="${VOLCANO_BASE:-https://beautifulahin.github.io/volcano-setup-temp}"
BASE="${BASE%/}"
DEST="${VOLCANO_DEST:-$HOME}"
SRC="${VOLCANO_SRC:-}"

VOL="$DEST/.volcano"
BIN="$VOL/bin"
KEYS="$VOL/keys"
SETUP="$VOL/설치기"
JOBS="$DEST/volcano_jobs"
VENV="$VOL/venv"
PY="$VENV/bin/python3"
LOG="$VOL/설치.log"

mkdir -p "$VOL" "$BIN" "$KEYS" "$SETUP" "$JOBS"
chmod 700 "$KEYS" 2>/dev/null || true

log(){  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null || true; }
say(){  printf '%s\n' "$*"; log "$*"; }
step(){ printf '\n[%s/10] %s\n' "$1" "$2"; log "[$1/10] $2"; }
ok(){   printf '  ✓ %s\n' "$1"; log "OK $1"; }
skip(){ printf '  · %s — 이미 있어 건너뜁니다\n' "$1"; log "SKIP $1"; }
warn(){ printf '  ! %s\n    → %s\n' "$1" "$2"; log "WARN $1 :: $2"; }
die(){  printf '\n  ✗ %s\n    → 할 일: %s\n\n  자세한 기록: %s\n' "$1" "$2" "$LOG"; log "FAIL $1 :: $2"; exit 1; }

# 1=주소 2=받을 자리
fetch(){
  curl -fsSL --retry 3 --retry-delay 2 -m 1800 -o "$2.내려받는중" "$1" && mv -f "$2.내려받는중" "$2"
}
# 1=파일 이름 2=받을 자리   (VOLCANO_SRC 가 있으면 웹 대신 거기서 복사)
fetch_pkg(){
  if [ -n "$SRC" ] && [ -f "$SRC/$1" ]; then cp -f "$SRC/$1" "$2"; return 0; fi
  fetch "$BASE/$1" "$2"
}
# 1=열쇠 이름 — 설정.json 에서 값 하나를 꺼낸다
cfg_get(){
  [ -f "$SETUP/설정.json" ] || return 0
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$SETUP/설정.json" | head -1
}
is_todo(){ [ -z "${1:-}" ] || [ "${1:-}" = "TODO" ]; }
# 받기가 실패했을 때 **인터넷 탓인지 받는곳 탓인지** 갈라서 말해 준다.
# 이걸 안 가르면 초보자는 멀쩡한 와이파이만 붙들고 헤맨다.
why_fail(){
  if ! curl -fsS -m 8 -o /dev/null https://www.google.com 2>/dev/null \
     && ! curl -fsS -m 8 -o /dev/null https://cloudflare.com 2>/dev/null; then
    printf '%s' "인터넷이 안 되는 것 같습니다. 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요"
    return
  fi
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "$BASE/$1" 2>/dev/null || echo 000)
  case "$code" in
    404|403) printf '%s' "인터넷은 됩니다 — 받는곳에 「$1」 이 아직 안 올라가 있습니다. 만든 사람에게 그대로 알려 주세요 ($BASE)" ;;
    000)     printf '%s' "인터넷은 됩니다 — 받는곳($BASE)에 닿지 못했습니다. 주소가 바뀌었을 수 있으니 만든 사람에게 알려 주세요" ;;
    *)       printf '%s' "인터넷은 됩니다 — 받는곳이 $code 로 답했습니다. 만든 사람에게 알려 주세요 ($BASE)" ;;
  esac
}
has(){ command -v "$1" >/dev/null 2>&1; }
# 1=zip 2=넣을 자리   (한 겹으로 펼친다)
unpack(){
  if has unzip; then
    unzip -o -q -j "$1" -d "$2"
  elif [ -x "$PY" ]; then
    "$PY" - "$1" "$2" <<'PYZIP'
import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if n.endswith('/'):
        continue
    p = os.path.join(sys.argv[2], os.path.basename(n))
    open(p, 'wb').write(z.read(n))
    os.chmod(p, 0o755)
PYZIP
  else
    return 1
  fi
}
# 1=ffmpeg 자리 — 자막을 얹는 기능이 있나
has_ass(){
  [ -x "$1" ] || return 1
  FILTERS="$("$1" -hide_banner -filters 2>/dev/null || true)"
  case "$FILTERS" in *" ass "*) return 0;; *) return 1;; esac
}

export PATH="$BIN:$DEST/.local/bin:$PATH"

case "$(uname -s)" in
  Darwin) OSNAME=macos ;;
  Linux)  OSNAME=linux ;;
  *) die "이 설치기는 맥과 리눅스에서만 씁니다 ($(uname -s))" "윈도우라면 install.ps1 을 쓰세요" ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=amd64 ;;
  *) die "모르는 칩입니다 ($(uname -m))" "만든 사람에게 이 줄을 그대로 알려 주세요" ;;
esac

cat <<HEAD
────────────────────────────────────
 볼케이노 설치기
 설치 자리 : $DEST
 이 컴퓨터 : $OSNAME / $ARCH
 관리자 비밀번호는 묻지 않습니다.
────────────────────────────────────
HEAD
log "=== 설치 시작 dest=$DEST os=$OSNAME arch=$ARCH ==="

# ── 1. 자리 만들기 ──────────────────────────────────────────
step 1 "자리 만들기"
ok "$VOL (도구·열쇠·설정)"
ok "$JOBS (작업장)"
# 설정.json 만은 **받는곳 것이 먼저**다. 운영자가 무엇을 고쳐 올리면
# 앱을 다시 굽지 않아도 그 값이 들어와야 하기 때문이다(다른 꾸러미는 앱이 품고 온 것이 먼저).
if fetch "$BASE/설정.json" "$SETUP/설정.json" 2>/dev/null; then
  ok "설정.json 을 받는곳에서 가져왔습니다"
elif [ -f "$SETUP/설정.json" ]; then
  printf '  · 설정.json — 받는곳에 못 닿아 있던 것을 그대로 씁니다\n'
elif [ -n "$SRC" ] && [ -f "$SRC/설정.json" ]; then
  cp -f "$SRC/설정.json" "$SETUP/설정.json"
  ok "설정.json (앱이 품고 온 것)"
else
  warn "설정.json 을 가져오지 못했습니다" "$(why_fail "설정.json")"
fi

# ── 2. 파이썬 ───────────────────────────────────────────────
step 2 "파이썬 3.12 준비"
# uv 가 딴 자리(사용자 홈)를 건드리지 않게 전부 우리 폴더로 못박는다.
export UV_PYTHON_INSTALL_DIR="$VOL/python"
export UV_PYTHON_BIN_DIR="$BIN"
export UV_CACHE_DIR="$VOL/cache"
export UV_TOOL_BIN_DIR="$BIN"
export UV_INSTALL_DIR="$BIN"
export UV_NO_MODIFY_PATH=1
export INSTALLER_NO_MODIFY_PATH=1
if has uv; then
  skip "uv"
else
  # 값은 export 해 둔다 — 「앞에 붙여 쓰기」는 curl 에만 걸리고 sh 에는 안 걸린다.
  curl -LsSf https://astral.sh/uv/install.sh 2>>"$LOG" | sh >>"$LOG" 2>&1 \
    || die "uv 를 설치하지 못했습니다" "인터넷 연결을 확인하고 이 설치 명령을 한 번 더 돌려 주세요"
  hash -r 2>/dev/null || true
  has uv || die "uv 가 설치됐는데 찾지 못합니다" "터미널을 닫았다 열고 설치 명령을 한 번 더 돌려 주세요"
  ok "uv"
fi
uv python install 3.12 >>"$LOG" 2>&1 || die "파이썬 3.12 를 받지 못했습니다" "인터넷 연결을 확인하고 다시 돌려 주세요"
if [ -x "$PY" ]; then
  skip "파이썬 자리 $VENV"
else
  uv venv --seed --python 3.12 "$VENV" >>"$LOG" 2>&1 \
    || die "파이썬 자리를 만들지 못했습니다" "$VENV 폴더를 지우지 말고 이름만 바꾼 뒤 다시 돌려 주세요"
  ok "파이썬 자리 $VENV"
fi
[ -x "$PY" ] || die "$PY 가 없습니다" "설치 명령을 한 번 더 돌려 주세요"

# ── 3. 파이썬 부품 ──────────────────────────────────────────
step 3 "파이썬 부품 넣기 (몇 분 걸립니다)"
uv pip install --python "$PY" --quiet \
    pillow numpy opencv-python fonttools brotli >>"$LOG" 2>&1 \
  || die "파이썬 부품을 넣지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요"
ok "그림·글꼴·영상 부품"
say "  · 받아쓰기(whisper) 를 넣는 중입니다 — 덩치가 커서 오래 걸립니다"
if uv pip install --python "$PY" --quiet openai-whisper >>"$LOG" 2>&1; then
  ok "받아쓰기(whisper)"
else
  warn "받아쓰기(whisper) 를 넣지 못했습니다" "설치는 계속합니다. 마무리에서 받아쓰기 열쇠를 넣으면 대신 쓸 수 있습니다"
fi

# ── 4. ffmpeg / ffprobe ─────────────────────────────────────
step 4 "영상 도구(ffmpeg) 준비"
HAVE_FFMPEG="$(command -v ffmpeg 2>/dev/null || true)"
if [ -n "$HAVE_FFMPEG" ] && has_ass "$HAVE_FFMPEG" && has ffprobe; then
  skip "ffmpeg ($HAVE_FFMPEG · 자막 기능 있음)"
else
  GOT=""
  if [ "$OSNAME" = macos ]; then
    SOURCES="https://ffmpeg.martin-riedl.de/redirect/latest/macos/$ARCH/snapshot"
    [ "$ARCH" = amd64 ] && SOURCES="$SOURCES evermeet"
  else
    SOURCES="https://ffmpeg.martin-riedl.de/redirect/latest/linux/$ARCH/snapshot johnvansickle"
  fi
  for SRCURL in $SOURCES; do
    say "  · 내려받는 중: $SRCURL"
    if [ "$SRCURL" = evermeet ]; then
      fetch "https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip"  "$VOL/ffmpeg.zip"  >>"$LOG" 2>&1 || continue
      fetch "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip" "$VOL/ffprobe.zip" >>"$LOG" 2>&1 || continue
      unpack "$VOL/ffmpeg.zip"  "$BIN" >>"$LOG" 2>&1 || continue
      unpack "$VOL/ffprobe.zip" "$BIN" >>"$LOG" 2>&1 || continue
    elif [ "$SRCURL" = johnvansickle ]; then
      fetch "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-${ARCH}-static.tar.xz" "$VOL/ffmpeg.tar.xz" >>"$LOG" 2>&1 || continue
      tar -xJf "$VOL/ffmpeg.tar.xz" -C "$VOL" >>"$LOG" 2>&1 || continue
      EXDIR="$(find "$VOL" -maxdepth 1 -type d -name 'ffmpeg-*-static' | head -1)"
      [ -n "$EXDIR" ] || continue
      cp -f "$EXDIR/ffmpeg" "$EXDIR/ffprobe" "$BIN/" || continue
      rm -f "$VOL/ffmpeg.tar.xz"
    else
      fetch "$SRCURL/ffmpeg.zip"  "$VOL/ffmpeg.zip"  >>"$LOG" 2>&1 || continue
      fetch "$SRCURL/ffprobe.zip" "$VOL/ffprobe.zip" >>"$LOG" 2>&1 || continue
      unpack "$VOL/ffmpeg.zip"  "$BIN" >>"$LOG" 2>&1 || continue
      unpack "$VOL/ffprobe.zip" "$BIN" >>"$LOG" 2>&1 || continue
    fi
    chmod +x "$BIN/ffmpeg" "$BIN/ffprobe" 2>/dev/null || true
    rm -f "$VOL/ffmpeg.zip" "$VOL/ffprobe.zip"
    if has_ass "$BIN/ffmpeg"; then GOT="$SRCURL"; break; fi
    warn "받은 ffmpeg 에 자막 기능이 없습니다 ($SRCURL)" "다른 곳에서 다시 받아 봅니다"
  done
  [ -n "$GOT" ] || die "자막을 얹을 수 있는 ffmpeg 를 구하지 못했습니다" \
      "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요. 그래도 안 되면 만든 사람에게 알려 주세요"
  [ -x "$BIN/ffprobe" ] || die "ffprobe 가 없습니다" "설치 명령을 한 번 더 돌려 주세요"
  ok "ffmpeg · ffprobe (자막 기능 확인함)"
fi

# ── 5. yt-dlp ───────────────────────────────────────────────
step 5 "영상 받는 도구(yt-dlp) 준비"
if has yt-dlp; then
  skip "yt-dlp ($(command -v yt-dlp))"
else
  case "$OSNAME/$ARCH" in
    macos/*)     FNAME=yt-dlp_macos ;;
    linux/amd64) FNAME=yt-dlp_linux ;;
    linux/arm64) FNAME=yt-dlp_linux_aarch64 ;;
  esac
  fetch "https://github.com/yt-dlp/yt-dlp/releases/latest/download/$FNAME" "$BIN/yt-dlp" \
    || die "yt-dlp 를 받지 못했습니다" "인터넷 연결을 확인하고 설치 명령을 한 번 더 돌려 주세요"
  chmod +x "$BIN/yt-dlp"
  ok "yt-dlp"
fi

# ── 6. Claude Code ──────────────────────────────────────────
step 6 "Claude Code 준비"
if has claude; then
  skip "claude ($(command -v claude))"
else
  if [ "$DEST" = "$HOME" ]; then
    curl -fsSL https://claude.ai/install.sh 2>>"$LOG" | bash >>"$LOG" 2>&1 || true
  else
    HOME="$DEST" bash -c 'curl -fsSL https://claude.ai/install.sh | bash' >>"$LOG" 2>&1 || true
  fi
  hash -r 2>/dev/null || true
  if has claude; then
    ok "claude"
  else
    warn "Claude Code 를 설치하지 못했습니다" "설치는 계속합니다. 나중에 터미널에 이렇게 치세요: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# ── 7. VS Code ──────────────────────────────────────────────
# 사람들이 실제로 쓰는 길은 VS Code 다(사용자 지시 2026-09-05).
# 관리자 비밀번호를 묻지 않으려고 dmg 가 아니라 zip 을 받아 응용 프로그램 폴더에 놓는다.
step 7 "VS Code 준비"
# 시험(VOLCANO_DEST)일 때는 진짜 응용 프로그램 폴더를 쳐다보지도 않는다 —
# 앞판에서 시험이 진짜 자리에 앱을 깔아 버린 적이 있다(실측 2026-09-05).
VSAPP=""
if [ -n "${VOLCANO_DEST:-}" ]; then
  VSLOOK="$DEST/Applications/Visual Studio Code.app"
  [ -d "$VSLOOK" ] && VSAPP="$VSLOOK"
else
  for cand in "/Applications/Visual Studio Code.app" "$DEST/Applications/Visual Studio Code.app"; do
    [ -d "$cand" ] && VSAPP="$cand" && break
  done
fi
if [ -n "$VSAPP" ]; then
  skip "VS Code ($VSAPP)"
else
  if [ -n "${VOLCANO_DEST:-}" ]; then
    VSDIR="$DEST/Applications"; mkdir -p "$VSDIR" 2>/dev/null || true
  else
    VSDIR="/Applications"
    { [ -d "$VSDIR" ] && [ -w "$VSDIR" ]; } || { VSDIR="$DEST/Applications"; mkdir -p "$VSDIR" 2>/dev/null || true; }
  fi
  if fetch "https://update.code.visualstudio.com/latest/darwin-universal/stable" "$VOL/vscode.zip" >>"$LOG" 2>&1; then
    if ditto -x -k "$VOL/vscode.zip" "$VOL/vscode_x" >>"$LOG" 2>&1; then
      SRCAPP="$(/usr/bin/find "$VOL/vscode_x" -maxdepth 2 -type d -name '*.app' -print 2>/dev/null | head -1)"
      if [ -n "$SRCAPP" ] && ditto "$SRCAPP" "$VSDIR/Visual Studio Code.app" >>"$LOG" 2>&1; then
        xattr -dr com.apple.quarantine "$VSDIR/Visual Studio Code.app" 2>/dev/null || true
        VSAPP="$VSDIR/Visual Studio Code.app"
        ok "VS Code → $VSAPP"
      fi
    fi
    rm -f "$VOL/vscode.zip" 2>/dev/null || true
    /usr/bin/find "$VOL/vscode_x" -delete 2>/dev/null || true
  fi
  [ -n "$VSAPP" ] || warn "VS Code 를 넣지 못했습니다" "설치는 계속합니다. code.visualstudio.com 에서 직접 받아 설치하셔도 됩니다"
fi

# 확장(Claude Code) 넣기 · code 명령 자리 잡아 두기
CODEBIN=""
if [ -n "$VSAPP" ] && [ -x "$VSAPP/Contents/Resources/app/bin/code" ]; then
  CODEBIN="$VSAPP/Contents/Resources/app/bin/code"
elif [ -z "${VOLCANO_DEST:-}" ] && has code; then
  CODEBIN="$(command -v code)"
fi
if [ -n "$CODEBIN" ]; then
  if "$CODEBIN" --install-extension anthropic.claude-code --force >>"$LOG" 2>&1; then
    ok "VS Code 확장 (Claude Code)"
  else
    warn "VS Code 확장을 넣지 못했습니다" "VS Code 를 열고 확장에서 「Claude Code」를 찾아 설치하세요"
  fi
  ln -sfn "$CODEBIN" "$BIN/code" 2>/dev/null || true
fi

# ── 8. 설정 적기 ────────────────────────────────────────────
step 8 "설정 적기"
[ -f "$VOL/env" ] || : >"$VOL/env"
# 1=찾을 낱말 2=넣을 줄   (있는 줄은 절대 고치지 않는다)
env_add(){
  if grep -q "$1" "$VOL/env" 2>/dev/null; then
    printf '  · %s — 이미 적혀 있어 그대로 둡니다\n' "$1"
  else
    printf '%s\n' "$2" >>"$VOL/env"
    printf '  ✓ %s\n' "$1"
  fi
}
env_add VOLCANO_HOME   "export VOLCANO_HOME=\"$VOL\""
env_add VOLCANO_PY     "export VOLCANO_PY=\"$PY\""
env_add VOLCANO_JOBS   "export VOLCANO_JOBS=\"$JOBS\""
[ -n "${CODEBIN:-}" ] && env_add VOLCANO_CODE "export VOLCANO_CODE=\"$CODEBIN\""
env_add "$BIN"         "export PATH=\"$BIN:$DEST/.local/bin:\$PATH\""

case "${SHELL:-}" in *zsh) RCFILE="$DEST/.zshrc" ;; *) RCFILE="$DEST/.bashrc" ;; esac
MARK="# >>> 볼케이노 <<<"
if grep -q "$MARK" "$RCFILE" 2>/dev/null; then
  printf '  · 터미널 설정 — 이미 붙어 있습니다\n'
else
  printf '\n%s\n[ -f "%s" ] && source "%s"\n' "$MARK" "$VOL/env" "$VOL/env" >>"$RCFILE"
  ok "터미널 설정 ($RCFILE)"
fi
fetch_pkg "점검.py"       "$SETUP/점검.py"       >>"$LOG" 2>&1 || warn "점검.py 를 가져오지 못했습니다" "$(why_fail "점검.py")"
fetch_pkg "설치마무리.py" "$SETUP/설치마무리.py" >>"$LOG" 2>&1 || warn "설치마무리.py 를 가져오지 못했습니다" "$(why_fail "설치마무리.py")"

# ── 9. 바탕화면 바로가기 ────────────────────────────────────
step 9 "바탕화면 바로가기 만들기"
if   [ -d "$DEST/Desktop" ];  then DESKTOP="$DEST/Desktop"
elif [ -d "$DEST/바탕화면" ]; then DESKTOP="$DEST/바탕화면"
else DESKTOP="$DEST"; fi
# 앱이 부른 것이면 바탕화면에 **앱 아이콘**을 놓는다 (검은 창이 뜨는 .command 대신).
if [ "${VOLCANO_APP:-0}" = "1" ] && [ -n "${VOLCANO_APP_PATH:-}" ] && [ -e "$VOLCANO_APP_PATH" ]; then
  LINK="$DESKTOP/볼케이노"
  if ln -sfn "$VOLCANO_APP_PATH" "$LINK" 2>/dev/null; then
    ok "$LINK (앱 아이콘)"
  else
    warn "바탕화면에 아이콘을 놓지 못했습니다" "응용 프로그램 폴더의 「볼케이노」를 바탕화면으로 끌어다 놓으세요"
  fi
  OLD_CMD="$DESKTOP/볼케이노.command"
  [ -f "$OLD_CMD" ] && mv -f "$OLD_CMD" "$SETUP/볼케이노.command.예전것" 2>/dev/null || true
else
SHORTCUT="$DESKTOP/볼케이노.command"
cat >"$SHORTCUT" <<SHORTCUT_END
#!/usr/bin/env bash
# 볼케이노 — 두 번 눌러서 시작합니다
source "$VOL/env" 2>/dev/null
if [ -f "$SETUP/점검.py" ]; then
  "\$VOLCANO_PY" "$SETUP/점검.py" || {
    echo
    echo "위 ✗ 를 먼저 고쳐 주세요. 그래도 시작하려면 엔터를 누르세요."
    read -r _
  }
fi
cd "$JOBS" || exit 1
exec claude
SHORTCUT_END
chmod +x "$SHORTCUT"
ok "$SHORTCUT"
fi

# ── 10. 마무리 (이 창에서 그대로) ───────────────────────────
# 새 창을 열지 않는다. curl | bash 로 들어와 stdin 이 파이프라도,
# 창 자체(/dev/tty)를 물려주면 이 자리에서 묻고 답할 수 있다.
step 10 "마무리 — 로그인과 열쇠 넣기"
FINISH="$SETUP/마무리.command"
if [ "${VOLCANO_APP:-0}" = "1" ]; then
  # 앱이 제 창 안에서 마무리 화면을 이어서 띄운다. 여기서 물으면 답할 사람이 없다.
  say "  · 마무리는 볼케이노 앱 창에서 이어서 합니다."
elif [ ! -f "$SETUP/설치마무리.py" ]; then
  warn "마무리 파일이 없어 여기서 멈춥니다" "$(why_fail "설치마무리.py")"
else
  cat >"$FINISH" <<FINISH_END
#!/usr/bin/env bash
# 나중에 다시 이어서 할 때 이 파일을 두 번 누르면 됩니다.
source "$VOL/env" 2>/dev/null
exec "$PY" "$SETUP/설치마무리.py"
FINISH_END
  chmod +x "$FINISH"
  if [ -r /dev/tty ]; then
    say ""
    say "  · 여기서 이어서 몇 가지만 물어보겠습니다."
    "$PY" "$SETUP/설치마무리.py" </dev/tty || true
  else
    warn "물어볼 창이 없습니다" "터미널에 이렇게 치세요: $FINISH"
  fi
fi

cat <<TAIL

────────────────────────────────────
 여기까지 끝났습니다.
 1) 못 넣은 것이 있으면 이렇게 이어서 하면 됩니다: $FINISH
 2) 다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다.
 기록: $LOG
────────────────────────────────────
TAIL
log "=== 설치 끝 ==="
