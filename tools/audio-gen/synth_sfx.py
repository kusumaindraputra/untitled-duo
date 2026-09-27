#!/usr/bin/env python3
"""Synthesise the fast-pace / bullet-hell SFX set offline (no API key, stdlib only).

The first 30 SFX came from ElevenLabs (see generate_sfx.py). The mechanics added
later (bullet patterns, lasers, mortars, Perfect Dodge, Perfect Cast, Special,
kill orbs, style rank, hazards, pillars) had no sound at all. This script renders
short chiptune-style cues for them so every one of those moments is audible.
The output is deterministic: the same script always writes the same bytes.

Usage:
  python3 tools/audio-gen/synth_sfx.py            # writes assets/audio/sfx/*.wav
  python3 tools/audio-gen/synth_sfx.py --list     # print the cue list only
  python3 tools/audio-gen/synth_sfx.py --out DIR  # write somewhere else

To replace a cue with a hand-made or ElevenLabs sound later, drop the new file in
assets/audio/sfx/ and point the matching entry in audio_event_registry.tres at it.
"""
import argparse
import math
import os
import random
import struct
import wave

RATE = 44100
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_OUT = os.path.join(REPO_ROOT, "assets", "audio", "sfx")


# ── Primitive generators (all return lists of floats in -1..1) ──────────────────

def _n(dur):
    return max(1, int(dur * RATE))


def tone(f0, f1, dur, shape="sine", curve=1.0, duty=0.5, vib_hz=0.0, vib_depth=0.0):
    """Oscillator sweeping f0→f1 over dur. curve>1 bends the sweep late, <1 early."""
    out = []
    phase = 0.0
    n = _n(dur)
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** curve)
        if vib_hz > 0.0:
            f *= 1.0 + vib_depth * math.sin(2.0 * math.pi * vib_hz * i / RATE)
        phase += f / RATE
        p = phase % 1.0
        if shape == "sine":
            s = math.sin(2.0 * math.pi * p)
        elif shape == "square":
            s = 1.0 if p < duty else -1.0
        elif shape == "saw":
            s = 2.0 * p - 1.0
        else:  # triangle
            s = 4.0 * abs(p - 0.5) - 1.0
        out.append(s)
    return out


def noise(dur, seed, cutoff=1.0):
    """White noise through a one-pole low-pass (cutoff 0..1, 1 = unfiltered)."""
    rng = random.Random(seed)
    out = []
    y = 0.0
    for _ in range(_n(dur)):
        y += cutoff * (rng.uniform(-1.0, 1.0) - y)
        out.append(y)
    return out


def env(sig, attack=0.005, decay_pow=1.0, hold=0.0):
    """Linear attack, then a (1-t)^decay_pow fall. hold = fraction kept at full level."""
    n = len(sig)
    a = max(1, int(attack * RATE))
    out = []
    for i, s in enumerate(sig):
        if i < a:
            g = i / a
        else:
            t = (i - a) / max(1, n - a)
            g = 1.0 if t < hold else (1.0 - (t - hold) / max(1e-6, 1.0 - hold)) ** decay_pow
        out.append(s * g)
    return out


def tremolo(sig, hz, depth):
    return [s * (1.0 - depth * 0.5 * (1.0 + math.sin(2.0 * math.pi * hz * i / RATE)))
            for i, s in enumerate(sig)]


def mix(*layers):
    """Sums (gain, signal) pairs; shorter signals are zero-padded."""
    n = max(len(sig) for _, sig in layers)
    out = [0.0] * n
    for gain, sig in layers:
        for i, s in enumerate(sig):
            out[i] += gain * s
    return out


def seq(*parts, gap=0.0):
    """Concatenates signals with an optional silent gap between them."""
    out = []
    silence = [0.0] * _n(gap) if gap > 0.0 else []
    for i, p in enumerate(parts):
        if i > 0:
            out += silence
        out += p
    return out


def note(f, dur, shape="square", decay=1.5, duty=0.5):
    return env(tone(f, f, dur, shape, duty=duty), attack=0.002, decay_pow=decay)


def normalise(sig, peak):
    m = max(1e-9, max(abs(s) for s in sig))
    return [s * peak / m for s in sig]


# ── Cue recipes ──────────────────────────────────────────────────────────────────
# Peak levels are set per cue so the busy ones (bullets, graze, orbs) sit under the
# spell and hit sounds, and the rare "moment" cues (Special, room rank) sit on top.

def sfx_bullet_fire():
    return 0.35, env(tone(1100, 520, 0.06, "square", duty=0.25), 0.001, 2.0)


def sfx_enemy_windup():
    return 0.40, env(tone(260, 820, 0.16, "triangle", curve=0.7), 0.01, 0.6, hold=0.5)


def sfx_laser_charge():
    body = tremolo(tone(180, 640, 0.55, "saw", curve=1.4), 18.0, 0.6)
    return 0.45, env(mix((0.7, body), (0.3, noise(0.55, 11, 0.25))), 0.02, 0.4, hold=0.8)


def sfx_laser_fire():
    body = mix((0.6, tone(110, 95, 0.45, "saw")), (0.4, tone(220, 190, 0.45, "square", duty=0.3)),
               (0.5, noise(0.45, 12, 0.5)))
    return 0.55, env(body, 0.004, 1.3, hold=0.25)


def sfx_mortar_whistle():
    return 0.40, env(tone(1500, 480, 0.6, "sine", curve=0.8, vib_hz=9.0, vib_depth=0.02), 0.03, 0.5, hold=0.7)


def sfx_mortar_blast():
    thump = env(tone(95, 38, 0.45, "sine"), 0.002, 1.8)
    crack = env(noise(0.45, 13, 0.35), 0.001, 2.5)
    return 0.75, mix((0.9, thump), (0.8, crack))


def sfx_enemy_alert():
    return 0.45, seq(note(660, 0.06, duty=0.25), note(990, 0.09, duty=0.25), gap=0.015)


def sfx_boss_phase():
    roar = env(mix((0.6, tone(70, 140, 0.9, "saw", curve=0.6)), (0.5, noise(0.9, 14, 0.15))),
               0.05, 1.2, hold=0.3)
    sting = env(tone(440, 880, 0.3, "square", duty=0.3), 0.005, 1.5)
    return 0.75, mix((1.0, roar), (0.45, sting))


def sfx_perfect_dodge():
    shimmer = mix((0.5, tone(700, 1800, 0.45, "sine", curve=0.6)),
                  (0.4, tone(1050, 2700, 0.45, "sine", curve=0.6)),
                  (0.2, noise(0.45, 15, 0.9)))
    return 0.55, env(shimmer, 0.12, 1.4)


def sfx_perfect_cast():
    return 0.55, seq(note(1047, 0.07, "triangle", 1.2), note(1319, 0.07, "triangle", 1.2),
                     note(1568, 0.14, "triangle", 1.6))


def sfx_special_ready():
    return 0.50, seq(note(784, 0.09, "square", 1.2, 0.3), note(1175, 0.09, "square", 1.2, 0.3),
                     note(1568, 0.22, "square", 1.8, 0.3), gap=0.02)


def sfx_special_fire():
    drop = env(tone(160, 34, 0.85, "sine", curve=0.5), 0.003, 1.2)
    blast = env(noise(0.85, 16, 0.5), 0.002, 2.2)
    ring = env(tone(880, 440, 0.5, "saw"), 0.002, 2.0)
    return 0.85, mix((1.0, drop), (0.7, blast), (0.25, ring))


def sfx_graze():
    return 0.22, env(tone(2600, 3200, 0.035, "square", duty=0.2), 0.001, 2.0)


def sfx_orb_pickup():
    return 0.30, seq(note(1319, 0.035, duty=0.25), note(1976, 0.06, duty=0.25))


def sfx_dash_ready():
    return 0.28, note(1200, 0.05, "triangle", 2.0)


def sfx_rank_up():
    return 0.45, seq(*[note(f, 0.06, duty=0.25) for f in (523, 659, 784)], note(1047, 0.14, duty=0.25))


def sfx_room_rank():
    return 0.60, seq(note(523, 0.1, decay=0.8), note(659, 0.1, decay=0.8), note(784, 0.1, decay=0.8),
                     note(1047, 0.1, decay=0.8), env(mix((0.6, tone(1047, 1047, 0.4, "square", duty=0.3)),
                                                         (0.4, tone(1568, 1568, 0.4, "triangle"))), 0.003, 1.5),
                     gap=0.02)


def sfx_pillar_break():
    crumble = env(tremolo(noise(0.5, 17, 0.3), 23.0, 0.7), 0.002, 1.5)
    thump = env(tone(80, 45, 0.3, "sine"), 0.002, 2.0)
    return 0.65, mix((0.9, crumble), (0.7, thump))


def sfx_reaction():
    carrier = []
    n = _n(0.26)
    for i in range(n):
        t = i / RATE
        mod = 3.0 * math.exp(-t * 9.0) * math.sin(2.0 * math.pi * 1370.0 * t)
        carrier.append(math.sin(2.0 * math.pi * 820.0 * t + mod))
    return 0.50, env(carrier, 0.002, 2.2)


def sfx_vent_ignite():
    whoosh = env(noise(0.4, 18, 0.2), 0.08, 1.0, hold=0.3)
    return 0.45, mix((1.0, whoosh), (0.3, env(tone(90, 120, 0.4, "saw"), 0.08, 1.0, hold=0.3)))


def sfx_boss_felled():
    # ADR-0041: the music cuts to this while the boss dissolves — a deep impact,
    # a long falling air tail and a high ring that hangs over the silence.
    boom = env(tone(110, 28, 1.6, "sine", curve=0.4), 0.002, 1.1)
    crack = env(noise(0.5, 19, 0.45), 0.001, 2.4)
    air = env(noise(1.8, 20, 0.08), 0.15, 1.3, hold=0.3)
    ring = env(mix((0.6, tone(1319, 1300, 1.8, "triangle")), (0.4, tone(1976, 1950, 1.8, "sine"))),
               0.01, 1.4)
    return 0.85, mix((1.0, boom), (0.6, crack), (0.35, air), (0.22, ring))


def sfx_ui_focus():
    return 0.22, note(1760, 0.03, "triangle", 2.5)


def sfx_ui_confirm():
    return 0.32, seq(note(880, 0.04, duty=0.25, decay=2.0), note(1320, 0.07, duty=0.25, decay=1.8))


def sfx_ui_back():
    return 0.28, seq(note(988, 0.04, "triangle", 2.0), note(660, 0.07, "triangle", 1.8))


CUES = [
    sfx_bullet_fire, sfx_enemy_windup, sfx_laser_charge, sfx_laser_fire, sfx_mortar_whistle,
    sfx_mortar_blast, sfx_enemy_alert, sfx_boss_phase, sfx_perfect_dodge, sfx_perfect_cast,
    sfx_special_ready, sfx_special_fire, sfx_graze, sfx_orb_pickup, sfx_dash_ready, sfx_rank_up,
    sfx_room_rank, sfx_pillar_break, sfx_reaction, sfx_vent_ignite, sfx_boss_felled,
    sfx_ui_focus, sfx_ui_confirm, sfx_ui_back,
]


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
        w.writeframes(bytes(frames))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=DEFAULT_OUT)
    p.add_argument("--list", action="store_true")
    args = p.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for fn in CUES:
        peak, sig = fn()
        # A 4 ms fade-out stops the click a hard cut would leave.
        tail = min(len(sig), int(0.004 * RATE))
        for i in range(tail):
            sig[len(sig) - tail + i] *= 1.0 - (i + 1) / tail
        sig = normalise(sig, peak)
        name = fn.__name__[len("sfx_"):]
        if args.list:
            print(f"{fn.__name__:<22} {len(sig) / RATE:5.2f}s")
            continue
        path = os.path.join(args.out, name + ".wav")
        write_wav(path, sig)
        print(f"wrote {os.path.relpath(path, REPO_ROOT)}  {len(sig) / RATE:.2f}s")


if __name__ == "__main__":
    main()
