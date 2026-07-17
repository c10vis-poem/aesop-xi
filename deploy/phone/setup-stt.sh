#!/data/data/com.termux/files/usr/bin/bash
# One-time setup: install sherpa-onnx in Debian proot + download models.
# Run from NATIVE Termux (not inside proot).
set -euo pipefail

MODELS_DIR="$HOME/models"
PROOT_BIND="$HOME:$HOME"

echo "=== AESOP STT setup ==="

# --- 1. Ensure termux-api works ---
if ! command -v termux-toast &>/dev/null; then
  echo "Installing termux-api package (CLI bridge)..."
  pkg install -y termux-api
fi
termux-toast "AESOP STT setup starting" 2>/dev/null || true

# --- 2. Ensure proot-distro + debian exist ---
if ! command -v proot-distro &>/dev/null; then
  echo "Installing proot-distro..."
  pkg install -y proot-distro
fi
if ! proot-distro list 2>/dev/null | grep -q "debian"; then
  echo "Installing Debian in proot (one-time, ~200MB)..."
  proot-distro install debian
else
  echo "Debian proot already installed."
fi

# --- 3. Ensure ffmpeg is in native Termux ---
if ! command -v ffmpeg &>/dev/null; then
  echo "Installing ffmpeg..."
  pkg install -y ffmpeg
fi

# --- 4. Create shared models directory ---
mkdir -p "$MODELS_DIR"

# --- 5. Install sherpa-onnx + numpy inside proot ---
echo "Installing sherpa-onnx in Debian proot..."
proot-distro login debian --bind "$PROOT_BIND" -- bash -c '
  apt-get update -qq
  apt-get install -y -qq python3-pip wget >/dev/null 2>&1
  pip install --break-system-packages sherpa-onnx numpy 2>&1 | tail -3
  python3 -c "import sherpa_onnx; print(\"sherpa-onnx\", sherpa_onnx.__version__)" 2>/dev/null \
    || python3 -c "import sherpa_onnx; print(\"sherpa-onnx installed OK\")"
'

# --- 6. Download models (into shared $MODELS_DIR, visible from both envs) ---

# 6a. Silero VAD model (~1.8MB)
VAD_MODEL="$MODELS_DIR/silero_vad.onnx"
if [ ! -f "$VAD_MODEL" ]; then
  echo "Downloading Silero VAD model..."
  wget -q -O "$VAD_MODEL" \
    "https://huggingface.co/csukuangfj/vad/resolve/main/silero_vad.onnx"
  echo "  -> $(du -h "$VAD_MODEL" | cut -f1)"
else
  echo "Silero VAD model already present."
fi

# 6b. Moonshine base int8 STT model (~288MB total)
MOON_DIR="$MODELS_DIR/sherpa-onnx-moonshine-base-en-int8"
if [ ! -f "$MOON_DIR/encode.int8.onnx" ]; then
  echo "Downloading Moonshine base int8 model (~288MB)..."
  mkdir -p "$MOON_DIR"
  BASE_URL="https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-base-en-int8/resolve/main"
  for f in preprocess.onnx encode.int8.onnx uncached_decode.int8.onnx cached_decode.int8.onnx tokens.txt; do
    if [ ! -f "$MOON_DIR/$f" ]; then
      echo "  $f ..."
      wget -q -O "$MOON_DIR/$f" "$BASE_URL/$f"
    fi
  done
  echo "  -> $(du -sh "$MOON_DIR" | cut -f1) total"
else
  echo "Moonshine model already present."
fi

# --- 7. Verify everything works ---
echo ""
echo "=== Verifying ==="
proot-distro login debian --bind "$PROOT_BIND" -- python3 -c "
import sherpa_onnx, os
models = os.path.expanduser('~/models')
vad = os.path.join(models, 'silero_vad.onnx')
moon = os.path.join(models, 'sherpa-onnx-moonshine-base-en-int8')
assert os.path.isfile(vad), f'Missing: {vad}'
assert os.path.isfile(os.path.join(moon, 'encode.int8.onnx')), f'Missing encoder'
assert os.path.isfile(os.path.join(moon, 'tokens.txt')), f'Missing tokens'
print('OK: sherpa-onnx + VAD model + Moonshine model all present')
"

echo ""
echo "=== Setup complete ==="
echo "Models at: $MODELS_DIR"
echo "Run: ./record_transcribe.sh"
termux-toast "AESOP STT setup done" 2>/dev/null || true
