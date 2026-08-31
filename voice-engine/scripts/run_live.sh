#!/usr/bin/env bash
#
# AESOP Voice Engine — Live Voice Loop Launcher
#
# Bridges Termux PulseAudio into the Debian proot and runs the live voice loop.
# This is the main entry point for real-time mic -> STT -> TTS -> speaker.
#
# Usage:
#   bash ~/repos/aesop/voice-engine/scripts/run_live.sh
#   bash ~/repos/aesop/voice-engine/scripts/run_live.sh --demo
#   bash ~/repos/aesop/voice-engine/scripts/run_live.sh --voice af_heart --speed 1.1

set -euo pipefail

# --- Find the PulseAudio socket ---
PULSE_SOCKET_DIR=$(find /data/data/com.termux/files/usr/tmp -maxdepth 1 -type d -name "pulse-*" 2>/dev/null | head -1)

if [ -z "$PULSE_SOCKET_DIR" ]; then
    echo "ERROR: PulseAudio socket not found. Start it first:"
    echo "  pulseaudio --start -nF ~/pulse-noauth.pa --exit-idle-time=-1 --disable-shm"
    exit 1
fi

PULSE_SOCKET="$PULSE_SOCKET_DIR/native"

if [ ! -S "$PULSE_SOCKET" ]; then
    echo "ERROR: PulseAudio socket exists but is not a socket: $PULSE_SOCKET"
    exit 1
fi

echo "Found PulseAudio socket: $PULSE_SOCKET"

# --- Launch the voice loop inside the proot with PulseAudio bridged ---
exec proot-distro login debian \
    --bind "$PULSE_SOCKET_DIR":/tmp/pulse-termux \
    -- env \
        PULSE_SERVER=unix:/tmp/pulse-termux/native \
        AESOP_MODELS_DIR=/root/models \
        python3 /root/repos/aesop/voice-engine/scripts/live_voice_loop.py "$@"
