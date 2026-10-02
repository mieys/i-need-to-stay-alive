"""Tur 6: gorev basarili - dokunsal/ASMR 4 yeni secenek (dosya mission_success_R6A..R6D)."""
import sys

import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, lp, hp, bp, noise, attack_env, dec,
                           bell, chime, marimba, coin, thump, woodblock, pad, reverb, finish, write)


def tap(f, d=0.18):
    """Kisa, tok ahsap/marimba vurusu (domino)."""
    t = T(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.05) + 0.3 * np.sin(2 * np.pi * f * 3.9 * t) * np.exp(-t / 0.012)
    x += 0.25 * bp(noise(d), 1500, 6000) * np.exp(-t / 0.003)
    return x * attack_env(len(t), 0.0005)


def mission_success_R6A():
    # Domino zinciri: hizlanan, perdesi yukselen tok vuruslar -> yumusak tok kapanis + sicak akor
    d = 1.8
    x = buf(d)
    notes = ("C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6")
    at, gap = 0.0, 0.085
    for n in notes:
        place(x, tap(nf(n)), at, 0.5)
        at += gap
        gap *= 0.86
    end = at + 0.02
    place(x, thump(140, 70, 0.3, 0.08, 0.03, 0.002), end, 0.6)
    for n, g in (("C5", 0.35), ("E5", 0.3), ("G5", 0.3), ("C6", 0.3)):
        place(x, marimba(nf(n), 1.0, 0.35), end, g)
    place(x, pad([nf("C4"), nf("G4"), nf("E5")], 0.9, 0.04, 0.7, 2000), end, 0.35)
    return finish(reverb(x, 1.1, 0.22, 0.7), 0.11)


def mission_success_R6B():
    # Muhur basildi: kisa iniş hava sesi -> agir, tok kagit+ahsap 'TUNK' -> sicak can
    d = 1.6
    x = buf(d)
    t = T(0.14)
    place(x, lp(noise(0.14), 3000 * (0.2 ** (t / 0.14)), 2) * np.sin(np.pi * t / 0.14), 0.0, 0.25)
    hit = 0.14
    place(x, thump(130, 55, 0.4, 0.12, 0.02, 0.0015), hit, 1.0)
    place(x, woodblock(230, 0.15), hit, 0.6)
    place(x, lp(noise(0.08), 2500, 2) * dec(0.08, 0.018, 0.0008), hit, 0.6)
    place(x, bell(nf("G5"), 1.1, 0.45, 1.41, 0.7, 0.25), hit + 0.12, 0.35)
    place(x, bell(nf("C6"), 1.1, 0.45, 1.41, 0.7, 0.25), hit + 0.12, 0.28)
    return finish(reverb(x, 1.0, 0.2, 0.6), 0.11)


def mission_success_R6C():
    # Altin patlama: Yeniden Dogus'un ters can cekisi + Kese'nin para patlamasi + kristal akor, kisa kuyruk
    d = 1.8
    x = buf(d)
    sw = bell(nf("C6"), 0.5, 0.25, 3.5, 1.0, 0.3)[::-1] * np.linspace(0, 1, N(0.5)) ** 2
    place(x, sw, 0.0, 0.45)
    hit = 0.5
    r = np.random.default_rng(6)
    for i in range(10):
        place(x, coin(r.uniform(2200, 4400), 0.4, 0.15), hit + r.uniform(0, 0.07), 0.16)
    place(x, thump(150, 75, 0.3, 0.08), hit, 0.45)
    for n, g in (("C6", 0.4), ("E6", 0.32), ("G6", 0.3)):
        place(x, chime(nf(n), 1.0, 0.4), hit, g)
    return finish(reverb(x, 1.2, 0.24, 0.6), 0.11)


def bubble(f0, d=0.03):
    t = T(d)
    f = f0 * (1 + 1.2 * t / d)
    return np.sin(phase_of(f, len(t))) * np.exp(-t / (d * 0.35)) * attack_env(len(t), 0.001)


def mission_success_R6D():
    # Bardak doluyor: perdesi yukselen sivi kabarciklari (dolma hissi) -> dolunca cam 'cin'
    d = 1.8
    x = buf(d)
    r = np.random.default_rng(9)
    fill = 0.85
    t0 = 0.0
    while t0 < fill:
        k = t0 / fill
        base = 500 + 1900 * k ** 1.3
        place(x, bubble(base * r.uniform(0.9, 1.1), r.uniform(0.02, 0.04)), t0, r.uniform(0.15, 0.35))
        t0 += r.uniform(0.015, 0.04)
    tt = T(fill)
    place(x, bp(noise(fill), 600 + 2000 * tt / fill, 1200 + 3500 * tt / fill) * 0.08 * np.sin(np.pi * tt / fill) ** 0.5, 0.0, 0.3)
    place(x, chime(nf("G6"), 1.0, 0.45), fill + 0.02, 0.4)
    place(x, chime(nf("C7"), 1.0, 0.4), fill + 0.06, 0.32)
    place(x, marimba(nf("C5"), 0.8, 0.3), fill + 0.02, 0.3)
    return finish(reverb(x, 1.1, 0.22, 0.6), 0.11)


ROUND6 = {k: v for k, v in globals().items() if "_R6" in k and callable(v)}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in ROUND6.items():
        if not only or name in only:
            write(name, fn())
