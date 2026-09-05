#!/usr/bin/env bash
# 볼케이노 — 맥 한 줄 설치
#
#   curl -fsSL https://volcanoai.io/setup/install.sh | bash
#
# ■ 여기서 하는 일은 「앱을 놓고 여는 것」 뿐이다.
#   파이썬·ffmpeg·받아쓰기 같은 나머지 설치는 **앱이 제 창 안에서** 이어서 한다.
#
# ■ 왜 터미널로 받나
#   브라우저로 받은 파일에는 맥이 「인터넷에서 받음」 표(com.apple.quarantine)를 붙인다.
#   그 표가 붙으면 공증받지 않은 앱은 「열지 않음」 창에 막힌다.
#   curl 로 받으면 그 표가 아예 붙지 않아 창이 뜨지 않는다.
#
# ■ 손댈 때 주의
#   · bash 는 변수 이름에 한글을 못 쓴다. 안에서 쓰는 이름은 영문으로 짓는다.
#   · 이 파일은 파이프로 bash 에 먹인다. stdin 이 스크립트 자신이므로 read 로 묻지 않는다.
#   · rm -rf 를 쓰지 않는다. 이미 깔린 앱은 지우지 말고 옮겨 둔다.

set -euo pipefail

BASE_URL="${VOLCANO_BASE:-https://beautifulahin.github.io/volcano-setup-temp}"
BASE_URL="${BASE_URL%/}"
# 꾸러미 이름은 ASCII 다 — 배포물 안·놓을 자리의 파일 이름에 한글을 쓰지 않는다.
# (윈도우 Expand-Archive 가 한글 이름을 못 풀어 설치가 죽은 적이 있다. 맥도 같은 규칙으로 맞춘다.)
# Finder 에는 Info.plist 의 CFBundleDisplayName 덕에 「볼케이노」로 보인다.
APP_NAME="Volcano.app"
APP_SHOW="볼케이노"      # 사람에게 보여 줄 이름

# 놓을 자리
#   · 평소  : /Applications → 권한이 없으면 ~/Applications
#   · 시험  : VOLCANO_DEST 를 주면 그 밑의 Applications 에만 놓고, **거기 것**을 연다.
#             (VOLCANO_APP_DEST 는 자리를 통째로 지정하는 예전 이름 — 함께 받는다)
#   시험 자리일 때는 진짜 자리(/Applications·~/Applications)로 절대 물러서지 않는다.
sandbox=0
if [ -n "${VOLCANO_APP_DEST:-}" ]; then
  DEST_ROOT="${VOLCANO_APP_DEST%/}"; sandbox=1
elif [ -n "${VOLCANO_DEST:-}" ]; then
  DEST_ROOT="${VOLCANO_DEST%/}/Applications"; sandbox=1
else
  DEST_ROOT="/Applications"
fi
# 이미 있던 앱을 치워 둘 자리도 시험 자리를 따라간다
KEEP_ROOT="$HOME"
if [ "$sandbox" = "1" ]; then KEEP_ROOT="${VOLCANO_DEST:-$DEST_ROOT}"; fi

tmp_dir=""
cleanup(){ if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then /usr/bin/find "$tmp_dir" -delete 2>/dev/null || true; fi; }
trap cleanup EXIT

say(){ printf '%s\n' "$*"; }
fail(){
  printf '\n❌ %s\n' "$1"; shift
  if [ $# -gt 0 ]; then printf '   %s\n' "$@"; fi
  exit 1
}

say ""
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say "  볼케이노 설치"
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say "  설치 자리 : $DEST_ROOT/$APP_NAME"
if [ "$sandbox" = "1" ]; then say "  (시험 자리입니다 — 응용 프로그램 폴더는 건드리지 않습니다)"; fi

# ① 맥인지 확인
if [ "$(uname -s)" != "Darwin" ]; then
  fail "이 설치 방법은 맥에서만 됩니다." \
       "윈도우를 쓰신다면 받는 페이지에서 윈도우 명령을 복사해 주세요." \
       "$BASE_URL"
fi

# ② 칩 가르기 — 로제타 안에서 돌면 uname 이 x86_64 라고 답하므로 하드웨어를 따로 본다
is_arm=0
if [ "$(uname -m)" = "arm64" ]; then
  is_arm=1
else
  arm_flag="$( { sysctl -n hw.optional.arm64 || /usr/sbin/sysctl -n hw.optional.arm64 ; } 2>/dev/null || echo 0 )"
  [ "$arm_flag" = "1" ] && is_arm=1
fi
if [ "$is_arm" = "1" ]; then
  asset="volcano-mac-apple-silicon.zip"; chip_name="Apple 칩"
else
  asset="volcano-mac-intel.zip";        chip_name="Intel 칩"
fi
say "[1/6] 내 맥: $chip_name — $asset 를 받습니다."

# ③ 내려받기
tmp_dir="$(mktemp -d)"
say "[2/6] 내려받는 중… (40MB 정도, 10초~1분)"
if ! curl -fL --retry 2 --progress-bar -o "$tmp_dir/$asset" "$BASE_URL/$asset"; then
  fail "내려받지 못했습니다." \
       "인터넷 연결을 확인하고 잠시 뒤 같은 명령을 다시 붙여넣어 보세요." \
       "그래도 안 되면 이 주소가 열리는지 봐 주세요: $BASE_URL/$asset"
fi
[ -s "$tmp_dir/$asset" ] || fail "받은 파일이 비어 있습니다. 잠시 뒤 다시 해 주세요."

# ④ 풀기 — 실행권한과 코드서명을 온전히 보존하려면 unzip 이 아니라 ditto 여야 한다
say "[3/6] 압축을 푸는 중…"
ditto -x -k "$tmp_dir/$asset" "$tmp_dir/x" 2>/dev/null \
  || fail "받은 파일의 압축을 풀지 못했습니다." "받다가 끊겼을 수 있습니다. 같은 명령을 한 번 더 붙여넣어 주세요."

app_src="$(/usr/bin/find "$tmp_dir/x" -maxdepth 3 -type d -name '*.app' -print 2>/dev/null | head -1)"
if [ -z "$app_src" ] || [ ! -d "$app_src/Contents/MacOS" ]; then
  fail "압축 안에서 「${APP_SHOW}」 앱을 찾지 못했습니다." "만든 사람에게 알려 주세요."
fi

# ⑤ 놓을 자리 정하기 — 응용 프로그램 폴더에 못 쓰면 홈 폴더의 Applications 로
if [ "$sandbox" = "1" ]; then
  # 시험 자리 — 없으면 만들고, 안 되면 그냥 멈춘다(진짜 자리로 물러서지 않는다)
  mkdir -p "$DEST_ROOT" 2>/dev/null || true
  [ -d "$DEST_ROOT" ] && [ -w "$DEST_ROOT" ] \
    || fail "$DEST_ROOT 에 넣지 못했습니다." "시험 자리이므로 응용 프로그램 폴더로 물러서지 않고 멈춥니다."
elif [ ! -d "$DEST_ROOT" ] || [ ! -w "$DEST_ROOT" ]; then
  say ""
  say "⚠️  $DEST_ROOT 에 넣을 권한이 없습니다. 홈 폴더의 Applications 에 넣습니다."
  DEST_ROOT="$HOME/Applications"
  mkdir -p "$DEST_ROOT" 2>/dev/null || true
  [ -w "$DEST_ROOT" ] || fail "$HOME/Applications 에도 넣지 못했습니다." "맥을 다시 켠 뒤 같은 명령을 다시 해 주세요."
fi
dest_app="$DEST_ROOT/$APP_NAME"

# 이미 깔려 있으면 지우지 말고 치운다
if [ -e "$dest_app" ]; then
  backup_dir="$KEEP_ROOT/.volcano_prev/$(date +%Y%m%d_%H%M)"
  mkdir -p "$backup_dir"
  mv "$dest_app" "$backup_dir/" \
    || fail "이미 있는 앱을 옮기지 못했습니다." "앱이 실행 중이면 먼저 끄고 같은 명령을 다시 해 주세요."
  say "[4/6] 이미 있던 앱은 지우지 않고 옮겨 두었습니다 → $backup_dir"
else
  say "[4/6] 처음 설치입니다."
fi

# ⑥ 놓기
ditto "$app_src" "$dest_app" || fail "$DEST_ROOT 에 넣지 못했습니다." "저장 공간을 확인하고 다시 해 주세요."
say "[5/6] 넣었습니다 → $dest_app"

# ⑦ 안전벨트 — 혹시라도 붙은 「인터넷에서 받음」 표를 떼어 둔다
xattr -dr com.apple.quarantine "$dest_app" 2>/dev/null || true

# ⑧ 열기 — 놓은 그 자리의 것을 연다
say "[6/6] 실행합니다…"
opened=0
if [ "${VOLCANO_NO_RUN:-0}" = "1" ]; then
  say ""
  say "✅ 놓기만 했습니다 (VOLCANO_NO_RUN=1) → $dest_app"
  say ""
  exit 0
fi
if [ "$sandbox" = "1" ]; then
  # 시험 자리에서는 open(런치서비스)을 쓰지 않는다 — 지금 창의 VOLCANO_DEST 가 앱에 안 넘어가고,
  # 이름이 같은 진짜 자리의 앱이 대신 열릴 수 있다. 실행파일을 바로 띄워 환경을 그대로 물려준다.
  app_bin="$(/usr/bin/find "$dest_app/Contents/MacOS" -maxdepth 1 -type f -perm -111 2>/dev/null | head -1)"
  if [ -n "$app_bin" ]; then
    ( "$app_bin" >/dev/null 2>&1 & )
    opened=1
  fi
else
  open "$dest_app" 2>/dev/null && opened=1
fi
if [ "$opened" = "1" ]; then
  say ""
  say "✅ 여기까지 끝났습니다. 잠시 뒤 볼케이노 창이 열립니다."
  say "   나머지 설치는 그 창 안에서 이어집니다 — 단추만 누르시면 됩니다."
else
  say ""
  say "✅ 앱은 넣었습니다. 다만 자동으로 열리지 않았습니다."
  say "   Finder 에서 $DEST_ROOT 의 「${APP_SHOW}」 을 더블클릭해 주세요."
fi
say ""
say "   다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다. 경고창은 나오지 않습니다."
say ""
