#!/usr/bin/env python3
"""Moonshine STT via sherpa-onnx.

Reads an audio file (any format ffmpeg can decode), transcribes with
sherpa-onnx's Moonshine ASR, prints the transcription to stdout.

Requirements (install in Debian proot):
  pip install sherpa-onnx soundfile numpy
  apt install ffmpeg
  Model: ~/models/sherpa-onnx-moonshine-base-en-int8/
"""

import argparse
import os
import subprocess
import sys
import tempfile

import numpy as np


def ensure_16k_wav(src, dst):
    r = subprocess.run(
        ["ffmpeg", "-y", "-i", src, "-ar", "16000", "-ac", "1",
         "-acodec", "pcm_s16le", dst],
        capture_output=True, timeout=30,
    )
    if r.returncode != 0:
        print(f"ffmpeg failed: {r.stderr.decode()}", file=sys.stderr)
        sys.exit(1)


def transcribe(audio_path, model_dir):
    import wave

    import sherpa_onnx

    recognizer = sherpa_onnx.OfflineRecognizer.from_moonshine(
        preprocessor=os.path.join(model_dir, "preprocess.onnx"),
        encoder=os.path.join(model_dir, "encode.int8.onnx"),
        uncached_decoder=os.path.join(model_dir, "uncached_decode.int8.onnx"),
        cached_decoder=os.path.join(model_dir, "cached_decode.int8.onnx"),
        tokens=os.path.join(model_dir, "tokens.txt"),
        num_threads=4,
    )

    with wave.open(audio_path, "rb") as f:
        sr = f.getframerate()
        frames = f.readframes(f.getnframes())
    samples = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0

    stream = recognizer.create_stream()
    stream.accept_waveform(sr, samples)
    recognizer.decode_stream(stream)
    return stream.result.text.strip()


def main():
    ap = argparse.ArgumentParser(description="Moonshine STT")
    ap.add_argument("audio_path", help="Audio file to transcribe")
    ap.add_argument(
        "--model-dir",
        default=os.path.expanduser("~/models/sherpa-onnx-moonshine-base-en-int8"),
    )
    args = ap.parse_args()

    if not os.path.isdir(args.model_dir):
        print(f"STT model not found: {args.model_dir}", file=sys.stderr)
        sys.exit(1)

    wav = tempfile.mktemp(suffix=".wav")
    try:
        ensure_16k_wav(args.audio_path, wav)
        text = transcribe(wav, args.model_dir)
        if text:
            print(text)
    finally:
        try:
            os.unlink(wav)
        except OSError:
            pass


if __name__ == "__main__":
    main()
