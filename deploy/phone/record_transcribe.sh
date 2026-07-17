#!/data/data/com.termux/files/usr/bin/bash
# AESOP STT — record from mic, transcribe with Moonshine.
# Run from NATIVE Termux. Calls proot internally for sherpa-onnx.
set -euo pipefail

AUDIO_RAW="$HOME/.stt_raw.wav"
AUDIO_16K="$HOME/.stt_16k.wav"
DURATION="${1:-5}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STT_PY="$SCRIPT_DIR/stt_process.py"

# --- Record ---
termux-toast "Speak now (${DURATION}s)"
termux-vibrate -d 100
termux-microphone-record -f "$AUDIO_RAW" -l "$DURATION" -e amr_wb -r 16000 -c 1

# Wait for recording to finish
sleep "$DURATION"
termux-microphone-record -q 2>/dev/null || true
sleep 0.5

# --- Convert to 16kHz mono PCM WAV ---
ffmpeg -y -i "$AUDIO_RAW" -ar 16000 -ac 1 -acodec pcm_s16le "$AUDIO_16K" 2>/dev/null

# --- Transcribe inside proot ---
termux-toast "Transcribing..."
RESULT=$(proot-distro login debian --bind "$HOME:$HOME" -- \
  python3 "$STT_PY" "$AUDIO_16K" 2>/dev/null)

if [ -n "$RESULT" ]; then
  echo "$RESULT"
  termux-toast "$RESULT"
else
  echo "(no speech detected)"
  termux-toast "No speech detected"
fi

# Cleanup
rm -f "$AUDIO_RAW" "$AUDIO_16K"
