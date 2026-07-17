#!/data/data/com.termux/files/usr/bin/bash
# AESOP Voice — complete one-command setup for STT + TTS + OpenWiki voice.
# Run from NATIVE Termux (not inside proot).
#
# What this installs:
#   Native Termux: termux-api, proot-distro, ffmpeg, nodejs
#   Proot Debian:  sherpa-onnx, numpy
#   Models:        Silero VAD (~2MB), Moonshine base int8 (~288MB),
#                  Kokoro multi-lang v1.0 (~326MB)
#
# Total disk: ~650MB for models + ~200MB for Debian proot
#
# Usage:
#   curl -sL <raw-url>/setup-voice.sh | bash
#   # or
#   cd ~/aesop && bash deploy/phone/setup-voice.sh
set -euo pipefail

MODELS_DIR="$HOME/models"
PROOT_BIND="$HOME:$HOME"
AESOP_DIR="${AESOP_DIR:-$HOME/aesop}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$*"; }
step() { printf '\n\033[36m[%s] %s\033[0m\n' "$1" "$2"; }
fail() { printf '\033[31m  ✗ %s\033[0m\n' "$*"; }

bold "=== AESOP Voice Setup ==="
echo "One-command setup: STT + TTS + OpenWiki voice integration"
echo ""

# ─── 1. Native Termux packages ───────────────────────────────────

step "1/7" "Native Termux packages"

for pkg_name in termux-api proot-distro ffmpeg; do
  cmd="$pkg_name"
  [ "$pkg_name" = "termux-api" ] && cmd="termux-toast"
  if ! command -v "$cmd" &>/dev/null; then
    echo "  Installing $pkg_name..."
    pkg install -y "$pkg_name" >/dev/null 2>&1
    ok "$pkg_name installed"
  else
    ok "$pkg_name already present"
  fi
done

if ! command -v node &>/dev/null; then
  echo "  Installing nodejs..."
  pkg install -y nodejs >/dev/null 2>&1
  ok "nodejs installed"
else
  ok "nodejs $(node -v) already present"
fi

termux-toast "AESOP Voice setup starting" 2>/dev/null || true

# ─── 2. Debian proot ─────────────────────────────────────────────

step "2/7" "Debian proot environment"

if ! proot-distro list 2>/dev/null | grep -q "debian"; then
  echo "  Installing Debian in proot (~200MB)..."
  proot-distro install debian
  ok "Debian installed"
else
  ok "Debian already installed"
fi

# ─── 3. Python packages inside proot ─────────────────────────────

step "3/7" "Python packages (sherpa-onnx + numpy)"

proot-distro login debian --bind "$PROOT_BIND" -- bash -c '
  if python3 -c "import sherpa_onnx" 2>/dev/null; then
    VER=$(python3 -c "import sherpa_onnx; print(sherpa_onnx.__version__)" 2>/dev/null || echo "unknown")
    echo "  ✓ sherpa-onnx $VER already installed"
  else
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq python3-pip wget >/dev/null 2>&1
    pip install --break-system-packages sherpa-onnx numpy 2>&1 | tail -3
    echo "  ✓ sherpa-onnx installed"
  fi
'

# ─── 4. Models directory ─────────────────────────────────────────

step "4/7" "Downloading models"
mkdir -p "$MODELS_DIR"

# 4a. Silero VAD (~2MB)
VAD_MODEL="$MODELS_DIR/silero_vad.onnx"
if [ ! -f "$VAD_MODEL" ]; then
  echo "  Silero VAD (~2MB)..."
  wget -q -O "$VAD_MODEL" \
    "https://huggingface.co/csukuangfj/vad/resolve/main/silero_vad.onnx"
  ok "Silero VAD $(du -h "$VAD_MODEL" | cut -f1)"
else
  ok "Silero VAD already present"
fi

# 4b. Moonshine base int8 (~288MB)
MOON_DIR="$MODELS_DIR/sherpa-onnx-moonshine-base-en-int8"
if [ ! -f "$MOON_DIR/encode.int8.onnx" ]; then
  echo "  Moonshine base int8 (~288MB)..."
  mkdir -p "$MOON_DIR"
  BASE_URL="https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-base-en-int8/resolve/main"
  for f in preprocess.onnx encode.int8.onnx uncached_decode.int8.onnx cached_decode.int8.onnx tokens.txt; do
    [ -f "$MOON_DIR/$f" ] && continue
    echo "    $f ..."
    wget -q -O "$MOON_DIR/$f" "$BASE_URL/$f"
  done
  ok "Moonshine $(du -sh "$MOON_DIR" | cut -f1)"
else
  ok "Moonshine already present"
fi

# 4c. Kokoro multi-lang v1.0 (~326MB)
KOKORO_DIR="$MODELS_DIR/kokoro-multi-lang-v1.0"
if [ ! -f "$KOKORO_DIR/model.onnx" ]; then
  echo "  Kokoro TTS v1.0 (~326MB)..."
  mkdir -p "$KOKORO_DIR"
  BASE_URL="https://huggingface.co/csukuangfj/kokoro-multi-lang-v1.0/resolve/main"
  for f in model.onnx voices.bin tokens.txt; do
    [ -f "$KOKORO_DIR/$f" ] && continue
    echo "    $f ..."
    wget -q -O "$KOKORO_DIR/$f" "$BASE_URL/$f"
  done
  for d in espeak-ng-data dict; do
    if [ ! -d "$KOKORO_DIR/$d" ]; then
      echo "    $d/ ..."
      proot-distro login debian --bind "$PROOT_BIND" -- bash -c "
        cd '$KOKORO_DIR'
        wget -q '$BASE_URL/$d.tar.gz' -O '$d.tar.gz'
        tar xzf '$d.tar.gz'
        rm -f '$d.tar.gz'
      "
    fi
  done
  for lex in lexicon-us-en.txt lexicon-gb-en.txt lexicon-zh.txt; do
    [ -f "$KOKORO_DIR/$lex" ] && continue
    wget -q -O "$KOKORO_DIR/$lex" "$BASE_URL/$lex" 2>/dev/null || true
  done
  ok "Kokoro $(du -sh "$KOKORO_DIR" | cut -f1)"
else
  ok "Kokoro TTS already present"
fi

# ─── 5. Verify models ────────────────────────────────────────────

step "5/7" "Verifying models"

proot-distro login debian --bind "$PROOT_BIND" -- python3 -c "
import sherpa_onnx, os, sys
models = os.path.expanduser('~/models')

checks = [
    ('Silero VAD', os.path.join(models, 'silero_vad.onnx')),
    ('Moonshine encoder', os.path.join(models, 'sherpa-onnx-moonshine-base-en-int8/encode.int8.onnx')),
    ('Moonshine tokens', os.path.join(models, 'sherpa-onnx-moonshine-base-en-int8/tokens.txt')),
    ('Kokoro model', os.path.join(models, 'kokoro-multi-lang-v1.0/model.onnx')),
    ('Kokoro voices', os.path.join(models, 'kokoro-multi-lang-v1.0/voices.bin')),
    ('Kokoro espeak', os.path.join(models, 'kokoro-multi-lang-v1.0/espeak-ng-data')),
]
ok = True
for name, path in checks:
    exists = os.path.exists(path)
    mark = '✓' if exists else '✗'
    print(f'  {mark} {name}')
    if not exists:
        ok = False
if not ok:
    sys.exit(1)
"

if [ $? -eq 0 ]; then
  ok "All models verified"
else
  fail "Some models missing — check output above"
  exit 1
fi

# ─── 6. AESOP scripts ────────────────────────────────────────────

step "6/7" "AESOP voice scripts"

if [ -f "$AESOP_DIR/deploy/phone/stt_process.py" ] && \
   [ -f "$AESOP_DIR/deploy/phone/tts_speak.py" ]; then
  ok "STT + TTS scripts found at $AESOP_DIR/deploy/phone/"
else
  fail "AESOP scripts not found at $AESOP_DIR/deploy/phone/"
  echo "  Clone the repo: git clone <aesop-url> ~/aesop"
  exit 1
fi

# ─── 7. OpenWiki voice check ─────────────────────────────────────

step "7/7" "OpenWiki voice integration"

OPENWIKI_DIR="$HOME/openwiki"
if [ -f "$OPENWIKI_DIR/dist/voice.js" ]; then
  ok "OpenWiki voice module built"
elif [ -f "$OPENWIKI_DIR/src/voice.ts" ]; then
  echo "  Building OpenWiki..."
  (cd "$OPENWIKI_DIR" && npm run build 2>/dev/null)
  if [ -f "$OPENWIKI_DIR/dist/voice.js" ]; then
    ok "OpenWiki built with voice support"
  else
    fail "Build failed — run: cd ~/openwiki && npm run build"
  fi
else
  echo "  Voice module not found in OpenWiki."
  echo "  Pull the voice branch: cd ~/openwiki && git pull origin claude/aesop-stt-tts-layer-0v6c83"
fi

# ─── Done ─────────────────────────────────────────────────────────

echo ""
bold "=== Setup Complete ==="
echo ""
echo "  Models:  $MODELS_DIR (~616MB)"
echo "  Scripts: $AESOP_DIR/deploy/phone/"
echo ""
bold "Usage:"
echo "  Run OpenWiki normally — voice auto-activates in Termux."
echo "  Press Ctrl+R to start recording, ENTER to transcribe."
echo "  Responses are spoken automatically (disable: AESOP_TTS=0)."
echo ""
bold "Standalone scripts:"
echo "  ./record_transcribe.sh    # STT only"
echo "  ./speak.sh 'hello'        # TTS only"
echo "  ./voice.sh                # voice loop with OpenWiki"
echo ""
termux-toast "AESOP Voice setup complete" 2>/dev/null || true
