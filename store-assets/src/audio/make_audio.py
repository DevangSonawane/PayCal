"""Synthesises the promo's soft background music and sound effects (no samples, nothing to license).

usage: python make_audio.py <out_dir>
writes music.wav and sfx.wav (48 kHz stereo, 28 s), cue times match video.html.
"""
import sys
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 48000
DUR = 28.0
N = int(SR * DUR)
rng = np.random.default_rng(7)


def t_(d):
    return np.arange(int(SR * d)) / SR


def lp(x, f, order=2):
    return sosfilt(butter(order, f, 'low', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


def add(buf, sig, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    sig = sig[: max(0, len(buf) - i)]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    buf[i:i + len(sig), 0] += sig * gain * l * 1.414
    buf[i:i + len(sig), 1] += sig * gain * r * 1.414


def env(n, a, d):
    """attack/exponential-decay envelope, a and d in seconds"""
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


# ---------------------------------------------------------------- music
def music():
    bpm = 92
    beat = 60 / bpm
    bar = beat * 4
    out = np.zeros((N, 2))
    # Fmaj9 - Em7 - Dm9 - Cmaj7(add9), warm and unresolved
    prog = [[53, 57, 60, 64, 67], [52, 55, 59, 62, 66], [50, 53, 57, 60, 64], [48, 52, 55, 59, 62]]
    bass = [41, 40, 38, 36]
    n_bars = int(np.ceil(DUR / bar)) + 1
    for b in range(n_bars):
        ch = prog[b % 4]
        start = b * bar
        # pad: detuned saws, low-passed, slow swell
        d = bar + 0.6
        t = t_(d)
        pad = np.zeros_like(t)
        for m in ch:
            for det in (-0.08, 0.08):
                f = hz(m + det)
                pad += 2 * ((t * f) % 1) - 1
        pad = lp(pad / len(ch), 900, 2)
        a = np.minimum(1, t / 0.5) * np.minimum(1, (d - t) / 0.6)
        add(out, pad * a, start, 0.055, -0.2)
        add(out, np.roll(pad, 300) * a, start, 0.055, 0.2)
        # soft sub bass on beats 1 and 3
        for k in (0, 2):
            tb = t_(beat * 1.8)
            s = np.sin(2 * np.pi * hz(bass[b % 4]) * tb) * env(len(tb), 0.01, 0.6)
            add(out, s, start + k * beat, 0.16)
        # plucked bell arpeggio (eighth notes)
        for k in range(8):
            if (b + k) % 3 == 2:
                continue
            m = ch[[0, 2, 4, 3, 1, 3, 2, 4][k]] + 12
            tp = t_(0.9)
            f = hz(m)
            s = (np.sin(2 * np.pi * f * tp) + 0.3 * np.sin(2 * np.pi * 2 * f * tp)) * env(len(tp), 0.004, 0.25)
            add(out, s, start + k * beat / 2, 0.045, [-0.5, 0.5][k % 2])
        # gentle kick + shaker groove
        for k in range(4):
            if k in (0, 2):
                tk = t_(0.35)
                f = 50 + 70 * np.exp(-tk * 30)
                kick = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tk), 0.002, 0.12)
                add(out, kick, start + k * beat, 0.22)
            if k in (1, 3):
                ts = t_(0.25)
                snare = bp(rng.standard_normal(len(ts)), 1500, 6000) * env(len(ts), 0.002, 0.06)
                add(out, snare, start + k * beat, 0.06)
            for h in range(2):
                th = t_(0.08)
                sh = hp(rng.standard_normal(len(th)), 7000) * env(len(th), 0.003, 0.02)
                add(out, sh, start + k * beat + h * beat / 2, 0.035 if h else 0.02, 0.4)
    # fade in, final ring-out
    t = np.arange(N) / SR
    fade = np.minimum(1, t / 1.2) * np.clip((DUR - t) / 2.5, 0, 1)
    out *= fade[:, None]
    return out


# ---------------------------------------------------------------- sfx
def whoosh(d=0.55):
    t = t_(d)
    n = rng.standard_normal(len(t))
    f = 400 + 3600 * np.sin(np.pi * t / d)
    out = np.zeros_like(n)
    # crude time-varying band-pass: crossfade three fixed bands
    for lo, hi, c in ((300, 1200, 0.2), (1000, 3500, 0.5), (3000, 8000, 0.8)):
        w = np.exp(-((t / d - c) ** 2) / 0.04)
        out += bp(n, lo, hi) * w
    return out * np.sin(np.pi * t / d) ** 2 * (f > 0)


def pop(f0=600, f1=1100, d=0.12):
    t = t_(d)
    f = f0 + (f1 - f0) * (1 - np.exp(-t * 40))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.002, d / 3)


def tick(f=2400):
    t = t_(0.04)
    return np.sin(2 * np.pi * f * t) * env(len(t), 0.0005, 0.008)


def click(f=1800):
    t = t_(0.08)
    return (np.sin(2 * np.pi * f * t) + 0.5 * bp(rng.standard_normal(len(t)), 2000, 6000)) * env(len(t), 0.001, 0.018)


def chime(notes=(84, 88, 91), gap=0.07, d=1.2):
    t = t_(d + gap * len(notes))
    out = np.zeros_like(t)
    for i, m in enumerate(notes):
        tt = t_(d)
        f = hz(m)
        s = (np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(2 * np.pi * 3 * f * tt)) * env(len(tt), 0.003, 0.35)
        j = int(i * gap * SR)
        out[j:j + len(s)] += s
    return out


def thud():
    t = t_(0.3)
    f = 90 * np.exp(-t * 8) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.002, 0.08) + 0.3 * lp(rng.standard_normal(len(t)), 800) * env(len(t), 0.001, 0.03)


def zip_(d=0.45):
    t = t_(d)
    n = bp(rng.standard_normal(len(t)), 2500, 7000)
    gr = (np.sin(2 * np.pi * (30 + 60 * t / d) * t) > 0.6).astype(float)
    return n * lp(gr, 200) * np.sin(np.pi * t / d)


def coin():
    t = t_(0.7)
    a = np.sin(2 * np.pi * hz(88) * t) * env(len(t), 0.002, 0.08)
    b = np.sin(2 * np.pi * hz(95) * t) * env(len(t), 0.002, 0.4)
    b[: int(0.08 * SR)] = 0
    return a + b


def sfx():
    out = np.zeros((N, 2))
    # scene transitions (circular wipes)
    for at in (3.2, 7.0, 11.4, 15.4, 19.6, 23.4):
        add(out, whoosh(), at - 0.12, 0.28, 0.3)
    # intro: logo pop + tagline chime
    add(out, pop(300, 900, 0.18), 0.25, 0.5)
    add(out, chime((79, 84, 88)), 0.85, 0.16)
    # home: balance count-up ticks, avatars pop, graffiti stamp, reminder slide
    for k in range(14):
        add(out, tick(2200 + 40 * k), 3.8 + k * 0.085, 0.10)
    for i in range(4):
        add(out, pop(500 + 80 * i, 900 + 80 * i), 4.45 + i * 0.12, 0.22, -0.3 + 0.2 * i)
    add(out, thud(), 5.15, 0.5)
    add(out, whoosh(0.3), 5.5, 0.10)
    # add expense: sheet slides up, amount ticks, people get checked, sticker pops
    add(out, whoosh(0.4), 7.45, 0.16, 0.4)
    for k in range(9):
        add(out, tick(2000 + 60 * k), 8.0 + k * 0.09, 0.09)
    for i in range(4):
        add(out, click(1500 + 150 * i), 8.95 + i * 0.25, 0.32, 0.3)
    add(out, pop(700, 1300, 0.15), 9.75, 0.35)
    # cribs: stats pop, cards swipe in, sticker
    add(out, pop(450, 800), 11.85, 0.2)
    add(out, pop(500, 900), 11.95, 0.2)
    for i in range(3):
        add(out, whoosh(0.28), 12.0 + i * 0.2, 0.14, 0.5)
    add(out, pop(700, 1300, 0.15), 14.15, 0.35)
    # settle: sheet up, transfer arrows zip, avatars land, button press + success
    add(out, whoosh(0.4), 16.05, 0.16, 0.4)
    for i in range(2):
        add(out, zip_(), 16.8 + i * 0.4, 0.18, 0.2)
        add(out, pop(600, 1000), 17.3 + i * 0.4, 0.22, 0.4)
    add(out, click(1200), 18.45, 0.4)
    add(out, coin(), 18.65, 0.22)
    # activity: banner, feed items drop in, sticker
    add(out, pop(400, 700, 0.15), 19.95, 0.22)
    for i in range(5):
        add(out, pop(800 + 60 * i, 1100 + 60 * i, 0.08), 20.3 + i * 0.22, 0.16, -0.4 + 0.2 * i)
    add(out, pop(700, 1300, 0.15), 22.4, 0.35)
    # end card: logo pop, tagline, play button sparkle
    add(out, pop(300, 900, 0.18), 23.65, 0.5)
    add(out, chime((79, 84, 88, 91)), 24.2, 0.15)
    add(out, pop(600, 1200, 0.15), 25.0, 0.32)
    add(out, chime((91, 96), 0.09, 1.8), 25.1, 0.12)
    return out


if __name__ == '__main__':
    d = sys.argv[1]
    for name, sig in (('music', music()), ('sfx', sfx())):
        sig = sig / max(1e-9, np.abs(sig).max()) * 0.89
        sf.write(f'{d}/{name}.wav', sig.astype(np.float32), SR)
        print(name, 'ok')
