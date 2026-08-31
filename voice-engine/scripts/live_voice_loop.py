#!/usr/bin/env python3
"""
AESOP Voice Engine — Live Voice Loop (mic -> VAD -> STT -> TTS -> speaker)

Real-time voice interaction. Listens on the mic, detects speech (VAD),
transcribes (Moonshine STT), synthesizes a reply (Kokoro TTS), and plays
it back through the speaker — all in one continuous loop.

Must run inside the Debian proot with PulseAudio bridged from Termux.
Use run_live.sh to launch with the correct bind mounts.

Usage (from Termux):
    bash ~/repos/aesop/voice-engine/scripts/run_live.sh
    bash ~/repos/aesop/voice-engine/scripts/run_live.sh --voice af_heart
    bash ~/repos/aesop/voice-engine/scripts/run_live.sh --speed 1.1

Usage (inside proot, if PulseAudio is already set up):
    python3 live_voice_loop.py
    python3 live_voice_loop.py --demo

Environment:
    AESOP_MODELS_DIR  — path to models (default: ~/models)
    PULSE_SERVER       — PulseAudio socket (set by run_live.sh)
"""

import argparse
import collections
import os
import sys
import threading
import time

import numpy as np
import sounddevice as sd
import sherpa_onnx

# ─── Audio constants ────────────────────────────────────────────────────────────

SAMPLE_RATE = 16000
VAD_WINDOW = 512  # Silero VAD requires 512-sample windows
CHANNELS = 1
DTYPE = "float32"


# ─── Model factories ───────────────────────────────────────────────────────────

def create_vad(models_dir):
    silero_path = os.path.join(models_dir, "silero-vad", "silero_vad.onnx")
    config = sherpa_onnx.VadModelConfig()
    config.silero_vad.model = silero_path
    config.silero_vad.threshold = 0.5
    config.silero_vad.min_silence_duration = 500
    config.silero_vad.max_speech_duration = 30.0
    config.sample_rate = SAMPLE_RATE
    return sherpa_onnx.VoiceActivityDetector(config)


def create_stt(models_dir, num_threads=2):
    moon_dir = os.path.join(models_dir, "moonshine-base-en-int8")
    return sherpa_onnx.OfflineRecognizer.from_moonshine(
        preprocessor=os.path.join(moon_dir, "preprocess.onnx"),
        encoder=os.path.join(moon_dir, "encode.int8.onnx"),
        uncached_decoder=os.path.join(moon_dir, "uncached_decode.int8.onnx"),
        cached_decoder=os.path.join(moon_dir, "cached_decode.int8.onnx"),
        tokens=os.path.join(moon_dir, "tokens.txt"),
        num_threads=num_threads,
        decoding_method="greedy_search",
    )


def create_tts(models_dir, speed=1.0):
    kokoro_dir = os.path.join(models_dir, "kokoro-multi-lang-v1.0")
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                model=os.path.join(kokoro_dir, "model.onnx"),
                voices=os.path.join(kokoro_dir, "voices.bin"),
                tokens=os.path.join(kokoro_dir, "tokens.txt"),
                data_dir=os.path.join(kokoro_dir, "espeak-ng-data"),
                lexicon=os.path.join(kokoro_dir, "lexicon-us-en.txt"),
                length_scale=speed,
            ),
        ),
    )
    return sherpa_onnx.OfflineTts(config)


# ─── Speech helpers ────────────────────────────────────────────────────────────

def text_to_speech(tts, text, speed=1.0):
    """Generate speech, return (samples_float32, sample_rate)."""
    audio = tts.generate(text=text, sid=0, speed=speed)
    samples = np.array(audio.samples, dtype=np.float32)
    return samples, audio.sample_rate


def speech_to_text(stt, samples_float32):
    """Transcribe audio samples, return text string."""
    stream = stt.create_stream()
    stream.accept_waveform(SAMPLE_RATE, samples_float32.tolist())
    stt.decode_stream(stream)
    return stream.result.text.strip()


def play_audio(samples, sr):
    """Play audio samples through the speaker (blocking)."""
    sd.play(samples, samplerate=sr)
    sd.wait()


# ─── Live voice loop ───────────────────────────────────────────────────────────

class LiveVoiceLoop:
    """
    Continuously listens on the mic, detects speech via VAD, transcribes with
    STT, generates a TTS reply, and plays it back.

    The mic runs in a background thread via sd.InputStream. Audio chunks are
    pushed into a queue. The main loop pulls 512-sample windows from the queue,
    feeds them to VAD, and when VAD emits a complete speech segment, runs STT
    -> TTS -> playback.
    """

    def __init__(self, vad, stt, tts, speed=1.0):
        self.vad = vad
        self.stt = stt
        self.tts = tts
        self.speed = speed

        self.audio_queue = collections.deque()
        self.queue_lock = threading.Lock()
        self.running = False

    def _mic_callback(self, indata, frames, time_info, status):
        """Called by sounddevice on the audio thread - must be fast."""
        with self.queue_lock:
            self.audio_queue.extend(indata[:, 0].tolist())

    def _drain_queue(self, n):
        """Pull n samples from the queue. Returns numpy array or None."""
        with self.queue_lock:
            if len(self.audio_queue) < n:
                return None
            samples = []
            for _ in range(n):
                samples.append(self.audio_queue.popleft())
            return np.array(samples, dtype=np.float32)

    def run(self):
        self.running = True
        print("=== AESOP Live Voice Loop ===")
        print(f"  STT: Moonshine base-en-int8")
        print(f"  TTS: Kokoro v1.0, speed={self.speed}")
        print(f"  VAD: Silero v5")
        print(f"  Audio: {SAMPLE_RATE}Hz mono, PulseAudio bridge")
        print()
        print("Listening... (speak into the mic)")
        print("Press Ctrl+C to stop.")
        print()

        with sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype=DTYPE,
            blocksize=VAD_WINDOW,
            callback=self._mic_callback,
        ):
            try:
                self._process_loop()
            except KeyboardInterrupt:
                print("\nStopping...")

        print("Voice loop stopped.")

    def _process_loop(self):
        """Main loop: read audio -> VAD -> STT -> TTS -> speaker."""
        while self.running:
            window = self._drain_queue(VAD_WINDOW)
            if window is None:
                time.sleep(0.01)
                continue

            self.vad.accept_waveform(window.tolist())

            while not self.vad.empty():
                segment = self.vad.front
                self.vad.pop()

                seg_samples = np.array(segment.samples, dtype=np.float32)
                start_s = segment.start / SAMPLE_RATE
                end_s = (segment.start + len(segment.samples)) / SAMPLE_RATE
                duration = end_s - start_s

                print(f"\n[VAD] Speech: {start_s:.2f}s - {end_s:.2f}s "
                      f"({duration:.2f}s)")

                if duration < 0.2:
                    print("[VAD] Too short, skipping.")
                    continue

                print("[STT] Transcribing...")
                t0 = time.time()
                text = speech_to_text(self.stt, seg_samples)
                t1 = time.time()
                print(f"[STT] ({t1-t0:.2f}s): \"{text}\"")

                if not text:
                    print("[STT] No speech recognized, continuing...")
                    continue

                response = f"You said: {text}"

                print(f"[TTS] \"{response}\"")
                t0 = time.time()
                tts_samples, tts_sr = text_to_speech(
                    self.tts, response, speed=self.speed)
                t1 = time.time()
                print(f"[TTS] {len(tts_samples)/tts_sr:.2f}s audio ({t1-t0:.2f}s)")

                print("[SPK] Playing...")
                play_audio(tts_samples, tts_sr)
                print("[SPK] Done. Listening again...")


# ─── Demo mode (no mic needed) ─────────────────────────────────────────────────

def run_demo(vad, stt, tts):
    """Self-test: TTS -> speaker -> STT round-trip."""
    print("=== AESOP Voice Engine - Demo Mode ===")
    print()

    test_text = "Hello, the voice engine is working."
    print(f"[TTS] Generating: \"{test_text}\"")
    tts_samples, tts_sr = text_to_speech(tts, test_text)
    print(f"[TTS] {len(tts_samples)/tts_sr:.2f}s audio at {tts_sr}Hz")

    print("[SPK] Playing through speaker...")
    play_audio(tts_samples, tts_sr)

    print("[STT] Transcribing the TTS output...")
    text = speech_to_text(stt, tts_samples)
    print(f"[STT] Result: \"{text}\"")

    print()
    print("Demo complete. All three layers (TTS, STT, playback) working.")
    print("Run without --demo for the live mic loop.")


# ─── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="AESOP Live Voice Loop (mic -> VAD -> STT -> TTS -> speaker)")
    parser.add_argument("--voice", "-v", default="af_heart",
                        help="Kokoro voice (default: af_heart)")
    parser.add_argument("--speed", "-s", type=float, default=1.0,
                        help="Speech speed (default: 1.0)")
    parser.add_argument("--models-dir",
                        default=os.environ.get("AESOP_MODELS_DIR",
                                               os.path.expanduser("~/models")),
                        help="Models directory (default: ~/models)")
    parser.add_argument("--demo", action="store_true",
                        help="Run self-test (TTS -> STT -> speaker, no mic)")
    args = parser.parse_args()

    models_dir = args.models_dir

    # Verify model paths
    for label, path in [
        ("Kokoro TTS", os.path.join(models_dir, "kokoro-multi-lang-v1.0", "model.onnx")),
        ("Moonshine STT", os.path.join(models_dir, "moonshine-base-en-int8", "encode.int8.onnx")),
        ("Silero VAD", os.path.join(models_dir, "silero-vad", "silero_vad.onnx")),
    ]:
        exists = "OK" if os.path.exists(path) else "MISSING"
        print(f"  [{exists}] {label}: {path}")

    if not os.path.exists(os.path.join(models_dir, "kokoro-multi-lang-v1.0", "model.onnx")):
        print("\nERROR: Models not found. Set AESOP_MODELS_DIR or use --models-dir.")
        sys.exit(1)

    print("\nLoading models...")
    vad = create_vad(models_dir)
    stt = create_stt(models_dir)
    tts = create_tts(models_dir, speed=args.speed)
    print("  All models loaded.")
    print()

    if args.demo:
        run_demo(vad, stt, tts)
    else:
        loop = LiveVoiceLoop(vad, stt, tts, speed=args.speed)
        loop.run()


if __name__ == "__main__":
    main()
