#!/data/data/com.termux/files/usr/bin/bash
# Extracts and validates GenieX's NPU benchmark tool, found sitting unused in
# ~/downloads/geniex-bench-android-arm64-v0.3.14.tar.gz. Confirmed 2026-08-29 via
# `file` that bin/geniex-bench is a native Android/bionic binary
# (interpreter /system/bin/linker64, built by NDK r29) — it runs directly in
# Termux, no proot needed. Bundles llama.cpp/ggml with Hexagon HTP backends for
# six NPU generations (v68/69/73/75/79/81) plus a compiled QNN context file
# (lib/qairt/htp-files/libqnnhtpv81.cat).
#
# Usage: setup_geniex_bench.sh [source_tarball]
#   Installs to ~/tools/geniex-bench, prints the bench binary's --help so you can
#   confirm it actually runs before pointing it at a real model.

set -euo pipefail

SRC="${1:-$HOME/downloads/geniex-bench-android-arm64-v0.3.14.tar.gz}"
DEST="$HOME/tools/geniex-bench"

if [ ! -f "$SRC" ]; then
    echo "ERROR: tarball not found at $SRC" >&2
    exit 1
fi

mkdir -p "$HOME/tools"

if [ -d "$DEST" ]; then
    echo "[setup_geniex_bench] Already extracted at $DEST, skipping."
else
    echo "[setup_geniex_bench] Extracting $SRC ..."
    tar xzf "$SRC" -C "$HOME/tools"
    mv "$HOME/tools/geniex-bench-android-arm64-v0.3.14" "$DEST"
fi

chmod +x "$DEST/bin/geniex-bench"

echo "[setup_geniex_bench] Binary type check:"
file "$DEST/bin/geniex-bench"

# libgeniex.so lives at lib/ (top level), not lib/llama_cpp/ -- and it in turn
# needs lib/qairt/'s libgeniex_core.so etc. All three dirs must be on the path.
GENIEX_LD_PATH="$DEST/lib:$DEST/lib/llama_cpp:$DEST/lib/qairt:$DEST/lib/qairt/htp-files"

echo "[setup_geniex_bench] Attempting to run it:"
LD_LIBRARY_PATH="$GENIEX_LD_PATH" "$DEST/bin/geniex-bench" --help 2>&1 || {
    echo "NOTE: --help failed or is not a supported flag for this build."
    echo "Binary is in place at $DEST/bin/geniex-bench; check its actual usage manually."
}

echo ""
echo "HTP backends available (pick the one matching this device's Hexagon version,"
echo "confirmed v79 on this phone via the Paage.ai APK teardown):"
ls "$DEST/lib/llama_cpp/" | grep htp
echo ""
echo "To run manually:"
echo "  LD_LIBRARY_PATH=\"$GENIEX_LD_PATH\" $DEST/bin/geniex-bench <args>"
