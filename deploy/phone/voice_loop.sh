#!/data/data/com.termux/files/usr/bin/bash
# AESOP voice loop — speak → STT → LLM → TTS → hear response.
# Run from NATIVE Termux.
set -euo pipefail

AUDIO_RAW="$HOME/.stt_raw.wav"
AUDIO_16K="$HOME/.stt_16k.wav"
TTS_OUT="$HOME/.tts_out.wav"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STT_PY="$SCRIPT_DIR/stt_process.py"

# OpenRouter config
API_URL="https://openrouter.ai/api/v1/chat/completions"
MODEL="${AESOP_MODEL:-z-ai/glm-5.2}"
SYSTEM_PROMPT="You are a helpful voice assistant. Keep responses concise — under 2 sentences. No markdown, no lists, no formatting. Speak naturally."

if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "Set OPENROUTER_API_KEY first"
  exit 1
fi

echo "=== AESOP Voice Loop ==="
echo "Model: $MODEL"
echo ""

while true; do
  # --- 1. Record ---
  rm -f "$AUDIO_RAW" "$AUDIO_16K" "$TTS_OUT"
  termux-toast "Listening..."
  termux-vibrate -d 100
  termux-microphone-record -f "$AUDIO_RAW" -e amr_wb -r 16000 -c 1
  read -r -p ">>> Listening. Press ENTER when done (or 'q' to quit). "
  termux-microphone-record -q 2>/dev/null || true
  sleep 0.3

  [ "$REPLY" = "q" ] && echo "Bye." && break

  # --- 2. STT ---
  ffmpeg -y -i "$AUDIO_RAW" -ar 16000 -ac 1 -acodec pcm_s16le "$AUDIO_16K" 2>/dev/null
  termux-toast "Transcribing..."
  USER_TEXT=$(proot-distro login debian --bind "$HOME:$HOME" -- \
    python3 "$STT_PY" "$AUDIO_16K" 2>/dev/null)

  if [ -z "$USER_TEXT" ]; then
    echo "(no speech detected)"
    continue
  fi
  echo "You: $USER_TEXT"

  # --- 3. LLM ---
  termux-toast "Thinking..."
  PAYLOAD=$(printf '{"model":"%s","messages":[{"role":"system","content":"%s"},{"role":"user","content":"%s"}],"max_tokens":200}' \
    "$MODEL" "$SYSTEM_PROMPT" "$(echo "$USER_TEXT" | sed 's/"/\\"/g')")

  RESPONSE=$(curl -s "$API_URL" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  REPLY_TEXT=$(echo "$RESPONSE" | python3 -c "import sys,json;print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null)

  if [ -z "$REPLY_TEXT" ]; then
    echo "LLM error: $RESPONSE"
    continue
  fi
  echo "AI: $REPLY_TEXT"

  # --- 4. TTS ---
  termux-toast "Speaking..."
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
a=tts.generate(sys.argv[1],sid=0,speed=1.0)
with wave.open(sys.argv[2],'w') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(a.sample_rate)
  s=[int(max(-1,min(1,x))*32767) for x in a.samples]
  f.writeframes(struct.pack(f'<{len(s)}h',*s))
" "$REPLY_TEXT" "$TTS_OUT"

  termux-media-player play "$TTS_OUT" 2>/dev/null || play-audio "$TTS_OUT" 2>/dev/null || true

  echo ""
done

rm -f "$AUDIO_RAW" "$AUDIO_16K" "$TTS_OUT"
