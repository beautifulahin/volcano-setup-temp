#!/usr/bin/env bash
# 볼케이노 — 처음 설치 (맥)
#
#   ■ 쓰는 법
#     이 파일 **하나만** 있으면 됩니다. 두 번 누르세요.
#     창이 안 열리고 「확인되지 않은 개발자」 경고가 뜨면
#     이 파일을 **오른쪽 클릭 → 열기** 를 한 번만 해 주세요.
#
#   ■ 하는 일
#     설치기를 웹에서 받아 이 창에서 그대로 끝까지 깝니다.
#     파이썬 · 영상 도구 · 받아쓰기 · Claude Code · VS Code 를 넣고
#     볼케이노를 붙여 바로 쓸 수 있게 합니다. 관리자 비밀번호는 묻지 않습니다.
#     (2026-09-06 사용자 지시 「한 파일로 하게해」 — 옆에 zip 을 두던 방식을 버렸다.)
#
#   ■ 손댈 때 주의
#     · bash 는 변수 이름에 한글을 못 쓴다. 안에서 쓰는 이름은 영문으로 짓는다.
#     · rm -rf 를 쓰지 않는다. 시험은 VOLCANO_DEST 로만 하고 HOME 은 바꾸지 않는다.

set -euo pipefail

BASE="${VOLCANO_BASE:-https://beautifulahin.github.io/volcano-setup-temp}"
BASE="${BASE%/}"

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
say "  이 창에서 전부 끝납니다. 10~20분쯤 걸립니다."
say "  관리자 비밀번호는 묻지 않습니다."
if [ -n "${VOLCANO_DEST:-}" ]; then say "  (시험 자리입니다 — 진짜 자리는 건드리지 않습니다)"; fi
say ""

# ① 맥인지
[ "$(uname -s)" = "Darwin" ] || fail "이 파일은 맥에서만 됩니다." "윈도우에서는 「setup.bat」 을 두 번 누르세요."

# ② 「인터넷에서 받음」 표를 뗀다 — 안 떼면 두 번째부터 또 경고가 뜬다
xattr -dr com.apple.quarantine "$0" 2>/dev/null || true

# ③ 설치기 본체를 받아 이 창에서 돈다.
#    인텔인지 애플 칩인지는 본체가 알아서 가른다 — 사람이 고를 것이 없다.
say "  · 최신 설치기를 받습니다…"
tmp_dir="$(mktemp -d)"
cleanup(){ if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then /usr/bin/find "$tmp_dir" -delete 2>/dev/null || true; fi; }
trap cleanup EXIT

body="$tmp_dir/body.sh"
curl -fsSL --connect-timeout 20 --max-time 180 "$BASE/%EC%84%A4%EC%B9%98%EB%B3%B8%EC%B2%B4.sh" -o "$body" 2>/dev/null \
  || curl -fsSL --connect-timeout 20 --max-time 180 "$BASE/설치본체.sh" -o "$body" 2>/dev/null \
  || fail "설치기를 받지 못했습니다." \
          "인터넷 연결을 확인하고 이 파일을 한 번 더 눌러 주세요." \
          "받는 곳: $BASE"

[ -s "$body" ] || fail "받은 설치기가 비어 있습니다." "잠시 뒤 한 번 더 눌러 주세요."

# 고침이(fix-mac.command)를 바탕화면에 놓아 둔다 — 나중에 뭔가 안 될 때 누를 것.
desk="${VOLCANO_DEST:-$HOME}/Desktop"
if [ -d "$desk" ]; then
  curl -fsSL --connect-timeout 15 --max-time 60 "$BASE/fix-mac.command" -o "$desk/volcano-fix.command" 2>/dev/null \
    && chmod 755 "$desk/volcano-fix.command" 2>/dev/null || true
fi

say ""
export VOLCANO_APP=''      # 이 창이 사람 창이다 — 여기서 묻는다
bash "$body"
