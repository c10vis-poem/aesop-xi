#!/data/data/com.termux/files/usr/bin/bash
# AESOP STT — record from mic, transcribe with Moonshine.
# Run from NATIVE Termux. Calls proot internally for sherpa-onnx.
#
# Usage:
#   ./record_transcribe.sh        # press ENTER to stop recording
#   ./record_transcribe.sh 10     # fixed 10-second recording
set -euo pipefail

AUDIO_RAW="$HOME/.stt_raw.wav"
AUDIO_16K="$HOME/.stt_16k.wav"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STT_PY="$SCRIPT_DIR/stt_process.py"

# --- Clean stale files ---
rm -f "$AUDIO_RAW" "$AUDIO_16K"

# --- Record ---
if [ -n "${1:-}" ]; then
  # Fixed duration mode
  termux-toast "Speak now (${1}s)"
  termux-vibrate -d 100
  termux-microphone-record -f "$AUDIO_RAW" -l "$1" -e amr_wb -r 16000 -c 1
  sleep "$1"
  termux-microphone-record -q 2>/dev/null || true
else
  # Open-ended mode — record until ENTER
  termux-toast "Recording... press ENTER to stop"
  termux-vibrate -d 100
  termux-microphone-record -f "$AUDIO_RAW" -e amr_wb -r 16000 -c 1
  read -r -p ">>> Recording. Press ENTER when done. "
  termux-microphone-record -q
fi
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
