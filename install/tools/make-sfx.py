#!/usr/bin/env python3
"""Builds the interface sounds in sounds/sfx/ (our own synthesis, free to use: CC0).

  python3 install/tools/make-sfx.py        needs numpy and scipy; ffmpeg for the music (.ogg)

sounds/sfx/<pack>/<event>.wav   packs: tap soft pluck keys crystal bubble retro
                                events: click switch-on switch-off slide type select done page-next page-prev add remove
  python3 install/tools/make-sfx.py --extra   only page-next, page-prev, add and remove
sounds/sfx/intro/*.wav          welcome intro and tour: night reveal open tip
sounds/sfx/music/calm.ogg       quiet music for the welcome intro and the Settings tour
"""
import os
import shutil
import subprocess
import wave

import numpy as np
from scipy.signal import butter, lfilter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "sounds", "sfx")
rng = np.random.default_rng(11)


# ---------------------------------------------------------------- building blocks
def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.001, decay=0.05):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    a = a * a * (3 - 2 * a)
    return a * np.exp(-x / decay)


def band(x, lo, hi, order=2):
    sos = butter(order, [lo, min(hi, SR / 2.1)], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x)


def lowp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2.1), fs=SR, output="sos"), x)


def highp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def sine(f, dur, decay, attack=0.001, glide=1.0, glide_t=0.03):
    """f glides to f*glide with time constant glide_t"""
    x = t(dur)
    ff = f * (glide + (1 - glide) * np.exp(-x / glide_t))
    return np.sin(2 * np.pi * np.cumsum(ff) / SR) * env(len(x), attack, decay)


def square(f, dur, decay, duty=0.5, attack=0.001):
    x = t(dur)
    ph = (f * x) % 1.0
    s = np.where(ph < duty, 1.0, -1.0)
    return lowp(s, 6000) * env(len(x), attack, decay)


def tick(dur=0.012, lo=2500, hi=9000, decay=0.0025):
    n = rng.standard_normal(int(SR * dur))
    return band(n, lo, hi) * env(len(n), 0.0003, decay)


def pluck(f, dur, bright=0.5, damp=0.996):
    """Karplus-Strong string: warm and musical"""
    n = int(SR / f)
    buf = rng.uniform(-1, 1, n)
    buf = lowp(buf, 1500 + 9000 * bright, 1)
    out = np.zeros(int(SR * dur))
    for i in range(len(out)):
        j = i % n
        nxt = buf[(i + 1) % n]
        v = buf[j]
        out[i] = v
        buf[j] = damp * 0.5 * (v + nxt)
    return out * env(len(out), 0.0005, dur * 0.6)


def rhodes(f, dur, vel=1.0, decay=1.2):
    """soft electric piano (two-operator FM with a little bell)"""
    x = t(dur)
    idx = vel * (1.6 * np.exp(-x / 0.35) + 0.25)
    mod = np.sin(2 * np.pi * f * x) * idx
    car = np.sin(2 * np.pi * f * x + mod)
    tine = 0.12 * vel * np.sin(2 * np.pi * f * 7.0 * x) * np.exp(-x / 0.05)
    return (car + tine) * env(len(x), 0.004, decay)


def bell(f, dur, decay, partials=((1, 1), (2.76, 0.3), (5.4, 0.1), (8.9, 0.03)), attack=0.001):
    x = t(dur)
    s = sum(g * np.sin(2 * np.pi * f * r * x) * np.exp(-x / (decay / (1 + 0.6 * k)))
            for k, (r, g) in enumerate(partials))
    return s * env(len(x), attack, 10)


def seq(*items):
    n = max(int(s * SR) + len(p) for p, s in items)
    out = np.zeros(n)
    for p, s in items:
        i = int(s * SR)
        out[i:i + len(p)] += p
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def room(x, wet=0.2, size=1.0, tail=1.0):
    """small soft room (Schroeder): 4 combs + 2 allpasses"""
    x = np.concatenate([x, np.zeros(int(SR * tail))])
    y = np.zeros_like(x)
    for d, g in ((0.0297, 0.80), (0.0371, 0.78), (0.0411, 0.76), (0.0437, 0.74)):
        n = int(d * SR * size)
        a = np.zeros(n + 1); a[0] = 1; a[n] = -g
        y += lfilter([1], a, x) / 4
    for d, g in ((0.005, 0.7), (0.0017, 0.7)):
        n = int(d * SR)
        b = np.zeros(n + 1); b[0] = -g; b[n] = 1
        a = np.zeros(n + 1); a[0] = 1; a[n] = -g
        y = lfilter(b, a, y)
    return x * (1 - wet) + lowp(y, 5000) * wet


def trim(s, floor=1e-3):
    a = np.abs(s)
    if a.max() == 0:
        return s
    last = np.nonzero(a > floor * a.max())[0][-1] + 1
    return s[:last]


def norm(s, peak):
    s = trim(s - np.mean(s))
    m = np.max(np.abs(s)) or 1
    s = s / m * peak
    f = min(len(s), int(0.006 * SR))
    s[-f:] *= np.linspace(1, 0, f) ** 2
    return s


def write(path, s):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(s, -1, 1) * 32767).astype("<i2").tobytes())


# ---------------------------------------------------------------- packs
def tap():
    """crisp and modern: tiny glassy taps, like a good phone"""
    def tp(f, d=0.035, dec=0.006, g=0.35):
        return mix(sine(f, d, dec), tick(0.008, 3000, 11000, 0.0012) * g)
    return {
        "click": tp(1850),
        "switch-on": seq((tp(1500), 0), (tp(2250), 0.038)),
        "switch-off": seq((tp(2250), 0), (tp(1500), 0.038)),
        "slide": sine(3200, 0.012, 0.0022),
        "type": mix(tick(0.01, 1800, 8000, 0.0018), sine(1900, 0.012, 0.002) * 0.5),
        "select": tp(1400, 0.06, 0.012, 0.2),
        "done": seq((bell(2093, 0.5, 0.18), 0), (bell(2794, 0.6, 0.22), 0.07)),
    }


def pebble():
    """Material-like: very short, dry and precise ticks with a soft round body (V3.23, the default pack)"""
    def tk(f, body=0.006, air=0.0009, g=0.5):
        # a pitched body that dies in a few ms, and a breath of high air on top
        return mix(sine(f, 0.03, body), tick(0.006, 2600, 9000, air) * g)
    def thump(f=95, d=0.05, dec=0.012):
        return sine(f, d, dec, glide=0.85, glide_t=0.02)
    return {
        "click": tk(1650, 0.007, 0.0010, 0.45),
        "switch-on": seq((tk(1250, 0.006), 0), (tk(1900, 0.008), 0.032)),
        "switch-off": mix(seq((tk(1500, 0.006), 0), (tk(1050, 0.007), 0.032)), thump() * 0.5),
        "slide": tk(3900, 0.0018, 0.0006, 0.3),
        "type": tick(0.006, 2200, 8000, 0.0011),
        "select": tk(3900, 0.0025, 0.0008, 0.35),
        "done": seq((tk(1650, 0.01), 0), (bell(2349, 0.32, 0.09), 0.045), (bell(3136, 0.36, 0.11), 0.10)),
        "page-next": mix(tk(1760, 0.01, 0.0015, 0.6), band(rng.normal(0, 1, int(SR * 0.025)), 1800, 7000) * env(int(SR * 0.025), 0.004, 0.006) * 0.25),
        "page-prev": mix(tk(1320, 0.01, 0.0015, 0.6), band(rng.normal(0, 1, int(SR * 0.025)), 1500, 6000) * env(int(SR * 0.025), 0.004, 0.006) * 0.25),
        "add": seq((tk(1400, 0.006), 0), (tk(2100, 0.009), 0.04)),
        "remove": seq((tk(1600, 0.006), 0), (tk(1000, 0.009), 0.04)),
    }


def soft():
    """quiet wooden taps"""
    def wood(f, d=0.06, dec=0.012):
        x = t(d)
        s = sum(g * np.sin(2 * np.pi * f * r * x) for r, g in ((1, 1), (2.7, 0.25), (5.1, 0.08)))
        return s * env(len(x), 0.001, dec)
    return {
        "click": mix(wood(520), tick(0.02, 900, 5000, 0.003) * 0.25),
        "switch-on": seq((wood(620, 0.08, 0.025), 0), (wood(930, 0.1, 0.03), 0.045)),
        "switch-off": seq((wood(930, 0.08, 0.025), 0), (wood(620, 0.1, 0.03), 0.045)),
        "slide": wood(1650, 0.025, 0.005) * 0.6,
        "type": mix(tick(0.02, 1500, 7000, 0.003) * 0.6, wood(380, 0.02, 0.004) * 0.4),
        "select": wood(780, 0.14, 0.04),
        "done": seq((wood(784, 0.5, 0.15), 0), (wood(1047, 0.6, 0.2), 0.09)),
    }


def pluck_pack():
    """a small harp: every click is a note, switches go up and down the scale"""
    return {
        "click": pluck(1046.5, 0.25, 0.45, 0.990),
        "switch-on": seq((pluck(784, 0.3, 0.5, 0.992), 0), (pluck(1174.7, 0.35, 0.5, 0.993), 0.06)),
        "switch-off": seq((pluck(1174.7, 0.3, 0.5, 0.992), 0), (pluck(784, 0.35, 0.5, 0.993), 0.06)),
        "slide": pluck(2637, 0.06, 0.3, 0.97) * 0.5,
        "type": pluck(1568, 0.06, 0.25, 0.96) * 0.5,
        "select": pluck(1318.5, 0.3, 0.5, 0.992),
        "done": seq(*[(pluck(f, 0.7, 0.55, 0.996), i * 0.07) for i, f in enumerate((1046.5, 1318.5, 1568, 2093))]),
    }


def keys():
    """a nice mechanical keyboard: deep thock with a light click on top"""
    def thock(body=170, click=2600, g=1.0):
        return mix(sine(body, 0.06, 0.018, glide=0.8, glide_t=0.02) * 0.9,
                   band(rng.standard_normal(int(SR * 0.03)), click * 0.7, click * 1.5) * env(int(SR * 0.03), 0.0003, 0.004) * 0.6,
                   tick(0.012, 4000, 11000, 0.0015) * 0.25) * g
    return {
        "click": thock(),
        "switch-on": seq((thock(160, 2400), 0), (thock(210, 3000, 0.8), 0.07)),
        "switch-off": seq((thock(210, 3000, 0.8), 0), (thock(160, 2400), 0.07)),
        "slide": tick(0.01, 3500, 9000, 0.0015) * 0.7,
        "type": thock(190, 2800, 0.7),
        "select": thock(150, 2200),
        "done": seq((thock(160, 2400), 0), (thock(180, 2600), 0.08), (thock(140, 2200), 0.16)),
    }


def crystal():
    """small glass bells"""
    return {
        "click": bell(1760, 0.09, 0.02),
        "switch-on": seq((bell(1318, 0.12, 0.04), 0), (bell(1976, 0.16, 0.05), 0.05)),
        "switch-off": seq((bell(1976, 0.12, 0.04), 0), (bell(1318, 0.16, 0.05), 0.05)),
        "slide": bell(2637, 0.03, 0.006) * 0.6,
        "type": bell(3136, 0.025, 0.004) * 0.5,
        "select": bell(1568, 0.2, 0.06),
        "done": seq((bell(1568, 0.7, 0.25), 0), (bell(2093, 0.8, 0.3), 0.1), (bell(2637, 0.9, 0.35) * 0.7, 0.2)),
    }


def bubble():
    """soft round pops"""
    def pop(f, d=0.07, g=1.6):
        return sine(f, d, d * 0.35, attack=0.002, glide=g, glide_t=d * 0.4)
    return {
        "click": pop(600),
        "switch-on": pop(480, 0.1, 1.9),
        "switch-off": pop(900, 0.1, 0.6),
        "slide": pop(1300, 0.03, 1.3) * 0.6,
        "type": pop(1000, 0.03, 1.3) * 0.5,
        "select": pop(760, 0.1, 1.5),
        "done": seq((pop(523, 0.16, 1.3), 0), (pop(659, 0.16, 1.3), 0.08), (pop(784, 0.22, 1.3), 0.16)),
    }


def retro():
    """8-bit blips, like an old game console"""
    def blip(f, d=0.05, dec=0.02, duty=0.25):
        return square(f, d, dec, duty)
    return {
        "click": seq((blip(880, 0.03, 0.012), 0), (blip(1320, 0.03, 0.012), 0.022)),
        "switch-on": seq((blip(660, 0.04, 0.02, 0.5), 0), (blip(990, 0.06, 0.03, 0.5), 0.04)),
        "switch-off": seq((blip(990, 0.04, 0.02, 0.5), 0), (blip(660, 0.06, 0.03, 0.5), 0.04)),
        "slide": blip(1760, 0.015, 0.006, 0.125) * 0.6,
        "type": blip(1320, 0.015, 0.006, 0.125) * 0.6,
        "select": seq((blip(784, 0.04, 0.02), 0), (blip(1046, 0.05, 0.025), 0.035)),
        "done": seq((blip(988, 0.09, 0.05, 0.5), 0), (blip(1319, 0.3, 0.12, 0.5), 0.08)),
    }


PEAK = {"click": 0.42, "switch-on": 0.45, "switch-off": 0.4, "slide": 0.22, "type": 0.2, "select": 0.42, "done": 0.45}


# ---------------------------------------------------------------- intro and tour
def intro():
    # night falls: a low, warm electric piano chord that blooms, no hiss
    night = room(mix(*[rhodes(f, 3.0, 0.6, 1.4) * g for f, g in ((130.8, 0.7), (196.0, 0.5), (246.9, 0.45), (329.6, 0.35))]), 0.3, 1.2, 1.5)
    # the moon draws itself in: a music-box run
    notes = (1046.5, 1318.5, 1568.0, 1975.5, 2349.3, 2637.0)
    reveal = room(seq(*[(bell(f, 1.2, 0.5, ((1, 1), (3.0, 0.15), (6.1, 0.04))) * (1 - i * 0.07), i * 0.13) for i, f in enumerate(notes)]), 0.3, 1.1, 1.2)
    # "Take a look": a bright, happy chord
    opening = room(mix(*[rhodes(f, 1.8, 0.8, 0.9) * g for f, g in ((261.6, 0.6), (329.6, 0.5), (392.0, 0.5), (523.3, 0.45))],
                       seq((bell(2093, 1.0, 0.4) * 0.25, 0.05), (bell(2637, 1.0, 0.4) * 0.2, 0.12))), 0.3, 1.2, 1.2)
    # one step of the tour: a soft two-note ping
    tip = room(seq((bell(1568, 0.7, 0.25, ((1, 1), (3.0, 0.12))), 0), (bell(2093, 0.8, 0.3, ((1, 1), (3.0, 0.12))) * 0.8, 0.08)), 0.25, 1.0, 0.8)
    return {"night": norm(night, 0.32), "reveal": norm(reveal, 0.36), "open": norm(opening, 0.38), "tip": norm(tip, 0.34)}


def calm(seconds=72, bpm=72):
    """lo-fi and friendly: soft electric piano chords, a little music box melody, a warm bass. No drums."""
    beat = 60 / bpm
    bar = 4 * beat
    out = np.zeros(int(SR * (seconds + 3)))

    def put(sig, at):
        i = int(at * SR)
        end = min(len(out), i + len(sig))
        out[i:end] += sig[:end - i]

    # Fmaj7 - Em7 - Dm7 - Cmaj7 (a gentle walk down)
    chords = [(174.6, 220.0, 261.6, 329.6), (164.8, 196.0, 246.9, 293.7),
              (146.8, 174.6, 220.0, 261.6), (130.8, 164.8, 196.0, 246.9)]
    bass = [87.3, 82.4, 73.4, 65.4]
    nbars = int(seconds / bar)
    for k in range(nbars):
        ch, start = chords[k % 4], k * bar
        for j, f in enumerate(ch):                  # a soft strum
            put(rhodes(f, bar + 1.2, 0.55, 1.6) * 0.32, start + j * 0.025)
        put(rhodes(ch[1], beat * 2, 0.35, 0.8) * 0.18, start + 2.5 * beat)   # a quiet echo of the chord
        put(sine(bass[k % 4], bar, 1.5, attack=0.02) * 0.45, start)
    melody = [(0, 659.3), (1.5, 784.0), (3, 880.0), (4, 784.0), (6, 659.3), (8, 587.3), (9.5, 659.3), (11, 523.3),
              (12, 587.3), (14, 659.3), (16, 698.5), (17.5, 659.3), (19, 587.3), (20, 523.3), (22, 587.3), (24, 659.3),
              (26, 784.0), (27.5, 659.3), (28, 587.3), (30, 523.3)]
    for rep in range(nbars // 8 + 1):
        for b, f in melody:
            at = 2 * bar + rep * 8 * bar + b * beat
            if at < seconds - 4:
                put(bell(f * 2, 1.6, 0.6, ((1, 1), (3.0, 0.12), (6.1, 0.03))) * 0.16, at)
    out = lowp(out, 4200)
    out = room(out, 0.28, 1.3, 2.0)[:len(out)]
    x = np.arange(len(out)) / SR
    out *= np.clip(x / 3.0, 0, 1) * np.clip((seconds - x) / 6.0, 0, 1)
    return norm(out, 0.5)


# ---------------------------------------------------------------- extra events (own noise source, so the older sounds never change)
rng2 = np.random.default_rng(302)


def sweep_noise(f0, f1, dur, decay, q=0.35):
    """filtered noise whose center moves from f0 to f1: a page being turned"""
    n = int(SR * dur)
    x = rng2.standard_normal(n)
    out = np.zeros(n)
    blk = 128
    zi = None
    for i in range(0, n, blk):
        k = i / max(1, n)
        c = f0 * (f1 / f0) ** k
        sos = butter(2, [max(80, c * (1 - q)), min(c * (1 + q), SR / 2.1)], btype="band", fs=SR, output="sos")
        if zi is None or zi.shape != (sos.shape[0], 2):
            zi = np.zeros((sos.shape[0], 2))
        seg, zi = sosfilt(sos, x[i:i + blk], zi=zi)
        out[i:i + blk] = seg
    return out * env(n, dur * 0.35, decay)


def chirp(f0, f1, dur, decay, square_wave=False):
    x = t(dur)
    ff = f0 * (f1 / f0) ** (x / dur)
    ph = 2 * np.pi * np.cumsum(ff) / SR
    s = np.sign(np.sin(ph)) * 0.6 if square_wave else np.sin(ph)
    return s * env(len(x), 0.002, decay)


def extra_events():
    """page-next / page-prev: the calendar changes month.  add / remove: a task is added or deleted in To-do."""
    def pack(voice, note, swish, lo, hi, up_gain=1.0):
        return {
            "page-next": mix(swish(lo, hi, 0.11, 0.05), voice(note * 1.5, 0.12) * 0.55),
            "page-prev": mix(swish(hi, lo, 0.11, 0.05), voice(note * 1.0, 0.12) * 0.55),
            "add": seq((voice(note * 1.0, 0.1), 0), (voice(note * 1.25, 0.1), 0.04), (voice(note * 1.5, 0.16), 0.08)),
            "remove": seq((voice(note * 1.4, 0.08), 0), (voice(note * 0.8, 0.14), 0.05)) * 0.9,
        }

    def tap_v(f, d):
        return mix(sine(f, d, d * 0.2), tick(0.006, 3000, 11000, 0.001) * 0.3)

    def soft_v(f, d):
        x = t(d + 0.05)
        return sum(g * np.sin(2 * np.pi * f * r * x) for r, g in ((1, 1), (2.7, 0.25))) * env(len(x), 0.001, d * 0.3)

    def pluck_v(f, d):
        return pluck(f, d + 0.12, 0.5, 0.992)

    def keys_v(f, d):
        return mix(sine(f * 0.18, 0.06, 0.02, glide=0.8, glide_t=0.02) * 0.8,
                   band(rng2.standard_normal(int(SR * 0.03)), f * 1.2, f * 2.2) * env(int(SR * 0.03), 0.0003, 0.004) * 0.6)

    def crystal_v(f, d):
        return bell(f * 1.5, d + 0.12, d * 0.4)

    def bubble_v(f, d):
        return sine(f * 0.6, d, d * 0.35, attack=0.002, glide=1.7, glide_t=d * 0.4)

    def retro_v(f, d):
        return square(f * 0.9, d, d * 0.4, 0.25)

    def retro_swish(f0, f1, dur, decay):
        return chirp(f0 * 0.5, f1 * 0.5, dur, decay, True) * 0.5

    return {
        "tap": pack(tap_v, 1100, sweep_noise, 1800, 6500),
        "soft": pack(soft_v, 520, sweep_noise, 900, 3500),
        "pluck": pack(pluck_v, 659, sweep_noise, 1400, 5000),
        "keys": pack(keys_v, 1300, sweep_noise, 1800, 6000),
        "crystal": pack(crystal_v, 880, sweep_noise, 2200, 8000),
        "bubble": pack(bubble_v, 760, sweep_noise, 600, 2600),
        "retro": pack(retro_v, 700, retro_swish, 800, 2600),
    }


PEAK.update({"page-next": 0.32, "page-prev": 0.32, "add": 0.4, "remove": 0.34})


def write_extra():
    gain = {"pluck": 1.6, "retro": 0.65, "keys": 1.1}
    for name, evs in extra_events().items():
        for ev, snd in evs.items():
            write(os.path.join(OUT, name, ev + ".wav"), norm(snd, min(0.8, PEAK[ev] * gain.get(name, 1.0))))
    print("extra sounds written")


def main():
    if "--extra" in os.sys.argv:      # only the newer events; the others stay as they are
        write_extra()
        return
    if "--pebble" in os.sys.argv:     # only the Pebble pack
        for ev, snd in pebble().items():
            write(os.path.join(OUT, "pebble", ev + ".wav"), norm(snd, PEAK[ev]))
        print("pebble written")
        return
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    packs = {"pebble": pebble, "tap": tap, "soft": soft, "pluck": pluck_pack, "keys": keys, "crystal": crystal, "bubble": bubble, "retro": retro}
    gain = {"pluck": 1.6, "retro": 0.65, "keys": 1.1}       # about the same loudness for every pack
    for name, fn in packs.items():
        for ev, s in fn().items():
            write(os.path.join(OUT, name, ev + ".wav"), norm(s, min(0.8, PEAK[ev] * gain.get(name, 1.0))))
    for ev, s in intro().items():
        write(os.path.join(OUT, "intro", ev + ".wav"), s)
    write_extra()
    wav = os.path.join(OUT, "music", "calm.wav")
    write(wav, calm())
    if shutil.which("ffmpeg"):
        ogg = os.path.join(OUT, "music", "calm.ogg")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
        os.remove(wav)
    print("sounds written to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
