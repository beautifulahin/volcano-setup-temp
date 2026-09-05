#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""볼케이노 점검 — 필요한 것이 다 있는지 3초 안에 보고 ✓/✗ 로 알려 준다.

  전부 ✓ 이면 종료코드 0, 하나라도 ✗ 이면 1.
  표준 라이브러리만 쓴다.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

윈도우 = os.name == "nt"

try:  # 말이 나오는 차례가 뒤섞이지 않게
    sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass


def 볼케이노집() -> Path:
    """도구·열쇠·설정이 사는 자리."""
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
실행기 = Path(os.environ.get("VOLCANO_RUNNER") or (집 / "runner"))


def 설정읽기() -> dict:
    for 자리 in (설치기 / "설정.json", Path(__file__).resolve().parent / "설정.json"):
        try:
            return json.loads(자리.read_text(encoding="utf-8"))
        except Exception:
            continue
    return {}


설정 = 설정읽기()

# (됐나, 무엇, 안 됐을 때 할 일, 기다리는 중인가)
# 「기다리는 중」 = 사용자가 할 일이 없고 운영자 값만 오면 저절로 채워지는 것.
# 그래서 화면에서 빨간 ✗ 와 갈라 보여 준다 — 잘못한 줄 알고 헤매지 않게.
줄들: list[tuple[bool, str, str, bool]] = []


def 적기(됐나, 무엇, 할일="", 기다림=False):
    줄들.append((bool(됐나), 무엇, 할일, bool(기다림)))


다시깔기 = "설치 명령을 한 번 더 돌려 주세요"


def 찾기(이름):
    """PATH 와 볼케이노 폴더에서 프로그램을 찾는다."""
    덧 = [str(집 / "bin"), str(파이썬.parent)]
    길 = os.pathsep.join(덧 + [os.environ.get("PATH", "")])
    return shutil.which(이름, path=길)


# ── 1. 파이썬 자리와 부품 ───────────────────────────────────
적기(파이썬.exists(), f"파이썬 자리 ({파이썬})", 다시깔기)

부품 = ["PIL", "numpy", "cv2", "fontTools", "brotli"]
찾은부품 = {이름: False for 이름 in 부품}
실행기됨 = False
if 파이썬.exists():
    잔소리 = (
        "import importlib.util as u,sys,json\n"
        "p=sys.argv[1]\n"
        "sys.path.insert(0,p) if p else None\n"
        "n=%r\n"
        "print(json.dumps({k:(u.find_spec(k) is not None) for k in n+['volcano_run']}))\n"
    ) % 부품
    try:
        답 = subprocess.run(
            [str(파이썬), "-c", 잔소리, str(실행기) if 실행기.exists() else ""],
            capture_output=True, text=True, timeout=15,
        )
        본것 = json.loads(답.stdout.strip() or "{}")
        찾은부품 = {이름: bool(본것.get(이름)) for 이름 in 부품}
        실행기됨 = bool(본것.get("volcano_run"))
    except Exception:
        pass

보이는이름 = {"PIL": "그림(PIL)", "numpy": "숫자(numpy)", "cv2": "영상(cv2)",
              "fontTools": "글꼴(fontTools)", "brotli": "압축(brotli)"}
for 이름 in 부품:
    적기(찾은부품[이름], f"파이썬 부품 — {보이는이름[이름]}", 다시깔기)

# ── 2. 프로그램들 ───────────────────────────────────────────
ffmpeg자리 = 찾기("ffmpeg")
자막된다 = False
if ffmpeg자리:
    try:
        답 = subprocess.run([ffmpeg자리, "-hide_banner", "-filters"],
                           capture_output=True, text=True, timeout=10)
        자막된다 = " ass " in 답.stdout
    except Exception:
        자막된다 = False
적기(bool(ffmpeg자리), "ffmpeg", 다시깔기)
적기(자막된다, "ffmpeg 의 자막 얹기 기능", "자막이 되는 ffmpeg 가 필요합니다 — " + 다시깔기)

for 이름, 보임, 할일 in [
    ("ffprobe", "ffprobe", 다시깔기),
    ("yt-dlp", "yt-dlp (영상 받기)", 다시깔기),
    ("curl", "curl", "맥이라면 터미널에서 xcode-select --install 을 한 번 돌려 주세요"),
    ("uv", "uv (파이썬 관리)", 다시깔기),
]:
    적기(bool(찾기(이름)), 보임, 할일)

whisper자리 = 찾기("whisper")
적기(bool(whisper자리), "whisper (받아쓰기)",
    "받아쓰기 열쇠를 넣었다면 없어도 됩니다. 넣으려면 " + 다시깔기)

claude자리 = 찾기("claude")
적기(bool(claude자리), "Claude Code",
    "터미널에 이렇게 치세요: curl -fsSL https://claude.ai/install.sh | bash")

# 파일이 있는 것과 로그인된 것은 다르다 — 로그인 안 된 채 [볼케이노 열기] 를 누르면
# 클로드가 한 줄 찍고 꺼져서 사람은 「프로세스 완료됨」만 본다.
# 물어보는 법은 한 가지뿐이다: claude auth status 가 돌려주는 JSON 의 loggedIn.
# 말글을 어림짐작하지 않는다 — 판정이 흔들리면 사람이 같은 자리를 맴돈다.
def 로그인판정(claude):
    """돌려주는 값: True(로그인됨) · False(아직) · None(모름)."""
    try:
        답 = subprocess.run([claude, "auth", "status"],
                           capture_output=True, text=True, timeout=25)
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


if claude자리:
    로그인 = 로그인판정(claude자리)
    적기(로그인 is True, "Claude Code 로그인"
         + ("" if 로그인 is not None else " (모름 — 물어보지 못했습니다)"),
         "볼케이노 앱의 [로그인 하기] 를 누르세요")

# ── 3. 실행기 ───────────────────────────────────────────────
# 주소가 아직 없을 때 하는 말. 무엇인지 · 왜 없는지 · 누구 잘못인지 · 무엇을 기다리면 되는지를
# 한 번에 말해 준다. 여기서 「설치를 다시 돌리라」 고 하면 안 된다 — 다시 돌려도 달라지지 않는다.
실행기설명 = (
    "실행기는 볼케이노가 주는 파일 두 개(volcano_run.py · volcano_drive.py)입니다. "
    "서버가 내리는 지시를 이 컴퓨터에서 실제로 실행하는 부품입니다. "
    "아직 받을 주소가 정해지지 않아 비어 있습니다 — 사용자가 잘못한 것이 아닙니다. "
    "볼케이노 운영자가 주소를 정하면 앱을 다시 열 때 저절로 받아집니다. 따로 하실 일이 없습니다."
)
실행기_주소 = str(설정.get("실행기_주소") or "TODO")
실행기있음 = (실행기 / "volcano_run.py").exists() and (실행기 / "volcano_drive.py").exists()
if 실행기_주소 in ("", "TODO"):
    적기(False, "실행기 (volcano_run.py · volcano_drive.py)", 실행기설명, 기다림=True)
else:
    적기(실행기있음, "실행기 (volcano_run.py · volcano_drive.py)", 다시깔기)
    적기(실행기됨, "실행기 불러오기 (import volcano_run)",
        "실행기 폴더가 깨졌습니다 — " + 다시깔기)

# ── 4. 설정과 열쇠 ──────────────────────────────────────────
적기((집 / "env").exists(), "설정 파일 (env)", 다시깔기)

# ── 볼케이노가 붙었나 · 승인됐나 ───────────────────────────
# 승인은 Claude Code 의 OAuth 가 한다(/mcp → Authenticate). 여기서는 결과만 본다.
이름 = str(설정.get("mcp_이름") or "volcano")
if claude자리:
    글 = ""
    try:
        답 = subprocess.run([claude자리, "mcp", "get", 이름],
                            capture_output=True, text=True, timeout=20)
        글 = (답.stdout or "") + (답.stderr or "")
    except Exception:
        pass
    if "Connected" in 글 or "✔" in 글:
        적기(True, "볼케이노 연결·승인됨")
    elif 글.strip():
        적기(False, "볼케이노 승인",
             "볼케이노를 열고  /mcp  → " + 이름 + " → Authenticate 를 누른 뒤,"
             " 볼케이노 앱에 쓰던 메일을 적으세요")
    else:
        적기(False, "볼케이노 붙이기", "설치마무리를 다시 돌려 주세요")

고른채널 = ""
채널자리 = 설치기 / "채널"
if 채널자리.exists():
    고른채널 = 채널자리.read_text(encoding="utf-8").strip()

채널별 = 설정.get("채널별_키") or {}
안내 = 설정.get("키_안내") or {}
if 고른채널:
    필요 = 채널별.get(고른채널, [])
    적기(True, f"고른 채널 — {고른채널}")
    for 열쇠 in 필요:
        보임 = (안내.get(열쇠) or {}).get("이름", 열쇠)
        있음 = (열쇠집 / 열쇠).exists() or bool(os.environ.get(열쇠.upper()))
        if 열쇠 == "asr" and not 있음 and whisper자리:
            적기(True, f"열쇠 — {보임} (whisper 로 대신함)")
            continue
        적기(있음, f"열쇠 — {보임}", "설치마무리를 다시 돌려 열쇠를 넣어 주세요")
else:
    적기(False, "고른 채널", "설치마무리를 돌려 채널을 골라 주세요")


# ── 내보내기 ────────────────────────────────────────────────
def 찍기():
    print()
    print("──── 볼케이노 점검 ────")
    나쁨 = 0
    for 됐나, 무엇, 할일, 기다림 in 줄들:
        print(f"  {'✓' if 됐나 else '✗'} {무엇}{'' if 됐나 or not 기다림 else ' — 기다리는 중'}")
        if not 됐나:
            나쁨 += 1
            if 할일:
                print(f"      → {할일}")
    print("───────────────────────")
    if 나쁨 == 0:
        print("  다 됐습니다. 바로 쓰면 됩니다.")
    else:
        print(f"  {나쁨}가지가 아직입니다. 위의 → 를 따라 해 주세요.")
    print()
    return 0 if 나쁨 == 0 else 1


def 값():
    """기계가 읽는 판 — 앱과 마무리 화면이 이것을 쓴다."""
    줄 = [{"됨": 됐나, "무엇": 무엇, "할일": 할일, "기다림": 기다림}
          for 됐나, 무엇, 할일, 기다림 in 줄들]
    나쁨 = sum(1 for 하나 in 줄 if not 하나["됨"])
    return {"됨": bool(줄) and 나쁨 == 0, "나쁨": 나쁨, "줄들": 줄}


if __name__ == "__main__":
    if "--json" in sys.argv[1:]:
        본것 = 값()
        print(json.dumps(본것, ensure_ascii=False))
        sys.exit(0 if 본것["됨"] else 1)
    sys.exit(찍기())
