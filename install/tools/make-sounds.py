#!/usr/bin/env python3
"""Builds the notification sounds in sounds/ (our own synthesis, free to use: CC0).

  python3 install/tools/make-sounds.py      needs numpy
"""
import os
import wave

import numpy as np

SR = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "sounds")


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.004, decay=0.5):
    x = np.arange(n) / SR
    a = np.clip(x / attack, 0, 1)
    a = a * a * (3 - 2 * a)                      # smooth attack, no click
    return a * np.exp(-x / decay)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bell(freq, dur, partials, decay, attack=0.003, detune=0.0):
    """partials: (ratio, gain, decay_factor)"""
    x = t(dur)
    s = np.zeros_like(x)
    for r, g, df in partials:
        f = freq * r
        if f > SR / 2.4:
            continue
        ph = 2 * np.pi * f * x
        tone = np.sin(ph)
        if detune:
            tone = 0.5 * (np.sin(ph * (1 + detune)) + np.sin(ph * (1 - detune)))
        s += g * tone * env(len(x), attack, decay * df)
    return s


def fade(sig, sec=0.06):
    n = min(len(sig), int(sec * SR))
    sig = sig.copy()
    sig[-n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))   # every note ends at zero: no clicks
    return sig


def place(buf, sig, at):
    sig = fade(sig)
    i = int(at * SR)
    buf[i:i + len(sig)] += sig[:max(0, len(buf) - i)]


def reverb(x, mix=0.18, size=1.0):
    """small, soft room (Schroeder: 4 combs + 2 allpasses)"""
    y = np.zeros(len(x) + SR)
    xx = np.concatenate([x, np.zeros(SR)])
    for d, g in ((0.0297, 0.77), (0.0371, 0.74), (0.0411, 0.72), (0.0437, 0.70)):
        n = int(d * SR * size)
        c = xx.copy()
        for i in range(n, len(c)):
            c[i] += g * c[i - n]
        y += c / 4
    for d, g in ((0.005, 0.7), (0.0017, 0.7)):
        n = int(d * SR)
        o = np.zeros_like(y)
        for i in range(len(y)):
            o[i] = -g * y[i] + (y[i - n] if i >= n else 0) + (g * o[i - n] if i >= n else 0)
        y = o
    y = lowpass(y, 5000)
    return xx * (1 - mix) + y * mix


def finish(name, x, peak=0.5):
    x = x - np.mean(x)
    # trim the tail when it is silent, fade the last 30 ms
    a = np.abs(x)
    last = np.nonzero(a > 1e-3 * a.max())[0][-1] + 1
    x = x[:last]
    f = min(len(x), int(0.03 * SR))
    x[-f:] *= np.linspace(1, 0, f)
    x = x / np.max(np.abs(x)) * peak
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("%-8s %.2fs" % (name, len(x) / SR))


GLASSP = [(1, 1.0, 1.0), (2.0, 0.22, 0.55), (3.01, 0.07, 0.35), (5.43, 0.035, 0.18)]


def glass():
    b = np.zeros(int(SR * 1.3))
    place(b, bell(1318.5, 1.1, GLASSP, 0.42), 0.0)          # E6
    place(b, bell(1975.5, 1.1, GLASSP, 0.50), 0.085)        # B6
    return reverb(lowpass(b, 7000), 0.22)


def droplet():
    def drop(f0, f1, dur):
        x = t(dur)
        f = f0 + (f1 - f0) * (1 - np.exp(-x / 0.018))      # bubble: pitch glides up
        ph = 2 * np.pi * np.cumsum(f) / SR
        return np.sin(ph) * env(len(x), 0.002, 0.055)
    b = np.zeros(int(SR * 0.6))
    place(b, drop(620, 1350, 0.35), 0.0)
    place(b, 0.6 * drop(900, 1900, 0.3), 0.11)
    return reverb(b, 0.25, 0.8)


def chime():
    b = np.zeros(int(SR * 1.4))
    p = [(1, 1.0, 1.0), (2, 0.18, 0.5), (3, 0.05, 0.3)]
    for i, f in enumerate((783.99, 987.77, 1174.66)):      # G5 B5 D6
        place(b, (0.85 + 0.1 * i) * bell(f, 1.2, p, 0.5, 0.006), 0.075 * i)
    return reverb(lowpass(b, 6000), 0.2)


def bubble():
    def pop(f0, f1, dur):
        x = t(dur)
        f = f1 + (f0 - f1) * np.exp(-x / 0.025)
        ph = 2 * np.pi * np.cumsum(f) / SR
        return (np.sin(ph) + 0.15 * np.sin(2 * ph)) * env(len(x), 0.0015, 0.045)
    b = np.zeros(int(SR * 0.5))
    place(b, pop(520, 900, 0.22), 0.0)
    place(b, 0.85 * pop(700, 1250, 0.22), 0.09)
    return reverb(lowpass(b, 5000), 0.15, 0.7)


def marimba():
    p = [(1, 1.0, 1.0), (3.93, 0.28, 0.16), (9.2, 0.05, 0.06)]
    b = np.zeros(int(SR * 1.0))
    place(b, bell(880.0, 0.8, p, 0.22, 0.002), 0.0)         # A5
    place(b, bell(1318.5, 0.8, p, 0.26, 0.002), 0.11)       # E6
    return reverb(lowpass(b, 6500), 0.18)


def aurora():
    b = np.zeros(int(SR * 2.0))
    p = [(1, 1.0, 1.0), (2, 0.12, 0.6), (3, 0.04, 0.4)]
    place(b, 0.7 * bell(587.33, 1.8, p, 0.75, 0.035, 0.0018), 0.0)   # D5
    place(b, 0.6 * bell(880.0, 1.8, p, 0.75, 0.035, 0.0018), 0.06)   # A5
    place(b, 0.45 * bell(1479.98, 1.6, p, 0.6, 0.03, 0.002), 0.16)   # F#6 shimmer
    return reverb(lowpass(b, 5500), 0.3, 1.3)


def ping():
    """crisp and modern: a bright glass tap with a soft high echo"""
    p = [(1, 1.0, 1.0), (2.76, 0.25, 0.35), (5.4, 0.08, 0.2)]
    b = np.zeros(int(SR * 1.2))
    place(b, bell(2093.0, 0.9, p, 0.28, 0.0008), 0.0)          # C7
    place(b, 0.45 * bell(2637.0, 0.9, p, 0.3, 0.0008), 0.12)   # E7
    return reverb(lowpass(b, 9000), 0.25, 0.9)


def ks(f, dur, damp=0.996, bright=0.6):
    """plucked string (Karplus-Strong)"""
    rng = np.random.default_rng(int(f))
    n = int(SR / f)
    buf = lowpass(rng.uniform(-1, 1, n), 1500 + 9000 * bright)
    out = np.zeros(int(SR * dur))
    for i in range(len(out)):
        j = i % n
        v = buf[j]
        out[i] = v
        buf[j] = damp * 0.5 * (v + buf[(i + 1) % n])
    return out


def harp():
    """a little harp run going up"""
    b = np.zeros(int(SR * 1.6))
    for i, f in enumerate((783.99, 987.77, 1174.66, 1567.98)):   # G5 B5 D6 G6
        place(b, (0.8 + 0.06 * i) * ks(f, 1.3, 0.9965), 0.075 * i)
    return reverb(b, 0.25, 1.1)


def keys():
    """two soft electric piano notes, a little lo-fi"""
    def ep(f, dur):
        x = t(dur)
        idx = 1.5 * np.exp(-x / 0.3) + 0.25
        return np.sin(2 * np.pi * f * x + idx * np.sin(2 * np.pi * f * x)) * env(len(x), 0.004, 0.7)
    b = np.zeros(int(SR * 1.6))
    place(b, ep(659.25, 1.4), 0.0)            # E5
    place(b, 0.9 * ep(987.77, 1.4), 0.13)     # B5
    place(b, 0.5 * ep(493.88, 1.4), 0.13)     # B4 under it
    return reverb(lowpass(b, 4500), 0.28, 1.2)


def ripple():
    """a water drop and its rings"""
    def drop(f0, f1, dur, dec):
        x = t(dur)
        f = f0 + (f1 - f0) * (1 - np.exp(-x / 0.02))
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.0015, dec)
    b = np.zeros(int(SR * 1.2))
    place(b, drop(700, 1500, 0.4, 0.06), 0.0)
    for k, g in enumerate((0.45, 0.28, 0.16)):
        place(b, g * drop(1100 + 150 * k, 1700 + 150 * k, 0.3, 0.05), 0.16 + 0.13 * k)
    return reverb(lowpass(b, 6000), 0.3, 1.1)


if __name__ == "__main__":
    finish("glass", glass())
    finish("droplet", droplet(), 0.55)
    finish("chime", chime())
    finish("bubble", bubble(), 0.5)
    finish("marimba", marimba())
    finish("aurora", aurora(), 0.45)
    finish("ping", ping(), 0.45)
    finish("harp", harp(), 0.5)
    finish("keys", keys(), 0.5)
    finish("ripple", ripple(), 0.5)
