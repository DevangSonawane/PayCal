"""Voiceover for the promo, generated locally with Kokoro (Apache-2.0).

usage: python make_vo.py <model.onnx> <voices.bin> <out_dir> [voice]
Each line is placed at its scene start; a line that would overrun its slot is sped up to fit.
"""
import sys
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

SR_OUT = 48000
DUR = 28.0

# (start, must end by, text). "Tab" is how Tabbb is said.
LINES = [
    (0.45, 3.15, "Splitting bills with friends? Meet Tab."),
    (3.65, 6.95, "Your crew, one tab. Every shared rupee, in one place."),
    (7.45, 11.3, "Add an expense once, and Tab splits it for everyone."),
    (11.85, 15.3, "Your flat, your trip, your squad. Each gets its own tab."),
    (15.85, 19.5, "When it's time, settle up in the fewest moves."),
    (20.0, 23.3, "And everyone stays in the loop. No more, who paid?"),
    (23.9, 27.6, "Tab. Split bills, keep friendships. Get it on Google Play."),
]


def main(model, voices, out_dir, voice='af_heart'):
    k = Kokoro(model, voices)
    track = np.zeros(int(SR_OUT * DUR), dtype=np.float32)
    for start, end, text in LINES:
        speed = 1.0
        while True:
            audio, sr = k.create(text, voice=voice, speed=speed, lang='en-us')
            # trim leading/trailing silence
            nz = np.flatnonzero(np.abs(audio) > 0.01)
            audio = audio[max(0, nz[0] - 200): nz[-1] + 1200]
            length = len(audio) / sr
            if start + length <= end or speed >= 1.3:
                break
            speed = round(speed + 0.05, 2)
        # resample to 48 kHz
        x = np.linspace(0, len(audio) - 1, int(len(audio) * SR_OUT / sr))
        audio = np.interp(x, np.arange(len(audio)), audio).astype(np.float32)
        i = int(start * SR_OUT)
        track[i:i + len(audio)] += audio[: len(track) - i]
        print(f'{start:5.2f}-{start + len(audio) / SR_OUT:5.2f} (slot {end})  speed {speed}  {text}')
    track = track / np.abs(track).max() * 0.89
    sf.write(f'{out_dir}/vo.wav', track, SR_OUT)


if __name__ == '__main__':
    main(*sys.argv[1:])
