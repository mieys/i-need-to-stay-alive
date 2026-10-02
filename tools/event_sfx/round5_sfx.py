"""Tur 5: gorev basladi D'nin cizirtisiz hali + gorev basarili icin 4 yeni (dosya <olay>_R5x)."""
import sys

import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, lp, hp, bp, noise, attack_env, dec,
                           bell, chime, coin, pluck, saw, thump, pad, reverb, finish, write)


def mission_start_R5D():
    # Gerilim nabzi (temiz): doygunluk (tanh) yok, tiz zil hisirtisi yok, gurultu yukselisi yerine tonal yukselis
    d = 1.9
    x = buf(d)
    for i, at in enumerate((0.0, 0.22, 0.4, 0.54, 0.65)):
        t = T(0.22)
        p = lp(saw(nf("D2"), 0.22, 16), 220 + 900 * np.exp(-t / 0.04), 2) * np.exp(-t / 0.08) * attack_env(len(t), 0.004)
        place(x, p, at, 0.5 + 0.1 * i)
    t = T(0.72)
    sweep = lp(saw(nf("D3") * (1 + t / 0.72), 0.72, 12), 300 + 1500 * (t / 0.72) ** 2, 2) * (t / 0.72) ** 2
    place(x, sweep, 0.0, 0.22)
    place(x, lp(noise(0.72), 900 + 1500 * (T(0.72) / 0.72), 2) * (T(0.72) / 0.72) ** 3, 0.0, 0.08)
    hit = 0.75
    place(x, thump(100, 36, 1.0, 0.35, 0.06, 0.007), hit, 1.0)
    place(x, lp(saw(nf("D2"), 1.0, 20) + saw(nf("A2") * 1.003, 1.0, 20), 700, 2) * dec(1.0, 0.35, 0.006), hit, 0.35)
    place(x, lp(noise(0.5), 1200, 2) * dec(0.5, 0.08, 0.002), hit, 0.25)
    return finish(reverb(x, 1.4, 0.26, 0.9, 3500), 0.13)


def kalimba(f, d=1.0, tau=0.45):
    t = T(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
    x += 0.3 * np.sin(2 * np.pi * f * 5.95 * t) * np.exp(-t / 0.03)
    x += 0.12 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / (tau * 0.4))
    click = bp(noise(0.006), 2000, 6000) * np.linspace(1, 0, N(0.006))
    x[:len(click)] += 0.25 * click
    return x * attack_env(len(t), 0.0008)


def mission_success_R5A():
    # Kalimba: yukari uc nota (Do-Mi-Sol) + oktav, sicak ve ASMR
    d = 1.8
    x = buf(d)
    for i, (n, g) in enumerate((("C5", 0.5), ("E5", 0.5), ("G5", 0.55), ("C6", 0.6))):
        place(x, kalimba(nf(n), 1.2, 0.5 + 0.1 * i), i * 0.085, g)
    place(x, kalimba(nf("E6"), 1.0, 0.5), 3 * 0.085 + 0.004, 0.2)
    return finish(reverb(x, 1.3, 0.25, 0.8), 0.11)


def mission_success_R5B():
    # Altin para: iki parlak para notasi (Si -> Mi, klasik 'para toplandi' araligi) can tinisiyla + kisa parilti
    d = 1.4
    x = buf(d)
    place(x, coin(nf("B5") * 2, 0.4, 0.12), 0.0, 0.15)
    place(x, bell(nf("B5"), 0.5, 0.12, 1.41, 0.8, 0.3), 0.0, 0.5)
    place(x, coin(nf("E6") * 2, 0.6, 0.2), 0.08, 0.16)
    place(x, bell(nf("E6"), 1.1, 0.5, 1.41, 0.8, 0.3), 0.08, 0.6)
    place(x, chime(nf("B6"), 0.8, 0.3), 0.08, 0.15)
    for i, n in enumerate(("E7", "G#7")):
        place(x, chime(nf(n), 0.4, 0.12), 0.2 + i * 0.05, 0.08)
    return finish(reverb(x, 1.1, 0.22, 0.6), 0.11)


def mission_success_R5C():
    # Derin + parlak: yukari hava cekisi -> yumusak alt 'bum' + kristal ding ayni anda (mobil oyun 'basardin')
    d = 1.7
    x = buf(d)
    t = T(0.3)
    place(x, lp(noise(0.3), 400 + 3000 * (t / 0.3) ** 2, 2) * (t / 0.3) ** 2.5, 0.0, 0.18)
    hit = 0.3
    place(x, thump(90, 48, 0.8, 0.28, 0.05, 0.004), hit, 0.85)
    place(x, chime(nf("G6"), 1.2, 0.55), hit, 0.4)
    place(x, chime(nf("D7"), 1.2, 0.45), hit + 0.003, 0.22)
    place(x, bell(nf("G5"), 1.2, 0.5, 1.41, 0.7, 0.25), hit, 0.35)
    place(x, pad([nf("G4"), nf("D5"), nf("B5")], 1.0, 0.03, 0.7, 2600), hit, 0.45)
    return finish(reverb(x, 1.3, 0.25, 0.7), 0.12)


def mission_success_R5D():
    # Tel tingirti: sicak naylon tel akoru yukari taranir (Cadd9) + hafif tik, yumusak sonus
    d = 2.0
    x = buf(d)
    chord = [nf(n) for n in ("C3", "G3", "D4", "E4", "G4", "C5")]
    for i, f in enumerate(chord):
        place(x, pluck(f, 1.8 - i * 0.03, 0.4, 0.998), i * 0.03, 0.28)
    place(x, bp(noise(0.02), 2000, 6000) * dec(0.02, 0.004), 0.0, 0.15)
    place(x, kalimba(nf("G5"), 1.0, 0.5), 0.2, 0.25)
    place(x, kalimba(nf("C6"), 1.0, 0.55), 0.28, 0.3)
    return finish(reverb(x, 1.4, 0.26, 0.8), 0.11)


ROUND5 = {k: v for k, v in globals().items() if "_R5" in k and callable(v)}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in ROUND5.items():
        if not only or name in only:
            write(name, fn())
