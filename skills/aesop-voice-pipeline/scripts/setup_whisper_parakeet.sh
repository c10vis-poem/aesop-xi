#!/data/data/com.termux/files/usr/bin/bash
# Extracts and validates the whisper.cpp + Parakeet toolkit, found sitting unused in
# ~/downloads/whisper-bin-ubuntu-arm64.tar.gz. Confirmed 2026-08-29 via `file` that
# whisper-server is a glibc Linux binary (interpreter /lib/ld-linux-aarch64.so.1) —
# unlike geniex-bench, this does NOT run natively in bionic Termux. It needs the
# Debian proot, same reason sherpa-onnx does. Host paths are visible unchanged
# inside `proot-distro login debian` (confirmed working all session), so no bind
# mount or copy into the proot's own filesystem is needed.
#
# Bundle includes: whisper-server, whisper-quantize, libwhisper.so, and test
# binaries for NVIDIA's Parakeet model (test-parakeet, test-parakeet-full-*) --
# Parakeet is the default STT in the huggingface/speech-to-speech repo cloned
# earlier this session (~/repos/speech-to-speech).
#
# Usage: setup_whisper_parakeet.sh [source_tarball]

set -euo pipefail

SRC="${1:-$HOME/downloads/whisper-bin-ubuntu-arm64.tar.gz}"
DEST="$HOME/tools/whisper-parakeet"

if [ ! -f "$SRC" ]; then
    echo "ERROR: tarball not found at $SRC" >&2
    exit 1
fi

mkdir -p "$HOME/tools"

if [ -d "$DEST" ]; then
    echo "[setup_whisper_parakeet] Already extracted at $DEST, skipping."
else
    echo "[setup_whisper_parakeet] Extracting $SRC ..."
    tar xzf "$SRC" -C "$HOME/tools"
    mv "$HOME/tools/whisper-bin-ubuntu-arm64" "$DEST"
fi

chmod +x "$DEST"/whisper-server "$DEST"/whisper-quantize "$DEST"/test-parakeet* 2>/dev/null || true

echo "[setup_whisper_parakeet] Verifying it actually runs inside the proot (glibc required):"
proot-distro login debian -- bash -c "
    export LD_LIBRARY_PATH='$DEST'
    '$DEST/whisper-server' --help 2>&1 | head -5 || echo 'whisper-server did not run -- check for missing glibc deps with ldd'
"

echo ""
echo "Contents:"
ls "$DEST"
echo ""
echo "To run whisper-server against a model, from Termux:"
echo "  proot-distro login debian -- env LD_LIBRARY_PATH=$DEST $DEST/whisper-server --help"
