#!/data/data/com.termux/files/usr/bin/bash
# AESOP voice pipeline setup for Termux
# Run once on a fresh device: bash ~/aesop/deploy/phone/setup-voice.sh
set -euo pipefail

echo "=== AESOP Voice Pipeline Setup ==="

# ── 1. Termux packages ──────────────────────────────────────────────
echo "[1/6] Installing Termux packages..."
pkg up -y
pkg install -y termux-api ffmpeg proot-distro tmux jq git nodejs

# ── 2. Debian proot ─────────────────────────────────────────────────
echo "[2/6] Setting up Debian proot..."
if ! proot-distro list --installed 2>/dev/null | grep -q debian; then
  proot-distro install debian
fi

proot-distro login debian --bind "$HOME:$HOME" -- bash -c '
  apt-get update -qq
  apt-get install -y -qq python3-pip ffmpeg > /dev/null 2>&1
  pip install --break-system-packages -q sherpa-onnx onnxruntime numpy soundfile
  echo "  proot Python deps installed."
'

# ── 3. Model directory ──────────────────────────────────────────────
echo "[3/6] Creating model directory..."
MODELS="$HOME/models"
mkdir -p "$MODELS"

# ── 4. Silero VAD model ─────────────────────────────────────────────
echo "[4/6] Downloading Silero VAD model..."
VAD_MODEL="$MODELS/silero_vad.onnx"
if [ ! -f "$VAD_MODEL" ]; then
  curl -fSL -o "$VAD_MODEL" \
    "https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx"
  echo "  silero_vad.onnx downloaded."
else
  echo "  silero_vad.onnx already exists, skipping."
fi

# ── 5. Moonshine STT model ──────────────────────────────────────────
echo "[5/6] Downloading Moonshine STT model..."
STT_DIR="$MODELS/sherpa-onnx-moonshine-base-en-int8"
if [ ! -f "$STT_DIR/encode.int8.onnx" ]; then
  mkdir -p "$STT_DIR"
  STT_BASE="https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-base-en-int8/resolve/main"
  for f in preprocess.onnx encode.int8.onnx uncached_decode.onnx cached_decode.onnx tokens.txt; do
    echo "  fetching $f..."
    curl -fSL -o "$STT_DIR/$f" "$STT_BASE/$f"
  done
  echo "  Moonshine STT model downloaded."
else
  echo "  Moonshine STT model already exists, skipping."
fi

# ── 6. Kokoro TTS model ─────────────────────────────────────────────
echo "[6/6] Downloading Kokoro TTS model..."
TTS_DIR="$MODELS/kokoro-multi-lang-v1.0"
if [ ! -f "$TTS_DIR/model.onnx" ]; then
  mkdir -p "$TTS_DIR"
  TTS_BASE="https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/kokoro-multi-lang-v1.0"

  echo "  fetching model.onnx (~326MB, this will take a while)..."
  curl -fSL -o "$TTS_DIR/model.onnx" "$TTS_BASE/model.onnx"

  for f in voices.bin tokens.txt; do
    echo "  fetching $f..."
    curl -fSL -o "$TTS_DIR/$f" "$TTS_BASE/$f"
  done

  echo "  fetching espeak-ng-data..."
  mkdir -p "$TTS_DIR/espeak-ng-data"
  # espeak-ng-data is a directory tree — get the archive if available,
  # otherwise the sherpa-onnx Python package bundles it
  proot-distro login debian --bind "$HOME:$HOME" -- python3 -c "
import sherpa_onnx, shutil, os
src = os.path.join(os.path.dirname(sherpa_onnx.__file__), 'espeak-ng-data')
dst = os.path.expanduser('$TTS_DIR/espeak-ng-data')
if os.path.isdir(src):
    shutil.copytree(src, dst, dirs_exist_ok=True)
    print('  espeak-ng-data copied from sherpa-onnx package.')
else:
    print('  espeak-ng-data not found in sherpa-onnx, may need manual download.')
" 2>/dev/null || echo "  espeak-ng-data: will use sherpa-onnx bundled data."

  echo "  Kokoro TTS model downloaded."
else
  echo "  Kokoro TTS model already exists, skipping."
fi

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
echo ""
echo "Models installed to: $MODELS"
echo "Voice scripts at:    $HOME/aesop/deploy/phone/"
echo ""
echo "Quick test:"
echo "  # STT test:"
echo '  termux-microphone-record -f ~/.test.wav -e amr_wb -r 16000 -c 1'
echo '  sleep 3 && termux-microphone-record -q'
echo '  proot-distro login debian --bind ~:~ -- python3 ~/aesop/deploy/phone/stt_process.py ~/.test.wav'
echo ""
echo "  # TTS test:"
echo '  proot-distro login debian --bind ~:~ -- python3 ~/aesop/deploy/phone/tts_speak.py ~/.test_tts.wav "Voice pipeline online."'
echo '  termux-media-player play ~/.test_tts.wav'
echo ""
echo "Next: run ~/aesop/deploy/phone/boot.sh to start everything in tmux."
