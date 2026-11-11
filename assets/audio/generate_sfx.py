#!/usr/bin/env python3
"""SpriteBonk original SFX generator (P0 batch, 2026-11-11).

Renders original synthesized one-shot SFX to assets/audio/sfx/<key>.wav
(44.1 kHz, 16-bit, mono). Every recipe below is an original design written
from the style notes in design/audio-requirements.md -- no parameter set is
copied from the original game's bundle (that is the whole point of the
reskin audio gate). Re-run to regenerate; tweak a recipe dict and re-run
to revise a single sound (pass its key as an argument).

Usage: python3 generate_sfx.py [key ...]   (no args = all keys)
"""
import sys
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 44100
OUT = Path(__file__).resolve().parent / "sfx"
rng = np.random.default_rng(20261111)

# ---------------------------------------------------------------- toolkit

def t(dur):
    return np.arange(int(SR * dur)) / SR

def env_adsr(n, a=0.005, d=0.05, s=0.0, r=0.08, peak=1.0):
    e = np.zeros(n)
    ai, di = int(a * SR), int(d * SR)
    ri = int(r * SR)
    si = max(n - ai - di - ri, 0)
    if ai: e[:ai] = np.linspace(0, peak, ai)
    if di: e[ai:ai + di] = np.linspace(peak, peak * s if s else peak * 0.0 + 0.0001, di) if s else np.linspace(peak, 0.35 * peak, di)
    if si: e[ai + di:ai + di + si] = (peak * s) if s else 0.35 * peak
    if ri: e[n - ri:] = np.linspace(e[n - ri] if n - ri > 0 else 0, 0, ri)
    return e

def exp_env(n, tau, peak=1.0, attack=0.002):
    tt = np.arange(n) / SR
    e = peak * np.exp(-tt / tau)
    ai = max(int(attack * SR), 1)
    e[:ai] *= np.linspace(0, 1, ai)
    return e

def sine(freq, dur, glide_to=None, phase=0.0):
    tt = t(dur)
    if glide_to:
        f = np.linspace(freq, glide_to, len(tt))
        ph = 2 * np.pi * np.cumsum(f) / SR + phase
    else:
        ph = 2 * np.pi * freq * tt + phase
    return np.sin(ph)

def square(freq, dur, glide_to=None, soft=6.0):
    return np.tanh(soft * sine(freq, dur, glide_to)) / np.tanh(soft) * 0.8

def tri(freq, dur, glide_to=None):
    return (2 / np.pi) * np.arcsin(np.clip(sine(freq, dur, glide_to), -0.999, 0.999))

def saw(freq, dur, glide_to=None):
    tt = t(dur)
    if glide_to:
        f = np.linspace(freq, glide_to, len(tt))
        ph = np.cumsum(f) / SR
    else:
        ph = freq * tt
    return 2 * (ph - np.floor(ph + 0.5))

def noise(dur, pink=False):
    n = int(SR * dur)
    w = rng.standard_normal(n)
    if pink:  # crude pink: cumulative lowpass blend
        sos = butter(1, 900, "low", fs=SR, output="sos")
        p = sosfilt(sos, w)
        w = 0.65 * w + 1.9 * p / (np.max(np.abs(p)) + 1e-9)
    return w

def filt(x, kind, freq, order=4):
    freq = np.clip(freq, 30, SR / 2 - 100)
    sos = butter(order, freq, kind, fs=SR, output="sos")
    return sosfilt(sos, x)

def band(x, lo, hi, order=4):
    sos = butter(order, [max(lo, 30), min(hi, SR / 2 - 100)], "band", fs=SR, output="sos")
    return sosfilt(sos, x)

def place(buf, x, at):
    i = int(at * SR)
    j = min(i + len(x), len(buf))
    if i < len(buf):
        buf[i:j] += x[:j - i]
    return buf

def notes(buf, seq, wave="sine", gain=0.5, note_dur=None, lp=None):
    """seq: list of (freq, start, dur). Simple melodic phrase renderer."""
    for f, at, d in seq:
        fn = {"sine": sine, "square": square, "tri": tri, "saw": saw}[wave]
        seg = fn(f, d) * exp_env(int(SR * d), tau=d * 0.45, peak=gain)
        if lp:
            seg = filt(seg, "low", lp)
        place(buf, seg, at)
    return buf

def finish(x, target_peak=0.89):
    x = np.asarray(x, dtype=np.float64)
    # trim trailing near-silence, keep 12 ms tail
    idx = np.where(np.abs(x) > 0.004)[0]
    if len(idx):
        x = x[:min(len(x), idx[-1] + int(0.012 * SR))]
    pk = np.max(np.abs(x)) + 1e-12
    x = x / pk * target_peak
    # 3 ms end fade to kill clicks
    n = min(int(0.003 * SR), len(x))
    x[-n:] *= np.linspace(1, 0, n)
    return (x * 32767).astype(np.int16)

# ---------------------------------------------------------------- recipes
# Each returns a float array. All parameters are original designs keyed to
# the style notes in design/audio-requirements.md.

def r_click():  # UI-01 woody light knock
    dur = 0.07
    b = np.zeros(int(SR * dur))
    knock = band(noise(0.03), 1400, 2600) * exp_env(int(SR * 0.03), 0.006, 0.9)
    thump = sine(210, 0.05, 150) * exp_env(int(SR * 0.05), 0.012, 0.55)
    place(b, knock, 0); place(b, thump, 0)
    return b

def r_deny():  # UI-02 muffled low "no"
    dur = 0.26
    b = np.zeros(int(SR * dur))
    a = filt(square(165, 0.11), "low", 700) * env_adsr(int(SR * 0.11), 0.004, 0.05, 0, 0.05, 0.7)
    c = filt(square(118, 0.15), "low", 600) * env_adsr(int(SR * 0.15), 0.004, 0.06, 0, 0.07, 0.75)
    place(b, a, 0); place(b, c, 0.10)
    return b

def r_xp():  # EC-01 crisp tiny pickup ping (engine steps pitch per combo)
    dur = 0.09
    s = sine(1480, dur, 1980) * exp_env(int(SR * dur), 0.022, 0.75)
    s += sine(2960, dur, 3400) * exp_env(int(SR * dur), 0.012, 0.25)
    return s

def r_coin():  # EC-02 metallic coin, light and not tiring
    dur = 0.14
    b = np.zeros(int(SR * dur))
    place(b, sine(2093, 0.09) * exp_env(int(SR * 0.09), 0.028, 0.6), 0)
    place(b, sine(2637, 0.12) * exp_env(int(SR * 0.12), 0.04, 0.55), 0.018)
    place(b, band(noise(0.015), 4000, 8000) * exp_env(int(SR * 0.015), 0.004, 0.3), 0)
    return b

def r_sparkle():  # EC-06 stardust purchase: airy rising glints, distinct from coin
    dur = 0.30
    b = np.zeros(int(SR * dur))
    for i, f in enumerate([2349, 2794, 3322]):
        place(b, sine(f, 0.16) * exp_env(int(SR * 0.16), 0.05, 0.5), i * 0.045)
    return filt(b, "high", 1200)

def r_heal():  # EC-03 warm rising recovery
    dur = 0.38
    b = np.zeros(int(SR * dur))
    notes(b, [(523, 0, 0.16), (659, 0.07, 0.18), (784, 0.14, 0.24)], wave="tri", gain=0.55, lp=2600)
    return b

def r_chest():  # EC-04 wooden chest: creak + latch + glint
    dur = 0.5
    b = np.zeros(int(SR * dur))
    creak = filt(saw(160, 0.16, 90), "low", 500) * env_adsr(int(SR * 0.16), 0.01, 0.05, 0, 0.06, 0.5)
    place(b, creak, 0.02)
    place(b, band(noise(0.02), 1800, 3200) * exp_env(int(SR * 0.02), 0.005, 0.7), 0.17)
    for i, f in enumerate([2637, 3520]):
        place(b, sine(f, 0.2) * exp_env(int(SR * 0.2), 0.06, 0.35), 0.20 + i * 0.05)
    return b

def r_charge():  # EC-10 altar charge tick: rising shimmer (retriggered)
    dur = 0.34
    tt = t(dur)
    s = sine(320, dur, 880) * (0.75 + 0.25 * np.sin(2 * np.pi * 26 * tt))
    return s * env_adsr(len(tt), 0.01, 0.08, 0.7, 0.1, 0.6)

def r_bell():  # EC-11 solemn altar bell (inharmonic partials)
    dur = 1.5
    b = np.zeros(int(SR * dur))
    base = 587
    for ratio, g, tau in [(1.0, 0.65, 0.55), (2.02, 0.4, 0.34), (2.74, 0.3, 0.22), (3.76, 0.18, 0.13), (5.4, 0.08, 0.07)]:
        b += sine(base * ratio, dur) * exp_env(int(SR * dur), tau, g)
    return filt(b, "low", 5200)

def r_whoosh():  # EC-12 / CB-09 airy sweep
    dur = 0.36
    n = noise(dur, pink=True)
    tt = t(dur)
    # sweeping bandpass via two static bands crossfaded
    lo = band(n, 300, 900); hi = band(n, 1200, 3600)
    w = 0.5 - 0.5 * np.cos(2 * np.pi * tt / dur)
    return (lo * (1 - w) + hi * w) * np.sin(np.pi * tt / dur) ** 1.5 * 1.4

def r_shot_default():  # SK-01 neutral shot
    dur = 0.10
    b = square(880, dur, 240) * exp_env(int(SR * dur), 0.026, 0.6)
    place(b, band(noise(0.03), 2500, 6000) * exp_env(int(SR * 0.03), 0.008, 0.35), 0)
    return b

def r_shot_grass():  # SK-01 grass: leafy puff + soft chirp
    dur = 0.13
    b = band(noise(dur, pink=True), 700, 2400) * exp_env(int(SR * dur), 0.045, 0.65)
    b += sine(760, dur, 470) * exp_env(int(SR * dur), 0.04, 0.4)
    return b

def r_shot_fire():  # SK-01 fire: crackly burst
    dur = 0.17
    b = filt(noise(dur), "low", 2600) * exp_env(int(SR * dur), 0.05, 0.8)
    n = int(SR * dur)
    crackle = np.zeros(n)
    for _ in range(26):
        i = rng.integers(0, n - 90)
        crackle[i:i + 90] += rng.standard_normal(90) * np.exp(-np.arange(90) / 22) * 0.5
    return b + filt(crackle, "high", 1800) * 0.32

def r_shot_water():  # SK-01 water: bubbly chirp
    dur = 0.15
    tt = t(dur)
    f = 540 + 260 * np.sin(2 * np.pi * 30 * tt)
    ph = 2 * np.pi * np.cumsum(f) / SR
    b = np.sin(ph) * exp_env(int(SR * dur), 0.045, 0.6)
    b += band(noise(dur, pink=True), 900, 2000) * exp_env(int(SR * dur), 0.05, 0.3)
    return b

def r_slash():  # SK-04 melee swing
    dur = 0.12
    n = noise(dur)
    hi = filt(n, "high", 2600)
    return hi * np.linspace(0.2, 1.0, len(hi)) * exp_env(int(SR * dur), 0.035, 1.0)

def _ult(element):
    dur = 0.72
    b = np.zeros(int(SR * dur))
    up = sine(180, 0.26, 720) * env_adsr(int(SR * 0.26), 0.02, 0.1, 0.8, 0.05, 0.45)
    place(b, up, 0)
    sub = sine(130, 0.4, 55) * exp_env(int(SR * 0.4), 0.13, 0.85)
    place(b, sub, 0.24)
    burst = {"grass": r_shot_grass, "fire": r_shot_fire, "water": r_shot_water}[element]()
    place(b, burst * 1.1, 0.24)
    place(b, burst * 0.7, 0.33)
    return b

def r_hit(power, bright):  # CB-01 tiers + CB-02 handled by params
    dur = 0.10 + 0.05 * power
    b = filt(noise(dur), "low", 1400 + 2600 * bright) * exp_env(int(SR * dur), 0.02 + 0.02 * power, 0.65 + 0.25 * power)
    b += sine(170 - 30 * power, dur, 80) * exp_env(int(SR * dur), 0.03 + 0.02 * power, 0.6)
    if bright > 0.6:
        place(b, sine(1244, 0.1) * exp_env(int(SR * 0.1), 0.03, 0.3), 0)
    return b

def r_mega():  # CB-02 crit: crack + growl
    dur = 0.28
    h = r_hit(1.0, 1.0)
    b = np.zeros(int(SR * dur))
    place(b, h, 0)
    place(b, filt(saw(196, 0.2, 65), "low", 900) * exp_env(int(SR * 0.2), 0.07, 0.55), 0.02)
    return b

def r_pop():  # CB-03 kill pop
    return sine(620, 0.09, 140) * exp_env(int(SR * 0.09), 0.02, 0.85)

def r_hurt():  # CB-05 player hurt: unmistakable low buzz-drop
    dur = 0.2
    b = filt(saw(140, dur, 70), "low", 1100) * exp_env(int(SR * dur), 0.06, 0.85)
    b += filt(noise(dur), "low", 800) * exp_env(int(SR * dur), 0.05, 0.4)
    return b

def r_jump():  # CB-07 light upward sweep (2nd jump pitched by engine)
    return sine(310, 0.13, 760) * env_adsr(int(SR * 0.13), 0.008, 0.05, 0, 0.05, 0.6)

def r_alarm():  # CB-12 elite warning, firm not shrill
    dur = 0.52
    b = np.zeros(int(SR * dur))
    for i, f in enumerate([494, 740, 494, 740]):
        seg = filt(square(f, 0.11), "low", 2400) * env_adsr(int(SR * 0.11), 0.005, 0.04, 0, 0.04, 0.55)
        place(b, seg, i * 0.125)
    return b

def r_boom():  # CB-13 explosion (size via engine pitch)
    dur = 0.55
    b = sine(118, dur, 38) * exp_env(int(SR * dur), 0.16, 1.0)
    n = filt(noise(dur), "low", 900) * exp_env(int(SR * dur), 0.11, 0.8)
    n2 = band(noise(dur), 300, 2400) * exp_env(int(SR * dur), 0.05, 0.4)
    return b + n + n2

def r_boss_start():  # CB-14 guardian entrance: low oppressive swell
    dur = 1.25
    b = np.zeros(int(SR * dur))
    for f, g in [(55, 0.5), (82.5, 0.35), (110, 0.22)]:
        place(b, filt(saw(f, dur), "low", 420) * env_adsr(int(SR * dur), 0.35, 0.3, 0.55, 0.45, g), 0)
    place(b, sine(587 * 2.74, 0.8) * exp_env(int(SR * 0.8), 0.3, 0.12), 0.3)
    place(b, filt(noise(dur), "low", 300) * env_adsr(int(SR * dur), 0.4, 0.3, 0.4, 0.4, 0.25), 0)
    return b

def r_level_up():  # LV-01 rising phrase (original)
    dur = 0.55
    b = np.zeros(int(SR * dur))
    notes(b, [(523, 0, 0.14), (659, 0.08, 0.14), (784, 0.16, 0.16), (1047, 0.24, 0.3)], wave="tri", gain=0.55, lp=3200)
    return b

def r_power():  # LV-02 pick confirmation: assured fifth + shimmer
    dur = 0.32
    b = np.zeros(int(SR * dur))
    notes(b, [(392, 0, 0.14), (587, 0.06, 0.24)], wave="tri", gain=0.55, lp=2800)
    place(b, sine(3136, 0.18) * exp_env(int(SR * 0.18), 0.05, 0.18), 0.1)
    return b

def r_victory():  # LV-07 victory jingle (original melody)
    dur = 1.15
    b = np.zeros(int(SR * dur))
    notes(b, [(523, 0, 0.16), (659, 0.11, 0.16), (784, 0.22, 0.16),
              (659, 0.36, 0.14), (880, 0.48, 0.2), (1047, 0.62, 0.5)], wave="tri", gain=0.55, lp=3600)
    notes(b, [(262, 0, 0.3), (330, 0.36, 0.3), (392, 0.62, 0.5)], wave="sine", gain=0.3)
    return b

def r_defeat():  # LV-08 gentle descending phrase (original)
    dur = 1.05
    b = np.zeros(int(SR * dur))
    notes(b, [(440, 0, 0.24), (415, 0.2, 0.24), (349, 0.4, 0.26), (294, 0.6, 0.42)], wave="sine", gain=0.55, lp=2200)
    return b

def r_ball_click():  # CH-04 wooden box latch
    dur = 0.16
    b = np.zeros(int(SR * dur))
    place(b, band(noise(0.018), 1500, 2800) * exp_env(int(SR * 0.018), 0.005, 0.8), 0)
    place(b, band(noise(0.022), 1100, 2200) * exp_env(int(SR * 0.022), 0.006, 0.9), 0.055)
    place(b, sine(1865, 0.06) * exp_env(int(SR * 0.06), 0.02, 0.25), 0.057)
    return b

def r_caught():  # CH-04 bond success phrase (original, distinct from level_up)
    dur = 0.62
    b = np.zeros(int(SR * dur))
    place(b, r_ball_click(), 0)
    notes(b, [(784, 0.14, 0.14), (988, 0.24, 0.14), (1319, 0.34, 0.26)], wave="sine", gain=0.5, lp=4200)
    return b

RECIPES = {
    "click": r_click, "deny": r_deny, "xp": r_xp, "coin": r_coin,
    "sparkle": r_sparkle, "heal": r_heal, "chest": r_chest,
    "charge": r_charge, "bell": r_bell, "whoosh": r_whoosh,
    "shot_default": r_shot_default, "shot_grass": r_shot_grass,
    "shot_fire": r_shot_fire, "shot_water": r_shot_water,
    "slash": r_slash,
    "ult_grass": lambda: _ult("grass"), "ult_fire": lambda: _ult("fire"),
    "ult_water": lambda: _ult("water"),
    "hit_weak": lambda: r_hit(0.15, 0.1), "hit_neutral": lambda: r_hit(0.5, 0.4),
    "hit_super": lambda: r_hit(0.85, 0.75), "hit_crit": lambda: r_hit(1.0, 1.0),
    "mega": r_mega, "pop": r_pop, "hurt": r_hurt, "jump": r_jump,
    "alarm": r_alarm, "boom": r_boom, "boss_start": r_boss_start,
    "level_up": r_level_up, "power": r_power, "victory": r_victory,
    "defeat": r_defeat, "ball_click": r_ball_click, "caught": r_caught,
}

def main():
    keys = sys.argv[1:] or list(RECIPES)
    OUT.mkdir(parents=True, exist_ok=True)
    for k in keys:
        data = finish(RECIPES[k]())
        wavfile.write(OUT / f"{k}.wav", SR, data)
        dur = len(data) / SR
        print(f"{k:14s} {dur:5.2f}s  peak {np.max(np.abs(data))/32767:.2f}")

if __name__ == "__main__":
    main()
