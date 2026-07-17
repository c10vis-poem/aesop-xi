"""TTS using sherpa-onnx + Kokoro model.

Runs inside the Debian proot where sherpa-onnx is installed.
Takes text as argument, writes WAV to stdout or a file.
"""
import sys
import os
import sherpa_onnx

KOKORO_DIR = None

def find_kokoro():
    candidates = [
        os.path.expanduser("~/models/kokoro-multi-lang-v1.0"),
        os.path.expanduser("~/models/kokoro-multi-lang-v1.x"),
        os.path.expanduser("~/storage/sherpa-kokoro/kokoro-multi-lang-v1.0"),
        os.path.expanduser("~/storage/sherpa-kokoro/kokoro-multi-lang-v1.x"),
        os.path.expanduser("~/storage/shared/sherpa-kokoro/kokoro-multi-lang-v1.0"),
        os.path.expanduser("~/storage/shared/sherpa-kokoro/kokoro-multi-lang-v1.x"),
    ]
    for d in candidates:
        if os.path.isfile(os.path.join(d, "model.onnx")):
            return d
    return None


def speak(text, output_path, speed=1.0, sid=0):
    kokoro = find_kokoro()
    if not kokoro:
        print("Kokoro model not found. Checked:", file=sys.stderr)
        for c in [
            "~/models/kokoro-multi-lang-v1.0",
            "~/models/kokoro-multi-lang-v1.x",
        ]:
            print(f"  {c}", file=sys.stderr)
        return 1

    voices_bin = os.path.join(kokoro, "voices.bin")
    data_dir = os.path.join(kokoro, "espeak-ng-data")
    tokens = os.path.join(kokoro, "tokens.txt")
    model = os.path.join(kokoro, "model.onnx")

    tts_config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                model=model,
                voices=voices_bin,
                tokens=tokens,
                data_dir=data_dir,
            ),
            num_threads=2,
        ),
        max_num_sentences=1,
    )
    tts = sherpa_onnx.OfflineTts(tts_config)
    audio = tts.generate(text, sid=sid, speed=speed)

    import wave
    with wave.open(output_path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(audio.sample_rate)
        import struct
        samples = [int(max(-1, min(1, s)) * 32767) for s in audio.samples]
        f.writeframes(struct.pack(f"<{len(samples)}h", *samples))

    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <output.wav> <text...>", file=sys.stderr)
        sys.exit(2)
    output = sys.argv[1]
    text = " ".join(sys.argv[2:])
    sys.exit(speak(text, output))
