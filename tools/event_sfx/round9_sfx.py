"""Tur 9: Hadime Q lanet ISABETI - kara buyu isabet/patlama sesi (4) + demo (tek isabet, sonra 3'erli yagmurlar)."""
import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, lp, hp, bp, noise, attack_env, dec,
                           bell, saw, thump, reverb, finish, write)
from round7_sfx import ghost_tone, crackle, shift
from round8_sfx import growl


def hit_A():
    # Karanlik patlama: tok alt patlama + bogulmus karanlik gurultu patlamasi + kisa minor can kuyrugu
    d = 0.7
    x = buf(d)
    place(x, thump(110, 38, 0.5, 0.15, 0.04, 0.002), 0.0, 0.9)
    t = T(0.35)
    place(x, lp(noise(0.35), 1800 * np.exp(-t / 0.08) + 250, 2) * np.exp(-t / 0.09) * attack_env(len(t), 0.002), 0.0, 0.8)
    place(x, bell(nf("D4"), 0.5, 0.18, 2.4, 1.2, 0.1), 0.01, 0.2)
    place(x, bell(nf("G#4"), 0.5, 0.16, 2.4, 1.0, 0.1), 0.01, 0.12)
    return finish(reverb(x, 1.0, 0.25, 0.4, 2800), 0.12)


def hit_B():
    # Lanet muhru: tok darbe + uyumsuz zil kumesi 'cing' + sonen tislama
    d = 0.7
    x = buf(d)
    place(x, thump(120, 50, 0.35, 0.1, 0.03, 0.002), 0.0, 0.8)
    for n, g in (("C#5", 0.3), ("G5", 0.22), ("D6", 0.12)):
        place(x, bell(nf(n), 0.5, 0.16, 2.76, 1.4, 0.1), 0.0, g)
    t = T(0.4)
    place(x, bp(noise(0.4), 2500, 7000) * np.exp(-t / 0.12) * attack_env(len(t), 0.004), 0.0, 0.15)
    return finish(reverb(x, 1.0, 0.26, 0.4, 3200), 0.12)


def hit_C():
    # Ruh parcalanmasi: darbe + kisa inen hayalet cigligi + citirti
    d = 0.7
    x = buf(d)
    place(x, thump(100, 42, 0.4, 0.12, 0.03, 0.002), 0.0, 0.8)
    t = T(0.32)
    place(x, lp(ghost_tone(nf("B5"), nf("E4"), 0.32, 12), 2600, 1) * np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.1), 0.0, 0.3)
    place(x, crackle(0.3, 140, 21) * np.exp(-T(0.3) / 0.07), 0.0, 0.45)
    return finish(reverb(x, 1.1, 0.28, 0.4, 3000), 0.12)


def hit_D():
    # Golge catlagi: keskin karanlik catirti + alt dusus + kisa iblis hiriltisi
    d = 0.7
    x = buf(d)
    t = T(0.08)
    place(x, bp(noise(0.08), 800, 4500) * np.exp(-t / 0.015) * attack_env(len(t), 0.0008), 0.0, 0.8)
    place(x, thump(95, 30, 0.5, 0.18, 0.06, 0.002), 0.0, 0.85)
    t2 = T(0.3)
    place(x, growl(nf("D2") * (1 - 0.3 * t2 / 0.3), 0.3) * np.clip(t2 / 0.01, 0, 1) * np.exp(-t2 / 0.09), 0.01, 0.35)
    return finish(reverb(x, 1.0, 0.25, 0.4, 2800), 0.12)


def demo(hit_st, gain_db=-9.0):
    """Tek isabet, sonra oyundaki gibi saniyede bir 3'erli isabet (perde 0.92-1.08, -9 dB)."""
    r = np.random.default_rng(17)
    out = np.zeros((N(3.0), 2))
    g = 10 ** (gain_db / 20)
    place(out, hit_st, 0.0, g)
    for v in (0.9, 1.9):
        for k in range(3):
            place(out, shift(hit_st, r.uniform(0.92, 1.08)), v + r.uniform(0.0, 0.06), g)
    peak = np.max(np.abs(out))
    return out * (0.85 / peak if peak > 0 else 1.0)


if __name__ == "__main__":
    for k in ("A", "B", "C", "D"):
        h = globals()["hit_" + k]()
        write("hadime_hit_" + k, h)
        write("hadime_hit_demo_" + k, demo(h))
