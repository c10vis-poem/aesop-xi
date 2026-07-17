#!/data/data/com.termux/files/usr/bin/bash
# AESOP voice — speak → STT → OpenWiki → TTS → hear response.
# Run from NATIVE Termux, inside a repo directory.
set -euo pipefail

AUDIO_RAW="$HOME/.stt_raw.wav"
AUDIO_16K="$HOME/.stt_16k.wav"
TTS_OUT="$HOME/.tts_out.wav"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STT_PY="$SCRIPT_DIR/stt_process.py"

echo "=== AESOP Voice ==="
echo ""

while true; do
  rm -f "$AUDIO_RAW" "$AUDIO_16K" "$TTS_OUT"

  # --- 1. Record ---
  termux-vibrate -d 100
  termux-microphone-record -f "$AUDIO_RAW" -e amr_wb -r 16000 -c 1
  read -r -p ">>> Listening. ENTER to send, q to quit. "
  termux-microphone-record -q 2>/dev/null || true
  sleep 0.3

  [ "$REPLY" = "q" ] && break

  # --- 2. STT ---
  ffmpeg -y -i "$AUDIO_RAW" -ar 16000 -ac 1 -acodec pcm_s16le "$AUDIO_16K" 2>/dev/null
  USER_TEXT=$(proot-distro login debian --bind "$HOME:$HOME" -- \
    python3 "$STT_PY" "$AUDIO_16K" 2>/dev/null)

  if [ -z "$USER_TEXT" ]; then
    echo "(no speech detected)"
    continue
  fi
  echo "You: $USER_TEXT"
  echo ""

  # --- 3. OpenWiki ---
  RESPONSE=$(openwiki -p "$USER_TEXT" 2>/dev/null)
  echo "$RESPONSE"
  echo ""

  # --- 4. TTS ---
  proot-distro login debian --bind "$HOME:$HOME" -- python3 -c "
import sherpa_onnx,wave,struct,sys
D='/root/models/kokoro-multi-lang-v1.0'
c=sherpa_onnx.OfflineTtsConfig(
  model=sherpa_onnx.OfflineTtsModelConfig(
    kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
      model=D+'/model.onnx',voices=D+'/voices.bin',
      tokens=D+'/tokens.txt',data_dir=D+'/espeak-ng-data',
      dict_dir=D+'/dict',lexicon=D+'/lexicon-us-en.txt',lang='en-us',
    ),num_threads=2,
  ),
)
tts=sherpa_onnx.OfflineTts(c)
text=sys.argv[1][:500]
a=tts.generate(text,sid=0,speed=1.0)
with wave.open(sys.argv[2],'w') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(a.sample_rate)
  s=[int(max(-1,min(1,x))*32767) for x in a.samples]
  f.writeframes(struct.pack(f'<{len(s)}h',*s))
" "$RESPONSE" "$TTS_OUT" 2>/dev/null

  termux-media-player play "$TTS_OUT" 2>/dev/null || true
  echo ""
done

rm -f "$AUDIO_RAW" "$AUDIO_16K" "$TTS_OUT"
