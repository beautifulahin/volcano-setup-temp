#!/bin/bash
# 볼케이노 — 진단하고 고칩니다 (맥)
# 두 번 눌러 실행하세요. 안 열리면 오른쪽 클릭 → 열기.
set -u
VHOME="${VOLCANO_HOME:-$HOME/.volcano}"
BIN="$VHOME/bin"
VENVPY="$VHOME/venv/bin/python3"
JOBS="${VOLCANO_JOBS:-$HOME/volcano_jobs}"
CLAUDE_BIN="$HOME/.local/bin"
fixed=""; left=""

echo
echo "=== 볼케이노 — 살펴보고 고칩니다 ==="
echo

# 1. Claude Code
if [ -x "$CLAUDE_BIN/claude" ] || command -v claude >/dev/null 2>&1; then
  echo "  [됨] Claude Code"
else
  echo "  [..] Claude Code 가 없습니다 — 깝니다"
  if curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1; then
    echo "  [고침] Claude Code 를 깔았습니다"; fixed="$fixed Claude"
  else
    echo "  [안됨] Claude Code 를 깔지 못했습니다"; left="$left Claude"
  fi
fi

# 2. PATH — 셸 설정에 심는다 (새 창에서 저절로 잡히게)
MARK="# volcano-path"
PLANTED=0
for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  [ -e "$rc" ] || touch "$rc"
  if ! grep -q "$MARK" "$rc" 2>/dev/null; then
    printf '\nexport PATH="%s:%s:$PATH"  %s\n' "$CLAUDE_BIN" "$BIN" "$MARK" >> "$rc"
    PLANTED=1
  fi
done
if [ "$PLANTED" = "1" ]; then echo "  [고침] 셸 설정에 길을 심었습니다"; fixed="$fixed PATH"
else echo "  [됨] 셸 설정"; fi

# 3. VS Code + 확장
CODE=""
for c in "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
         "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
  [ -x "$c" ] && CODE="$c" && break
done
[ -z "$CODE" ] && command -v code >/dev/null 2>&1 && CODE="code"
if [ -n "$CODE" ]; then
  echo "  [됨] VS Code"
  if "$CODE" --list-extensions 2>/dev/null | grep -q "anthropic.claude-code"; then
    echo "  [됨] Claude Code 확장"
  else
    echo "  [..] Claude Code 확장을 넣습니다"
    "$CODE" --install-extension anthropic.claude-code --force >/dev/null 2>&1 \
      && { echo "  [고침] 확장을 넣었습니다"; fixed="$fixed 확장"; } \
      || { echo "  [안됨] 확장을 넣지 못했습니다"; left="$left 확장"; }
  fi
else
  echo "  [없음] VS Code — code.visualstudio.com 에서 받으시면 됩니다"; left="$left VSCode"
fi

# 4. 작업 폴더 설정
mkdir -p "$JOBS/.vscode" 2>/dev/null
cat > "$JOBS/.vscode/settings.json" << JSONEOF
{
  "security.workspace.trust.enabled": false,
  "terminal.integrated.env.osx": {
    "PATH": "$CLAUDE_BIN:$BIN:\${env:PATH}"
  }
}
JSONEOF
echo "  [됨] 작업 폴더 설정"

# 5. 파이썬 (알려만 준다 — 고치려면 설치기를 다시 돌려야 한다)
if [ -x "$VENVPY" ]; then
  echo "  [됨] 파이썬"
else
  echo "  [..] 파이썬이 없습니다 — 깝니다 (몇 분 걸립니다)"
  export UV_INSTALL_DIR="$BIN" UV_UNMANAGED_INSTALL="$BIN" \
         UV_PYTHON_INSTALL_DIR="$VHOME/python" UV_PYTHON_BIN_DIR="$BIN" \
         UV_TOOL_BIN_DIR="$BIN" UV_NO_MODIFY_PATH=1
  UV=""
  [ -x "$BIN/uv" ] && UV="$BIN/uv"
  [ -z "$UV" ] && command -v uv >/dev/null 2>&1 && UV="uv"
  if [ -z "$UV" ]; then
    curl -fsSL https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
    [ -x "$BIN/uv" ] && UV="$BIN/uv"
  fi
  if [ -n "$UV" ]; then
    "$UV" python install 3.12 >/dev/null 2>&1
    "$UV" venv --seed --python 3.12 "$VHOME/venv" >/dev/null 2>&1
    [ -x "$VHOME/venv/bin/python3" ] && VENVPY="$VHOME/venv/bin/python3"
    if [ -x "$VENVPY" ]; then
      "$UV" pip install --python "$VENVPY" --quiet pillow numpy opencv-python fonttools brotli >/dev/null 2>&1
      "$UV" pip install --python "$VENVPY" --quiet openai-whisper >/dev/null 2>&1
    fi
  fi
  if [ -x "$VENVPY" ] || [ -x "$VHOME/venv/bin/python3" ]; then
    echo "  [고침] 파이썬을 깔았습니다"; fixed="$fixed 파이썬"
  else
    echo "  [안됨] 파이썬을 깔지 못했습니다 — setup-mac.command 를 다시 돌려 주세요"; left="$left 파이썬"
  fi
fi

echo
echo "──────────────────────────────────────"
[ -n "$fixed" ] && echo "  고친 것:$fixed"
[ -n "$left" ]  && echo "  아직 없는 것:$left"
[ -z "$fixed$left" ] && echo "  다 멀쩡합니다."
echo
echo "  이 창을 닫고 새로 여세요."
echo "  그다음 VS Code 에서 왼쪽 Claude 아이콘(또는 ⌘+Esc)을 누르시면 됩니다."
echo
read -r -p "  엔터를 누르면 창이 닫힙니다… " _ || true
