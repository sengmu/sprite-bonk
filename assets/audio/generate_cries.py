#!/usr/bin/env python3
"""Original partner cries for SpriteBonk — procedural voice casting.

Replaces the legacy hash chirps (22050 Hz structural placeholders)
with an original cry for every species the game can field: the 159
species of the 79 roster families (all evolution stages), plus
three generic fallbacks for unlisted ids.

Voice-casting system (all synthesis is original, designed here):
- A family's voice is seeded by its family id, so relatives share a
  recognisable motif (syllable pattern, contour, wobble).
- Each species' pitch register comes from its body size (weight /
  height from the game data): big bodies call low, small ones high.
  Later evolution stages sit lower and call longer than their young.
- Timbre flavour comes from the species' primary type (17 flavours:
  bubbly water, buzzy electric, gravelly rock, eerie ghost, ...).
- The three starter families (1 / 4 / 7) are hand-designed around
  their shipped redesigns: hollow-stump puppet (wood knock + a
  muffled chirp from inside), cold-charcoal beast (breathy growl
  with ember crackle), counter-rotating bivalve (spinning bubble
  whistle with a shell clack).

Delivery: WAV 16-bit / 44.1 kHz / mono, peak 0.89 (-1 dBFS),
RMS-balanced so no species is whisper-quiet next to another.

Usage: python3 generate_cries.py [key ...]   (default: all)
Output: assets/audio/sfx/cry_<key>.wav, cry_fallback_{s,m,l}.wav
"""
import hashlib
import json
import os
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SFX_DIR = os.path.join(HERE, "sfx")
DATA = os.path.join(HERE, "..", "data")


def seed_of(text):
    return int.from_bytes(hashlib.md5(text.encode()).digest()[:6], "little")


def write_wav(path, x):
    x = np.clip(x, -1.0, 1.0)
    peak = np.max(np.abs(x))
    if peak > 0:
        x = x * (0.89 / max(peak, 0.89)) if peak > 0.89 else x
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def balance(x, target_rms=0.16):
    """RMS-balance toward a common level under the peak ceiling."""
    rms = float(np.sqrt(np.mean(x ** 2)) + 1e-9)
    g = target_rms / rms
    y = x * g
    peak = np.max(np.abs(y))
    if peak > 0.89:
        y = y * (0.89 / peak)
    return y


# ---------------------------------------------------------------
# Voice primitives. A "voice" renders syllables: each syllable is a
# pitch-glide tone stack with a type flavour applied.
# ---------------------------------------------------------------

def _glide_tone(n, f0, f1, kind):
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / max(n / SR, 1e-3))
    ph = np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(2 * np.pi * ph), f
    if kind == "tri":
        return 2 * np.abs(2 * (ph - np.floor(ph + 0.5))) - 1, f
    if kind == "saw":
        return (2 * (ph - np.floor(ph + 0.5))), f
    if kind == "square":
        return np.sign(np.sin(2 * np.pi * ph)) * 0.7, f
    return np.sin(2 * np.pi * ph), f


def syllable(dur, f0, f1, flavour, rng):
    """One call syllable with a type flavour."""
    n = max(16, int(dur * SR))
    t = np.arange(n) / SR
    atk = min(0.03, dur * 0.25)
    env = np.minimum(1.0, t / max(atk, 1e-3)) * np.exp(-t / (dur * 0.85))
    base_kind = {"rock": "square", "ground": "square", "steel": "square",
                 "electric": "saw", "dark": "saw", "fighting": "square",
                 "bug": "saw"}.get(flavour, "tri")
    if flavour in ("psychic", "ghost", "ice", "fairy", "water"):
        base_kind = "sine"
    x, f = _glide_tone(n, f0, f1, base_kind)
    harm, _ = _glide_tone(n, f0 * 2.0, f1 * 2.0, "sine")
    x = x * 0.8 + harm * 0.25
    if flavour == "water":      # bubbly: fast shallow FM wobble
        wob = 1.0 + 0.06 * np.sin(2 * np.pi * 27 * t)
        x = x * wob + 0.2 * np.sin(2 * np.pi * f * t * 1.5) * env
    elif flavour == "grass":    # chirpy vibrato
        x = x * (1.0 + 0.10 * np.sin(2 * np.pi * 11 * t))
    elif flavour == "fire":     # breathy edge
        nz = rng.standard_normal(n)
        sos = signal.butter(2, [900, 4200], "bandpass", fs=SR, output="sos")
        x = x + signal.sosfilt(sos, nz) * 0.35 * env
    elif flavour == "electric":  # buzzy tremolo
        x = x * (0.65 + 0.35 * np.sign(np.sin(2 * np.pi * 42 * t)))
    elif flavour in ("rock", "ground", "steel"):  # gravel
        nz = rng.standard_normal(n)
        sos = signal.butter(2, 500, "low", fs=SR, output="sos")
        x = x * 0.85 + signal.sosfilt(sos, nz) * 0.8 * env
    elif flavour in ("psychic", "ghost"):  # eerie detuned fifth
        fifth, _ = _glide_tone(n, f0 * 1.5, f1 * 1.5, "sine")
        x = x * 0.7 + fifth * 0.45
        env = np.minimum(1.0, t / max(dur * 0.4, 1e-3)) * np.exp(-t / (dur * 1.2))
    elif flavour == "bug":      # trill gating
        x = x * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 38 * t)))
    elif flavour == "ice":      # crystalline shimmer harmonic
        ping, _ = _glide_tone(n, f0 * 3.0, f1 * 3.0, "sine")
        x = x + ping * 0.3 * np.exp(-t / 0.06)
    elif flavour == "fairy":    # bell-bright
        ping, _ = _glide_tone(n, f0 * 2.76, f1 * 2.76, "sine")
        x = x + ping * 0.22
    elif flavour == "dragon":   # resonant depth: sub octave
        sub, _ = _glide_tone(n, f0 * 0.5, f1 * 0.5, "sine")
        x = x * 0.75 + sub * 0.5
    elif flavour == "dark":     # rough AM growl
        x = x * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * t))
    return x * env


def render_voice(base, n_syl, contour, flavour, rng, syl_dur=0.16,
                 gap=0.06, stage=0):
    """Assemble syllables into one cry."""
    parts = []
    f = base
    for i in range(n_syl):
        kind = contour[i % len(contour)]
        ratio = {"up": 1.28, "down": 0.78, "updown": 1.0,
                 "downup": 1.0, "flat": 1.04}[kind]
        f1 = f * ratio
        s = syllable(syl_dur * (1.0 + 0.12 * i), f, f1, flavour, rng)
        if kind == "updown":
            s = s * np.concatenate([np.linspace(0.6, 1.0, len(s) // 2),
                                    np.linspace(1.0, 0.55, len(s) - len(s) // 2)])
        parts.append(s)
        parts.append(np.zeros(int(gap * SR)))
        f = f * (0.94 if i % 2 == 0 else 1.05)
    x = np.concatenate(parts) if parts else np.zeros(1)
    return x


# ---------------------------------------------------------------
# Hand-designed starter families (shipped redesign identities).
# ---------------------------------------------------------------

def stump_cry(stage, rng):
    """Family 1, hollow-stump puppet: a wooden knock, then a muffled
    two-note chirp from inside the hollow."""
    base = [560.0, 470.0, 390.0][stage]
    dur_knock = 0.07
    n = int(dur_knock * SR)
    t = np.arange(n) / SR
    knock = (np.sin(2 * np.pi * (170 - 40 * stage) * t) * np.exp(-t / 0.02)
             + rng.standard_normal(n) * 0.4 * np.exp(-t / 0.008))
    chirp = syllable(0.17 + 0.04 * stage, base, base * 1.18, "grass", rng)
    chirp2 = syllable(0.2 + 0.05 * stage, base * 0.9, base * 0.8, "grass", rng)
    sos = signal.butter(2, 1500, "low", fs=SR, output="sos")  # muffled
    chirp = signal.sosfilt(sos, chirp) * 1.6
    chirp2 = signal.sosfilt(sos, chirp2) * 1.6
    return np.concatenate([knock * 0.7, np.zeros(int(0.07 * SR)),
                           chirp, np.zeros(int(0.05 * SR)), chirp2])


def charcoal_cry(stage, rng):
    """Family 4, cold-charcoal beast: breathy low growl with ember
    crackle; at rest it barely sounds — the call swells open."""
    base = [300.0, 245.0, 195.0][stage]
    dur = 0.5 + 0.16 * stage
    n = int(dur * SR)
    t = np.arange(n) / SR
    x, _ = _glide_tone(n, base * 0.8, base * 1.1, "saw")
    sos = signal.butter(2, 700, "low", fs=SR, output="sos")
    x = signal.sosfilt(sos, x) * 1.4
    env = (t / dur) ** 1.5 * np.exp(-np.maximum(0.0, t - dur * 0.75) / 0.08)
    x = x * env * (0.75 + 0.25 * np.sin(2 * np.pi * 17 * t))
    sos_pop = signal.butter(2, 2200, "low", fs=SR, output="sos")
    for _ in range(5 + 4 * stage):  # ember crackle pops (low, woody)
        at = rng.uniform(0.05, dur - 0.03)
        ln = int(0.008 * SR)
        i0 = int(at * SR)
        pop = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (0.002 * SR))
        x[i0:i0 + ln] += signal.sosfilt(sos_pop, pop) * 0.55
    nz = rng.standard_normal(n)
    sos2 = signal.butter(2, [600, 2600], "bandpass", fs=SR, output="sos")
    x += signal.sosfilt(sos2, nz) * 0.10 * env
    return x


def bivalve_cry(stage, rng):
    """Family 7, counter-rotating bivalve: a shell clack, then a
    spinning bubble whistle (rotation slows as it grows)."""
    base = [640.0, 520.0, 430.0][stage]
    clack_n = int(0.03 * SR)
    t = np.arange(clack_n) / SR
    clack = rng.standard_normal(clack_n) * np.exp(-t / 0.006) * 0.8
    dur = 0.42 + 0.1 * stage
    n = int(dur * SR)
    tt = np.arange(n) / SR
    rot = [26.0, 20.0, 15.0][stage]
    f = base * (1.0 + 0.15 * np.sin(2 * np.pi * (rot / 6.0) * tt))
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph) * (0.7 + 0.3 * np.sin(2 * np.pi * rot * tt))
    env = np.minimum(1.0, tt / 0.04) * np.exp(-tt / (dur * 0.8))
    return np.concatenate([clack, np.zeros(int(0.05 * SR)), x * env])


STARTER_BUILDERS = {1: stump_cry, 4: charcoal_cry, 7: bivalve_cry}


# ---------------------------------------------------------------
# Parametric casting for the remaining families.
# ---------------------------------------------------------------

CONTOURS = [["up", "down"], ["down", "up"], ["updown"], ["up", "up", "down"],
            ["down"], ["up", "downup"], ["flat", "up"], ["down", "down", "up"]]


def base_freq(weight_hg, height_dm, all_weights):
    """Pitch register from body size, percentile-mapped over the set."""
    w = np.log(max(weight_hg, 1) + 5.0)
    lo, hi = np.log(np.min(all_weights) + 5.0), np.log(np.max(all_weights) + 5.0)
    pct = (w - lo) / max(hi - lo, 1e-6)
    return float(880.0 * (175.0 / 880.0) ** pct)  # 880 Hz tiny -> 175 Hz huge


def species_cry(sp, fam_seed, all_weights):
    rng = np.random.default_rng(fam_seed)
    contour = CONTOURS[rng.integers(0, len(CONTOURS))]
    wobble = float(rng.uniform(0.9, 1.1))
    stage = int(sp["evoStage"])
    base = base_freq(sp["weight"], sp["height"], all_weights) * wobble
    base *= (0.93 ** stage)                       # grown forms sit lower
    n_syl = int(min(3, 1 + stage + int(rng.integers(0, 2))))
    syl_dur = float(rng.uniform(0.12, 0.19)) * (1.0 + 0.18 * stage)
    flavour = sp["types"][0]
    rng_sp = np.random.default_rng(seed_of(sp["key"]))
    x = render_voice(base, n_syl, contour, flavour, rng_sp, syl_dur,
                     gap=float(rng.uniform(0.045, 0.085)), stage=stage)
    if sp.get("legendary") or sp.get("mythical"):  # shimmer echo
        d = int(0.09 * SR)
        echo = np.concatenate([np.zeros(d), x * 0.35])[:len(x)]
        x = x + echo
    return balance(x)


def main():
    poke = json.load(open(os.path.join(DATA, "pokemon.json")))
    roster = json.load(open(os.path.join(DATA, "roster.json")))
    fams = set(int(k) for k in roster.keys())
    fielded = [p for p in poke if p["family"] in fams]
    all_weights = np.array([p["weight"] for p in fielded], dtype=float)
    only = set(sys.argv[1:])
    os.makedirs(SFX_DIR, exist_ok=True)
    stats = []
    for sp in fielded:
        key = sp["key"]
        if only and key not in only:
            continue
        fam = int(sp["family"])
        stage = int(sp["evoStage"])
        if fam in STARTER_BUILDERS:
            rng = np.random.default_rng(seed_of(key))
            x = balance(STARTER_BUILDERS[fam](stage, rng),
                        target_rms=0.17)
        else:
            x = species_cry(sp, seed_of(f"family:{fam}"), all_weights)
        path = os.path.join(SFX_DIR, f"cry_{key}.wav")
        write_wav(path, x)
        stats.append((key, len(x) / SR, float(np.max(np.abs(x)))))
    if not only:
        for name, base, fl in (("cry_fallback_s", 760.0, "normal"),
                               ("cry_fallback_m", 430.0, "normal"),
                               ("cry_fallback_l", 210.0, "normal")):
            rng = np.random.default_rng(seed_of(name))
            x = balance(render_voice(base, 2, ["up", "down"], fl, rng,
                                     syl_dur=0.15))
            write_wav(os.path.join(SFX_DIR, name + ".wav"), x)
    durs = [d for _, d, _ in stats]
    print(f"cries: {len(stats)} files, dur {min(durs):.2f}-{max(durs):.2f}s, "
          f"peak max {max(p for _, _, p in stats):.3f}")


if __name__ == "__main__":
    main()
