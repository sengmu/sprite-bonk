#!/usr/bin/env python3
"""Original BGM loops for SpriteBonk — parametric composition + synthesis.

Replaces the legacy sequencer renders (11025 Hz / 8-bit, mined from the
original game's sequencer design) with fully original compositions
rendered at 44.1 kHz stereo and encoded as OGG Vorbis q6.

Every melody, progression voicing, bass line and drum pattern below is
an original composition written for this game (requirements list
BGM-01..04 style notes: menu = light low-poly forest feel; ingame =
rhythm-driven, loopable; boss = tense and pressing). No note data is
taken from any existing work.

Engineering notes (the "does not clip / does not grate" contract):
- Wrap-add rendering: every event is added into the loop buffer with
  indices modulo the loop length, so pad tails and delays cross the
  loop seam exactly — the loop is seamless by construction.
- Conservative layer gains, final peak normalised to 0.89 (-1 dBFS),
  integrated loudness adjusted to about -16 LUFS (K-weighted).
- Stereo: pads spread, hats alternate, melody near centre with a
  cyclic feedback delay for space.

Usage: python3 generate_bgm.py [track ...]   (default: all)
Output: assets/audio/music/bgm_<name>.ogg (+ .wav kept beside it)
"""
import os
import subprocess
import sys

import numpy as np
from scipy import ndimage, signal

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "music")
PEAK = 0.89
rng = np.random.default_rng(20261111)


def midi_f(m):
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


class Loop:
    """Stereo loop buffer with wrap-add event rendering."""

    def __init__(self, bpm, bars):
        self.bpm = bpm
        self.bars = bars
        self.beat = 60.0 / bpm
        self.dur = bars * 4 * self.beat
        self.n = int(round(self.dur * SR))
        self.buf = np.zeros((self.n, 2))

    def _add(self, sig, at_sec, pan):
        """Add mono signal at time at_sec (wraps around the loop)."""
        start = int(round(at_sec * SR)) % self.n
        idx = (start + np.arange(len(sig))) % self.n
        g_l = np.cos((pan + 1.0) * np.pi / 4.0)
        g_r = np.sin((pan + 1.0) * np.pi / 4.0)
        np.add.at(self.buf[:, 0], idx, sig * g_l)
        np.add.at(self.buf[:, 1], idx, sig * g_r)

    # ---- voices -------------------------------------------------
    def tone(self, at, midi, dur, gain=0.2, kind="tri", pan=0.0,
             attack=0.01, decay=None, slide_to=None):
        n = max(2, int(dur * SR))
        t = np.arange(n) / SR
        f0 = midi_f(midi)
        if slide_to is not None:
            f = f0 * (midi_f(slide_to) / f0) ** (t / max(dur, 1e-3))
            ph = np.cumsum(f) / SR
        else:
            ph = f0 * t
        if kind == "sine":
            x = np.sin(2 * np.pi * ph)
        elif kind == "tri":
            x = 2 * np.abs(2 * (ph - np.floor(ph + 0.5))) - 1
        elif kind == "square":
            x = np.sign(np.sin(2 * np.pi * ph)) * 0.6
        elif kind == "saw":
            x = 2 * (ph - np.floor(ph + 0.5))
        else:
            x = np.sin(2 * np.pi * ph)
        if decay is None:
            env = np.minimum(1.0, t / max(attack, 1e-3))
            env *= np.exp(-t / max(dur * 0.9, 0.05)) * 0.7 + 0.3 * np.exp(-t / 0.08)
            env = np.minimum(env, 1.0)
        else:
            env = np.minimum(1.0, t / max(attack, 1e-3)) * np.exp(-t / decay)
        self._add(x * env * gain, at, pan)

    def pad(self, at, midis, dur, gain=0.05, pan=0.0):
        """Detuned saw stack through a gentle lowpass, slow swell."""
        n = max(2, int(dur * SR))
        t = np.arange(n) / SR
        env = np.minimum(1.0, t / 0.6) * np.minimum(1.0, (dur - t) / 0.6)
        for i, m in enumerate(midis):
            f = midi_f(m)
            for det in (-5.0, 0.0, 5.0):
                ph = f * (2 ** (det / 1200.0)) * t
                x = 2 * (ph - np.floor(ph + 0.5))
                b, a = signal.butter(1, 1100, "low", fs=SR)
                x = signal.lfilter(b, a, x)
                self._add(x * env * gain / 3.0, at,
                          pan + (-0.35 + 0.35 * i))

    def noise_hit(self, at, dur, gain, ftype, freq, pan=0.0, decay=None):
        n = max(2, int(dur * SR))
        t = np.arange(n) / SR
        x = rng.standard_normal(n)
        wn = freq
        if ftype == "bandpass":
            wn = [freq * 0.6, min(freq * 1.6, SR * 0.49)]
        sos = signal.butter(2, wn, ftype, fs=SR, output="sos")
        x = signal.sosfilt(sos, x)
        x /= (np.max(np.abs(x)) + 1e-9)
        env = np.exp(-t / (decay if decay else dur * 0.35))
        self._add(x * env * gain, at, pan)

    def kick(self, at, gain=0.5):
        n = int(0.24 * SR)
        t = np.arange(n) / SR
        f = 46.0 + 84.0 * np.exp(-t / 0.03)
        ph = np.cumsum(f) / SR
        x = np.sin(2 * np.pi * ph) * np.exp(-t / 0.09)
        self._add(x * gain, at, 0.0)

    def snare(self, at, gain=0.22):
        self.noise_hit(at, 0.16, gain, "bandpass", 1900, decay=0.045)
        self.tone(at, 44, 0.07, gain * 0.5, "tri", decay=0.03)

    # ---- finishing ----------------------------------------------
    def add_delay(self, mix_from=0.0, delay_beats=0.75, fb=0.26, wet=0.10):
        """Cyclic feedback delay over the whole loop (seamless)."""
        d = int(round(delay_beats * self.beat * SR)) % self.n
        src = self.buf.copy()
        idx = np.arange(self.n)
        acc = np.zeros_like(src)
        cur = src
        g = wet
        for _ in range(4):
            acc += np.roll(cur, d) * g
            cur = np.roll(cur, d) * fb
            g *= fb
        self.buf += acc

    def finish(self):
        """Drive + peak-limit to the ceiling, then loudness-trim.

        The raw layer sums are peaky (kick transients) with a quiet
        body; a plain peak normalise leaves the loop far too quiet.
        So: drive the mix up, hold peaks with a smoothed limiter at
        the -1 dBFS ceiling, then trim to about -16 LUFS.
        """
        x = self.buf * 1.8
        x = _limit(x, 0.85)
        lufs = k_loudness(x)
        # k_loudness under-reads ffmpeg's BS.1770 by ~12.1 dB on these
        # mixes (calibrated 2026-11-11 against loudnorm on 3 tracks),
        # so the in-script target is -16 - 12.1 in estimator units.
        g = 10 ** ((-28.1 - lufs) / 20.0)
        if g > 1.0:
            x = _limit(x * g, 0.85)
        elif g < 1.0:
            x = x * g
        return x, k_loudness(x), float(np.max(np.abs(x)))


def _limit(x, ceiling):
    """Lookahead-style peak limiter: smoothed gain from a peak envelope."""
    env = np.max(np.abs(x), axis=1)
    env = ndimage.maximum_filter1d(env, size=int(0.004 * SR), mode="nearest")
    a = np.exp(-1.0 / (0.12 * SR))  # ~120 ms release tail
    env_lp = signal.lfilter([1 - a], [1, -a], env)
    sm = np.maximum(env, env_lp)
    gain = np.minimum(1.0, ceiling / np.maximum(sm, 1e-9))
    b, aa = signal.butter(1, 900, "low", fs=SR)  # de-zipper the gain
    gain = np.minimum(signal.lfilter(b, aa, gain), 1.0)
    return x * gain[:, None]


def k_loudness(x):
    """ITU-R BS.1770-ish integrated loudness (ungated approximation)."""
    b1, a1 = signal.butter(1, 1680, "high", fs=SR)  # shelf approx via hp
    y = x.copy()
    for ch in range(2):
        y[:, ch] = signal.lfilter(b1, a1, y[:, ch])
    ms = np.mean(y ** 2)
    return 10 * np.log10(ms + 1e-12) - 0.691 + 3.0  # rough K offset


def seam_step(x):
    d = np.abs(x[0] - x[-1]).max()
    internal = np.abs(np.diff(x[:, 0])).max()
    return float(d), float(internal)


def render(name, build_fn):
    loop = build_fn()
    x, lufs, peak = loop.finish()
    os.makedirs(OUT_DIR, exist_ok=True)
    wav = os.path.join(OUT_DIR, f"bgm_{name}.wav")
    ogg = os.path.join(OUT_DIR, f"bgm_{name}.ogg")
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                    "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)
    d, internal = seam_step(x)
    clipped = int(np.sum(np.abs(x) >= 0.999))
    print(f"{name}: {loop.dur:.1f}s peak={peak:.3f} lufs~{lufs:.1f} "
          f"seam={d:.5f} (max internal step {internal:.5f}) clipped={clipped} "
          f"ogg={os.path.getsize(ogg)}B")
    return ogg


# ---------------------------------------------------------------
# Compositions. Melody events are (bar, beat, midi, len_beats),
# all lines written for this game. Chords are pad voicings + a
# bass root per bar.
# ---------------------------------------------------------------

def _shift(events, bars, replace=None):
    """Shift a phrase by N bars; replace={bar: events} swaps whole bars."""
    out = [(b + bars, bt, n, ln) for (b, bt, n, ln) in events
           if not replace or (b + bars) not in replace]
    if replace:
        for bar, evs in replace.items():
            out += evs
    return out


def _melody(loop, events, gain, kind="tri", decay=0.42, pan=0.0):
    for bar, beat, midi, ln in events:
        loop.tone(bar * 4 * loop.beat + beat * loop.beat, midi,
                  ln * loop.beat, gain, kind, pan=pan, decay=decay)


def _pads(loop, voicings, gain=0.05):
    for bar, v in enumerate(voicings):
        loop.pad(bar * 4 * loop.beat, v, 4 * loop.beat, gain)


def _bass_line(loop, roots, pattern, gain=0.30, decay=0.16, kind="tri"):
    """pattern: list of (beat, semitone_offset)."""
    for bar, root in enumerate(roots):
        for beat, off in pattern:
            loop.tone(bar * 4 * loop.beat + beat * loop.beat, root + off,
                      0.5 * loop.beat, gain, kind, decay=decay)


def build_menu():
    lp = Loop(92.0, 8)
    chords = [[62, 66, 69], [59, 62, 66], [59, 62, 67], [57, 61, 64],
              [62, 66, 69], [59, 62, 66], [59, 62, 67], [57, 61, 64]]
    _pads(lp, chords, 0.045)
    _bass_line(lp, [38, 35, 43, 45] * 2, [(0, 0), (2, 0)], 0.26, 0.5)
    mel = [
        (0, 0, 69, 1), (0, 1, 66, .5), (0, 1.5, 69, .5), (0, 2, 74, 1.5), (0, 3.5, 73, .5),
        (1, 0, 71, 1.5), (1, 1.5, 69, .5), (1, 2, 66, 2),
        (2, 0, 67, 1), (2, 1, 71, 1), (2, 2, 74, 1), (2, 3, 71, 1),
        (3, 0, 69, 2), (3, 2, 76, 1), (3, 3, 73, 1),
        (4, 0, 69, 1), (4, 1, 66, .5), (4, 1.5, 69, .5), (4, 2, 74, 1.5), (4, 3.5, 73, .5),
        (5, 0, 71, 1.5), (5, 1.5, 74, .5), (5, 2, 78, 2),
        (6, 0, 67, 1), (6, 1, 71, 1), (6, 2, 74, 1), (6, 3, 71, 1),
        (7, 0, 69, 1), (7, 1, 73, 1), (7, 2, 76, 2),
    ]
    _melody(lp, mel, 0.24, "tri", 0.55)
    for bar in (2, 6):  # sparse high pings, forest sparkle
        lp.tone(bar * 4 * lp.beat + 3 * lp.beat, 86, lp.beat, 0.045,
                "sine", decay=0.7)
    lp.add_delay(wet=0.09)
    for bar in range(8):  # soft pulse: kick on 1, shaker 8ths
        lp.kick(bar * 4 * lp.beat, 0.16)
        for s in range(8):
            lp.noise_hit(bar * 4 * lp.beat + s * 0.5 * lp.beat, 0.05,
                         0.045, "highpass", 7200, decay=0.02)
    return lp


def _ingame1(shift=0):
    lp = Loop(116.0, 16)
    cyc_v = [[59, 62, 67], [59, 64, 67], [60, 64, 67], [62, 66, 69]]
    cyc_b = [43, 40, 36, 38]
    _pads(lp, [[n + shift for n in v] for v in cyc_v * 4], 0.042)
    _bass_line(lp, [r + shift for r in cyc_b * 4],
               [(0, 0), (0.5, 0), (1, 12), (1.5, 0),
                (2, 0), (2.5, 12), (3, 0), (3.5, 7)], 0.30, 0.15)
    A = [
        (0, 0, 67, .5), (0, .5, 71, .5), (0, 1, 74, 1), (0, 2, 71, .5), (0, 2.5, 67, .5), (0, 3, 69, 1),
        (1, 0, 76, 1.5), (1, 1.5, 74, .5), (1, 2, 71, 1), (1, 3, 67, 1),
        (2, 0, 72, .5), (2, .5, 76, .5), (2, 1, 79, 1), (2, 2, 76, 1), (2, 3, 74, 1),
        (3, 0, 74, 1), (3, 1, 69, 1), (3, 2, 78, 2),
    ]
    A2 = _shift(A, 4, replace={7: [(7, 0, 74, 1), (7, 1, 78, 1),
                                   (7, 2, 79, 2)]})
    B = [
        (8, 0, 71, .5), (8, .5, 74, .5), (8, 1, 79, .5), (8, 1.5, 74, .5), (8, 2, 71, 1), (8, 3, 74, 1),
        (9, 0, 76, 1), (9, 1, 79, 1), (9, 2, 83, 1.5), (9, 3.5, 81, .5),
        (10, 0, 79, 1), (10, 1, 76, 1), (10, 2, 72, 1), (10, 3, 74, 1),
        (11, 0, 78, 1.5), (11, 1.5, 81, .5), (11, 2, 86, 2),
    ]
    A3 = _shift(A, 12, replace={15: [(15, 0, 71, 1), (15, 1, 74, 1),
                                     (15, 2, 79, 1.5), (15, 3.5, 78, .5)]})
    mel = [(b, bt, n + shift, ln) for (b, bt, n, ln) in (A + A2 + B + A3)]
    _melody(lp, mel, 0.25, "tri", 0.4)
    for bar in range(9, 16):  # light 16th arp over the back half
        v = cyc_v[bar % 4]
        for s in range(16):
            lp.tone(bar * 4 * lp.beat + s * 0.25 * lp.beat,
                    v[s % 3] + 12 + shift, 0.25 * lp.beat, 0.05,
                    "sine", decay=0.1)
    for bar in range(16):
        for bt in range(4):
            lp.kick(bar * 4 * lp.beat + bt * lp.beat, 0.40)
        lp.snare(bar * 4 * lp.beat + 1 * lp.beat, 0.19)
        lp.snare(bar * 4 * lp.beat + 3 * lp.beat, 0.19)
        for s in range(8):
            lp.noise_hit(bar * 4 * lp.beat + s * 0.5 * lp.beat, 0.04,
                         0.07 if s % 2 else 0.05, "highpass", 8200,
                         pan=0.25 if s % 2 else -0.25, decay=0.015)
    return lp


def _ingame2(shift=0):
    lp = Loop(104.0, 16)
    cyc_v = [[59, 64, 67], [60, 64, 67], [57, 60, 64], [59, 63, 66]]
    cyc_b = [40, 36, 45, 47]
    _pads(lp, [[n + shift for n in v] for v in cyc_v * 4], 0.046)
    _bass_line(lp, [r + shift for r in cyc_b * 4],
               [(0, 0), (1.5, 0), (2, 12), (3.5, 7)], 0.30, 0.3)
    P = [
        (0, 0, 76, 2), (0, 2, 74, .5), (0, 2.5, 72, .5), (0, 3, 71, 1),
        (1, 0, 72, 1.5), (1, 1.5, 74, .5), (1, 2, 76, 2),
        (2, 0, 69, 1), (2, 1, 72, 1), (2, 2, 76, 1), (2, 3, 74, 1),
        (3, 0, 75, 1), (3, 1, 71, 1), (3, 2, 78, 2),
    ]
    P2 = _shift(P, 4, replace={7: [(7, 0, 75, 1), (7, 1, 78, 1),
                                   (7, 2, 83, 2)]})
    V = [
        (8, .5, 76, 1.5), (8, 2, 79, .5), (8, 2.5, 76, .5), (8, 3, 74, 1),
        (9, .5, 72, 1), (9, 1.5, 76, 1), (9, 2.5, 79, 1.5),
        (10, .5, 81, 1.5), (10, 2, 76, .5), (10, 2.5, 74, .5), (10, 3, 72, 1),
        (11, 0, 75, 1), (11, 1, 78, 1), (11, 2, 83, 1), (11, 3, 78, 1),
    ]
    P3 = _shift(P, 12, replace={15: [(15, 0, 76, 2), (15, 2, 71, 2)]})
    mel = [(b, bt, n + shift, ln) for (b, bt, n, ln) in (P + P2 + V + P3)]
    _melody(lp, mel, 0.25, "tri", 0.5)
    for bar in range(4, 16):  # 8th-note chord arp, triangle
        v = cyc_v[bar % 4]
        for s in range(8):
            lp.tone(bar * 4 * lp.beat + s * 0.5 * lp.beat,
                    v[[0, 1, 2, 1][s % 4]] + 12 + shift, 0.5 * lp.beat,
                    0.055, "tri", decay=0.12)
    lp.add_delay(wet=0.08)
    for bar in range(16):
        lp.kick(bar * 4 * lp.beat, 0.38)
        lp.kick(bar * 4 * lp.beat + 2.5 * lp.beat, 0.38)
        lp.snare(bar * 4 * lp.beat + 1 * lp.beat, 0.19)
        lp.snare(bar * 4 * lp.beat + 3 * lp.beat, 0.19)
        for s in range(8):
            lp.noise_hit(bar * 4 * lp.beat + s * 0.5 * lp.beat, 0.04,
                         0.045, "highpass", 7800, decay=0.015)
    return lp


def build_boss():
    lp = Loop(132.0, 8)
    prog = [[62, 65, 69], [62, 65, 69], [58, 62, 65], [57, 61, 64],
            [62, 65, 69], [62, 65, 69], [58, 62, 65], [57, 61, 64]]
    roots = [38, 38, 46, 45, 38, 38, 46, 45]
    for bar in range(8):
        at = bar * 4 * lp.beat
        lp.tone(at, roots[bar] - 12 if roots[bar] > 40 else roots[bar],
                4 * lp.beat, 0.10, "sine", attack=0.05, decay=3.0)
        for bt in (0, 1.5):  # chord stabs
            for n in prog[bar]:
                lp.tone(at + bt * lp.beat, n, 0.5 * lp.beat, 0.085,
                        "saw", decay=0.16)
        for s in range(8):  # driving 8th bass ostinato
            lp.tone(at + s * 0.5 * lp.beat,
                    roots[bar] + (12 if s == 7 else 0), 0.5 * lp.beat,
                    0.30, "tri", decay=0.10)
    mel = [
        (0, 0, 74, .5), (0, .5, 74, .5), (0, 1, 77, .5), (0, 1.5, 74, .5), (0, 2, 72, .5), (0, 2.5, 74, .5), (0, 3, 69, 1),
        (1, 0, 74, .5), (1, .5, 77, .5), (1, 1, 81, 1), (1, 2, 77, .5), (1, 2.5, 74, .5), (1, 3, 70, 1),
        (2, 0, 70, 1), (2, 1, 74, 1), (2, 2, 77, 1.5), (2, 3.5, 75, .5),
        (3, 0, 73, 1), (3, 1, 76, 1), (3, 2, 81, 2),
        (4, 0, 74, .5), (4, .5, 74, .5), (4, 1, 77, .5), (4, 1.5, 74, .5), (4, 2, 72, .5), (4, 2.5, 74, .5), (4, 3, 69, 1),
        (5, 0, 74, .5), (5, .5, 77, .5), (5, 1, 81, 1), (5, 2, 77, .5), (5, 2.5, 74, .5), (5, 3, 72, 1),
        (6, 0, 70, 1), (6, 1, 74, 1), (6, 2, 77, 1.5), (6, 3.5, 75, .5),
        (7, 0, 74, .5), (7, .5, 74, .5), (7, 1, 74, .5), (7, 1.5, 74, .5), (7, 2, 77, 1), (7, 3, 76, 1),
    ]
    _melody(lp, mel, 0.17, "saw", 0.20)
    for bar in range(8):
        at = bar * 4 * lp.beat
        for bt in range(4):
            lp.kick(at + bt * lp.beat, 0.44)
        lp.snare(at + 1 * lp.beat, 0.21)
        lp.snare(at + 3 * lp.beat, 0.21)
        lp.snare(at + 3.5 * lp.beat, 0.11)
        for s in range(16):
            lp.noise_hit(at + s * 0.25 * lp.beat, 0.03, 0.032,
                         "highpass", 8600, pan=0.3 if s % 2 else -0.3,
                         decay=0.012)
    lp.noise_hit(0, 0.5, 0.10, "bandpass", 5200, decay=0.3)  # crash
    return lp


BUILDERS = {
    "menu": build_menu,
    "ingame1": lambda: _ingame1(0),
    "ingame2": lambda: _ingame2(0),
    "ingame3": lambda: _ingame1(2),    # listed variant scheme: transposed
    "ingame4": lambda: _ingame2(-2),  # renders of the two ingame songs
    "boss": build_boss,
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(BUILDERS)
    for nm in names:
        render(nm, BUILDERS[nm])
