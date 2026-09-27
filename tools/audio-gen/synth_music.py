#!/usr/bin/env python3
"""Compose the per-floor, title and ending music offline (no API key) — ADR-0049.

The first five music loops came from ElevenLabs (see generate_music.py), and every
floor shared one combat loop (mus_combat_floor). This script writes the rest of the
soundtrack procedurally so each floor has its own combat track and the title screen
and the ending are no longer silent:

  mus_title           Title / main menu loop. A minor, 84 BPM. Pads, arp, bell line.
  mus_combat_floor2   Floor 2 (Warped Warden). E phrygian, 140 BPM. Wobbling bass.
  mus_combat_floor3   Floor 3 (Cipher Keeper). C# minor, 156 BPM. Power chords.
  mus_ending          Victory / ending cue. D major, 76 BPM. One-shot, rings out.

Floor 1 keeps the original mus_combat_floor loop. Which cue plays where is set in
assets/data/music_playlist.tres, not here.

Loops are rendered twice and the second pass is kept, so echo and reverb tails from
the end of the loop are already present at its start and the loop point is seamless.
The output is deterministic: the same script always writes the same audio.

Requires numpy and lameenc (pip install numpy lameenc).

Usage:
  python3 tools/audio-gen/synth_music.py                 # writes assets/audio/music/*.mp3
  python3 tools/audio-gen/synth_music.py --list          # print the track list only
  python3 tools/audio-gen/synth_music.py --only mus_title
  python3 tools/audio-gen/synth_music.py --wav           # also write .wav previews to --out
"""
import argparse
import os
import sys
import wave

import numpy as np

RATE = 44100
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_OUT = os.path.join(REPO_ROOT, "assets", "audio", "music")
NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
              "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


# ── Pitch helpers ────────────────────────────────────────────────────────────────

def midi(name):
    """'A3' → 57. Accepts sharps and flats ('C#4', 'Bb2')."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


# ── Oscillators and envelopes (numpy, vectorised) ────────────────────────────────

def _t(dur):
    return np.arange(max(1, int(dur * RATE))) / RATE


def osc(freq, dur, shape="saw", vib_hz=0.0, vib_depth=0.0, duty=0.5, glide_from=None):
    """Band-unlimited oscillator. freq in Hz; optional vibrato and glide."""
    t = _t(dur)
    f = np.full(t.shape, float(freq))
    if glide_from is not None:
        g = np.clip(t / 0.06, 0.0, 1.0)
        f = glide_from + (freq - glide_from) * g
    if vib_hz > 0.0:
        f = f * (1.0 + vib_depth * np.sin(2.0 * np.pi * vib_hz * t))
    phase = np.cumsum(f) / RATE
    p = phase % 1.0
    if shape == "sine":
        return np.sin(2.0 * np.pi * p)
    if shape == "square":
        return np.where(p < duty, 1.0, -1.0)
    if shape == "tri":
        return 4.0 * np.abs(p - 0.5) - 1.0
    return 2.0 * p - 1.0  # saw


def adsr(n, a=0.005, d=0.1, s=0.7, r=0.05):
    """Linear ADSR over n samples; release is taken from the end of the note."""
    env = np.full(n, s)
    ai, di, ri = int(a * RATE), int(d * RATE), int(r * RATE)
    ai = min(ai, n)
    env[:ai] = np.linspace(0.0, 1.0, ai, endpoint=False)
    di = min(di, n - ai)
    env[ai:ai + di] = np.linspace(1.0, s, di, endpoint=False)
    ri = min(ri, n)
    if ri > 0:
        env[n - ri:] *= np.linspace(1.0, 0.0, ri)
    return env


def decay(n, seconds):
    """Exponential fall to ~-60 dB over [param seconds]."""
    return np.exp(-6.9 * np.arange(n) / (seconds * RATE))


def lowpass(x, cutoff, order=2):
    """Static low-pass by FFT magnitude shaping (Butterworth-like roll-off)."""
    if len(x) < 4:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spec *= 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2 * order))
    return np.fft.irfft(spec, len(x))


def highpass(x, cutoff, order=2):
    if len(x) < 4:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spec *= 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(spec, len(x))


# ── Instruments — each returns a mono numpy array ───────────────────────────────

def kick(rng, punch=1.0):
    n = int(0.32 * RATE)
    t = np.arange(n) / RATE
    f = 45.0 + 110.0 * np.exp(-t * 28.0)
    body = np.sin(2.0 * np.pi * np.cumsum(f) / RATE) * decay(n, 0.30)
    click = rng.uniform(-1, 1, n) * decay(n, 0.008) * 0.3
    return np.tanh((body + click) * 1.6 * punch)


def snare(rng):
    n = int(0.22 * RATE)
    tone_part = np.sin(2.0 * np.pi * 190.0 * np.arange(n) / RATE) * decay(n, 0.08)
    rattle = highpass(rng.uniform(-1, 1, n), 1200.0) * decay(n, 0.18)
    return 0.45 * tone_part + 0.8 * rattle


def hat(rng, open_hat=False):
    n = int((0.22 if open_hat else 0.05) * RATE)
    return highpass(rng.uniform(-1, 1, n), 6500.0, 3) * decay(n, 0.2 if open_hat else 0.045)


def bass(m, dur, cutoff=900.0, drive=1.8, wobble=0.0):
    x = osc(hz(m), dur, "saw", vib_hz=wobble, vib_depth=0.012 if wobble else 0.0)
    x = x + 0.6 * osc(hz(m - 12), dur, "square")
    x = lowpass(x, cutoff)
    return np.tanh(x * drive) * adsr(len(x), 0.004, 0.08, 0.8, 0.03)


def pluck(m, dur, shape="tri", tail=0.35):
    x = osc(hz(m), dur, shape, duty=0.3)
    return lowpass(x, 3200.0) * decay(len(x), tail) * adsr(len(x), 0.002, 0.0, 1.0, 0.02)


def pad(ms, dur, cutoff=1400.0, attack=0.6):
    x = np.zeros(int(dur * RATE))
    for m in ms:
        for detune in (-0.08, 0.0, 0.08):
            x += osc(hz(m + detune), dur, "saw")[:len(x)]
    x = lowpass(x / (3.0 * len(ms)), cutoff)
    return x * adsr(len(x), attack, 0.3, 0.85, min(0.8, dur * 0.3))


def bell(m, dur):
    n = int(dur * RATE)
    x = osc(hz(m), dur, "sine")[:n] + 0.35 * osc(hz(m) * 2.76, dur, "sine")[:n] \
        + 0.15 * osc(hz(m) * 5.4, dur, "sine")[:n]
    return x * decay(n, max(0.6, dur)) * adsr(n, 0.003, 0.0, 1.0, 0.05)


def lead(m, dur, shape="square", cutoff=3800.0, vib=True, glide_from=None):
    x = osc(hz(m), dur, shape, vib_hz=5.5 if vib else 0.0, vib_depth=0.006, duty=0.35,
            glide_from=hz(glide_from) if glide_from is not None else None)
    return lowpass(x, cutoff) * adsr(len(x), 0.01, 0.12, 0.7, 0.06)


def power_chord(m, dur, drive=4.0):
    x = osc(hz(m), dur, "saw") + osc(hz(m + 7), dur, "saw") + 0.7 * osc(hz(m + 12), dur, "saw")
    x = np.tanh(lowpass(x, 2600.0) * drive) * 0.6
    return x * adsr(len(x), 0.004, 0.1, 0.75, 0.04)


# ── Mixer ─────────────────────────────────────────────────────────────────────────

class Mix:
    """Stereo buses with a send to a shared echo and a shared room reverb."""

    def __init__(self, seconds):
        self.n = int(seconds * RATE) + RATE * 3  # headroom for tails
        self.dry = np.zeros((2, self.n))
        self.echo_send = np.zeros((2, self.n))
        self.verb_send = np.zeros((2, self.n))

    def add(self, sig, at, gain=1.0, pan=0.0, echo=0.0, verb=0.15):
        i = int(at * RATE)
        if i >= self.n:
            return
        sig = sig[: self.n - i] * gain
        left, right = np.sqrt(0.5 * (1.0 - pan)), np.sqrt(0.5 * (1.0 + pan))
        for bus, amt in ((self.dry, 1.0), (self.echo_send, echo), (self.verb_send, verb)):
            if amt <= 0.0:
                continue
            bus[0, i:i + len(sig)] += sig * left * amt
            bus[1, i:i + len(sig)] += sig * right * amt

    def render(self, echo_sec, echo_fb=0.4):
        out = self.dry.copy()
        # Ping-pong echo: alternate channels on each repeat.
        d = int(echo_sec * RATE)
        for k in range(1, 7):
            g = echo_fb ** k
            src = self.echo_send[(k + 1) % 2]
            if d * k >= self.n:
                break
            out[k % 2, d * k:] += lowpass(src[: self.n - d * k], 4500.0 - 400.0 * k) * g
        # Room: a handful of dark, decaying taps (mono-ish, widened by channel offsets).
        taps = [(0.029, 0.55), (0.047, 0.5), (0.071, 0.45), (0.113, 0.38),
                (0.167, 0.3), (0.241, 0.22), (0.353, 0.15), (0.509, 0.09)]
        verb = np.zeros_like(out)
        for idx, (sec, g) in enumerate(taps):
            s = int(sec * RATE)
            ch = idx % 2
            verb[ch, s:] += self.verb_send[ch, : self.n - s] * g
            verb[1 - ch, s + 97:] += self.verb_send[1 - ch, : self.n - s - 97] * g * 0.8
        out += np.stack([lowpass(verb[0], 3000.0), lowpass(verb[1], 3000.0)])
        return out


def finish(stereo, target_rms_db=-16.0, ceiling=0.93, air_hz=9000.0):
    """Tames the top end, loudness-matches to target RMS, then soft-limits under the ceiling."""
    stereo = np.stack([lowpass(stereo[0], air_hz, 1), lowpass(stereo[1], air_hz, 1)])
    rms = np.sqrt(np.mean(stereo ** 2)) + 1e-12
    stereo = stereo * (10.0 ** (target_rms_db / 20.0) / rms)
    return np.tanh(stereo / ceiling) * ceiling


# ── Arrangement helpers ─────────────────────────────────────────────────────────

def chord(root, quality):
    """Root name ('A2') + quality → list of MIDI notes."""
    r = midi(root)
    steps = {"m": [0, 3, 7], "M": [0, 4, 7], "m7": [0, 3, 7, 10], "M7": [0, 4, 7, 11],
             "m9": [0, 3, 7, 10, 14], "sus2": [0, 2, 7], "5": [0, 7, 12], "7": [0, 4, 7, 10]}
    return [r + s for s in steps[quality]]


def drums(mx, rng, bar_t, step, kick_steps, snare_steps, hat_steps, gain=1.0, open_steps=()):
    for s in kick_steps:
        mx.add(kick(rng), bar_t + s * step, 0.9 * gain, 0.0, verb=0.05)
    for s in snare_steps:
        mx.add(snare(rng), bar_t + s * step, 0.55 * gain, 0.05, verb=0.3)
    for s in hat_steps:
        mx.add(hat(rng), bar_t + s * step, 0.11 * gain, 0.35, verb=0.05)
    for s in open_steps:
        mx.add(hat(rng, True), bar_t + s * step, 0.09 * gain, -0.3, verb=0.1)


def loop_render(compose, bars, bpm, echo_div=0.75):
    """Renders two passes of a loop and keeps the second, so tails wrap seamlessly."""
    bar = 4 * 60.0 / bpm
    length = bars * bar
    mx = Mix(2 * length)
    compose(mx, 0.0)
    compose(mx, length)
    out = mx.render(echo_div * 60.0 / bpm)
    i0, i1 = int(length * RATE), int(2 * length * RATE)
    return out[:, i0:i1]


# ── Tracks ────────────────────────────────────────────────────────────────────────

def mus_title():
    """Title / main menu. A minor, 84 BPM, 16 bars. Calm, mysterious, a little hopeful."""
    bpm, bars = 84, 16
    beat = 60.0 / bpm
    bar = 4 * beat
    prog = [("A2", "m9"), ("F2", "M7"), ("D2", "m7"), ("E2", "7")] * 4
    melody = [  # (bar, beat, note, beats) — enters on the second pass of the progression
        (4, 0, "E5", 1.5), (4, 1.5, "C5", 0.5), (4, 2, "B4", 2), (5, 0, "A4", 3),
        (6, 0, "F5", 1.5), (6, 1.5, "E5", 0.5), (6, 2, "D5", 2), (7, 0, "G#4", 3),
        (8, 0, "E5", 1), (8, 1, "A5", 1), (8, 2, "G5", 1), (8, 3, "E5", 1), (9, 0, "C5", 3),
        (10, 0, "D5", 1), (10, 1, "F5", 1), (10, 2, "E5", 2), (11, 0, "B4", 2), (11, 2, "G#4", 2),
        (12, 0, "A4", 1.5), (12, 1.5, "C5", 0.5), (12, 2, "E5", 2), (13, 0, "F5", 2), (13, 2, "E5", 2),
        (14, 0, "D5", 2), (14, 2, "C5", 2), (15, 0, "B4", 2), (15, 2, "E4", 2),
    ]

    def compose(mx, t0):
        rng = np.random.default_rng(1101)
        for b, (root, q) in enumerate(prog):
            bt = t0 + b * bar
            notes = chord(root, q)
            mx.add(pad([m + 12 for m in notes[:4]], bar + 0.4, cutoff=1100.0, attack=0.9), bt, 0.55,
                   verb=0.5)
            mx.add(bass(notes[0], bar * 0.95, cutoff=320.0, drive=1.0), bt, 0.35, verb=0.1)
            arp = [notes[i % len(notes)] + 24 for i in (0, 1, 2, 3, 2, 1, 2, 3)]
            for i, m in enumerate(arp):
                mx.add(pluck(m, beat * 0.5, "tri", 0.5), bt + i * beat * 0.5, 0.18,
                       pan=-0.4 if i % 2 else 0.4, echo=0.45, verb=0.3)
            if b % 2 == 1:
                mx.add(kick(rng, 0.6), bt, 0.35, verb=0.4)
        for b, bb, name, beats in melody:
            mx.add(bell(midi(name), beats * beat + 0.4), t0 + b * bar + bb * beat, 0.3,
                   pan=0.1, echo=0.35, verb=0.45)

    return loop_render(compose, bars, bpm, echo_div=0.75)


def mus_combat_floor2():
    """Floor 2, the Warped Warden's halls. E phrygian, 140 BPM, 24 bars. Wobbling, off-kilter."""
    bpm, bars = 140, 24
    beat = 60.0 / bpm
    step = beat / 4
    bar = 4 * beat
    roots = ["E2", "F2", "E2", "D2", "E2", "F2", "G2", "F2"] * 3
    riff = [0, 0, 12, 0, 0, 10, 0, 7, 0, 0, 12, 0, 13, 12, 10, 7]  # 16th offsets
    lead_line = [  # (bar, step, note, steps)
        (8, 0, "B4", 6), (8, 6, "C5", 2), (8, 8, "B4", 4), (8, 12, "G4", 4),
        (9, 0, "E4", 8), (9, 10, "F4", 2), (9, 12, "G4", 4),
        (10, 0, "A4", 6), (10, 6, "B4", 2), (10, 8, "C5", 4), (10, 12, "D5", 4),
        (11, 0, "B4", 12), (11, 12, "A4", 4),
        (12, 0, "E5", 4), (12, 4, "D5", 4), (12, 8, "C5", 4), (12, 12, "B4", 4),
        (13, 0, "C5", 6), (13, 6, "B4", 2), (13, 8, "A4", 8),
        (14, 0, "G4", 4), (14, 4, "A4", 4), (14, 8, "B4", 4), (14, 12, "D5", 4),
        (15, 0, "E5", 16),
        (20, 0, "F5", 4), (20, 4, "E5", 4), (20, 8, "C5", 4), (20, 12, "B4", 4),
        (21, 0, "C5", 8), (21, 8, "B4", 8),
        (22, 0, "G4", 4), (22, 4, "A4", 4), (22, 8, "B4", 8),
        (23, 0, "E4", 12),
    ]

    def compose(mx, t0):
        rng = np.random.default_rng(2202)
        for b, root in enumerate(roots):
            bt = t0 + b * bar
            r = midi(root)
            for s, off in enumerate(riff):
                if (b % 8 == 7) and s >= 12:
                    continue  # drop-out before the turnaround
                mx.add(bass(r + off, step * 0.9, cutoff=700.0 + 500.0 * (s % 4 == 0), drive=2.4,
                            wobble=6.0), bt + s * step, 0.42, verb=0.05)
            quality = "m" if root in ("E2", "D2") else "M"
            mx.add(pad([m + 12 for m in chord(root, quality)], bar, cutoff=900.0, attack=0.2),
                   bt, 0.3, pan=-0.2, verb=0.35)
            for s in (0, 3, 6, 10, 14) if b % 4 != 3 else (0, 3, 6, 8, 10, 12, 14, 15):
                mx.add(power_chord(r + 12, step * 1.6, 2.5), bt + s * step, 0.16, pan=0.3, verb=0.2)
            kicks = (0, 6, 10) if b % 2 == 0 else (0, 3, 8, 11)
            fills = (12, 13, 14, 15) if b % 8 == 7 else ()
            drums(mx, rng, bt, step, kicks, (4, 12) + fills, range(0, 16, 2), 1.0, (14,))
        for b, s, name, steps in lead_line:
            mx.add(lead(midi(name), steps * step, "saw", 2600.0), t0 + b * bar + s * step, 0.2,
                   pan=0.15, echo=0.3, verb=0.3)

    return loop_render(compose, bars, bpm, echo_div=0.75)


def mus_combat_floor3():
    """Floor 3, the Cipher Core. C# minor, 156 BPM, 32 bars. Relentless, the last push."""
    bpm, bars = 156, 32
    beat = 60.0 / bpm
    step = beat / 4
    bar = 4 * beat
    prog = ["C#2", "A1", "E2", "B1", "C#2", "A1", "B1", "G#1"] * 4
    arp_shape = [0, 7, 12, 15, 12, 7, 19, 15, 0, 7, 12, 15, 19, 15, 12, 7]
    theme = [  # (bar offset in an 8-bar phrase, step, note, steps)
        (0, 0, "G#4", 6), (0, 6, "A4", 2), (0, 8, "G#4", 4), (0, 12, "E4", 4),
        (1, 0, "C#5", 12), (1, 12, "B4", 4),
        (2, 0, "E5", 6), (2, 6, "D#5", 2), (2, 8, "C#5", 4), (2, 12, "B4", 4),
        (3, 0, "D#5", 16),
        (4, 0, "G#4", 6), (4, 6, "A4", 2), (4, 8, "B4", 4), (4, 12, "C#5", 4),
        (5, 0, "E5", 8), (5, 8, "F#5", 8),
        (6, 0, "G#5", 6), (6, 6, "F#5", 2), (6, 8, "E5", 4), (6, 12, "D#5", 4),
        (7, 0, "C5", 16),
    ]

    def compose(mx, t0):
        rng = np.random.default_rng(3303)
        for b, root in enumerate(prog):
            bt = t0 + b * bar
            r = midi(root)
            intense = b >= 8
            quality = "m" if root in ("C#2",) else "M"
            if root == "G#1":
                quality = "7"
            # Galloping bass: 8th + two 16ths.
            for s in range(0, 16, 4):
                for off in (0, 2, 3):
                    mx.add(bass(r, step * 0.9, cutoff=1100.0, drive=2.8), bt + (s + off) * step,
                           0.42, verb=0.03)
            if intense:
                for s in (0, 6, 12):
                    mx.add(power_chord(r + 12, step * (5 if s < 12 else 3.5), 4.5),
                           bt + s * step, 0.2, pan=-0.35, verb=0.15)
                    mx.add(power_chord(r + 12, step * (5 if s < 12 else 3.5), 4.5),
                           bt + s * step + 0.012, 0.2, pan=0.35, verb=0.15)
            third = 3 if quality == "m" else 4
            for s, off in enumerate(arp_shape):
                m = r + 24 + (off if off not in (15,) else 12 + third)
                mx.add(pluck(m, step * 0.9, "square", 0.12), bt + s * step, 0.1,
                       pan=0.5 if s % 2 else -0.5, echo=0.25, verb=0.1)
            mx.add(pad([m + 12 for m in chord(root, quality)], bar, 1200.0, 0.15), bt, 0.22,
                   verb=0.4)
            kicks = (0, 4, 8, 12) if b % 8 != 7 else (0, 2, 4, 6, 8, 9, 10, 11, 12, 13, 14, 15)
            snares = (4, 12) if b % 8 != 7 else (4, 12, 14, 15)
            drums(mx, rng, bt, step, kicks, snares, range(0, 16) if intense else range(0, 16, 2),
                  1.1 if intense else 0.9, (2, 6, 10, 14) if intense else ())
        for phrase in (1, 3):
            for b, s, name, steps in theme:
                mx.add(lead(midi(name), steps * step, "square", 3400.0),
                       t0 + (phrase * 8 + b) * bar + s * step, 0.2, pan=0.0, echo=0.3, verb=0.3)

    return loop_render(compose, bars, bpm, echo_div=0.75)


def mus_ending():
    """Ending / victory. D major, 76 BPM, 16 bars + ring-out. One-shot (does not loop)."""
    bpm = 76
    beat = 60.0 / bpm
    bar = 4 * beat
    prog = [("D2", "M"), ("A1", "M"), ("B1", "m"), ("G1", "M"),
            ("D2", "M"), ("A1", "M"), ("G1", "M7"), ("A1", "sus2"),
            ("B1", "m7"), ("G1", "M7"), ("D2", "M"), ("A1", "M"),
            ("B1", "m"), ("G1", "M"), ("A1", "sus2"), ("A1", "M")]
    melody = [
        (0, 0, "F#5", 2), (0, 2, "E5", 1), (0, 3, "D5", 1), (1, 0, "C#5", 3), (1, 3, "A4", 1),
        (2, 0, "B4", 1.5), (2, 1.5, "C#5", 0.5), (2, 2, "D5", 2), (3, 0, "B4", 4),
        (4, 0, "A5", 2), (4, 2, "F#5", 1), (4, 3, "D5", 1), (5, 0, "E5", 3), (5, 3, "C#5", 1),
        (6, 0, "D5", 1), (6, 1, "E5", 1), (6, 2, "F#5", 2), (7, 0, "E5", 4),
        (8, 0, "F#5", 1.5), (8, 1.5, "G5", 0.5), (8, 2, "A5", 2), (9, 0, "B5", 2), (9, 2, "A5", 2),
        (10, 0, "F#5", 2), (10, 2, "D5", 2), (11, 0, "E5", 3), (11, 3, "C#5", 1),
        (12, 0, "D5", 2), (12, 2, "F#5", 2), (13, 0, "B4", 2), (13, 2, "D5", 2),
        (14, 0, "E5", 2), (14, 2, "C#5", 2), (15, 0, "E5", 2), (15, 2, "A4", 2),
        (16, 0, "D5", 8),
    ]
    total = 16 * bar + 6.0 * beat
    mx = Mix(total)
    rng = np.random.default_rng(4404)
    for b, (root, q) in enumerate(prog):
        bt = b * bar
        notes = chord(root, q)
        mx.add(pad([m + 12 for m in notes], bar + 0.5, cutoff=1500.0, attack=0.8), bt, 0.5, verb=0.5)
        mx.add(bass(notes[0], bar * 0.95, cutoff=360.0, drive=1.0), bt, 0.32, verb=0.1)
        for i in range(8):
            m = notes[(0, 1, 2, 1, 2, 0, 2, 1)[i] % len(notes)] + 24
            mx.add(pluck(m, beat * 0.5, "tri", 0.6), bt + i * beat * 0.5, 0.12,
                   pan=-0.35 if i % 2 else 0.35, echo=0.4, verb=0.3)
        if 4 <= b < 15:
            drums(mx, rng, bt, beat / 4, (0, 8), (4, 12) if b >= 8 else (), (), 0.55)
    # Final resolve: a held D major chord that rings out.
    end_t = 16 * bar
    mx.add(pad([m + 12 for m in chord("D2", "M")] + [midi("A4")], 6.0 * beat, 1500.0, 0.3),
           end_t, 0.6, verb=0.6)
    mx.add(bass(midi("D2"), 5.0 * beat, 300.0, 1.0), end_t, 0.3)
    for b, bb, name, beats in melody:
        mx.add(bell(midi(name), beats * beat + 0.5), b * bar + bb * beat, 0.3, pan=0.1,
               echo=0.35, verb=0.45)
    out = mx.render(0.75 * beat)
    out = out[:, : int((total + 2.5) * RATE)]
    fade = int(3.0 * RATE)
    out[:, -fade:] *= np.linspace(1.0, 0.0, fade) ** 2
    return out


TRACKS = {
    "mus_title": (mus_title, True),
    "mus_combat_floor2": (mus_combat_floor2, True),
    "mus_combat_floor3": (mus_combat_floor3, True),
    "mus_ending": (mus_ending, False),
}


# ── Output ───────────────────────────────────────────────────────────────────────

def to_pcm16(stereo):
    inter = np.empty(stereo.shape[1] * 2)
    inter[0::2], inter[1::2] = stereo[0], stereo[1]
    return (np.clip(inter, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()


def write_mp3(path, pcm):
    import lameenc  # noqa: PLC0415 — only needed when writing

    enc = lameenc.Encoder()
    enc.set_bit_rate(160)
    enc.set_in_sample_rate(RATE)
    enc.set_channels(2)
    enc.set_quality(2)
    data = enc.encode(pcm) + enc.flush()
    with open(path, "wb") as f:
        f.write(data)
    return len(data)


def write_wav(path, pcm):
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=DEFAULT_OUT)
    p.add_argument("--only", default="")
    p.add_argument("--list", action="store_true")
    p.add_argument("--wav", action="store_true", help="also write .wav previews")
    args = p.parse_args()
    names = list(TRACKS)
    if args.only:
        names = [n for n in names if n in {s.strip() for s in args.only.split(",")}]
    if args.list:
        for n in names:
            print(f"{n:<20} {'loop' if TRACKS[n][1] else 'one-shot'}  {TRACKS[n][0].__doc__.strip()}")
        return 0
    os.makedirs(args.out, exist_ok=True)
    for n in names:
        audio = finish(TRACKS[n][0]())
        pcm = to_pcm16(audio)
        size = write_mp3(os.path.join(args.out, n + ".mp3"), pcm)
        if args.wav:
            write_wav(os.path.join(args.out, n + ".wav"), pcm)
        print(f"  ok: {n:<20} {audio.shape[1] / RATE:5.1f}s  {size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
