"""VAD + STT processor using sherpa-onnx (Silero VAD + Moonshine).

Runs inside the Debian proot where sherpa-onnx is installed.
Reads a 16kHz mono WAV, detects speech segments, transcribes them.
Prints transcription to stdout (one line per segment).
"""
import sys
import os
import wave
import numpy as np
import sherpa_onnx

SAMPLE_RATE = 16000


def find_file(name, candidates):
    for d in candidates:
        p = os.path.join(os.path.expanduser(d), name)
        if os.path.isfile(p):
            return p
    return None


def find_dir(name, candidates):
    for d in candidates:
        p = os.path.join(os.path.expanduser(d), name)
        if os.path.isdir(p):
            return p
    return None


SEARCH_PATHS = [
    "~/models",
    "~/sherpa-onnx-moonshine-base-en-int8",
    "~/storage/shared",
    "~/storage",
    "/sdcard",
    ".",
]

VAD_MODEL = find_file("silero_vad.onnx", SEARCH_PATHS)
MOON_DIR = find_dir("sherpa-onnx-moonshine-base-en-int8", SEARCH_PATHS)

if not VAD_MODEL:
    VAD_MODEL = os.path.expanduser("~/models/silero_vad.onnx")
if not MOON_DIR:
    MOON_DIR = os.path.expanduser("~/models/sherpa-onnx-moonshine-base-en-int8")


def create_vad():
    config = sherpa_onnx.VadModelConfig()
    config.silero_vad.model = VAD_MODEL
    config.silero_vad.min_silence_duration = 0.3
    config.silero_vad.min_speech_duration = 0.15
    config.silero_vad.threshold = 0.4
    config.sample_rate = SAMPLE_RATE
    return sherpa_onnx.VoiceActivityDetector(config, buffer_size_in_seconds=60)


def create_recognizer():
    return sherpa_onnx.OfflineRecognizer.from_moonshine(
        preprocessor=os.path.join(MOON_DIR, "preprocess.onnx"),
        encoder=os.path.join(MOON_DIR, "encode.int8.onnx"),
        uncached_decoder=os.path.join(MOON_DIR, "uncached_decode.int8.onnx"),
        cached_decoder=os.path.join(MOON_DIR, "cached_decode.int8.onnx"),
        tokens=os.path.join(MOON_DIR, "tokens.txt"),
    )


def read_wav(path):
    with wave.open(path) as f:
        assert f.getframerate() == SAMPLE_RATE, (
            f"Expected {SAMPLE_RATE}Hz, got {f.getframerate()}Hz"
        )
        assert f.getnchannels() == 1, f"Expected mono, got {f.getnchannels()} channels"
        frames = f.readframes(f.getnframes())
    samples = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
    return samples


def transcribe(wav_path):
    vad = create_vad()
    recognizer = create_recognizer()
    samples = read_wav(wav_path)

    window = 512
    for i in range(0, len(samples), window):
        chunk = samples[i : i + window]
        if len(chunk) < window:
            chunk = np.pad(chunk, (0, window - len(chunk)))
        vad.accept_waveform(chunk)

    found = False
    while not vad.empty():
        seg = vad.front
        stream = recognizer.create_stream()
        stream.accept_waveform(SAMPLE_RATE, seg.samples)
        recognizer.decode_stream(stream)
        text = stream.result.text.strip()
        if text:
            print(text)
            found = True
        vad.pop()

    if not found:
        # No speech segments detected by VAD — try the whole file directly
        stream = recognizer.create_stream()
        stream.accept_waveform(SAMPLE_RATE, samples.tolist())
        recognizer.decode_stream(stream)
        text = stream.result.text.strip()
        if text:
            print(text)
            found = True

    if not found:
        print("(no speech detected)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <input.wav>", file=sys.stderr)
        sys.exit(2)
    sys.exit(transcribe(sys.argv[1]))
