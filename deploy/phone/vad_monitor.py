#!/usr/bin/env python3
"""Silero VAD monitor for the OpenWiki/AESOP voice pipeline.

Watches an audio file being written by termux-microphone-record,
periodically decodes and runs Silero VAD to detect speech boundaries.

Modes:
  tail  — detect end-of-speech (silence after speech). Auto-stop recording.
  onset — detect speech onset. Interrupt TTS playback.

Outputs a single JSON line to stdout on detection, then exits.

Requirements (install in Debian proot):
  pip install onnxruntime numpy
  apt install ffmpeg
  Model: ~/models/silero_vad.onnx
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import wave

import numpy as np
import onnxruntime as ort

SAMPLE_RATE = 16000
CHUNK_SIZE = 512  # Silero VAD requires 512 samples (32ms) at 16kHz

SPEECH_THRESHOLD = 0.5
SILENCE_DURATION_S = 1.5
MIN_SPEECH_DURATION_S = 0.3
ONSET_DURATION_S = 0.15
POLL_INTERVAL_S = 0.7
MAX_DURATION_S = 60


class SileroVAD:
    def __init__(self, model_path):
        opts = ort.SessionOptions()
        opts.inter_op_num_threads = 1
        opts.intra_op_num_threads = 1
        self.session = ort.InferenceSession(model_path, opts)
        self._h = np.zeros((2, 1, 64), dtype=np.float32)
        self._c = np.zeros((2, 1, 64), dtype=np.float32)
        self._sr = np.array([SAMPLE_RATE], dtype=np.int64)

    def __call__(self, chunk):
        inp = chunk.astype(np.float32).reshape(1, -1)
        out, self._h, self._c = self.session.run(
            None, {"input": inp, "h": self._h, "c": self._c, "sr": self._sr}
        )
        return float(out[0][0])


def decode_to_pcm(src, dst):
    r = subprocess.run(
        ["ffmpeg", "-y", "-i", src, "-ar", str(SAMPLE_RATE),
         "-ac", "1", "-acodec", "pcm_s16le", dst],
        capture_output=True, timeout=15,
    )
    return r.returncode == 0


def read_pcm_samples(wav_path):
    with wave.open(wav_path, "rb") as wf:
        raw = wf.readframes(wf.getnframes())
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def tail_mode(audio_path, vad):
    """Block until end-of-speech detected in a growing audio file."""
    processed_chunks = 0
    speech_seen = False
    silent_chunks = 0
    silence_needed = int(SILENCE_DURATION_S * SAMPLE_RATE / CHUNK_SIZE)
    min_speech_chunks = int(MIN_SPEECH_DURATION_S * SAMPLE_RATE / CHUNK_SIZE)
    speech_chunk_count = 0
    last_file_size = 0
    t0 = time.monotonic()
    snap = tempfile.mktemp(suffix=".amr")
    pcm = tempfile.mktemp(suffix=".wav")

    try:
        while time.monotonic() - t0 < MAX_DURATION_S:
            if not os.path.exists(audio_path):
                time.sleep(POLL_INTERVAL_S)
                continue

            sz = os.path.getsize(audio_path)
            if sz <= last_file_size + 500:
                time.sleep(POLL_INTERVAL_S)
                continue
            last_file_size = sz

            shutil.copy2(audio_path, snap)
            if not decode_to_pcm(snap, pcm):
                time.sleep(POLL_INTERVAL_S)
                continue

            audio = read_pcm_samples(pcm)
            total_chunks = len(audio) // CHUNK_SIZE

            for i in range(processed_chunks, total_chunks):
                chunk = audio[i * CHUNK_SIZE : (i + 1) * CHUNK_SIZE]
                prob = vad(chunk)

                if prob >= SPEECH_THRESHOLD:
                    speech_seen = True
                    speech_chunk_count += 1
                    silent_chunks = 0
                elif speech_seen and speech_chunk_count >= min_speech_chunks:
                    silent_chunks += 1
                    if silent_chunks >= silence_needed:
                        elapsed = time.monotonic() - t0
                        print(json.dumps({"event": "speech_end", "elapsed": round(elapsed, 2)}))
                        sys.stdout.flush()
                        return

            processed_chunks = total_chunks
            time.sleep(POLL_INTERVAL_S)

        print(json.dumps({"event": "timeout", "elapsed": MAX_DURATION_S}))
        sys.stdout.flush()
    finally:
        for f in (snap, pcm):
            try:
                os.unlink(f)
            except OSError:
                pass


def onset_mode(audio_path, vad):
    """Block until speech onset detected in a growing audio file."""
    onset_needed = int(ONSET_DURATION_S * SAMPLE_RATE / CHUNK_SIZE)
    processed_chunks = 0
    speech_run = 0
    last_file_size = 0
    t0 = time.monotonic()
    snap = tempfile.mktemp(suffix=".amr")
    pcm = tempfile.mktemp(suffix=".wav")

    try:
        while time.monotonic() - t0 < MAX_DURATION_S:
            if not os.path.exists(audio_path):
                time.sleep(0.3)
                continue

            sz = os.path.getsize(audio_path)
            if sz <= last_file_size + 300:
                time.sleep(0.3)
                continue
            last_file_size = sz

            shutil.copy2(audio_path, snap)
            if not decode_to_pcm(snap, pcm):
                time.sleep(0.3)
                continue

            audio = read_pcm_samples(pcm)
            total_chunks = len(audio) // CHUNK_SIZE

            for i in range(processed_chunks, total_chunks):
                chunk = audio[i * CHUNK_SIZE : (i + 1) * CHUNK_SIZE]
                prob = vad(chunk)

                if prob >= SPEECH_THRESHOLD:
                    speech_run += 1
                    if speech_run >= onset_needed:
                        elapsed = time.monotonic() - t0
                        print(json.dumps({"event": "speech_start", "elapsed": round(elapsed, 2)}))
                        sys.stdout.flush()
                        return
                else:
                    speech_run = 0

            processed_chunks = total_chunks
            time.sleep(0.3)
    finally:
        for f in (snap, pcm):
            try:
                os.unlink(f)
            except OSError:
                pass


def main():
    ap = argparse.ArgumentParser(description="Silero VAD monitor")
    ap.add_argument("mode", choices=["tail", "onset"])
    ap.add_argument("audio_path", help="Audio file being written by termux-microphone-record")
    ap.add_argument("--model", default=os.path.expanduser("~/models/silero_vad.onnx"))
    args = ap.parse_args()

    if not os.path.exists(args.model):
        print(json.dumps({"error": f"VAD model not found: {args.model}"}), file=sys.stderr)
        sys.exit(1)

    vad = SileroVAD(args.model)

    if args.mode == "tail":
        tail_mode(args.audio_path, vad)
    else:
        onset_mode(args.audio_path, vad)


if __name__ == "__main__":
    main()
