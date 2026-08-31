# Rubik Pi (Qualcomm Dragonwing) — T3 Audio/Desktop Node Setup

**Role in AESOP:** T3 Home Node — desktop OS + TTS endpoint (Kokoro/sherpa-onnx).
See `profiles/nav.yaml`.

This node provides:
- Desktop OS (Qualcomm Linux / Debian-based)
- TTS audio output via sherpa-onnx + Kokoro multi-lang v1.0
- Audio endpoint for the AESOP voice pipeline

## Prerequisites

- Jetson T3 hub is **already stable** (Postgres, OmniRoute, vault sync running)
- Tailscale is set up on the phone and Jetson
- Model files exist at `~/models/` on the phone (shared, ABI-agnostic):
  - `kokoro-multi-lang-v1.x/` — Kokoro TTS bundle (model.onnx, espeak-ng-data, lexicon, dict)
  - `moonshine-base-en-int8/` — Moonshine STT model
  - `silero-vad/` — Silero VAD v5 model

## Step 1: Flash the Rubik Pi

Follow Qualcomm's official flashing docs — do not guess the image name.

1. Download the Qualcomm Linux / Debian-based image from:
   - Thundercomm official portal (search "Rubik Pi flashing guide")
   - Qualcomm Developer Network
2. Use the official flashing host tool provided by Thundercomm/Qualcomm.
3. The exact image name and flashing procedure may change — **verify against
   the official source before flashing.** Report conflicts, don't improvise.

After first boot:
```bash
# Complete the OS setup wizard
# Connect to WiFi
# Open terminal
sudo apt update && sudo apt install -y curl git python3-pip
```

## Step 2: Join Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Note your 100.x.y.z tailnet IP
```

Enable MagicDNS in the Tailscale admin console if not already done.

## Step 3: Install sherpa-onnx

The Rubik Pi runs a Debian-based Linux on aarch64 with glibc — unlike Termux/bionic,
**prebuilt sherpa-onnx wheels should install directly**:

```bash
pip3 install sherpa-onnx --break-system-packages
```

Verify:
```bash
python3 -c "import sherpa_onnx; print(sherpa_onnx.__version__)"
```

If the wheel doesn't install (architecture mismatch), build from source:
```bash
sudo apt install -y cmake build-essential libsndfile1-dev
pip3 install --no-binary sherpa-onnx sherpa-onnx --break-system-packages
```

## Step 4: Set Up Shared Models

Model files are ABI-agnostic data — copy from the phone or download from HF mirrors:

```bash
mkdir -p ~/models

# Option A: Copy from phone over Tailscale (scp)
scp -r ubuntu@<phone-tailnet-ip>:~/models/kokoro-multi-lang-v1.x ~/models/
scp -r ubuntu@<phone-tailnet-ip>:~/models/moonshine-base-en-int8 ~/models/
scp -r ubuntu@<phone-tailnet-ip>:~/models/silero-vad ~/models/

# Option B: Download from HuggingFace
pip3 install huggingface_hub --break-system-packages
python3 -c "
from huggingface_hub import snapshot_download
snapshot_download('csukuangfj/kokoro-multi-lang-v1_0', local_dir='~/models/kokoro-multi-lang-v1.x')
snapshot_download('csukuangfj/sherpa-onnx-moonshine-base-en-int8', local_dir='~/models/moonshine-base-en-int8')
snapshot_download('R4kSo1997/sherpa-onnx-silero-vad-v5', local_dir='~/models/silero-vad')
"
```

## Step 5: TTS Endpoint Service

Clone the aesop repo and set up the voice engine as a systemd service:

```bash
git clone https://github.com/c10vis-poem/aesop ~/aesop

# Test TTS first
python3 ~/aesop/voice-engine/scripts/tts_test.py "Hello from Rubik Pi" --output /tmp/test.wav
aplay /tmp/test.wav  # or use the desktop audio player

# Install as systemd service (TTS HTTP endpoint)
sudo tee /etc/systemd/system/aesop-tts.service << 'SVC'
[Unit]
Description=AESOP TTS Endpoint (Kokoro/sherpa-onnx)
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/aesop/voice-engine/scripts
ExecStart=/usr/bin/python3 /home/ubuntu/aesop/voice-engine/scripts/live_voice_loop.py
Restart=on-failure
RestartSec=10
Environment=MODELS_DIR=/home/ubuntu/models
Environment=AESOP_VOICE_SID=af_heart

[Install]
WantedBy=multi-user.target
SVC

sudo systemctl daemon-reload
sudo systemctl enable aesop-tts
sudo systemctl start aesop-tts
sudo systemctl status aesop-tts
```

## Step 6: Verify from Phone

From the phone over Tailscale:
```bash
# TTS endpoint reachable?
curl http://rubik-pi:8080/health

# Generate speech?
curl -X POST http://rubik-pi:8080/tts \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello from AESOP","voice":"af_heart"}' \
  --output /tmp/test.wav
```

## Architecture Notes

- **Model files are shared, not duplicated.** The kokoro/moonshine/silero bundles
  are identical across phone (Termux proot), Rubik Pi, and any future node.
  Per RESUME.md: "ONE shared folder, ABI-agnostic per-ABI-runtime decision."
- **sherpa-onnx runtime is per-ABI.** The Rubik Pi (aarch64 glibc) uses a different
  binary than Termux (aarch64 bionic) — but the model data is the same.
- **Audio I/O:** The Rubik Pi has a desktop OS with native ALSA/PulseAudio.
  No PulseAudio bridge needed (unlike the Termux proot setup).
- **No Novus-Agenti dependency.** The voice engine runs standalone in userspace.
  Later integration with the Omni Claw app can use HTTP (like ort_engine pattern).

## Success Criteria

- [ ] Rubik Pi flashed with Qualcomm Linux, boots to desktop
- [ ] Tailscale connected, 100.x.y.z IP noted
- [ ] `sherpa-onnx` installs and imports successfully
- [ ] Models present at `~/models/` (kokoro, moonshine, silero)
- [ ] TTS test generates audio: `python3 tts_test.py "test" --output /tmp/test.wav`
- [ ] TTS service running: `systemctl status aesop-tts`
- [ ] Phone can reach TTS endpoint over Tailscale
