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
    # Center the waveform: a 12 Hz high-pass strips the LF asymmetry
    # that short low thuds otherwise leave as a DC offset (inaudible).
    x = filt(x, "high", 12, order=2)
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

# ---------------------------------------------------------------- P1/P2 batch
# Second production batch (2026-11-11, user go-ahead): every remaining
# one-shot key from the requirements list (P1 35 / P2 12 minus the BGM
# and partner-cry rows, which stay held for the user's direction) plus
# synthesized ambience loops. Same rule as P0: original designs from the
# list's style notes, nothing copied from the original game's recipes.

def r_hover():  # UI-12 desktop hover tick (wiring is touch-first light)
    return sine(1900, 0.035) * exp_env(int(SR * 0.035), 0.012, 0.35)

def r_shot_electric():  # SK-02 electric: crackle burst + descending zap
    dur = 0.16
    b = np.zeros(int(SR * dur))
    place(b, band(noise(0.05), 2400, 7000) * exp_env(int(SR * 0.05), 0.02, 0.8), 0)
    place(b, band(noise(0.04), 1800, 5200) * exp_env(int(SR * 0.04), 0.015, 0.7), 0.045)
    place(b, square(1500, 0.09, glide_to=420) * exp_env(int(SR * 0.09), 0.035, 0.4), 0.01)
    return b

def r_shot_ice():  # SK-02 ice: crystalline partials + hp shimmer
    dur = 0.22
    b = np.zeros(int(SR * dur))
    for f, g in [(1568, 0.5), (2349, 0.32), (3136, 0.2)]:
        place(b, sine(f, 0.16) * exp_env(int(SR * 0.16), 0.05, g), 0)
    place(b, band(noise(0.1), 5000, 11000) * exp_env(int(SR * 0.1), 0.03, 0.3), 0.01)
    return b

def r_shot_psychic():  # SK-02 psychic: wobbling glide
    dur = 0.24
    tt = t(dur)
    wob = 1.0 + 0.06 * np.sin(2 * np.pi * 26 * tt)
    base = sine(620, dur, glide_to=990) * wob
    harm = sine(1240, dur, glide_to=1980) * 0.35
    return (base + harm) * exp_env(int(SR * dur), 0.09, 0.55)

def r_shot_ghost():  # SK-02 ghost: breathy descending wail
    dur = 0.3
    b = np.zeros(int(SR * dur))
    place(b, band(noise(dur), 500, 1600) * env_adsr(int(SR * dur), 0.05, 0.1, 0.25, 0.12, 0.5), 0)
    place(b, sine(392, dur, glide_to=185) * exp_env(int(SR * dur), 0.11, 0.4), 0.01)
    return b

def r_beam():  # SK-06 beam: sustained driven hum
    dur = 0.34
    b = saw(164, dur) * 0.5 + sine(82, dur) * 0.4 + sine(328, dur) * 0.22
    return filt(b, "low", 2600) * env_adsr(int(SR * dur), 0.012, 0.05, 0.75, 0.07, 0.85)

def r_beam_ice():  # SK-06 ice beam: hum + crystalline shimmer
    dur = 0.34
    shimmer = band(noise(dur), 4200, 9000) * 0.3 \
        * env_adsr(int(SR * dur), 0.02, 0.08, 0.5, 0.08, 0.8)
    return r_beam() + shimmer

def r_cone_fire():  # SK-07 fire cone: low-mid breath of flame
    dur = 0.32
    b = band(noise(dur, pink=True), 240, 950) * env_adsr(int(SR * dur), 0.03, 0.08, 0.5, 0.1, 0.9)
    return b + sine(98, dur) * exp_env(int(SR * dur), 0.12, 0.3)

def r_cone_other():  # SK-07 cone (other types): mid breath
    dur = 0.28
    return band(noise(dur), 480, 1700) * env_adsr(int(SR * dur), 0.025, 0.06, 0.5, 0.09, 0.85)

def r_nova():  # SK-05 nova: expanding ring chirp + swell
    dur = 0.34
    b = np.zeros(int(SR * dur))
    place(b, sine(294, 0.26, glide_to=880) * exp_env(int(SR * 0.26), 0.1, 0.5), 0)
    place(b, band(noise(0.24), 700, 2600) * env_adsr(int(SR * 0.24), 0.04, 0.09, 0.3, 0.09, 0.55), 0.02)
    return b

def r_nova_ground():  # SK-05 ground nova: lower, heavier
    dur = 0.36
    b = np.zeros(int(SR * dur))
    place(b, sine(147, 0.3, glide_to=392) * exp_env(int(SR * 0.3), 0.12, 0.55), 0)
    place(b, filt(noise(0.12), "low", 320) * exp_env(int(SR * 0.12), 0.05, 0.6), 0)
    return b

def r_dodge():  # CB-06 dodge: light high whoosh, quicker than whoosh()
    dur = 0.13
    return band(noise(dur), 1600, 4200) * env_adsr(int(SR * dur), 0.015, 0.04, 0.2, 0.05, 0.8)

def r_land():  # CB-08 landing: soft thud
    dur = 0.13
    b = filt(noise(0.07), "low", 300) * exp_env(int(SR * 0.07), 0.03, 0.8)
    return np.pad(b, (0, int(SR * dur) - len(b))) + sine(88, dur) * exp_env(int(SR * dur), 0.05, 0.4)

def r_dive():  # CB-10 dive: descending rush
    dur = 0.26
    tt = t(dur)
    sweep = band(noise(dur), 600, 2400) * (0.3 + 0.7 * tt / dur)
    return sweep + sine(587, dur, glide_to=196) * exp_env(int(SR * dur), 0.1, 0.4)

def r_slam():  # CB-10 slam: compact heavy impact (engine scales by size)
    dur = 0.24
    b = np.zeros(int(SR * dur))
    place(b, sine(72, 0.2, glide_to=41) * exp_env(int(SR * 0.2), 0.09, 0.85), 0)
    place(b, filt(noise(0.09), "low", 500) * exp_env(int(SR * 0.09), 0.035, 0.7), 0)
    return b

def r_encounter():  # CH-06 encounter alert: firm two-step
    dur = 0.26
    b = np.zeros(int(SR * dur))
    notes(b, [(392, 0.0, 0.09), (587, 0.1, 0.15)], wave="tri", gain=0.55, lp=3200)
    return b

def r_throw_ball():  # CH-03 toss the wooden box: airy arc + soft knock
    dur = 0.24
    b = np.zeros(int(SR * dur))
    place(b, band(noise(0.12), 900, 2600) * env_adsr(int(SR * 0.12), 0.03, 0.05, 0.2, 0.05, 0.5), 0)
    place(b, filt(noise(0.03), "low", 700) * exp_env(int(SR * 0.03), 0.012, 0.6), 0.15)
    return b

def r_ball_open():  # CH-03 wooden box opens: latch + lid creak
    dur = 0.3
    b = np.zeros(int(SR * dur))
    place(b, r_ball_click(), 0)
    place(b, band(noise(0.1), 500, 1200) * env_adsr(int(SR * 0.1), 0.04, 0.04, 0.2, 0.04, 0.4), 0.07)
    place(b, sine(523, 0.12) * exp_env(int(SR * 0.12), 0.05, 0.3), 0.13)
    return b

def r_ball_shake():  # CH-05 box rattles: three woody shakes
    dur = 0.34
    b = np.zeros(int(SR * dur))
    for at in (0.0, 0.11, 0.22):
        place(b, band(noise(0.05), 750, 2100) * exp_env(int(SR * 0.05), 0.02, 0.65), at)
        place(b, filt(noise(0.02), "low", 600) * exp_env(int(SR * 0.02), 0.008, 0.5), at + 0.01)
    return b

def r_slot_tick():  # EC-13 reel ratchet tick (engine pitch-jitters it)
    return band(noise(0.03), 1300, 3400) * exp_env(int(SR * 0.03), 0.01, 0.85)

def r_slot_lever():  # EC-13 lever: clunk + spring
    dur = 0.18
    b = np.zeros(int(SR * dur))
    place(b, filt(noise(0.04), "low", 500) * exp_env(int(SR * 0.04), 0.015, 0.7), 0)
    place(b, sine(880, 0.12, glide_to=330) * exp_env(int(SR * 0.12), 0.05, 0.3), 0.03)
    place(b, band(noise(0.025), 1500, 3000) * exp_env(int(SR * 0.025), 0.008, 0.6), 0.12)
    return b

def r_slot_stop():  # EC-15 reel stop / no-win thunk
    dur = 0.11
    b = filt(noise(0.05), "low", 650) * exp_env(int(SR * 0.05), 0.02, 0.75)
    return np.pad(b, (0, int(SR * dur) - len(b))) + sine(196, dur) * exp_env(int(SR * dur), 0.045, 0.4)

def r_slot_coins():  # EC-15 coin-bag win: small cascade of pings
    dur = 0.5
    b = np.zeros(int(SR * dur))
    for i, at in enumerate((0.0, 0.07, 0.15, 0.24, 0.35)):
        f = 2093 - i * 130
        place(b, sine(f, 0.09) * exp_env(int(SR * 0.09), 0.03, 0.5), at)
        place(b, sine(f * 1.5, 0.06) * exp_env(int(SR * 0.06), 0.02, 0.22), at)
    return b

def r_slot_curse():  # EC-15 curse: eerie descending minor steps
    dur = 0.55
    b = np.zeros(int(SR * dur))
    place(b, sine(494, 0.24, glide_to=466) * exp_env(int(SR * 0.24), 0.1, 0.5), 0)
    place(b, sine(370, 0.3, glide_to=311) * exp_env(int(SR * 0.3), 0.13, 0.5), 0.16)
    place(b, band(noise(0.3), 300, 900) * env_adsr(int(SR * 0.3), 0.08, 0.1, 0.15, 0.1, 0.25), 0.05)
    return b

def r_jackpot():  # EC-14 jackpot: happy rising arpeggio (original)
    dur = 0.6
    b = np.zeros(int(SR * dur))
    notes(b, [(523, 0.0, 0.11), (659, 0.09, 0.11), (784, 0.18, 0.11),
              (1047, 0.27, 0.3)], wave="tri", gain=0.5, lp=5200)
    place(b, band(noise(0.25), 5000, 10000) * exp_env(int(SR * 0.25), 0.09, 0.16), 0.27)
    return b

def r_zap():  # EC-15 / thunder stun: electric snap-buzz
    dur = 0.14
    b = np.zeros(int(SR * dur))
    place(b, square(139, 0.1) * exp_env(int(SR * 0.1), 0.04, 0.55), 0)
    place(b, band(noise(0.06), 2600, 8000) * exp_env(int(SR * 0.06), 0.02, 0.7), 0)
    return b

def r_evolve_done():  # LV-06 growth complete: shimmering ascent (original)
    dur = 0.7
    b = np.zeros(int(SR * dur))
    notes(b, [(659, 0.0, 0.18), (880, 0.13, 0.18), (1175, 0.26, 0.4)],
          wave="sine", gain=0.48, lp=6000)
    place(b, band(noise(0.4), 5200, 10500) * env_adsr(int(SR * 0.4), 0.1, 0.12, 0.2, 0.12, 0.2), 0.15)
    return b

def r_streak():  # CB-04 kill-chain blip (engine pitches it up per chain)
    return tri(880, 0.07) * exp_env(int(SR * 0.07), 0.025, 0.6)

def r_confirm():  # UI-04 wallet connected: gentle two-note confirm
    dur = 0.3
    b = np.zeros(int(SR * dur))
    notes(b, [(660, 0.0, 0.13), (880, 0.11, 0.18)], wave="sine", gain=0.45, lp=3800)
    return b

def r_start():  # UI-08 run start: fifth up with weight
    dur = 0.3
    b = np.zeros(int(SR * dur))
    notes(b, [(392, 0.0, 0.12), (587, 0.1, 0.19)], wave="tri", gain=0.55, lp=3600)
    place(b, filt(noise(0.035), "low", 420) * exp_env(int(SR * 0.035), 0.014, 0.55), 0)
    return b

def r_panel_open():  # UI-09 panel opens: paper/board slide up
    dur = 0.16
    tt = t(dur)
    sw = band(noise(dur), 380, 1300) * np.sin(np.pi * tt / dur) ** 1.5
    return sw * 0.8 + sine(320, dur, glide_to=520) * exp_env(int(SR * dur), 0.07, 0.12)

def r_panel_close():  # UI-09 panel closes: shorter slide down
    dur = 0.12
    tt = t(dur)
    sw = band(noise(dur), 380, 1100) * np.sin(np.pi * tt / dur) ** 1.5
    return sw * 0.65 + sine(460, dur, glide_to=300) * exp_env(int(SR * dur), 0.05, 0.1)

def r_buff():  # EC-09 generic pickup-buff gain
    dur = 0.2
    b = np.zeros(int(SR * dur))
    place(b, sine(740, 0.12, glide_to=1108) * exp_env(int(SR * 0.12), 0.05, 0.5), 0)
    place(b, sine(2217, 0.07) * exp_env(int(SR * 0.07), 0.025, 0.18), 0.06)
    return b

def r_chest_gold():  # EC-04 gold-trim chest: deeper knock + richer shimmer
    dur = 0.55
    b = np.zeros(int(SR * dur))
    place(b, filt(noise(0.05), "low", 380) * exp_env(int(SR * 0.05), 0.02, 0.8), 0)
    place(b, band(noise(0.07), 600, 1500) * exp_env(int(SR * 0.07), 0.028, 0.5), 0.06)
    for f, at, g in [(1568, 0.12, 0.4), (2093, 0.17, 0.34), (2637, 0.23, 0.28), (3136, 0.3, 0.2)]:
        place(b, sine(f, 0.16) * exp_env(int(SR * 0.16), 0.055, g), at)
    return b

def r_mimic():  # EC-16 mimic point: gear ticks into a magic gliss (no voice)
    dur = 0.42
    b = np.zeros(int(SR * dur))
    for i, at in enumerate((0.0, 0.06, 0.12)):
        place(b, band(noise(0.02), 1800 - i * 300, 3200 - i * 300) * exp_env(int(SR * 0.02), 0.007, 0.6), at)
    place(b, sine(880, 0.24, glide_to=1568) * exp_env(int(SR * 0.24), 0.09, 0.4), 0.16)
    place(b, sine(1760, 0.18, glide_to=2637) * exp_env(int(SR * 0.18), 0.07, 0.16), 0.18)
    return b

def r_ult_ready():  # SK-09 ult charged: bright ready ping, stands out
    dur = 0.34
    b = np.zeros(int(SR * dur))
    notes(b, [(1175, 0.0, 0.1), (1568, 0.09, 0.22)], wave="sine", gain=0.5, lp=7000)
    place(b, sine(2350, 0.2) * exp_env(int(SR * 0.2), 0.07, 0.16), 0.09)
    return b

def r_revive():  # CB-11 revive: warm rising restoration (original)
    dur = 0.6
    b = np.zeros(int(SR * dur))
    notes(b, [(523, 0.0, 0.17), (659, 0.14, 0.17), (784, 0.28, 0.3)],
          wave="sine", gain=0.46, lp=4200)
    place(b, sine(262, 0.5) * env_adsr(int(SR * 0.5), 0.08, 0.15, 0.25, 0.15, 0.18), 0)
    return b

def r_rage():  # CB-16 guardian enrage: low growl swell (not a cry)
    dur = 0.75
    tt = t(dur)
    growl = saw(58, dur, glide_to=87) * (0.75 + 0.25 * np.sin(2 * np.pi * 11 * tt))
    b = filt(growl, "low", 300) * 0.8
    b = b + band(noise(dur, pink=True), 180, 520) * 0.45
    return b * env_adsr(int(SR * dur), 0.09, 0.2, 0.55, 0.2, 0.9)

def r_boss_down():  # CB-17 variant: short triumphant phrase over the boom
    dur = 0.55
    b = np.zeros(int(SR * dur))
    notes(b, [(392, 0.0, 0.13), (523, 0.11, 0.13), (659, 0.22, 0.3)],
          wave="tri", gain=0.5, lp=4400)
    return b

def r_banish():  # LV-05 banish: paper tear
    dur = 0.2
    tt = t(dur)
    tear = band(noise(dur), 700, 3400) * (0.35 + 0.65 * np.abs(np.sin(2 * np.pi * 9 * tt)))
    return tear * np.sin(np.pi * tt / dur) ** 0.7

def r_shiny_spawn():  # CH-07 shiny ally appears: rare sparkle ping
    dur = 0.4
    b = np.zeros(int(SR * dur))
    for f, at in [(2093, 0.0), (2637, 0.07), (3136, 0.14)]:
        place(b, sine(f, 0.2) * exp_env(int(SR * 0.2), 0.07, 0.34), at)
    place(b, band(noise(0.22), 6000, 11000) * exp_env(int(SR * 0.22), 0.08, 0.14), 0.05)
    return b

def r_terminal():  # EC-17 recompile terminal: gears + low whir
    dur = 0.38
    b = np.zeros(int(SR * dur))
    for i, at in enumerate((0.0, 0.07, 0.15)):
        place(b, band(noise(0.022), 1200 + i * 250, 2600 + i * 250) * exp_env(int(SR * 0.022), 0.008, 0.6), at)
    place(b, band(noise(0.2), 280, 720) * env_adsr(int(SR * 0.2), 0.05, 0.06, 0.3, 0.06, 0.4), 0.1)
    place(b, sine(330, 0.1) * exp_env(int(SR * 0.1), 0.04, 0.25), 0.26)
    return b

def r_greet():  # EC-18 shopkeeper door: small bell + wooden shuffle
    dur = 0.4
    b = np.zeros(int(SR * dur))
    for ratio, g in [(1.0, 0.42), (2.02, 0.2), (2.74, 0.13)]:
        place(b, sine(1175 * ratio, 0.3) * exp_env(int(SR * 0.3), 0.11, g), 0.02)
    place(b, band(noise(0.09), 500, 1400) * env_adsr(int(SR * 0.09), 0.03, 0.04, 0.15, 0.03, 0.3), 0.0)
    return b

RECIPES_P12 = {
    "hover": r_hover, "shot_electric": r_shot_electric, "shot_ice": r_shot_ice,
    "shot_psychic": r_shot_psychic, "shot_ghost": r_shot_ghost,
    "beam": r_beam, "beam_ice": r_beam_ice, "cone_fire": r_cone_fire,
    "cone_other": r_cone_other, "nova": r_nova, "nova_ground": r_nova_ground,
    "dodge": r_dodge, "land": r_land, "dive": r_dive, "slam": r_slam,
    "encounter": r_encounter, "throw_ball": r_throw_ball,
    "ball_open": r_ball_open, "ball_shake": r_ball_shake,
    "slot_tick": r_slot_tick, "slot_lever": r_slot_lever,
    "slot_stop": r_slot_stop, "slot_coins": r_slot_coins,
    "slot_curse": r_slot_curse, "jackpot": r_jackpot, "zap": r_zap,
    "evolve_done": r_evolve_done, "streak": r_streak,
    "confirm": r_confirm, "start": r_start, "panel_open": r_panel_open,
    "panel_close": r_panel_close, "buff": r_buff, "chest_gold": r_chest_gold,
    "mimic": r_mimic, "ult_ready": r_ult_ready, "revive": r_revive,
    "rage": r_rage, "boss_down": r_boss_down, "banish": r_banish,
    "shiny_spawn": r_shiny_spawn, "terminal": r_terminal, "greet": r_greet,
}

# ------------------------------------------------- ambience (stereo OGG loops)
# EN-01 / EN-02: synthesized beds, looped by blending the tail into the
# head content. Encoded OGG Vorbis q6 per the format ruling for loops.

LOOP_FADE = 2.0  # seconds of head crossfade

def _loop_mix(s, dur):
    """Seamless whole-file loop of length `dur` from stream s (which is
    LOOP_FADE seconds longer): the head crossfades in from the stream's
    own continuation, so the pure-stream tail flows straight into it."""
    n = int(SR * dur)
    f = int(LOOP_FADE * SR)
    out = s[:n].copy()
    w = np.linspace(0, 1, f)
    out[:f] = s[:f] * w + s[n:n + f] * (1 - w)
    return out

def _place_stereo(out, seg, at, pan):
    place(out[:, 0], seg * (1 - pan), at)
    place(out[:, 1], seg * pan, at)

def _bed_pair(dur, seed):
    """Decorrelated stereo noise pair."""
    r = np.random.default_rng(seed)
    return r.standard_normal(int(SR * dur)), r.standard_normal(int(SR * dur))

def r_amb_forest():  # EN-01 forest bed: leaves + sparse birds, very quiet
    dur = 24.0
    ext = dur + LOOP_FADE
    tt = np.arange(int(SR * ext)) / SR
    wl, wr = _bed_pair(ext, 101)
    lfo_l = 0.75 + 0.25 * np.sin(2 * np.pi * tt / 12.0)
    lfo_r = 0.75 + 0.25 * np.sin(2 * np.pi * tt / 12.0 + 1.1)
    left = _loop_mix(filt(wl, "low", 480) * 1.4 * lfo_l, dur)
    right = _loop_mix(filt(wr, "low", 480) * 1.4 * lfo_r, dur)
    out = np.stack([left, right], axis=1)
    chirp_rng = np.random.default_rng(7)
    for _ in range(9):  # birds stay clear of the wrap zones
        at = chirp_rng.uniform(LOOP_FADE + 0.6, dur - LOOP_FADE - 0.6)
        f0 = chirp_rng.uniform(2300, 2900)
        seg = sine(f0, 0.14, glide_to=f0 * 1.25) * exp_env(int(SR * 0.14), 0.05, 0.10)
        _place_stereo(out, seg * 0.5, at, chirp_rng.uniform(0.25, 0.75))
    return out

def r_amb_rain():  # EN-02 rain bed: steady wash + sparse droplets
    dur = 20.0
    ext = dur + LOOP_FADE
    wl, wr = _bed_pair(ext, 202)
    left = _loop_mix(band(wl, 420, 3400) * 0.8 + filt(wl, "low", 220) * 0.9, dur)
    right = _loop_mix(band(wr, 420, 3400) * 0.8 + filt(wr, "low", 220) * 0.9, dur)
    out = np.stack([left, right], axis=1)
    drop_rng = np.random.default_rng(11)
    for _ in range(46):
        at = drop_rng.uniform(LOOP_FADE + 0.5, dur - LOOP_FADE - 0.5)
        f0 = drop_rng.uniform(1750, 2650)
        seg = sine(f0, 0.03) * exp_env(int(SR * 0.03), 0.008, 0.14)
        _place_stereo(out, seg, at, drop_rng.uniform(0.15, 0.85))
    return out

def r_amb_wind():  # EN-02 wind / fog bed: slow gusting bands
    dur = 22.0
    ext = dur + LOOP_FADE
    tt = np.arange(int(SR * ext)) / SR
    wl, wr = _bed_pair(ext, 303)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * tt / 11.0) ** 2
    gust_r = 0.55 + 0.45 * np.sin(2 * np.pi * tt / 11.0 + 0.7) ** 2
    left = _loop_mix(band(wl, 190, 880) * gust * 1.2, dur)
    right = _loop_mix(band(wr, 190, 880) * gust_r * 1.2, dur)
    return np.stack([left, right], axis=1)

AMBIENCE = {"amb_forest": r_amb_forest, "amb_rain": r_amb_rain, "amb_wind": r_amb_wind}

def _render_ambience(key):
    import subprocess, tempfile, os
    x = np.asarray(AMBIENCE[key](), dtype=np.float64)
    pk = np.max(np.abs(x)) + 1e-12
    x = (x / pk * 0.5 * 32767).astype(np.int16)  # beds sit well under SFX
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, key + ".wav")
        wavfile.write(tmp, SR, x)
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp,
                        "-codec:a", "libvorbis", "-q:a", "6",
                        str(OUT / f"{key}.ogg")], check=True)
    print(f"{key:14s} {len(x) / SR:5.1f}s loop (ogg q6)")

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
    global RECIPES
    RECIPES = {**RECIPES, **RECIPES_P12}
    keys = sys.argv[1:] or list(RECIPES) + list(AMBIENCE)
    OUT.mkdir(parents=True, exist_ok=True)
    for k in keys:
        if k in AMBIENCE:
            _render_ambience(k)
            continue
        data = finish(RECIPES[k]())
        wavfile.write(OUT / f"{k}.wav", SR, data)
        dur = len(data) / SR
        print(f"{k:14s} {dur:5.2f}s  peak {np.max(np.abs(data))/32767:.2f}")

if __name__ == "__main__":
    main()
