#!/usr/bin/env bash
# 볼케이노 — 처음 설치 (맥)
#
#   ■ 쓰는 법
#     이 파일을 volcano-mac-*.zip 과 **같은 폴더**에 두고 두 번 누르세요.
#     창이 안 열리고 「확인되지 않은 개발자」 경고가 뜨면
#     이 파일을 **오른쪽 클릭 → 열기** 를 한 번만 해 주세요. (그다음부터는 두 번 누르면 됩니다)
#
#   ■ 하는 일
#     옆에 있는 zip 에서 내 맥에 맞는 것을 골라 → 풀고 → 「인터넷에서 받음」 표를 떼고 →
#     응용 프로그램 폴더에 놓고 → 엽니다. 나머지 설치는 앱 창 안에서 이어집니다.
#
#   ■ 손댈 때 주의
#     · bash 는 변수 이름에 한글을 못 쓴다. 안에서 쓰는 이름은 영문으로 짓는다.
#     · rm -rf 를 쓰지 않는다. 이미 깔린 앱은 지우지 말고 옮겨 둔다.
#     · 시험은 VOLCANO_DEST 로만 한다. HOME 은 바꾸지 않는다(맥 키체인이 깨진다).

set -euo pipefail

# 꾸러미 이름은 ASCII 다 — 배포물 안·놓을 자리의 파일 이름에 한글을 쓰지 않는다.
# (윈도우 Expand-Archive 가 한글 이름을 못 풀어 설치가 죽은 적이 있다. 맥도 같은 규칙으로 맞춘다.)
# Finder 에는 Info.plist 의 CFBundleDisplayName 덕에 「볼케이노」로 보인다.
APP_NAME="Volcano.app"
APP_SHOW="볼케이노"      # 사람에게 보여 줄 이름
here="$(cd "$(dirname "$0")" && pwd)"

# 놓을 자리
#   · 평소 : /Applications → 권한이 없으면 ~/Applications
#   · 시험 : VOLCANO_DEST 를 주면 그 밑의 Applications 에만 놓고 거기 것을 연다.
sandbox=0
if [ -n "${VOLCANO_DEST:-}" ]; then
  DEST_ROOT="${VOLCANO_DEST%/}/Applications"; sandbox=1
else
  DEST_ROOT="/Applications"
fi
KEEP_ROOT="$HOME"
if [ "$sandbox" = "1" ]; then KEEP_ROOT="${VOLCANO_DEST%/}"; fi

say(){ printf '%s\n' "$*"; }
hold(){                     # 두 번 눌러 연 창이 바로 닫히지 않게
  if [ -t 0 ]; then printf '\n  엔터를 누르면 이 창이 닫힙니다 '; read -r _ || true; fi
}
fail(){
  printf '\n❌ %s\n' "$1"; shift
  if [ $# -gt 0 ]; then printf '   %s\n' "$@"; fi
  hold; exit 1
}

say ""
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say "  볼케이노 처음 설치"
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say "  설치 자리 : $DEST_ROOT/$APP_NAME"
if [ "$sandbox" = "1" ]; then say "  (시험 자리입니다 — 응용 프로그램 폴더는 건드리지 않습니다)"; fi
say ""
say "  ※ 이 창이 안 열리고 경고가 떴다면: 이 파일을 오른쪽 클릭 → 열기 를 한 번만 하세요."
say ""

# ① 맥인지
[ "$(uname -s)" = "Darwin" ] || fail "이 파일은 맥에서만 됩니다." "윈도우에서는 「처음설치.bat」 을 두 번 누르세요."

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
say "[1/5] 내 맥: $chip_name — $asset 를 찾습니다."

zip_path="$here/$asset"
if [ ! -f "$zip_path" ]; then
  # 이름이 조금 다를 수 있으니 한 번 더 찾아본다
  zip_path="$(/usr/bin/find "$here" -maxdepth 1 -type f -name "$asset" -print 2>/dev/null | head -1)"
fi
[ -n "$zip_path" ] && [ -f "$zip_path" ] \
  || fail "이 파일 옆에서 「$asset」 을 찾지 못했습니다." \
          "받은 파일을 전부 같은 폴더에 두고 다시 두 번 눌러 주세요." \
          "지금 폴더: $here"

# ③ 표 떼기 — 받은 zip 에 붙은 「인터넷에서 받음」 표를 먼저 뗀다
say "[2/5] 「인터넷에서 받음」 표를 뗍니다…"
xattr -dr com.apple.quarantine "$zip_path" 2>/dev/null || true
xattr -dr com.apple.quarantine "$0" 2>/dev/null || true

# ④ 풀기 — 실행권한과 코드서명을 온전히 보존하려면 unzip 이 아니라 ditto 여야 한다
say "[3/5] 압축을 푸는 중…"
tmp_dir="$(mktemp -d)"
cleanup(){ if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then /usr/bin/find "$tmp_dir" -delete 2>/dev/null || true; fi; }
trap cleanup EXIT
ditto -x -k "$zip_path" "$tmp_dir/x" 2>/dev/null \
  || fail "압축을 풀지 못했습니다." "받다가 끊겼을 수 있습니다. 파일을 다시 받아 주세요."

app_src="$(/usr/bin/find "$tmp_dir/x" -maxdepth 3 -type d -name '*.app' -print 2>/dev/null | head -1)"
if [ -z "$app_src" ] || [ ! -d "$app_src/Contents/MacOS" ]; then
  fail "압축 안에서 「${APP_SHOW}」 앱을 찾지 못했습니다." "파일을 건네준 사람에게 알려 주세요."
fi
xattr -dr com.apple.quarantine "$app_src" 2>/dev/null || true

# ⑤ 놓을 자리 — 응용 프로그램 폴더에 못 쓰면 홈 폴더의 Applications 로
if [ "$sandbox" = "1" ]; then
  mkdir -p "$DEST_ROOT" 2>/dev/null || true
  [ -d "$DEST_ROOT" ] && [ -w "$DEST_ROOT" ] \
    || fail "$DEST_ROOT 에 넣지 못했습니다." "시험 자리이므로 응용 프로그램 폴더로 물러서지 않고 멈춥니다."
elif [ ! -d "$DEST_ROOT" ] || [ ! -w "$DEST_ROOT" ]; then
  say ""
  say "⚠️  $DEST_ROOT 에 넣을 권한이 없습니다. 홈 폴더의 Applications 에 넣습니다."
  DEST_ROOT="$HOME/Applications"
  mkdir -p "$DEST_ROOT" 2>/dev/null || true
  [ -w "$DEST_ROOT" ] || fail "$HOME/Applications 에도 넣지 못했습니다." "맥을 다시 켠 뒤 다시 해 주세요."
fi
dest_app="$DEST_ROOT/$APP_NAME"

# 이미 깔려 있으면 지우지 말고 치운다
if [ -e "$dest_app" ]; then
  backup_dir="$KEEP_ROOT/.volcano_prev/$(date +%Y%m%d_%H%M)"
  mkdir -p "$backup_dir"
  mv "$dest_app" "$backup_dir/" \
    || fail "이미 있는 앱을 옮기지 못했습니다." "볼케이노가 켜져 있으면 끄고 다시 해 주세요."
  say "[4/5] 이미 있던 앱은 지우지 않고 옮겨 두었습니다 → $backup_dir"
else
  say "[4/5] 처음 설치입니다."
fi

ditto "$app_src" "$dest_app" || fail "$DEST_ROOT 에 넣지 못했습니다." "저장 공간을 확인하고 다시 해 주세요."
# 놓은 뒤에도 한 번 더 — 표가 남아 있으면 「열지 않음」 창이 뜬다
xattr -dr com.apple.quarantine "$dest_app" 2>/dev/null || true
say "   넣었습니다 → $dest_app"

# ⑥ 열기 — 놓은 그 자리의 것을 연다
say "[5/5] 실행합니다…"
opened=0
if [ "${VOLCANO_NO_RUN:-0}" = "1" ]; then
  say ""
  say "✅ 놓기만 했습니다 (VOLCANO_NO_RUN=1) → $dest_app"
  hold; exit 0
fi
if [ "$sandbox" = "1" ]; then
  # 시험 자리에서는 open(런치서비스)을 쓰지 않는다 — 지금 창의 VOLCANO_DEST 가 안 넘어가고,
  # 이름이 같은 진짜 자리의 앱이 대신 열릴 수 있다.
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
  say "✅ 다 됐습니다. 잠시 뒤 볼케이노 창이 열립니다."
  say "   나머지 설치는 그 창 안에서 이어집니다 — 단추만 누르시면 됩니다."
else
  say ""
  say "✅ 앱은 넣었습니다. 다만 자동으로 열리지 않았습니다."
  say "   Finder 에서 $DEST_ROOT 의 「${APP_SHOW}」 을 두 번 눌러 주세요."
fi
say ""
say "   다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 됩니다. 경고창은 나오지 않습니다."
hold
