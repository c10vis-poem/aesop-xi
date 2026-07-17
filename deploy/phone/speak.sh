#!/data/data/com.termux/files/usr/bin/bash
# AESOP TTS — text to speech via Kokoro.
# Run from NATIVE Termux. Calls proot internally for sherpa-onnx.
set -euo pipefail

SID="${AESOP_VOICE:-0}"
TEXT="$*"
if [ -z "$TEXT" ]; then
  echo "Usage: speak.sh <text to speak>"
  echo "  Set AESOP_VOICE=N to change voice (0-52)"
  exit 1
fi

AUDIO_OUT="$HOME/.tts_out.wav"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

proot-distro login debian --bind "$HOME:$HOME" -- \
  python3 "$SCRIPT_DIR/tts_speak.py" "$AUDIO_OUT" --sid "$SID" "$TEXT"

if [ -f "$AUDIO_OUT" ]; then
  play-audio "$AUDIO_OUT" 2>/dev/null || ffplay -nodisp -autoexit "$AUDIO_OUT" 2>/dev/null || termux-media-player play "$AUDIO_OUT"
  rm -f "$AUDIO_OUT"
fi
