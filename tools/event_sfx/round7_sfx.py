"""Tur 7: Topla gorevi kristal toplama (4) + Hadime Q takimlari (4 x kitap acilisi + lanet dususu + demo)."""
import sys

import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, onepole_lp, lp, hp, bp, noise, attack_env, dec,
                           bell, chime, coin, saw, thump, pad, reverb, finish, write, fade_out, SR)


# ================================================================ kristal toplama (kisa, sik calar)

def crystal_A():
    # Cam tin: tek, temiz kristal tini + minik pirilti
    d = 0.5
    x = buf(d)
    place(x, chime(nf("E7"), 0.45, 0.22), 0.0, 0.6)
    place(x, chime(nf("B7"), 0.3, 0.1), 0.02, 0.15)
    return finish(reverb(x, 0.6, 0.18, 0.3), 0.09)


def crystal_B():
    # Kristal sikirti: uc kucuk cam parcasi hizlica + yumusak parilti
    d = 0.5
    x = buf(d)
    for i, (f, g) in enumerate(((nf("A6"), 0.45), (nf("E7"), 0.35), (nf("C#7"), 0.3))):
        place(x, chime(f, 0.3, 0.09), i * 0.03, g)
    place(x, bp(noise(0.05), 5000, 11000) * dec(0.05, 0.01), 0.0, 0.08)
    return finish(reverb(x, 0.6, 0.2, 0.3), 0.09)


def crystal_C():
    # Yumusak pop + can: dokunsal alcak 'tup' ve ustune sicak can tinisi
    d = 0.5
    x = buf(d)
    t = T(0.06)
    f = 260 * (1 + 1.5 * (t / 0.06))
    place(x, np.sin(phase_of(f, len(t))) * np.exp(-t / 0.018) * attack_env(len(t), 0.002), 0.0, 0.7)
    place(x, bell(nf("G6"), 0.4, 0.15, 1.41, 0.6, 0.25), 0.012, 0.35)
    return finish(reverb(x, 0.5, 0.15, 0.25), 0.09)


def crystal_D():
    # Sihirli emis: ters kristal kabarmasi (ice cekilir) -> minik ding
    d = 0.5
    x = buf(d)
    sw = chime(nf("E7"), 0.14, 0.08)[::-1] * np.linspace(0, 1, N(0.14)) ** 2
    place(x, sw, 0.0, 0.35)
    place(x, chime(nf("B6"), 0.35, 0.16), 0.14, 0.5)
    place(x, chime(nf("E7"), 0.3, 0.12), 0.145, 0.2)
    return finish(reverb(x, 0.6, 0.18, 0.3), 0.09)


# ================================================================ Hadime Q

def whisper(d, f1=700, f2=1200, f3=2600, rate=7.0, seed=1):
    """Fisilti: formantli gurultu + hece benzeri genlik dalgalanmasi."""
    r = np.random.default_rng(seed)
    n = noise(d)
    x = bp(n, f1 * 0.7, f1 * 1.3) + 0.7 * bp(n, f2 * 0.8, f2 * 1.2) + 0.4 * bp(n, f3 * 0.85, f3 * 1.15)
    t = T(d)
    am = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * rate * t + r.uniform(0, 3))) ** 1.5
    return x * am


def page_flip(d=0.18):
    t = T(d)
    x = bp(noise(d), 1200, 6000) * np.sin(np.pi * t / d) ** 2
    return x * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 40 * t)))


# --- Takim A: Fisilti (sayfa + fisildayan koro / karanlik nefes vurusu)
def hadimeA_open():
    d = 1.6
    x = buf(d)
    place(x, page_flip(0.2), 0.0, 0.5)
    place(x, page_flip(0.15), 0.12, 0.35)
    t = T(1.3)
    w = whisper(1.3, seed=2) * np.clip(t / 0.3, 0, 1) * np.clip((1.3 - t) / 0.6, 0, 1)
    place(x, w, 0.1, 0.5)
    place(x, pad([nf("D3"), nf("F3"), nf("A3")], 1.3, 0.3, 0.7, 900), 0.1, 0.5)
    return finish(reverb(x, 1.6, 0.32, 0.9, 3000), 0.10)


def hadimeA_curse():
    d = 0.45
    x = buf(d)
    t = T(0.22)
    place(x, whisper(0.22, 500, 900, 2000, 12, 5) * np.exp(-t / 0.06) * attack_env(len(t), 0.004), 0.0, 0.5)
    place(x, thump(85, 45, 0.3, 0.07, 0.03, 0.003), 0.0, 0.7)
    return finish(reverb(x, 0.9, 0.22, 0.4, 2500), 0.10)


# --- Takim B: Kara zil (uyumsuz alcak zil / kucuk karanlik zil vurusu)
def hadimeB_open():
    d = 1.8
    x = buf(d)
    sw = bell(nf("D4"), 0.5, 0.25, 2.4, 1.2, 0.1)[::-1] * np.linspace(0, 1, N(0.5)) ** 2
    place(x, sw, 0.0, 0.35)
    place(x, bell(nf("D3"), 1.4, 0.6, 2.4, 1.8, 0.1), 0.5, 0.6)
    place(x, bell(nf("G#3"), 1.4, 0.55, 2.4, 1.4, 0.1), 0.5, 0.35)
    return finish(reverb(x, 1.8, 0.33, 1.0, 3000), 0.11)


def hadimeB_curse():
    d = 0.5
    x = buf(d)
    place(x, bell(nf("C#5"), 0.4, 0.12, 2.4, 1.2, 0.1), 0.0, 0.45)
    place(x, bell(nf("G5"), 0.4, 0.1, 2.4, 1.0, 0.1), 0.0, 0.2)
    place(x, thump(95, 50, 0.25, 0.06), 0.0, 0.6)
    return finish(reverb(x, 0.9, 0.22, 0.4), 0.10)


# --- Takim C: Mor alev (karanlik ates tutusmasi / alevli karanlik darbe)
def crackle(d, density=60, seed=3):
    r = np.random.default_rng(seed)
    x = np.zeros(N(d))
    idx = r.integers(0, len(x), int(d * density))
    x[idx] = r.uniform(-1, 1, len(idx))
    return bp(x, 1500, 7000)


def hadimeC_open():
    d = 1.6
    x = buf(d)
    t = T(0.5)
    place(x, lp(noise(0.5), 400 + 2600 * (t / 0.5), 2) * (t / 0.5) ** 1.5, 0.0, 0.5)
    t2 = T(1.0)
    roar = lp(noise(1.0), 900, 2) * np.clip(t2 / 0.05, 0, 1) * np.exp(-t2 / 0.4)
    place(x, roar, 0.45, 0.7)
    place(x, crackle(1.0, 80) * np.exp(-t2 / 0.5), 0.45, 0.6)
    place(x, lp(saw(nf("D2"), 1.0, 20) + saw(nf("D2") * 1.01, 1.0, 20), 400, 2) * np.clip(t2 / 0.1, 0, 1) * np.exp(-t2 / 0.6), 0.45, 0.4)
    return finish(reverb(x, 1.3, 0.28, 0.9, 3500), 0.11)


def hadimeC_curse():
    d = 0.45
    x = buf(d)
    t = T(0.3)
    place(x, lp(noise(0.3), 1500, 2) * np.exp(-t / 0.06) * attack_env(len(t), 0.002), 0.0, 0.7)
    place(x, crackle(0.3, 120, 7) * np.exp(-t / 0.1), 0.0, 0.5)
    place(x, thump(100, 45, 0.3, 0.07), 0.0, 0.6)
    return finish(reverb(x, 0.8, 0.2, 0.4), 0.10)


# --- Takim D: Ruh ciglik (yukselen hayalet inlemesi / inen hayalet 'vuuu' + tok)
def ghost_tone(f0, f1, d, vib=6.0):
    t = T(d)
    f = f0 * (f1 / f0) ** (t / d) * (1 + 0.02 * np.sin(2 * np.pi * vib * t))
    x = np.sin(phase_of(f, len(t))) + 0.35 * np.sin(phase_of(f * 2.01, len(t))) + 0.15 * np.sin(phase_of(f * 3.0, len(t)))
    return x


def hadimeD_open():
    d = 1.8
    x = buf(d)
    t = T(1.3)
    wail = ghost_tone(nf("A4"), nf("E5"), 1.3) * np.clip(t / 0.35, 0, 1) * np.clip((1.3 - t) / 0.6, 0, 1)
    place(x, lp(wail, 2500, 1), 0.0, 0.35)
    place(x, lp(ghost_tone(nf("A4") * 1.5, nf("E5") * 1.5, 1.3) * np.clip(t / 0.5, 0, 1) * np.clip((1.3 - t) / 0.6, 0, 1), 2500, 1), 0.05, 0.12)
    place(x, pad([nf("A2"), nf("E3")], 1.5, 0.4, 0.7, 500), 0.0, 0.6)
    return finish(reverb(x, 2.0, 0.38, 1.1, 3000), 0.10)


def hadimeD_curse():
    d = 0.55
    x = buf(d)
    t = T(0.3)
    place(x, lp(ghost_tone(nf("E5"), nf("A4"), 0.3, 9), 2200, 1) * np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.1), 0.0, 0.35)
    place(x, thump(90, 45, 0.3, 0.07, 0.03, 0.004), 0.12, 0.65)
    return finish(reverb(x, 1.0, 0.26, 0.4), 0.10)


# ================================================================ demo (oyundaki gibi: acilis + 3'erli lanet yagmurlari)

def shift(x, ratio):
    """Basit perde kaydirma (yeniden ornekleme) - oyundaki pitch_scale gibi."""
    n = int(len(x) / ratio)
    idx = np.arange(n) * ratio
    return np.stack([np.interp(idx, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], axis=1)


def demo(open_st, curse_st, curse_gain_db=-9.0, open_gain_db=-4.0):
    """Oyundaki SKILL_SFX seviyeleriyle: acilis -4 dB, her lanet -9 dB (rastgele perde 0.92-1.08)."""
    r = np.random.default_rng(11)
    d = 3.8
    out = np.zeros((N(d), 2))
    place(out, open_st, 0.0, 10 ** (open_gain_db / 20))
    for v in (1.0, 2.0, 3.0):
        for k in range(3):
            c = shift(curse_st, r.uniform(0.92, 1.08))
            place(out, c, v + k * r.uniform(0.0, 0.05), 10 ** (curse_gain_db / 20))
    peak = np.max(np.abs(out))
    ## Oyundaki goreli seviyeler korunur, dinleme icin tepe 0.85'e cekilir.
    return out * (0.85 / peak if peak > 0 else 1.0)


SETS = {"A": (hadimeA_open, hadimeA_curse), "B": (hadimeB_open, hadimeB_curse),
        "C": (hadimeC_open, hadimeC_curse), "D": (hadimeD_open, hadimeD_curse)}

if __name__ == "__main__":
    for k, fn in (("crystal_A", crystal_A), ("crystal_B", crystal_B), ("crystal_C", crystal_C), ("crystal_D", crystal_D)):
        write(k, fn())
    for k, (fo, fc) in SETS.items():
        o, c = fo(), fc()
        write("hadime_q_open_%s" % k, o)
        write("hadime_q_curse_%s" % k, c)
        write("hadime_q_demo_%s" % k, demo(o, c))
