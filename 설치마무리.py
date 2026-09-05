#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""볼케이노 설치 마무리 — 로그인 · 볼케이노 붙이기 · 채널 고르기 · 열쇠 넣기.

  설치기가 새 터미널 창에서 이 파일을 연다(여기서는 사람에게 물을 수 있다).
  설치 직후라 아무것도 못 믿으므로 **표준 라이브러리만** 쓴다 — 더 깔 것이 없다.

  **기본은 터미널 판**이다 — 붙여넣은 그 창 하나에서 끝까지 한다.
  새 창을 열지 않는다. `curl … | bash` 로 들어오면 stdin 이 파이프라 못 묻는데,
  그때는 창 자체(/dev/tty · 윈도우 CONIN$)를 열어 거기서 읽는다(사람창).
  claude 로그인과 승인도 그 창을 물려받아 같은 자리에서 돈다.

  --화면 을 주면 브라우저 화면으로 한다. 안방(127.0.0.1)에만 자리를 잡고
  빈 포트를 골라 띄우며, 시작할 때 만든 비밀글자(표)가 없는 요청은 전부 막는다.
  브라우저를 못 열면 저절로 터미널 판으로 되돌아간다.
"""
import http.server
import json
import os
import re
import secrets
import shlex
import shutil
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path

윈도우 = os.name == "nt"

try:  # 말이 나오는 차례가 뒤섞이지 않게
    sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass


def 볼케이노집() -> Path:
    있는것 = os.environ.get("VOLCANO_HOME")
    if 있는것:
        return Path(있는것)
    if 윈도우:
        바탕 = os.environ.get("LOCALAPPDATA") or str(Path.home())
        return Path(바탕) / "volcano"
    return Path.home() / ".volcano"


집 = 볼케이노집()
설치기 = 집 / "설치기"
열쇠집 = 집 / "keys"
파이썬 = 집 / ("venv/Scripts/python.exe" if 윈도우 else "venv/bin/python3")
설치기.mkdir(parents=True, exist_ok=True)
열쇠집.mkdir(parents=True, exist_ok=True)
try:
    os.chmod(열쇠집, 0o700)
except Exception:
    pass


def 작업장() -> Path:
    """볼케이노가 작업 폴더를 두는 자리. env 가 알려 주면 그것을 쓴다."""
    있는것 = os.environ.get("VOLCANO_JOBS")
    if 있는것:
        return Path(있는것).expanduser()
    return Path.home() / "volcano_jobs"


def 설정읽기() -> dict:
    for 자리 in (설치기 / "설정.json", Path(__file__).resolve().parent / "설정.json"):
        try:
            return json.loads(자리.read_text(encoding="utf-8"))
        except Exception:
            continue
    return {}


설정 = 설정읽기()
남길것: list[str] = []   # 운영자에게 받아야 채워지는 것


def 줄():
    print("─" * 46)


def 제목(글):
    print()
    줄()
    print(f" {글}")
    줄()


창간직 = {}


def 사람창():
    """사람이 글자를 치는 창.

    설치가 `curl … | bash` 로 들어오면 stdin 이 파이프라 input() 이 못 쓴다.
    그럴 때는 창 자체(/dev/tty · 윈도우는 CONIN$)를 열어 거기서 읽는다.
    그것도 못 열면 진짜 무인 환경이니 None 을 돌려준다."""
    if "것" in 창간직:
        return 창간직["것"]
    것 = None
    try:
        if sys.stdin is not None and sys.stdin.isatty():
            것 = sys.stdin
    except Exception:
        것 = None
    if 것 is None:
        try:
            것 = open("CONIN$" if 윈도우 else "/dev/tty", "r",
                      encoding="utf-8", errors="replace")
        except Exception:
            것 = None
    창간직["것"] = 것
    return 것


def 사람있나():
    return 사람창() is not None


def 사람실행(명령, **덧):
    """사람이 직접 쳐야 하는 프로그램을 **이 창에서** 돌린다."""
    창 = 사람창()
    덧.setdefault("check", False)
    if 창 is not None and 창 is not sys.stdin:
        덧["stdin"] = 창
    return subprocess.run(명령, **덧)


def 물음(글, 기본=""):
    창 = 사람창()
    if 창 is None:
        print(글)
        return 기본
    try:
        sys.stdout.write(글)
        sys.stdout.flush()
        답 = 창.readline()
    except (EOFError, KeyboardInterrupt):
        print()
        return 기본
    if 답 == "":          # 창이 닫혔다
        print()
        return 기본
    return 답.strip() or 기본


def 예아니오(글, 기본=True):
    안내 = "[예/아니오] " + ("(그냥 엔터 = 예)" if 기본 else "(그냥 엔터 = 아니오)")
    답 = 물음(f"{글} {안내} ").lower()
    if not 답:
        return 기본
    return 답[0] in ("y", "예", "ㅇ", "네") or 답.startswith("예")


def 로조사(말):
    """받침을 보고 「로」 인지 「으로」 인지 고른다."""
    끝 = (말 or "").strip()[-1:]
    if not 끝:
        return "로"
    코드 = ord(끝)
    if 0xAC00 <= 코드 <= 0xD7A3:
        받침 = (코드 - 0xAC00) % 28
        return "로" if 받침 in (0, 8) else "으로"   # 0=받침없음, 8=ㄹ
    return "로"


def 찾기(이름):
    덧 = [str(집 / "bin"), str(파이썬.parent)]
    길 = os.pathsep.join(덧 + [os.environ.get("PATH", "")])
    return shutil.which(이름, path=길)


def 비었나(값):
    return not 값 or 값 == "TODO"


# ── 1. Claude Code 로그인 ───────────────────────────────────
# 로그인 판정은 오직 claude auth status 의 JSON(loggedIn) 하나로 한다.
# 말글을 어림짐작하면 판정이 흔들려서 사람이 같은 자리를 맴돈다.
로그인명령 = ["auth", "login", "--claudeai"]


def 로그인판정(claude=None):
    """돌려주는 값: True(로그인됨) · False(아직) · None(모름)."""
    claude = claude or 찾기("claude")
    if not claude:
        return None
    try:
        답 = subprocess.run([claude, "auth", "status"],
                            capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    글 = (답.stdout or "") + "\n" + (답.stderr or "")
    앞, 뒤 = 글.find("{"), 글.rfind("}")
    if 앞 < 0 or 뒤 < 앞:
        return None
    try:
        본것 = json.loads(글[앞:뒤 + 1])
    except Exception:
        return None
    값 = 본것.get("loggedIn")
    return bool(값) if isinstance(값, bool) else None


def 로그인():
    제목("1. Claude Code 로그인")
    claude = 찾기("claude")
    if not claude:
        print("  ✗ Claude Code 가 아직 없습니다.")
        print("    → 터미널에 이렇게 치세요: curl -fsSL https://claude.ai/install.sh | bash")
        return False
    if 로그인판정(claude) is True:
        print("  ✓ 이미 로그인돼 있습니다.")
        return True
    print("  이제 로그인을 합니다.")
    print("   · 브라우저가 열립니다.")
    print("   · Claude 계정으로 로그인하세요.")
    print("   · 끝나면 이 창으로 돌아오세요.")
    물음("  준비되면 엔터를 누르세요… ")
    # 사람이 치는 창이 아예 없으면(진짜 무인 환경) 로그인을 띄우지 않는다.
    # 띄우면 영어 오류만 뱉고 죽어서, 초보자가 못 읽는 글이 화면에 남는다.
    if not 사람있나():
        print("  ! 지금은 사람이 직접 치는 창이 아니어서 로그인을 못 엽니다.")
        print("    → 터미널에서  claude auth login --claudeai  를 친 뒤,"
              " 이 마무리를 다시 돌려 주세요.")
        return False
    try:
        사람실행([claude] + 로그인명령)
    except Exception as 왜:
        print(f"  ! 로그인을 띄우지 못했습니다: {왜}")
    if 로그인판정(claude) is True:
        print("  ✓ 로그인됐습니다.")
        return True
    print("  ✗ 아직입니다.")
    print("    → 터미널에  claude auth login --claudeai  를 친 뒤,"
          " 이 마무리를 다시 돌려 주세요.")
    return False


# ── 2. 볼케이노 붙이고 승인받기 ─────────────────────────────
# 가입은 운영자가 따로 받는다. 그리고 **메일은 우리가 대신 보내지 않는다** —
# 볼케이노는 OAuth 를 쓰고, Claude Code 가 브라우저를 열어 메일을 받고
# 토큰까지 스스로 저장한다. 그 페이지가 「열쇠를 복사해 옮길 일이 없다」고
# 적어 둔 그 길이다. 우리는 붙여 주고, 살았는지 보고, 승인됐는지 알려 준다.

def 서버살았나(주소):
    """돌아오는 값: (살았나, 사람에게 할 말)"""
    문 = 주소.rstrip("/") + "/oauth/authorize"
    청 = urllib.request.Request(문, headers={"User-Agent": "volcano-setup"})
    try:
        urllib.request.urlopen(청, timeout=15, context=ssl.create_default_context())
        return True, ""
    except urllib.error.HTTPError as 답:
        # 400 은 정상이다 — 인자 없이 부르면 그렇게 답한다. 살아 있다는 뜻.
        if 답.code in (400, 401, 403):
            return True, ""
        if 답.code == 404:
            return False, ("볼케이노 로그인 창구가 없어졌습니다 (404). "
                           "주소가 바뀐 것 같습니다 — 만든 사람에게 알려 주세요.")
        return False, f"볼케이노 서버가 {답.code} 로 답했습니다. 잠시 뒤 다시 해 보세요."
    except urllib.error.URLError as 왜:
        return False, ("볼케이노 서버에 닿지 못했습니다. "
                       f"인터넷을 확인해 보시고, 그래도 안 되면 서버가 내려간 것입니다 ({왜.reason}).")
    except Exception as 왜:
        return False, f"볼케이노 서버를 확인하지 못했습니다 ({type(왜).__name__})."


def 이미붙은이름(주소):
    """같은 주소가 **다른 이름으로** 이미 붙어 있는지 본다.
    이미 쓰던 사람에게 두 벌을 만들지 않으려는 것이다.
    돌아오는 값: (이름 또는 None, 승인됐나)"""
    claude = 찾기("claude")
    if not claude:
        return None, False
    try:
        답 = subprocess.run([claude, "mcp", "list"],
                            capture_output=True, text=True, timeout=90)
    except Exception:
        return None, False
    민주소 = 주소.rstrip("/")
    for 줄 in (답.stdout or "").splitlines():
        if 민주소 not in 줄 or ":" not in 줄:
            continue
        이름 = 줄.split(":", 1)[0].strip()
        if not 이름 or " " in 이름:
            continue
        return 이름, ("Connected" in 줄 or "✔" in 줄)
    return None, False


def 연결됐나(이름=None):
    """claude mcp get 으로 승인 여부를 본다. 돌아오는 값: True/False/None(모름)"""
    claude = 찾기("claude")
    if not claude:
        return None
    이름 = 이름 or str(설정.get("mcp_이름") or "volcano")
    try:
        답 = subprocess.run([claude, "mcp", "get", 이름],
                            capture_output=True, text=True, timeout=60)
    except Exception:
        return None
    글 = (답.stdout or "") + (답.stderr or "")
    if "Connected" in 글 or "✔" in 글:
        return True
    if "Needs authentication" in 글 or "authenticate" in 글.lower():
        return False
    return None if 답.returncode != 0 else False


def 볼케이노붙이기():
    제목("2. 볼케이노 붙이기")
    주소 = str(설정.get("mcp_주소") or "").strip()
    if 비었나(주소):
        print("  · 볼케이노 주소가 아직 없습니다. 이 단계는 건너뜁니다.")
        남길것.append("볼케이노 주소 — 만든 사람에게 받아야 합니다")
        return False

    이름 = str(설정.get("mcp_이름") or "volcano")

    # ★ 이미 쓰던 사람 — 같은 주소가 딴 이름으로 붙어 있으면 그것을 쓴다.
    #   여기서 또 붙이면 같은 서버가 두 벌이 되어 어느 쪽을 쓸지 헷갈린다.
    옛이름, 옛승인 = 이미붙은이름(주소)
    if 옛이름:
        if 옛승인:
            print(f"  ✓ 이미 붙어 있고 승인도 돼 있습니다 (이름: {옛이름}). 그대로 씁니다.")
            return True
        print(f"  · 이미 붙어 있습니다 (이름: {옛이름}). 승인만 이어서 하겠습니다.")
        이름 = 옛이름
    else:
        print("  · 볼케이노 서버가 살아 있는지 봅니다…", flush=True)
        살았다, 할말 = 서버살았나(주소)
        if not 살았다:
            print(f"  ✗ {할말}")
            남길것.append("볼케이노 붙이기 — 서버에 닿지 못했습니다")
            return False
        print("  ✓ 서버가 살아 있습니다.")
        if not 엠시피등록(None):
            return False
        if 연결됐나(이름):
            print("  ✓ 이미 승인돼 있습니다. 바로 쓸 수 있습니다.")
            return True

    print()
    print("  ── 이제 메일로 승인을 받습니다")
    print("     · 브라우저가 열립니다.")
    print("     · **볼케이노 앱에 쓰던 그 메일**을 적으면 끝입니다.")
    print("       (비밀번호는 없습니다. 승인된 수강생 계정만 열립니다)")
    print("     · 열쇠를 복사해 옮길 일은 없습니다 — 볼케이노가 알아서 저장합니다.")
    print()
    물음("     준비되면 엔터를 누르세요… ")

    claude = 찾기("claude")
    # 사람이 치는 창이 아예 없으면 걸지 않는다 — 영어 오류만 뱉고 죽는다.
    if not 사람있나():
        print("  ! 지금은 사람이 직접 치는 창이 아니어서 승인을 못 엽니다.")
        print(f"    → 터미널에서  claude mcp login {이름}  을 치시면 됩니다.")
        남길것.append("볼케이노 승인 — 아직 못 함")
        return True
    try:
        사람실행([claude, "mcp", "login", 이름], timeout=15 * 60)
    except Exception:
        pass

    if 연결됐나(이름):
        print("  ✓ 승인됐습니다. 이제 바로 쓸 수 있습니다.")
        return True

    print("  ! 아직 승인이 안 됐습니다.")
    print("    → 브라우저를 닫으셨다면, 바탕화면의 「볼케이노」를 누른 뒤")
    print(f"       /mcp  →  {이름}  →  Authenticate 로 이어서 하시면 됩니다.")
    남길것.append("볼케이노 승인 — 아직 못 함")
    return True


def 엠시피붙이기(이름=None, 토큰=None):
    """볼케이노를 Claude 에 붙인다. 화면에 찍지 않고 값만 돌려준다: (됐나, 할 말)"""
    주소 = str(설정.get("mcp_주소") or "").strip()
    claude = 찾기("claude")
    if not 주소 or not claude:
        return False, "Claude Code 를 찾지 못해 붙이지 못했습니다."
    이름 = 이름 or str(설정.get("mcp_이름") or "volcano")
    명령 = [claude, "mcp", "add", "--scope", "user", "--transport", "http", 이름, 주소]
    if 토큰:
        명령 += ["--header", f"Authorization: Bearer {토큰}"]
    try:
        답 = subprocess.run(명령, capture_output=True, text=True, timeout=60)
        if 답.returncode == 0 or "already" in (답.stdout + 답.stderr).lower():
            return True, "볼케이노를 Claude 에 붙였습니다."
    except Exception:
        pass
    return False, "볼케이노를 붙이지 못했습니다. 나중에 이 마무리를 다시 돌리면 됩니다."


def 엠시피등록(토큰):
    됐나, 말 = 엠시피붙이기(None, 토큰)
    print(("  ✓ " if 됐나 else "  ! ") + 말)
    if not 됐나:
        남길것.append("볼케이노 붙이기 — 아직 못 함")
    return 됐나


# ── 3. 채널 고르기 ──────────────────────────────────────────
def 채널목록():
    """(이름들, 기본으로 권할 이름). 열쇠가 없는 「인물형」이 처음 쓰는 사람에게 제일 쉽다."""
    채널별 = 설정.get("채널별_키") or {}
    이름들 = list(채널별.keys())
    기본 = ("인물형" if "인물형" in 이름들 else (이름들[0] if 이름들 else ""))
    return 이름들, 기본


def 고른채널():
    자리 = 설치기 / "채널"
    try:
        return 자리.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def 채널저장(이름):
    """고른 채널을 적어 둔다. 화면에 찍지 않고 값만 돌려준다: (됐나, 할 말)"""
    채널별 = 설정.get("채널별_키") or {}
    if 이름 not in 채널별:
        return False, "목록에 없는 채널입니다."
    try:
        (설치기 / "채널").write_text(이름 + "\n", encoding="utf-8")
    except Exception as 왜:
        return False, f"채널을 적어 두지 못했습니다 ({type(왜).__name__})."
    return True, f"{이름}{로조사(이름)} 했습니다."


def 채널고르기():
    제목("3. 만들 채널 고르기")
    채널별 = 설정.get("채널별_키") or {}
    if not 채널별:
        print("  · 채널 목록이 없습니다. 건너뜁니다.")
        return "", []
    이름들, 기본 = 채널목록()
    print("  나중에 언제든 바꿀 수 있습니다.\n")
    for 번, 이름 in enumerate(이름들, 1):
        필요 = 채널별[이름]
        꼬리 = "열쇠가 필요 없습니다" if not 필요 else f"열쇠 {len(필요)}개 필요"
        표 = "  ← 처음이라면 이것" if 이름 == 기본 else ""
        print(f"   {번:>2}) {이름:<14} {꼬리}{표}")
    print()
    while True:
        고른 = 물음(f"  번호를 적으세요 (그냥 엔터 = {기본}): ")
        if not 고른:
            이름 = 기본
            break
        if 고른.isdigit() and 1 <= int(고른) <= len(이름들):
            이름 = 이름들[int(고른) - 1]
            break
        if 고른 in 이름들:
            이름 = 고른
            break
        print("  ! 목록에 있는 번호를 적어 주세요.")
    됐나, 말 = 채널저장(이름)
    print(("  ✓ " if 됐나 else "  ! ") + 말)
    return 이름, 채널별[이름]


# ── 가입 안내 창 ────────────────────────────────────────────
def 가입안내창(채널, 필요):
    """무엇에 가입해야 하는지 **브라우저 창**으로 띄운다.
    터미널 글자는 링크를 누를 수 없고 스크롤로 사라진다."""
    안내 = 설정.get("키_안내") or {}
    if not 필요:
        return
    칸 = []
    for 열쇠 in 필요:
        속 = 안내.get(열쇠) or {}
        절차 = "".join(f"<li>{쓰기(줄)}</li>" for 줄 in (속.get("절차") or []))
        주소 = (속.get("발급") or "").strip()
        단추 = (f'<a class=go href="{쓰기(주소)}" target=_blank rel=noopener>가입하러 가기 →</a>'
                if 주소 else "")
        칸.append(f"""<section>
  <h2>{쓰기(속.get("이름", 열쇠))}</h2>
  <p class=why>{쓰기(속.get("쓰임",""))}</p>
  <ol>{절차}</ol>
  <p class=cost>{쓰기(속.get("돈",""))}</p>
  {단추}
</section>""")

    쪽 = f"""<!doctype html><html lang=ko><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>볼케이노 — 가입할 것</title><style>
:root{{color-scheme:light dark;--bg:#fff;--s:#f6f6f7;--ink:#141414;--dim:#6b6b70;--line:#e4e4e7;--m:#FF6B35}}
@media(prefers-color-scheme:dark){{:root{{--bg:#0b0b0c;--s:#161618;--ink:#f2f2f3;--dim:#9a9aa2;--line:#2a2a2e}}}}
*{{box-sizing:border-box}}
body{{margin:0;padding:32px 20px 64px;background:var(--bg);color:var(--ink);
 font:16px/1.65 -apple-system,BlinkMacSystemFont,"Malgun Gothic","Apple SD Gothic Neo",sans-serif}}
.wrap{{max-width:640px;margin:0 auto}}
h1{{font-size:26px;margin:0 0 6px}}
.sub{{color:var(--dim);margin:0 0 28px}}
.tag{{display:inline-block;background:var(--m);color:#fff;border-radius:6px;
 padding:2px 10px;font-size:14px;font-weight:600}}
section{{background:var(--s);border:1px solid var(--line);border-radius:12px;
 padding:20px 22px;margin:0 0 16px}}
h2{{font-size:18px;margin:0 0 4px}}
.why{{color:var(--dim);margin:0 0 12px;font-size:15px}}
ol{{margin:0 0 12px;padding-left:22px}} li{{margin:3px 0}}
.cost{{color:var(--dim);font-size:14px;margin:0 0 14px}}
.go{{display:inline-block;background:var(--m);color:#fff;text-decoration:none;
 border-radius:8px;padding:9px 16px;font-weight:600}}
.end{{color:var(--dim);font-size:14px;margin-top:28px;text-align:center}}
</style></head><body><div class=wrap>
<h1>가입할 곳 {len(필요)}군데</h1>
<p class=sub><span class=tag>{쓰기(채널)}</span> 채널을 만들려면 아래가 필요합니다.
받은 열쇠는 설치 창에 하나씩 붙여넣으면 됩니다.</p>
{"".join(칸)}
<p class=end>이 창은 그냥 닫으셔도 됩니다. 설치 창으로 돌아가세요.</p>
</div></body></html>"""

    자리 = 설치기 / "가입안내.html"
    try:
        자리.write_text(쪽, encoding="utf-8")
        webbrowser.open(자리.as_uri())
        print(f"  · 가입할 곳을 새 창에 띄웠습니다 ({len(필요)}군데).")
    except Exception:
        print(f"  · 가입 안내: {자리}")


def 쓰기(값):
    """HTML 에 안전하게 넣기."""
    return (str(값 or "").replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


# ── 4. 열쇠 넣기 ────────────────────────────────────────────
def 아는열쇠():
    """설정이 아는 열쇠 이름 전부. 엉뚱한 이름으로 아무 파일이나 만들지 않으려는 것이다."""
    아는것 = set((설정.get("키_안내") or {}).keys())
    for 필요 in (설정.get("채널별_키") or {}).values():
        아는것.update(필요 or [])
    return 아는것


def 열쇠저장(이름, 값):
    """열쇠 하나를 넣는다. 화면에 찍지 않고 값만 돌려준다: (됐나, 할 말)"""
    if 이름 not in 아는열쇠() or not re.fullmatch(r"[A-Za-z0-9_.\-]+", 이름 or ""):
        return False, "모르는 열쇠입니다."
    속 = (설정.get("키_안내") or {}).get(이름) or {}
    보임 = 속.get("이름", 이름)
    값 = (값 or "").strip()
    if not 값:
        return False, "아무것도 안 들어왔습니다."
    최소 = int(속.get("최소길이") or 8)
    if len(값) < 최소:
        return False, (f"너무 짧습니다 ({len(값)}자). 열쇠는 {최소}자 이상입니다 —"
                       " 잘못 붙여넣은 것 같습니다.")
    자리 = 열쇠집 / 이름
    try:
        자리.write_text(값 + "\n", encoding="utf-8")
    except Exception as 왜:
        return False, f"넣지 못했습니다 ({type(왜).__name__})."
    try:
        os.chmod(자리, 0o600)
    except Exception:
        pass
    return True, f"{보임} — 넣었습니다."


def 열쇠넣기(필요, 고른채널=""):
    제목("4. 열쇠 넣기")
    if not 필요:
        print("  이 채널은 열쇠가 필요 없습니다. 바로 쓸 수 있습니다.")
        return
    안내 = 설정.get("키_안내") or {}
    whisper = 찾기("whisper")
    가입안내창(고른채널 or "", [ㅋ for ㅋ in 필요 if not (ㅋ == "asr" and whisper)])
    print("  아래 것들을 하나씩 받아서 붙여넣습니다.")
    print("  지금 없으면 그냥 엔터를 눌러 건너뛰어도 됩니다 — 나중에 다시 넣을 수 있습니다.\n")
    for 열쇠 in 필요:
        속 = 안내.get(열쇠) or {}
        보임 = 속.get("이름", 열쇠)
        자리 = 열쇠집 / 열쇠
        print(f"  ── {보임} ({열쇠})")
        쓰임 = (속.get("쓰임") or "").strip()
        if 쓰임:
            print(f"     · 무엇에 쓰나: {쓰임}")
        if 열쇠 == "asr" and whisper:
            print("     · 이 컴퓨터에 받아쓰기(whisper) 가 깔려 있어 열쇠 없이도 됩니다.")
            if not 예아니오("     그래도 열쇠를 넣으시겠습니까?", False):
                print("     · 건너뜁니다.")
                continue
        아무거나 = 속.get("아무거나")
        if 아무거나:
            print(f"     · 이 가운데 아무거나 하나면 됩니다: {', '.join(아무거나)}")
        대신 = 속.get("대신")
        if 대신:
            print(f"     · {대신}")
        if 자리.exists():
            if not 예아니오("     이미 넣어 둔 것이 있습니다. 새것으로 바꾸시겠습니까?", False):
                print("     · 그대로 둡니다.")
                continue
        절차 = 속.get("절차") or []
        if 절차:
            print("     · 받는 순서:")
            for 번, 줄 in enumerate(절차, 1):
                print(f"        {번}. {줄}")
        돈 = (속.get("돈") or "").strip()
        if 돈:
            print(f"     · 돈: {돈}")
        발급 = (속.get("발급") or "").strip()
        if 발급:
            print(f"     · 받는 곳: {발급}")
            if 예아니오("     브라우저로 열어 드릴까요?", True):
                try:
                    webbrowser.open(발급)
                except Exception:
                    print("     ! 브라우저를 열지 못했습니다. 위 주소를 직접 열어 주세요.")
        else:
            print("     · 받는 곳은 운영자에게 물어보세요.")
        최소 = int(속.get("최소길이") or 8)
        while True:
            값 = 물음("     여기에 붙여넣고 엔터 (건너뛰려면 그냥 엔터): ").strip()
            if not 값:
                break
            if len(값) < 최소:
                print(f"     ! 너무 짧습니다 ({len(값)}자). 열쇠는 {최소}자 이상입니다 —"
                      " 잘못 붙여넣은 것 같습니다.")
                print("       다시 붙여넣거나, 그냥 엔터를 눌러 건너뛰세요.")
                continue
            break
        if not 값:
            print("     · 건너뜁니다.")
            남길것.append(f"열쇠 {보임} — 아직 안 넣음")
            continue
        됐나, 말 = 열쇠저장(열쇠, 값)
        print(f"     ✓ 넣었습니다 ({자리})" if 됐나 else f"     ! {말}")
        if not 됐나:
            남길것.append(f"열쇠 {보임} — 아직 안 넣음")


# ── 5. 점검 ─────────────────────────────────────────────────
def 점검파일찾기():
    for 자리 in (설치기 / "점검.py", Path(__file__).resolve().parent / "점검.py"):
        if 자리.exists():
            return 자리
    return None


def 점검():
    제목("5. 마지막 점검")
    점검파일 = 점검파일찾기()
    if not 점검파일:
        print("  · 점검 파일이 없어 건너뜁니다.")
        return 1
    쓸파이썬 = str(파이썬) if 파이썬.exists() else sys.executable
    답 = subprocess.run([쓸파이썬, str(점검파일)])
    return 답.returncode


def 하기():
    print()
    print("╔════════════════════════════════════════════╗")
    print("║   볼케이노 설치 마무리                     ║")
    print("║   몇 가지만 물어보고 끝납니다.             ║")
    print("╚════════════════════════════════════════════╝")
    로그인()
    볼케이노붙이기()
    고른, 필요 = 채널고르기()
    열쇠넣기(필요, 고른)
    코드 = 점검()
    제목("끝났습니다")
    if 남길것:
        print("  아직 못 채운 것:")
        for 하나 in 남길것:
            print(f"   · {하나}")
        print()
    print("  다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 시작됩니다.")
    print("  VS Code 를 쓰시면 거기서 Claude Code 를 열어도 볼케이노가 붙어 있습니다.")
    print("  바탕화면 아이콘은 VS Code 없이 바로 쓰실 때 쓰세요.")
    print()

    # 승인이 아직이면 바로 열어 준다 — 사람이 따로 찾아 들어갈 일이 없게.
    claude = 찾기("claude")
    if claude and 사람있나() and 연결됐나() is not True:
        print("  이제 볼케이노를 엽니다.")
        print("   · 열리면  /mcp  → volcano → Authenticate 를 눌러 메일을 적으세요.")
        물음("  준비되면 엔터를 누르세요… ")
        try:
            사람실행([claude], cwd=str(작업장()))
        except Exception:
            print("  ! 열지 못했습니다. 바탕화면의 「볼케이노」를 두 번 누르세요.")
    else:
        물음("  이 창을 닫으려면 엔터를 누르세요… ")
    return 코드


# ══════════════════════════════════════════════════════════════
#  여기서부터는 **브라우저 화면** 판이다.
#  위의 터미널 판을 그대로 두고, 「찍지 않고 값만 돌려주는」 얇은 껍데기만 덧댄다.
#  추가 설치는 0 — 표준 라이브러리만 쓴다.
# ══════════════════════════════════════════════════════════════


# ── 값만 돌려주는 껍데기 (화면이 쓴다) ──────────────────────
def 지금():
    return time.time()


def 상태_로그인():
    """Claude Code 가 깔렸나 · 로그인됐나."""
    claude = 찾기("claude")
    if not claude:
        return {"됨": False, "깔림": False, "잰때": 지금(),
                "말": "Claude Code 가 아직 없습니다.",
                "할일": "터미널에 이렇게 치세요:  curl -fsSL https://claude.ai/install.sh | bash"}
    본것 = 로그인판정(claude)
    if 본것 is True:
        return {"됨": True, "깔림": True, "잰때": 지금(), "말": "로그인돼 있습니다."}
    return {"됨": False, "깔림": True, "잰때": 지금(),
            "말": ("아직 로그인 전입니다." if 본것 is False
                  else "로그인됐는지 물어보지 못했습니다 (모름)."),
            "할일": "아래 단추를 누르면 새 검은 창이 열립니다. 거기서 로그인하세요."}


def 상태_볼케이노():
    """붙었나 · 어떤 이름으로 · 승인됐나."""
    주소 = str(설정.get("mcp_주소") or "").strip()
    이름 = str(설정.get("mcp_이름") or "volcano")
    if 비었나(주소):
        return {"됨": False, "건너뜀": True, "이름": 이름, "붙음": False, "승인": False,
                "잰때": 지금(), "말": "볼케이노 주소가 아직 없습니다.",
                "할일": "만든 사람에게 주소를 받아야 합니다."}
    # ★ 같은 주소가 딴 이름으로 이미 붙어 있으면 그 이름을 쓴다 — 두 벌을 만들지 않는다.
    옛이름, 옛승인 = 이미붙은이름(주소)
    if 옛이름:
        이름 = 옛이름
        승인 = 옛승인 or (연결됐나(이름) is True)
        return {"됨": 승인, "건너뜀": False, "이름": 이름, "붙음": True, "승인": 승인,
                "잰때": 지금(),
                "말": ("붙었고 승인도 됐습니다." if 승인 else f"붙어 있습니다 (이름: {이름}). 승인만 남았습니다."),
                "할일": ("" if 승인 else "아래 단추를 누르면 새 검은 창이 열립니다. 볼케이노 앱에 쓰던 그 메일을 적으면 끝입니다.")}
    살았다, 할말 = 서버살았나(주소)
    if not 살았다:
        return {"됨": False, "건너뜀": False, "이름": 이름, "붙음": False, "승인": False,
                "잰때": 지금(), "말": "볼케이노 서버에 닿지 못했습니다.", "할일": 할말}
    return {"됨": False, "건너뜀": False, "이름": 이름, "붙음": False, "승인": False,
            "잰때": 지금(), "말": "서버는 살아 있습니다. 아직 붙이지 않았습니다.",
            "할일": "아래 단추를 누르면 붙이고 승인 창을 엽니다."}


def 상태_채널():
    채널별 = 설정.get("채널별_키") or {}
    이름들, 기본 = 채널목록()
    고른 = 고른채널()
    카드 = [{"이름": 하나, "필요": list(채널별.get(하나) or []), "권장": 하나 == 기본,
             "고름": 하나 == 고른} for 하나 in 이름들]
    return {"됨": bool(고른 and 고른 in 채널별), "고른": 고른, "기본": 기본, "목록": 카드}


def 상태_열쇠():
    """고른 채널이 요구하는 것만 돌려준다."""
    고른 = 고른채널()
    필요 = list((설정.get("채널별_키") or {}).get(고른) or [])
    안내 = 설정.get("키_안내") or {}
    whisper = bool(찾기("whisper"))
    칸 = []
    for 열쇠 in 필요:
        속 = 안내.get(열쇠) or {}
        넣어둠 = (열쇠집 / 열쇠).exists() or bool(os.environ.get(열쇠.upper()))
        칸.append({
            "이름": 열쇠,
            "보임": 속.get("이름", 열쇠),
            "쓰임": 속.get("쓰임", ""),
            "절차": list(속.get("절차") or []),
            "돈": 속.get("돈", ""),
            "발급": 속.get("발급", ""),
            "아무거나": list(속.get("아무거나") or []),
            "대신": 속.get("대신", ""),
            "최소길이": int(속.get("최소길이") or 8),
            "넣어둠": 넣어둠,
            "없어도됨": (열쇠 == "asr" and whisper),
        })
    남은 = [ㅋ for ㅋ in 칸 if not ㅋ["넣어둠"] and not ㅋ["없어도됨"]]
    return {"됨": not 남은, "채널": 고른, "목록": 칸, "whisper": whisper}


def 점검값():
    """점검.py 를 그대로 불러 ✓/✗ 를 값으로 받는다 (찍는 대신 읽는다)."""
    점검파일 = 점검파일찾기()
    if not 점검파일:
        return {"됨": False, "잰때": 지금(), "줄들": [], "말": "점검 파일이 없습니다."}
    쓸파이썬 = str(파이썬) if 파이썬.exists() else sys.executable
    try:
        답 = subprocess.run([쓸파이썬, str(점검파일)], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    except Exception as 왜:
        return {"됨": False, "잰때": 지금(), "줄들": [], "말": f"점검을 돌리지 못했습니다 ({type(왜).__name__})."}
    줄들 = []
    for 하나 in (답.stdout or "").splitlines():
        벗김 = 하나.strip()
        if 벗김[:2] in ("✓ ", "✗ "):
            줄들.append({"됨": 벗김[0] == "✓", "무엇": 벗김[1:].strip(), "할일": ""})
        elif 벗김.startswith("→") and 줄들:
            줄들[-1]["할일"] = 벗김.lstrip("→").strip()
    나쁨 = sum(1 for ㅈ in 줄들 if not ㅈ["됨"])
    return {"됨": bool(줄들) and 나쁨 == 0, "잰때": 지금(), "줄들": 줄들, "나쁨": 나쁨,
            "말": ("다 됐습니다." if 줄들 and 나쁨 == 0 else f"{나쁨}가지가 아직입니다.")}


# ── 사람이 직접 쳐야 하는 것은 새 검은 창에서 ───────────────
# claude 로그인과 mcp 승인은 브라우저 화면 안에서 못 돈다 —
# 사람이 글자를 치는 창이 있어야 한다. 그래서 창을 하나 띄워 거기서 돌린다.
# ── 윈도우 .bat 은 순수 ASCII 껍데기로만 쓴다 ────────────────
# cmd 는 .bat 을 시스템 코드페이지(한국어 윈도우는 CP949)로 읽는다. UTF-8 한글을 넣으면
# 파일 전체가 깨진 바이트가 되어 「내부 또는 외부 명령이 아닙니다」 만 쏟아지고 한 줄도 안 돈다.
# 파일 안의 chcp 65001 은 이미 읽기 시작한 뒤라 소용이 없다.
# 그래서 한글과 실제 일은 같은 이름의 .ps1(UTF-8 BOM)에 담고 .bat 은 그것만 부른다.
# PowerShell 5.1 은 BOM 없는 UTF-8 한글도 깨뜨리므로 BOM 은 반드시 붙인다.
윈도우껍데기 = """@echo off
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
"""


def 홑(글):
    """PowerShell 홑따옴표 글. 안의 홑따옴표는 두 번 적어 막는다."""
    return "'" + str(글).replace("'", "''") + "'"


def 배치쌍쓰기(배치자리, 파워셸줄들):
    """ASCII .bat 껍데기 + 같은 이름의 UTF-8 BOM .ps1 을 짝으로 만든다."""
    배치자리.with_suffix(".ps1").write_text(
        "\r\n".join(파워셸줄들) + "\r\n", encoding="utf-8-sig")
    배치자리.write_text(윈도우껍데기.replace("\n", "\r\n"), encoding="ascii")


def 창밑글(이름):
    """새 창에 물려 줄 환경. 지금 창이 아는 것을 그대로 넘긴다.

    HOME(윈도우는 USERPROFILE)은 바꾸지 않는다 — 맥 키체인이 깨져
    「키체인을 발견할 수 없음」 이 뜨고 클로드 로그인이 남지 않는다.
    볼케이노 것(venv·열쇠·설치기·작업장)은 VOLCANO_HOME·VOLCANO_DEST 로 옮긴다 —
    시험은 그 둘만으로 한다."""
    길 = os.pathsep.join([str(집 / "bin"), str(파이썬.parent), os.environ.get("PATH", "")])
    밑 = {"VOLCANO_HOME": str(집), "PATH": 길}
    for 키 in ("VOLCANO_DEST", "VOLCANO_JOBS", "VOLCANO_RUNNER",
               "VOLCANO_PY", "VOLCANO_BASE", "VOLCANO_SRC"):
        값 = os.environ.get(키)
        if 값:
            밑[키] = 값
    return 밑


def 새터미널창(파일이름, 안내, 명령, 확인클로드=""):
    """새 검은 창을 띄워 거기서 명령을 돌린다.
    명령은 낱말 목록. 돌아오는 값: (띄웠나, 사람에게 할 말)

    확인클로드를 주면 명령이 끝난 뒤 그 자리에서 claude auth status 로 물어보고
    「로그인됐습니다 / 아직입니다」 를 찍는다. 그리고 창을 붙잡는다 —
    안 붙잡으면 사람은 「프로세스 완료됨」 만 보고 무슨 일이 있었는지 못 읽는다."""
    밑 = 창밑글(파일이름)
    if 윈도우:
        자리 = 설치기 / (파일이름 + ".bat")
        줄들 = ["try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}"]
        줄들 += [f"$env:{키} = {홑(값)}" for 키, 값 in 밑.items()]
        줄들 += [f"Write-Host {홑(한줄)}" for 한줄 in 안내]
        줄들 += ["Write-Host ''",
                 "& " + " ".join(홑(낱말) for 낱말 in 명령),
                 "Write-Host ''"]
        if 확인클로드:
            줄들 += [f"$잰것 = (& {홑(확인클로드)} auth status 2>$null | Out-String)",
                     "if ($잰것 -match '\"loggedIn\"\\s*:\\s*true')"
                     " { Write-Host '  ✓ 로그인됐습니다.' }"
                     " else { Write-Host '  ✗ 아직입니다. 다시 눌러 주세요.' }",
                     "Write-Host ''"]
        줄들 += ["Write-Host '  이 창은 이제 닫으셔도 됩니다. 설치 화면으로 돌아가세요.'",
                 "try { Read-Host '  엔터를 누르면 창이 닫힙니다' | Out-Null } catch {}"]
        try:
            배치쌍쓰기(자리, 줄들)
            os.startfile(str(자리))   # noqa: S606 — 새 콘솔이 열린다
            return True, "새 창을 열었습니다. 거기서 이어서 하세요."
        except Exception as 왜:
            return False, f"새 창을 열지 못했습니다 ({type(왜).__name__}). 직접 치셔도 됩니다: " + " ".join(명령)

    자리 = 설치기 / (파일이름 + ".command")
    줄들 = ["#!/bin/bash"]
    줄들 += [f"export {키}={shlex.quote(값)}" for 키, 값 in 밑.items()]
    줄들 += ["clear"]
    줄들 += [f"echo {shlex.quote(한줄)}" for 한줄 in 안내]
    줄들 += ["echo", " ".join(shlex.quote(낱말) for 낱말 in 명령), "echo"]
    if 확인클로드:
        줄들 += [f"if {shlex.quote(확인클로드)} auth status 2>/dev/null"
                 " | tr -d ' \\t\\n' | grep -q '\"loggedIn\":true'; then",
                 "  echo '  ✓ 로그인됐습니다.'",
                 "else",
                 "  echo '  ✗ 아직입니다. 브라우저에서 로그인을 마치지 못했다면 다시 눌러 주세요.'",
                 "fi", "echo"]
    줄들 += ["echo '  이 창은 이제 닫으셔도 됩니다. 설치 화면으로 돌아가세요.'",
             "read -r -p '  엔터를 누르면 창이 닫힙니다… ' _ || true"]
    try:
        자리.write_text("\n".join(줄들) + "\n", encoding="utf-8")
        os.chmod(자리, 0o700)
    except Exception as 왜:
        return False, f"새 창을 준비하지 못했습니다 ({type(왜).__name__})."

    if sys.platform == "darwin":
        try:
            답 = subprocess.run(["open", "-a", "Terminal", str(자리)],
                                capture_output=True, text=True, timeout=30)
            if 답.returncode == 0:
                return True, "새 창을 열었습니다. 거기서 이어서 하세요."
        except Exception:
            pass
        return False, f"새 창을 열지 못했습니다. 터미널에서 이 파일을 열어 주세요: {자리}"

    for 창, 앞 in (("x-terminal-emulator", ["-e"]), ("gnome-terminal", ["--"]),
                   ("konsole", ["-e"]), ("xfce4-terminal", ["-e"]), ("xterm", ["-e"])):
        어디 = shutil.which(창)
        if not 어디:
            continue
        try:
            subprocess.Popen([어디] + 앞 + ["bash", str(자리)])
            return True, "새 창을 열었습니다. 거기서 이어서 하세요."
        except Exception:
            continue
    return False, f"새 창을 열 만한 터미널을 못 찾았습니다. 이 파일을 직접 돌려 주세요: {자리}"


def 창_로그인():
    claude = 찾기("claude")
    if not claude:
        return False, "Claude Code 가 아직 없습니다. 설치 명령을 한 번 더 돌려 주세요."
    return 새터미널창("로그인", [
        "  ── Claude Code 로그인 ──",
        "",
        "  · 브라우저가 열립니다.",
        "  · Claude 계정으로 로그인하세요.",
        "  · 끝나면 이 창으로 돌아오세요.",
    ], [claude] + 로그인명령, 확인클로드=claude)


def 창_승인(이름=None):
    claude = 찾기("claude")
    if not claude:
        return False, "Claude Code 가 아직 없습니다. 설치 명령을 한 번 더 돌려 주세요."
    주소 = str(설정.get("mcp_주소") or "").strip()
    if 비었나(주소):
        return False, "볼케이노 주소가 아직 없습니다. 만든 사람에게 받아야 합니다."
    이름 = 이름 or str(설정.get("mcp_이름") or "volcano")
    옛이름, _ = 이미붙은이름(주소)
    if 옛이름:
        이름 = 옛이름           # 이미 붙은 것이 있으면 그 이름을 쓴다
    else:
        살았다, 할말 = 서버살았나(주소)
        if not 살았다:
            return False, 할말
        됐나, 말 = 엠시피붙이기(이름)
        if not 됐나:
            return False, 말
    return 새터미널창("승인", [
        "  ── 볼케이노 승인 받기 ──",
        "",
        "  · 곧 브라우저가 열립니다.",
        "  · 볼케이노 앱에 쓰던 그 메일을 적으면 끝입니다. 비밀번호는 없습니다.",
        "  · 열쇠를 복사해 옮길 일은 없습니다 — 볼케이노가 알아서 저장합니다.",
        "  · 끝나면 설치 화면이 저절로 다음으로 넘어갑니다.",
    ], [claude, "mcp", "login", 이름])


# ── 화면 (HTML 한 장 · 인라인 CSS·JS) ───────────────────────
# 색·둥근 모서리·단계 번호는 설치 안내 쪽(index.html)과 같은 말씨로 맞췄다.
화면HTML = r"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>볼케이노 마무리</title>
<style>
  :root{
    --바탕:#f6f7f9; --글:#16181d; --흐린글:#5b6270; --판:#ffffff; --선:#e2e5ea;
    --강조:#d84315; --강조글:#ffffff; --코드바탕:#111418; --코드글:#e8eaed;
    --좋음:#2e7d32; --나쁨:#c62828;
  }
  @media (prefers-color-scheme: dark){
    :root{
      --바탕:#101216; --글:#eceef2; --흐린글:#9aa3b2; --판:#181b21; --선:#2a2f38;
      --강조:#ff7043; --강조글:#1a1a1a; --코드바탕:#0a0c0f; --코드글:#eceef2;
      --좋음:#66bb6a; --나쁨:#ef5350;
    }
  }
  *{box-sizing:border-box}
  body{
    margin:0; padding:32px 20px 72px; background:var(--바탕); color:var(--글);
    font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Malgun Gothic","Noto Sans KR",sans-serif;
    line-height:1.7; -webkit-font-smoothing:antialiased;
  }
  .가운데{max-width:760px; margin:0 auto}
  h1{font-size:38px; margin:0 0 8px; letter-spacing:-.02em}
  .부제{font-size:19px; color:var(--흐린글); margin:0 0 36px}
  .판{background:var(--판); border:1px solid var(--선); border-radius:18px;
      padding:24px; margin-bottom:20px}
  .판.잠깐{opacity:.55}
  .차례{display:flex; align-items:center; gap:12px; margin:0 0 12px}
  .번호{
    flex:0 0 auto; width:34px; height:34px; border-radius:50%;
    background:var(--강조); color:var(--강조글);
    font-size:19px; font-weight:700; display:flex; align-items:center; justify-content:center;
  }
  .차례 h2{font-size:22px; margin:0; font-weight:700}
  .알약{margin-left:auto; font-size:15px; font-weight:700; color:var(--흐린글);
        border:1px solid var(--선); border-radius:999px; padding:2px 12px; white-space:nowrap}
  .알약.좋음{color:var(--좋음); border-color:var(--좋음)}
  .알약.나쁨{color:var(--나쁨); border-color:var(--나쁨)}
  .설명{font-size:17px; color:var(--흐린글); margin:0 0 12px}
  .할일{font-size:16px; margin:0 0 14px; padding:10px 14px; border-radius:0 10px 10px 0;
        background:var(--바탕); border-left:3px solid var(--강조)}
  button.단추{
    background:var(--강조); color:var(--강조글); border:0; border-radius:12px;
    padding:0 24px; min-height:52px; font-size:17px; font-weight:700; cursor:pointer;
    font-family:inherit;
  }
  button.단추:active{transform:translateY(1px)}
  button.단추[disabled]{opacity:.45; cursor:default}
  button.단추.수수{background:transparent; color:var(--강조); border:1px solid var(--강조);
                    min-height:42px; font-size:16px; padding:0 16px}
  .카드들{display:flex; flex-wrap:wrap; gap:10px}
  .카드{border:1px solid var(--선); border-radius:14px; padding:12px 16px; cursor:pointer;
        background:var(--바탕); min-width:180px; font-family:inherit; font-size:16px;
        color:var(--글); text-align:left}
  .카드:hover{border-color:var(--강조)}
  .카드.고름{border-color:var(--강조); box-shadow:inset 0 0 0 1px var(--강조)}
  .카드 b{display:block; font-size:17px}
  .카드 span{font-size:14px; color:var(--흐린글)}
  .꼬리표{display:inline-block; background:var(--강조); color:var(--강조글);
          border-radius:6px; padding:0 8px; font-size:13px; font-weight:700; margin-left:6px}
  .열쇠{border:1px solid var(--선); border-radius:14px; padding:16px 18px; margin-bottom:12px}
  .열쇠머리{display:flex; align-items:center; gap:8px; font-size:18px; font-weight:700}
  .열쇠 ol{margin:0 0 10px; padding-left:22px; font-size:15px; color:var(--흐린글)}
  .열쇠 .돈{font-size:14px; color:var(--흐린글); margin:0 0 12px}
  a.가기{display:inline-block; background:var(--강조); color:var(--강조글); text-decoration:none;
         border-radius:10px; padding:8px 16px; font-weight:700; font-size:15px; margin-bottom:12px}
  .넣는칸{display:flex; gap:8px; flex-wrap:wrap; align-items:stretch}
  .넣는칸 input{
    flex:1 1 260px; min-width:0; background:var(--코드바탕); color:var(--코드글);
    border:1px solid var(--선); border-radius:10px; padding:12px 14px; font-size:15px;
    font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
  }
  .빨강{color:var(--나쁨); font-size:15px; margin:8px 0 0; font-weight:700}
  .초록{color:var(--좋음); font-size:15px; margin:8px 0 0; font-weight:700}
  ul.점검줄{list-style:none; margin:0; padding:0; font-size:16px}
  ul.점검줄 li{margin:4px 0}
  ul.점검줄 .안됨{color:var(--나쁨); font-weight:700}
  ul.점검줄 .고침{display:block; font-size:15px; color:var(--흐린글); padding-left:22px}
  .꼬리{margin-top:34px; font-size:15px; color:var(--흐린글); text-align:center}
</style></head>
<body><div class="가운데">

<h1>볼케이노 마무리</h1>
<p class="부제">다섯 가지만 하면 끝납니다. 이 창은 켜 둔 채로 하세요.</p>

<div class="판" id="판1">
  <div class="차례"><div class="번호">1</div><h2>Claude Code 로그인</h2><span class="알약" id="알약1">살펴보는 중…</span></div>
  <p class="설명" id="말1">…</p>
  <p class="할일" id="할일1" hidden></p>
  <button class="단추" id="단추1" hidden>로그인 하기</button>
</div>

<div class="판" id="판2">
  <div class="차례"><div class="번호">2</div><h2>볼케이노 붙이고 승인받기</h2><span class="알약" id="알약2">살펴보는 중…</span></div>
  <p class="설명" id="말2">…</p>
  <p class="할일" id="할일2" hidden></p>
  <button class="단추" id="단추2" hidden>승인 받기</button>
</div>

<div class="판" id="판3">
  <div class="차례"><div class="번호">3</div><h2>만들 채널 고르기</h2><span class="알약" id="알약3">살펴보는 중…</span></div>
  <p class="설명">나중에 언제든 바꿀 수 있습니다.</p>
  <div class="카드들" id="채널칸"></div>
</div>

<div class="판" id="판4">
  <div class="차례"><div class="번호">4</div><h2>열쇠 넣기</h2><span class="알약" id="알약4">살펴보는 중…</span></div>
  <p class="설명" id="말4">채널을 먼저 고르세요.</p>
  <div id="열쇠칸"></div>
</div>

<div class="판" id="판5">
  <div class="차례"><div class="번호">5</div><h2>마지막 점검</h2><span class="알약" id="알약5">살펴보는 중…</span></div>
  <ul class="점검줄" id="점검칸"></ul>
  <p class="설명" id="말5" style="margin-top:12px"></p>
  <button class="단추 수수" id="단추5">다시 점검</button>
</div>

<div class="판" id="끝판">
  <p class="설명" id="끝말">다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 시작됩니다.</p>
  <button class="단추" id="단추끝">다 됐습니다 — 닫기</button>
</div>

<p class="꼬리">막히면 이 화면을 통째로 찍어서 보내 주세요.</p>
</div>

<script>
const 표 = new URLSearchParams(location.search).get("t") || "";
const 찾 = (아이디) => document.getElementById(아이디);
let 마지막상태 = null;
let 열쇠서명 = "";
let 채널서명 = "";
const 적은값 = {};

async function 부르기(길, 몸){
  const 짐 = {method: 몸 ? "POST" : "GET", headers: {"X-Setup": 표}};
  if (몸){ 짐.headers["Content-Type"] = "application/json"; 짐.body = JSON.stringify(몸); }
  const 답 = await fetch(길, 짐);
  if (!답.ok) throw new Error(답.status);
  return await 답.json();
}

function 알약칠(아이디, 됐나, 글){
  const ㅇ = 찾(아이디);
  ㅇ.textContent = 글;
  ㅇ.className = "알약" + (됐나 === true ? " 좋음" : (됐나 === false ? " 나쁨" : ""));
}
function 안내칠(아이디, 글){
  const ㅇ = 찾(아이디);
  ㅇ.textContent = 글 || "";
  ㅇ.hidden = !글;
}
function 딱지(값){ return (값 === null || 값 === undefined) ? "" : String(값); }

function 그리기(상태){
  마지막상태 = 상태;
  if (!상태.준비){ return; }

  // 1. 로그인
  const 로 = 상태.로그인 || {};
  알약칠("알약1", !!로.됨, 로.됨 ? "됐습니다" : "아직입니다");
  찾("말1").textContent = 딱지(로.말);
  안내칠("할일1", 로.됨 ? "" : 딱지(로.할일));
  찾("단추1").hidden = !!로.됨 || 로.깔림 === false;

  // 2. 볼케이노
  const 볼 = 상태.볼케이노 || {};
  알약칠("알약2", 볼.건너뜀 ? null : !!볼.승인, 볼.건너뜀 ? "건너뜁니다" : (볼.승인 ? "됐습니다" : "아직입니다"));
  찾("말2").textContent = 딱지(볼.말) + (볼.붙음 && 볼.이름 ? "  (이름: " + 볼.이름 + ")" : "");
  안내칠("할일2", 볼.승인 ? "" : 딱지(볼.할일));
  찾("단추2").hidden = !!볼.승인 || !!볼.건너뜀 || !로.됨;
  찾("판2").classList.toggle("잠깐", !로.됨);

  // 3. 채널
  const 채 = 상태.채널 || {목록: []};
  알약칠("알약3", 채.됨 ? true : null, 채.고른 ? 채.고른 : "고르세요");
  const 서명3 = JSON.stringify(채.목록.map(ㅋ => [ㅋ.이름, ㅋ.고름]));
  if (서명3 !== 채널서명){
    채널서명 = 서명3;
    const 칸 = 찾("채널칸"); 칸.innerHTML = "";
    채.목록.forEach(ㅋ => {
      const 단추 = document.createElement("button");
      단추.type = "button";
      단추.className = "카드" + (ㅋ.고름 ? " 고름" : "");
      const 이름 = document.createElement("b");
      이름.textContent = ㅋ.이름;
      if (ㅋ.권장){
        const 표시 = document.createElement("span");
        표시.className = "꼬리표"; 표시.textContent = "처음이라면 이것";
        이름.appendChild(표시);
      }
      const 밑 = document.createElement("span");
      밑.textContent = ㅋ.필요.length ? ("열쇠 " + ㅋ.필요.length + "개 필요") : "열쇠가 필요 없습니다";
      단추.appendChild(이름); 단추.appendChild(밑);
      단추.addEventListener("click", async () => {
        await 부르기("/api/채널", {이름: ㅋ.이름});
        채널서명 = ""; 열쇠서명 = "";
        새로()
      });
      칸.appendChild(단추);
    });
  }

  // 4. 열쇠
  const 열 = 상태.열쇠 || {목록: []};
  const 필요수 = 열.목록.length;
  알약칠("알약4", 필요수 === 0 ? null : (열.됨 ? true : false),
        !채.고른 ? "채널 먼저" : (필요수 === 0 ? "필요 없습니다" : (열.됨 ? "됐습니다" : "아직입니다")));
  찾("말4").textContent = !채.고른 ? "채널을 먼저 고르세요."
    : (필요수 === 0 ? "이 채널은 열쇠가 필요 없습니다. 바로 쓸 수 있습니다."
                    : "아래 것들을 하나씩 받아서 붙여넣으세요. 지금 없으면 나중에 넣어도 됩니다.");
  찾("판4").classList.toggle("잠깐", !채.고른);
  const 서명4 = JSON.stringify([채.고른, 열.목록.map(ㅋ => [ㅋ.이름, ㅋ.넣어둠, ㅋ.없어도됨])]);
  if (서명4 !== 열쇠서명){ 열쇠서명 = 서명4; 열쇠그리기(열); }

  // 5. 점검
  const 점 = 상태.점검;
  if (점){
    알약칠("알약5", 점.줄들.length ? 점.됨 : null, 점.줄들.length ? (점.됨 ? "다 됐습니다" : (점.나쁨 + "가지 남음")) : "…");
    const 칸 = 찾("점검칸"); 칸.innerHTML = "";
    점.줄들.forEach(ㅈ => {
      const 리 = document.createElement("li");
      const 표시 = document.createElement("span");
      표시.textContent = (ㅈ.됨 ? "✓ " : "✗ ") + ㅈ.무엇;
      if (!ㅈ.됨) 표시.className = "안됨";
      리.appendChild(표시);
      if (!ㅈ.됨 && ㅈ.할일){
        const 고 = document.createElement("span");
        고.className = "고침"; 고.textContent = "→ " + ㅈ.할일;
        리.appendChild(고);
      }
      칸.appendChild(리);
    });
    찾("말5").textContent = 딱지(점.말);
  }
}

function 열쇠그리기(열){
  const 칸 = 찾("열쇠칸"); 칸.innerHTML = "";
  열.목록.forEach(ㅋ => {
    const 판 = document.createElement("div");
    판.className = "열쇠";

    const 머리 = document.createElement("div");
    머리.className = "열쇠머리";
    머리.textContent = ㅋ.보임;
    const 알 = document.createElement("span");
    알.className = "알약 " + (ㅋ.넣어둠 ? "좋음" : (ㅋ.없어도됨 ? "" : "나쁨"));
    알.textContent = ㅋ.넣어둠 ? "넣어 둠" : (ㅋ.없어도됨 ? "열쇠 없이 가능" : "아직");
    머리.appendChild(알);
    판.appendChild(머리);

    if (ㅋ.쓰임){ const ㅍ = document.createElement("p"); ㅍ.className = "설명"; ㅍ.textContent = ㅋ.쓰임; 판.appendChild(ㅍ); }
    if (ㅋ.없어도됨){ const ㅍ = document.createElement("p"); ㅍ.className = "할일";
      ㅍ.textContent = "이 컴퓨터에 받아쓰기(whisper) 가 깔려 있어 열쇠 없이도 됩니다. 그래도 넣으면 더 빠릅니다."; 판.appendChild(ㅍ); }
    if (ㅋ.아무거나 && ㅋ.아무거나.length){ const ㅍ = document.createElement("p"); ㅍ.className = "설명";
      ㅍ.textContent = "이 가운데 아무거나 하나면 됩니다: " + ㅋ.아무거나.join(", "); 판.appendChild(ㅍ); }
    if (ㅋ.절차 && ㅋ.절차.length){
      const 목 = document.createElement("ol");
      ㅋ.절차.forEach(줄 => { const 리 = document.createElement("li"); 리.textContent = 줄; 목.appendChild(리); });
      판.appendChild(목);
    }
    if (ㅋ.돈){ const ㅍ = document.createElement("p"); ㅍ.className = "돈"; ㅍ.textContent = "돈: " + ㅋ.돈; 판.appendChild(ㅍ); }
    if (ㅋ.발급){
      const 가 = document.createElement("a");
      가.className = "가기"; 가.href = ㅋ.발급; 가.target = "_blank"; 가.rel = "noopener noreferrer";
      가.textContent = "가입하러 가기 →";
      판.appendChild(가);
      판.appendChild(document.createElement("br"));
    }

    const 넣는칸 = document.createElement("div");
    넣는칸.className = "넣는칸";
    const 적기 = document.createElement("input");
    적기.type = "text"; 적기.spellcheck = false; 적기.autocomplete = "off";
    적기.placeholder = "여기에 붙여넣으세요";
    적기.value = 적은값[ㅋ.이름] || "";
    적기.addEventListener("input", () => { 적은값[ㅋ.이름] = 적기.value; });
    const 넣기 = document.createElement("button");
    넣기.type = "button"; 넣기.className = "단추"; 넣기.textContent = "넣기";
    넣는칸.appendChild(적기); 넣는칸.appendChild(넣기);

    const 말 = document.createElement("p");
    말.className = "빨강"; 말.hidden = true;

    if (ㅋ.넣어둠){
      const 바꾸기 = document.createElement("button");
      바꾸기.type = "button"; 바꾸기.className = "단추 수수"; 바꾸기.textContent = "새것으로 바꾸기";
      넣는칸.hidden = true;
      바꾸기.addEventListener("click", () => { 넣는칸.hidden = false; 바꾸기.hidden = true; 적기.focus(); });
      판.appendChild(바꾸기);
    }
    판.appendChild(넣는칸);
    판.appendChild(말);
    칸.appendChild(판);

    넣기.addEventListener("click", async () => {
      const 값 = (적기.value || "").trim();
      말.hidden = false; 말.className = "빨강";
      if (!값){ 말.textContent = "아무것도 안 들어왔습니다."; return; }
      if (값.length < ㅋ.최소길이){
        말.textContent = "너무 짧습니다 (" + 값.length + "자). 열쇠는 " + ㅋ.최소길이 + "자 이상입니다 — 잘못 붙여넣은 것 같습니다.";
        return;
      }
      넣기.disabled = true;
      try{
        const 답 = await 부르기("/api/열쇠", {이름: ㅋ.이름, 값: 값});
        말.textContent = 답.말 || "";
        말.className = 답.됐나 ? "초록" : "빨강";
        if (답.됐나){ 적기.value = ""; delete 적은값[ㅋ.이름]; 열쇠서명 = ""; 새로(); }
      } catch(에러){ 말.textContent = "넣지 못했습니다."; }
      넣기.disabled = false;
    });
  });
}

async function 새로(점검다시){
  try{
    const 상태 = await 부르기("/api/상태" + (점검다시 ? "?check=1" : ""));
    그리기(상태);
  } catch(에러){ /* 잠깐 못 물어봐도 다음 번에 다시 묻는다 */ }
}

async function 창띄우기(길, 단추){
  단추.disabled = true;
  const 본말 = 단추.textContent;
  단추.textContent = "새 창을 엽니다…";
  try{
    const 답 = await 부르기(길, {});
    if (!답.됐나){ alert(답.말 || "열지 못했습니다."); }
  } catch(에러){ alert("열지 못했습니다."); }
  단추.textContent = 본말;
  단추.disabled = false;
  새로();
}

찾("단추1").addEventListener("click", (ㅇ) => 창띄우기("/api/로그인", ㅇ.currentTarget));
찾("단추2").addEventListener("click", (ㅇ) => 창띄우기("/api/승인", ㅇ.currentTarget));
찾("단추5").addEventListener("click", async (ㅇ) => {
  const 눌린 = ㅇ.currentTarget;
  눌린.disabled = true; 찾("알약5").textContent = "점검 중…";
  await 새로(true);
  눌린.disabled = false;
});
찾("단추끝").addEventListener("click", async (ㅇ) => {
  ㅇ.currentTarget.disabled = true;
  try{ await 부르기("/api/끝", {}); } catch(에러){}
  document.body.innerHTML =
    '<div class="가운데"><h1>다 됐습니다</h1>' +
    '<p class="부제">이 창은 닫으셔도 됩니다. ' +
    '다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 시작됩니다.</p></div>';
});

// 앱 안(속창)에서 열렸으면 내 키를 바깥에 알려 준다.
// 그래야 앱이 창을 그만큼 늘려서, 작은 칸 안에서 또 스크롤되지 않는다.
let 앞선키 = 0;
function 키알리기(){
  if (window.parent === window) return;
  const 키 = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
  if (!(키 > 0) || Math.abs(키 - 앞선키) < 8) return;
  앞선키 = 키;
  try{ window.parent.postMessage({볼케이노높이: 키}, "*"); } catch(에러){}
}
if (window.parent !== window){
  setInterval(키알리기, 700);
  window.addEventListener("load", 키알리기);
  키알리기();
}

새로();
setInterval(() => 새로(), 2000);
</script>
</body></html>
"""


# ── 상태 담아 두기 ──────────────────────────────────────────
# 화면은 2초마다 물어본다. 그때마다 claude 를 부르면 느리고 아까우니,
# 한 번 조사한 값을 담아 두고 뒤에서만 새로 잰다.
상태잠금 = threading.Lock()
상태통 = {"준비": False}
조사중 = False


def 최근인가(칸, 초):
    return bool(칸) and (지금() - float(칸.get("잰때") or 0) < 초)


def 상태만들기(이전, 점검다시=False):
    로 = 이전.get("로그인")
    if not (로 and (로.get("됨") or 최근인가(로, 8))):
        로 = 상태_로그인()
    볼 = 이전.get("볼케이노")
    if not (볼 and (볼.get("승인") or 볼.get("건너뜀") or 최근인가(볼, 5))):
        볼 = 상태_볼케이노()
    점 = 이전.get("점검")
    if 점검다시 or not 점:
        점 = 점검값()
    return {"준비": True, "때": 지금(), "로그인": 로, "볼케이노": 볼,
            "채널": 상태_채널(), "열쇠": 상태_열쇠(), "점검": 점}


def 상태돌리기(점검다시):
    global 상태통, 조사중
    try:
        새것 = 상태만들기(dict(상태통), 점검다시)
        with 상태잠금:
            상태통 = 새것
    except Exception:
        pass
    finally:
        with 상태잠금:
            조사중 = False


def 상태가져오기(점검다시=False):
    """바로 돌려주고, 낡았으면 뒤에서 새로 잰다."""
    global 조사중
    with 상태잠금:
        지금것 = dict(상태통)
        시작 = (not 조사중) and (점검다시 or not 지금것.get("준비")
                                 or 지금() - float(지금것.get("때") or 0) > 3)
        if 시작:
            조사중 = True
        돌고있나 = 조사중
    if 시작:
        threading.Thread(target=상태돌리기, args=(점검다시,), daemon=True).start()
    지금것["조사중"] = 돌고있나
    return 지금것


# ── 안방 서버 (127.0.0.1 · 표가 없으면 전부 403) ────────────
표 = secrets.token_urlsafe(24)


class 손님(http.server.BaseHTTPRequestHandler):
    server_version = "setup"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    def log_message(self, 꼴, *값):   # 화면에 서버 기록을 흘리지 않는다
        pass

    # ── 남이 못 건드리게 ──
    def 들여도되나(self, 물음표):
        # 1) 이 컴퓨터 안 주소로 온 것만 (딴 이름으로 돌려 들어오는 것 막기)
        온집 = (self.headers.get("Host") or "").strip()
        if 온집 not in (f"127.0.0.1:{self.server.server_address[1]}",
                        f"localhost:{self.server.server_address[1]}"):
            return False
        # 2) 다른 웹페이지가 시킨 것 막기
        온데 = self.headers.get("Origin")
        if 온데 and 온데 != f"http://127.0.0.1:{self.server.server_address[1]}":
            return False
        # 3) 시작할 때 만든 비밀글자가 있어야 한다
        # 이름은 ASCII 여야 한다 — HTTP 는 머리글에 한글을 못 싣는다.
        온표 = self.headers.get("X-Setup") or (물음표.get("t") or [""])[0]
        return secrets.compare_digest(온표, 표)

    def 길읽기(self):
        """주소를 한글로 되돌린다.
        브라우저는 %EC%83%81… 로 바꿔 보내고 curl 은 글자 그대로 보내는데,
        파이썬은 둘 다 latin-1 로 읽어 놓기 때문이다."""
        생, _, 물음 = self.path.partition("?")
        try:
            바이트 = 생.encode("latin-1")
        except UnicodeEncodeError:
            바이트 = 생.encode("utf-8")
        길 = urllib.parse.unquote_to_bytes(바이트).decode("utf-8", "replace")
        return 길, urllib.parse.parse_qs(물음)

    def 보내기(self, 코드, 몸, 종류="application/json; charset=utf-8"):
        짐 = 몸 if isinstance(몸, bytes) else str(몸).encode("utf-8")
        self.send_response(코드)
        self.send_header("Content-Type", 종류)
        self.send_header("Content-Length", str(len(짐)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        try:
            self.wfile.write(짐)
        except Exception:
            pass

    def 짐보내기(self, 값, 코드=200):
        self.보내기(코드, json.dumps(값, ensure_ascii=False))

    def 몸읽기(self):
        try:
            길이 = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return {}
        if 길이 <= 0 or 길이 > 1 << 16:
            return {}
        try:
            return json.loads(self.rfile.read(길이).decode("utf-8")) or {}
        except Exception:
            return {}

    def do_GET(self):
        길, 물음표 = self.길읽기()
        if not self.들여도되나(물음표):
            self.보내기(403, "주소가 올바르지 않습니다. 설치 창에 나온 주소를 그대로 여세요.",
                        "text/plain; charset=utf-8")
            return
        if 길 in ("/", "/index.html"):
            self.보내기(200, 화면HTML, "text/html; charset=utf-8")
            return
        if 길 == "/api/상태":
            self.짐보내기(상태가져오기((물음표.get("check") or [""])[0] == "1"))
            return
        self.보내기(404, "없는 자리입니다.", "text/plain; charset=utf-8")

    def do_POST(self):
        길, 물음표 = self.길읽기()
        if not self.들여도되나(물음표):
            self.보내기(403, "주소가 올바르지 않습니다.", "text/plain; charset=utf-8")
            return
        몸 = self.몸읽기()

        if 길 == "/api/로그인":
            됐나, 말 = 창_로그인()
            self.짐보내기({"됐나": 됐나, "말": 말})
        elif 길 == "/api/승인":
            됐나, 말 = 창_승인()
            self.짐보내기({"됐나": 됐나, "말": 말})
        elif 길 == "/api/채널":
            됐나, 말 = 채널저장(str(몸.get("이름") or ""))
            self.짐보내기({"됐나": 됐나, "말": 말})
        elif 길 == "/api/열쇠":
            됐나, 말 = 열쇠저장(str(몸.get("이름") or ""), str(몸.get("값") or ""))
            self.짐보내기({"됐나": 됐나, "말": 말})
        elif 길 == "/api/끝":
            self.짐보내기({"됐나": True, "말": "닫습니다."})
            threading.Thread(target=self.server.shutdown, daemon=True).start()
        else:
            self.보내기(404, "없는 자리입니다.", "text/plain; charset=utf-8")


def 서버열기():
    """빈 포트를 골라 127.0.0.1 에만 묶는다. (서버, 주소) 또는 (None, "")"""
    try:
        서버 = http.server.ThreadingHTTPServer(("127.0.0.1", 0), 손님)
    except Exception:
        return None, ""
    서버.daemon_threads = True
    포트 = 서버.server_address[1]
    return 서버, f"http://127.0.0.1:{포트}/?t={urllib.parse.quote(표)}"


def 웹으로(창없이=False):
    """브라우저 화면으로 돈다. 못 열면 False 를 돌려 터미널 판으로 넘긴다.

    창없이=True 면 브라우저를 열지 않고 주소만 알려 준 뒤 계속 돈다.
    볼케이노 앱이 이 화면을 제 창 안에 띄울 때 쓴다 — 창을 두 번 열지 않기 위해서다."""
    서버, 주소 = 서버열기()
    if not 서버:
        print("  ! 화면을 띄울 자리를 못 잡았습니다. 터미널로 이어서 하겠습니다.")
        return False

    if 창없이:
        print(f"설치화면주소: {주소}", flush=True)
    else:
        열렸나 = False
        try:
            열렸나 = webbrowser.open(주소)   # 자리는 이미 잡아 뒀으니 먼저 온 손님은 기다린다
        except Exception:
            열렸나 = False
        if not 열렸나:
            서버.server_close()
            print("  ! 이 컴퓨터에서 브라우저를 열지 못했습니다. 터미널로 이어서 하겠습니다.")
            return False

    상태가져오기()   # 미리 한 번 살펴본다 (뒤에서 돈다)

    if not 창없이:
        print()
        print("  ✓ 브라우저에 마무리 화면을 띄웠습니다. 거기서 이어서 하세요.")
        print("    화면이 안 보이면 이 주소를 직접 여세요:")
        print(f"      {주소}")
        print()
        print("  · 브라우저 대신 이 창에서 하시려면 엔터를 누르세요.")

    돌아섬 = {"터미널로": False}

    def 엔터기다리기():
        try:
            sys.stdin.readline()
        except Exception:
            return
        돌아섬["터미널로"] = True
        서버.shutdown()

    if sys.stdin.isatty() and not 창없이:
        threading.Thread(target=엔터기다리기, daemon=True).start()

    try:
        서버.serve_forever(poll_interval=0.3)
    except KeyboardInterrupt:
        pass
    finally:
        서버.server_close()

    if 돌아섬["터미널로"]:
        return False
    print()
    print("  다 됐습니다. 이 창은 닫으셔도 됩니다.")
    print("  다음부터는 바탕화면의 「볼케이노」를 두 번 누르면 시작됩니다.")
    return True


def 시작():
    """기본은 터미널 판 — 붙여넣은 그 창 하나에서 끝까지 한다.
    브라우저 화면은 --화면 을 줬을 때만 띄우고, 못 띄우면 터미널로 되돌아간다."""
    인자 = sys.argv[1:]
    if "--화면" in 인자 or "--screen" in 인자:
        창없이 = "--창없이" in 인자
        if 웹으로(창없이):
            return 0
        if 창없이:
            return 1     # 앱이 띄운 것이다 — 터미널 판으로 넘어가 봐야 물을 사람이 없다
        # 브라우저를 못 열었거나 사람이 엔터를 눌렀다 — 옛 흐름 그대로 이어서 한다.
    return 하기()


if __name__ == "__main__":
    try:
        sys.exit(시작())
    except KeyboardInterrupt:
        print("\n  멈췄습니다. 바탕화면의 「볼케이노」로 다시 이어서 할 수 있습니다.")
        sys.exit(1)
