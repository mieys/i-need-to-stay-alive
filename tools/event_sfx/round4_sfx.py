"""Tur 4: gorev basladi / gorev basarili / arkadas dustu - tamamen yeni 4'er secenek (dosya adi <olay>_R4A..R4D)."""
import sys

import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, lp, hp, bp, noise, attack_env, dec,
                           bell, chime, marimba, coin, pluck, saw, thump, woodblock, pad, reverb, finish, write, fade_out)


def click(f=2500, d=0.03, tone=0.5):
    """Mekanik/dokunsal 'tik': kisa bant gecirgen gurultu + minik rezonans."""
    t = T(d)
    x = bp(noise(d), f * 0.6, f * 1.6) * np.exp(-t / 0.004)
    x += tone * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.006)
    return x * attack_env(len(t), 0.0003)


def sand(d, seed=1):
    """Akan kum: yogun, kisik granuler tikirtilar."""
    r = np.random.default_rng(seed)
    x = np.zeros(N(d))
    idx = r.integers(0, len(x), int(d * 900))
    x[idx] = r.uniform(-1, 1, len(idx))
    return bp(x, 2500, 9000)


# ---------------------------------------------------------------- gorev basladi

def mission_start_R4A():
    # Kum saati dondu: ahsap 'tak' + kum akisi + temiz bir can
    d = 1.6
    x = buf(d)
    place(x, woodblock(420, 0.14), 0.0, 0.8)
    place(x, woodblock(520, 0.12), 0.07, 0.5)
    t = T(1.0)
    place(x, sand(1.0) * np.clip(t / 0.15, 0, 1) * np.clip((1.0 - t) / 0.5, 0, 1), 0.1, 0.5)
    place(x, bell(nf("E6"), 1.2, 0.5, 3.5, 1.0, 0.25), 0.18, 0.4)
    place(x, bell(nf("B5"), 1.2, 0.5, 3.5, 1.0, 0.25), 0.18, 0.25)
    return finish(reverb(x, 1.2, 0.25, 0.8), 0.10)


def mission_start_R4B():
    # Run aktivasyonu: minorden majore cozulen yukari can arpeji + whoosh + yumusak darbe
    d = 1.8
    x = buf(d)
    for i, n in enumerate(("A4", "C5", "E5", "A5")):
        place(x, chime(nf(n), 0.8, 0.35), i * 0.09, 0.3)
    t = T(0.4)
    place(x, lp(hp(noise(0.4), 300), 600 * (12 ** (t / 0.4)), 2) * (t / 0.4) ** 2, 0.0, 0.18)
    hit = 0.4
    place(x, thump(130, 55, 0.5, 0.16), hit, 0.75)
    for n, g in (("A4", 0.3), ("C#5", 0.28), ("E5", 0.26), ("A5", 0.2)):
        place(x, chime(nf(n), 1.3, 0.6), hit, g)
    place(x, pad([nf("A3"), nf("E4"), nf("C#5")], 1.2, 0.05, 0.8, 1800), hit, 0.6)
    return finish(reverb(x, 1.6, 0.32, 1.0), 0.12)


def mission_start_R4C():
    # Muhur: derin nabiz + yukselen kristal titresim, tek kararli kapanis
    d = 1.7
    x = buf(d)
    for i, at in enumerate((0.0, 0.32, 0.56)):
        place(x, thump(70, 40, 0.4, 0.14, 0.04, 0.004), at, 0.6 + 0.15 * i)
    t = T(0.75)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * (6 + 14 * t / 0.75) * t)
    shim = (np.sin(phase_of(nf("E6") * (1 + 0.5 * t / 0.75), len(t))) + 0.5 * np.sin(phase_of(nf("B6") * (1 + 0.5 * t / 0.75), len(t))))
    place(x, shim * trem * (t / 0.75) ** 2, 0.0, 0.12)
    hit = 0.76
    place(x, thump(110, 42, 0.8, 0.3), hit, 1.0)
    place(x, bell(nf("E5"), 1.0, 0.45, 1.41, 1.2, 0.2), hit, 0.35)
    place(x, bell(nf("B5"), 1.0, 0.4, 1.41, 1.0, 0.2), hit, 0.22)
    return finish(reverb(x, 1.5, 0.3, 0.9), 0.12)


def mission_start_R4D():
    # Gerilim nabzi: hizlanan alcak sentez darbeleri + yukselis -> tok, genis vurus
    d = 1.9
    x = buf(d)
    times = (0.0, 0.22, 0.4, 0.54, 0.65)
    for i, at in enumerate(times):
        t = T(0.2)
        p = lp(saw(nf("D2"), 0.2, 20), 300 + 1200 * np.exp(-t / 0.04), 2) * np.exp(-t / 0.08)
        place(x, p, at, 0.5 + 0.1 * i)
    t = T(0.72)
    place(x, lp(hp(noise(0.72), 400), 500 * (14 ** (t / 0.72)), 2) * (t / 0.72) ** 2.2, 0.0, 0.2)
    hit = 0.75
    place(x, thump(100, 36, 1.0, 0.35), hit, 1.0)
    place(x, lp(saw(nf("D2"), 1.0, 30) + saw(nf("A2") * 1.003, 1.0, 30), 900, 2) * dec(1.0, 0.35, 0.005), hit, 0.35)
    place(x, lp(hp(noise(0.8), 3000), 9000, 1) * dec(0.8, 0.18), hit, 0.08)
    return finish(np.tanh(reverb(x, 1.5, 0.28, 0.9) * 1.3) / 1.3, 0.13)


# ---------------------------------------------------------------- gorev basarili (dokunsal, tatmin edici, temiz son)

def mission_success_R4A():
    # Onay: tok 'tik' + yukari iki marimba notasi + kristal 'ding' - kisa ve net, isaret kutusu tiklanir gibi
    d = 1.4
    x = buf(d)
    place(x, click(1800, 0.03), 0.0, 0.6)
    place(x, marimba(nf("G5"), 0.5, 0.18), 0.02, 0.55)
    place(x, marimba(nf("C6"), 0.7, 0.25), 0.11, 0.6)
    place(x, chime(nf("C7"), 0.9, 0.45), 0.11, 0.25)
    place(x, chime(nf("G6"), 0.9, 0.4), 0.115, 0.18)
    place(x, pad([nf("C5"), nf("E5"), nf("G5")], 0.8, 0.03, 0.6, 2400), 0.11, 0.45)
    return finish(reverb(x, 1.0, 0.22, 0.6), 0.11)


def mission_success_R4B():
    # Kilit acildi: mekanik tikirti-takirti (yaylar, dili) + 'klak' + sicak can akoru
    d = 1.7
    x = buf(d)
    r = np.random.default_rng(3)
    for i, at in enumerate((0.0, 0.05, 0.09, 0.12)):
        place(x, click(r.uniform(2500, 4000), 0.03, 0.4), at, 0.35)
    place(x, click(1300, 0.05, 0.7), 0.2, 0.7)
    place(x, thump(240, 140, 0.12, 0.03), 0.2, 0.5)
    for n, g in (("C5", 0.4), ("E5", 0.35), ("G5", 0.3), ("C6", 0.25)):
        place(x, bell(nf(n), 1.2, 0.45, 1.41, 0.7, 0.25), 0.26, g)
    return finish(reverb(x, 1.1, 0.24, 0.7), 0.11)


def mission_success_R4C():
    # Odul kesesi: kesenin icine dusen paralar + yumusak 'tuf' + tek sicak can
    d = 1.5
    x = buf(d)
    r = np.random.default_rng(14)
    for i in range(7):
        at = 0.25 * (i / 6) ** 0.8 + r.uniform(0, 0.015)
        place(x, lp(coin(r.uniform(2000, 3400), 0.3, 0.09), 6000, 1), at, 0.22)
    place(x, lp(noise(0.12), 700, 2) * dec(0.12, 0.03), 0.3, 0.6)
    place(x, thump(150, 90, 0.15, 0.04), 0.3, 0.45)
    place(x, bell(nf("G5"), 1.1, 0.45, 1.41, 0.9, 0.25), 0.36, 0.45)
    place(x, bell(nf("C6"), 1.1, 0.45, 1.41, 0.9, 0.25), 0.36, 0.3)
    return finish(reverb(x, 1.1, 0.22, 0.7), 0.11)


def mission_success_R4D():
    # Kristal tamam: uc cam tini birlikte (majör) + yumusak acilan hava, kisa temiz kuyruk
    d = 1.6
    x = buf(d)
    place(x, click(3200, 0.02, 0.3), 0.0, 0.3)
    for n, g in (("C6", 0.4), ("E6", 0.32), ("G6", 0.28), ("C5", 0.3)):
        place(x, chime(nf(n), 1.2, 0.5), 0.005, g)
    place(x, pad([nf("C5"), nf("G5"), nf("E6")], 1.0, 0.06, 0.7, 3000), 0.0, 0.5)
    return finish(reverb(x, 1.3, 0.26, 0.7), 0.11)


# ---------------------------------------------------------------- arkadas dustu

def ally_down_R4A():
    # Dusen kalkan: metal kalkan yere carpar, sekip titreyerek durur
    d = 1.6
    x = buf(d)
    place(x, coin(620, 1.0, 0.45), 0.0, 0.5)
    place(x, coin(910, 0.9, 0.35), 0.002, 0.3)
    place(x, thump(140, 70, 0.3, 0.08), 0.0, 0.6)
    place(x, bp(noise(0.08), 1000, 6000) * dec(0.08, 0.015), 0.0, 0.4)
    # sekmeler: giderek sik ve kisik
    at, gap, g = 0.0, 0.18, 0.45
    for _ in range(7):
        at += gap
        place(x, coin(640, 0.25, 0.08), at, g * 0.5)
        place(x, bp(noise(0.03), 1000, 5000) * dec(0.03, 0.006), at, g * 0.4)
        gap *= 0.7
        g *= 0.75
    return finish(reverb(x, 1.2, 0.25, 0.8), 0.10)


def ally_down_R4B():
    # Ruh cikisi: havali inen whoosh + kisik minör 'ooh' koro (formant) + uzak can
    d = 2.2
    x = buf(d)
    t = T(1.6)
    vox = np.zeros(len(t))
    for f in (nf("A3"), nf("C4"), nf("E4")):
        vox += saw(f * (1 + 0.004 * np.sin(2 * np.pi * 4.5 * t)), 1.6, 20)
    vox = bp(vox, 300, 900) + 0.5 * bp(vox, 600, 1100)
    vox *= np.clip(t / 0.4, 0, 1) * np.clip((1.6 - t) / 0.8, 0, 1)
    place(x, vox, 0.05, 0.35)
    w = lp(hp(noise(1.2), 400), 3000 * (0.15 ** (T(1.2) / 1.2)), 2) * np.sin(np.pi * T(1.2) / 1.2)
    place(x, w, 0.0, 0.25)
    place(x, bell(nf("E5"), 1.4, 0.6, 2.0, 0.6, 0.1), 0.0, 0.2)
    return finish(reverb(x, 2.0, 0.38, 1.2, 3000), 0.10)


def ally_down_R4C():
    # Gerilim darbesi: iki bogulmus davul + gergin, uyumsuz yay kumesi (tehlike hissi)
    d = 1.9
    x = buf(d)
    place(x, thump(85, 40, 0.5, 0.18), 0.0, 0.8)
    place(x, thump(85, 40, 0.5, 0.18), 0.2, 0.7)
    t = T(1.3)
    cluster = np.zeros(len(t))
    for n in ("D4", "D#4", "A4", "G#4"):
        cluster += saw(nf(n) * (1 + 0.006 * np.sin(2 * np.pi * 6 * t + len(n))), 1.3, 24)
    cluster = lp(cluster * np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.5), 2200, 2) / 4
    place(x, cluster, 0.2, 0.6)
    return finish(reverb(x, 1.6, 0.3, 1.0, 3000), 0.10)


def ally_down_R4D():
    # Kopan tel: gerilen tel 'tiing' perde kayarak kopar + vizilti + tok darbe
    d = 1.6
    x = buf(d)
    t = T(0.3)
    f = nf("E5") * (1 + 0.05 * (t / 0.3))
    place(x, np.sin(phase_of(f, len(t))) * np.clip(t / 0.05, 0, 1) * 0.6, 0.0, 0.35)
    snap = 0.3
    place(x, bp(noise(0.03), 2000, 9000) * dec(0.03, 0.005), snap, 0.6)
    t = T(1.0)
    f2 = nf("E5") * 1.05 * (0.25 ** (np.clip(t / 0.5, 0, 1)))
    buzz = saw(f2, 1.0, 25) * np.exp(-t / 0.25)
    place(x, lp(buzz, 2500, 1), snap, 0.4)
    place(x, thump(90, 45, 0.6, 0.2), snap + 0.02, 0.7)
    return finish(reverb(x, 1.5, 0.3, 0.9), 0.10)


ROUND4 = {k: v for k, v in globals().items() if "_R4" in k and callable(v)}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in ROUND4.items():
        if not only or name in only:
            write(name, fn())
